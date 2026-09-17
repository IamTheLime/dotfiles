//! The window's root: the title strip (tabs plus window buttons), the active
//! terminal, the plugin sidebar, and the one place that executes `AppCommand`.

use std::collections::VecDeque;
use std::path::PathBuf;
use std::rc::Rc;

use futures::StreamExt;
use gpui::{
    App, Context, CursorStyle, Entity, FocusHandle, Focusable, KeyDownEvent, MouseButton, Pixels, Point, Render,
    Subscription, Window, div, prelude::*, px,
};
use tw_control::{ControlEvent, ControlServer};
use tw_scripting::{HostEvent, HostMessage, NodeHost, PluginState, PluginView, TabInfo};

use crate::actions::{
    self, CloseDocument, CloseTab, MinimizeWindow, MoveTabLeft, MoveTabRight, NewTab, NextTab, PrevTab, ReloadPlugins,
};
use crate::command::{AppCommand, Direction, TabId};
use crate::markdown::{self, Document};
use crate::terminal_view::{TerminalView, TerminalViewEvent};
use crate::theme;
use crate::widgets::{self, Dispatch};

const LOG_LINES: usize = 40;

struct Tab {
    id: TabId,
    view: Entity<TerminalView>,
    _events: Subscription,
}

/// The Node process that runs the plugins is either up or explains why not.
enum Plugins {
    Running(NodeHost),
    Stopped { error: String },
}

/// The control socket is either listening or explains why not.
enum Control {
    Listening(ControlServer),
    Failed(String),
}

/// A tab being dragged along the strip.
#[derive(Clone)]
struct DraggedTab {
    index: usize,
    title: String,
}

/// The pill that follows the pointer while a tab is dragged.
struct TabDragPreview {
    title: String,
    position: Point<Pixels>,
}

impl Render for TabDragPreview {
    fn render(&mut self, _: &mut Window, _: &mut Context<Self>) -> impl IntoElement {
        div().pl(self.position.x - px(30.0)).pt(self.position.y - px(12.0)).child(
            div()
                .px_3()
                .py_1()
                .rounded_md()
                .bg(theme::raised())
                .text_sm()
                .text_color(theme::text())
                .shadow_md()
                .child(self.title.clone()),
        )
    }
}

pub struct Workspace {
    tabs: Vec<Tab>,
    active: usize,
    next_tab_id: u64,
    plugin_dir: PathBuf,
    plugins: Plugins,
    plugin_names: Vec<String>,
    /// The last trees the host rendered; the sidebar draws these.
    plugin_views: Vec<PluginView>,
    control: Control,
    /// The markdown document shown at the top of the sidebar, if any.
    document: Option<Document>,
    log: VecDeque<String>,
    focus_handle: FocusHandle,
}

impl Workspace {
    pub fn new(plugin_dir: PathBuf, window: &mut Window, cx: &mut Context<Self>) -> Self {
        let mut workspace = Self {
            tabs: Vec::new(),
            active: 0,
            next_tab_id: 1,
            plugin_dir,
            plugins: Plugins::Stopped { error: "not started".to_owned() },
            plugin_names: Vec::new(),
            plugin_views: Vec::new(),
            control: Control::Failed("not started".to_owned()),
            document: None,
            log: VecDeque::new(),
            focus_handle: cx.focus_handle(),
        };
        workspace.start_plugins(window, cx);
        workspace.start_control(window, cx);
        workspace.execute(AppCommand::NewTab, window, cx);
        workspace
    }

    /// The single dispatch point. Every producer ends up here.
    pub fn execute(&mut self, command: AppCommand, window: &mut Window, cx: &mut Context<Self>) {
        let tabs_change = matches!(
            command,
            AppCommand::NewTab
                | AppCommand::CloseTab(_)
                | AppCommand::CloseActiveTab
                | AppCommand::SelectTab(_)
                | AppCommand::NextTab
                | AppCommand::PrevTab
                | AppCommand::MoveActiveTab(_)
                | AppCommand::MoveTab { .. }
        );
        match command {
            AppCommand::NewTab => self.open_tab(window, cx),
            AppCommand::CloseActiveTab => {
                if let Some(tab) = self.tabs.get(self.active) {
                    let id = tab.id;
                    self.close_tab(id, window, cx);
                }
            }
            AppCommand::CloseTab(id) => self.close_tab(id, window, cx),
            AppCommand::SelectTab(index) => self.select_tab(index, window, cx),
            AppCommand::NextTab => {
                if !self.tabs.is_empty() {
                    self.select_tab((self.active + 1) % self.tabs.len(), window, cx);
                }
            }
            AppCommand::PrevTab => {
                if !self.tabs.is_empty() {
                    self.select_tab((self.active + self.tabs.len() - 1) % self.tabs.len(), window, cx);
                }
            }
            AppCommand::WriteToTerminal { tab, text } => {
                let target = match tab {
                    Some(id) => self.tabs.iter().find(|t| t.id == id),
                    None => self.tabs.get(self.active),
                };
                match target {
                    Some(tab) => tab.view.update(cx, |view, cx| view.write(&text, cx)),
                    None => self.push_log("no tab to write to".to_owned()),
                }
            }
            AppCommand::MoveActiveTab(direction) => {
                let to = match direction {
                    Direction::Left => self.active.checked_sub(1),
                    Direction::Right => Some(self.active + 1).filter(|to| *to < self.tabs.len()),
                };
                if let Some(to) = to {
                    self.move_tab(self.active, to);
                }
            }
            AppCommand::MoveTab { from, to } => self.move_tab(from, to),
            AppCommand::ReloadPlugins => self.reload_plugins(window, cx),
            AppCommand::Log(message) => self.push_log(message),
            AppCommand::ShowDocument { title, markdown } => {
                let document = Document::new(title, &markdown);
                log::info!("document: {} ({} blocks)", document.title, document.blocks.len());
                self.document = Some(document);
            }
            AppCommand::CloseDocument => self.document = None,
        }
        if tabs_change {
            self.refresh_plugins(cx);
        }
        cx.notify();
    }

    // --- tabs ----------------------------------------------------------------

    fn open_tab(&mut self, window: &mut Window, cx: &mut Context<Self>) {
        let id = TabId(self.next_tab_id);
        self.next_tab_id += 1;
        let view = cx.new(|cx| TerminalView::new(id, cx));
        let events = cx.subscribe_in(&view, window, Self::on_terminal_event);
        self.tabs.push(Tab { id, view, _events: events });
        self.select_tab(self.tabs.len() - 1, window, cx);
    }

    fn on_terminal_event(
        &mut self,
        view: &Entity<TerminalView>,
        event: &TerminalViewEvent,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) {
        match event {
            TerminalViewEvent::TitleChanged(_) => {
                self.refresh_plugins(cx);
                cx.notify();
            }
            TerminalViewEvent::Exited => {
                let id = view.read(cx).id;
                self.execute(AppCommand::CloseTab(id), window, cx);
            }
        }
    }

    fn close_tab(&mut self, id: TabId, window: &mut Window, cx: &mut Context<Self>) {
        let Some(index) = self.tabs.iter().position(|t| t.id == id) else { return };
        // Dropping the entity drops the session, which kills the shell.
        self.tabs.remove(index);
        if self.tabs.is_empty() {
            cx.quit();
            return;
        }
        let next = if index < self.active { self.active - 1 } else { self.active };
        self.select_tab(next.min(self.tabs.len() - 1), window, cx);
    }

    /// Keeps the same tab active after the reorder.
    fn move_tab(&mut self, from: usize, to: usize) {
        if from == to || from >= self.tabs.len() || to >= self.tabs.len() {
            return;
        }
        let active_id = self.tabs[self.active].id;
        let tab = self.tabs.remove(from);
        self.tabs.insert(to, tab);
        self.active = self.tabs.iter().position(|t| t.id == active_id).unwrap_or(0);
    }

    fn select_tab(&mut self, index: usize, window: &mut Window, cx: &mut Context<Self>) {
        let Some(tab) = self.tabs.get(index) else { return };
        self.active = index;
        let handle = tab.view.read(cx).focus_handle(cx);
        window.focus(&handle);
        cx.notify();
    }

    // --- control socket ---------------------------------------------------------

    fn start_control(&mut self, window: &mut Window, cx: &mut Context<Self>) {
        match ControlServer::bind(ControlServer::default_path()) {
            Ok((server, mut events)) => {
                self.control = Control::Listening(server);
                cx.spawn_in(window, async move |this, cx| {
                    while let Some(event) = events.next().await {
                        let alive = this.update_in(cx, |ws, window, cx| ws.on_control_event(event, window, cx)).is_ok();
                        if !alive {
                            break;
                        }
                    }
                })
                .detach();
            }
            Err(error) => {
                self.push_log(format!("control socket: {error}"));
                self.control = Control::Failed(error.to_string());
            }
        }
    }

    fn on_control_event(&mut self, event: ControlEvent, window: &mut Window, cx: &mut Context<Self>) {
        match event {
            ControlEvent::Command(command) => self.execute(AppCommand::from(command), window, cx),
            ControlEvent::BadLine { line, error } => self.push_log(format!("control: {error}: {line}")),
        }
        cx.notify();
    }

    // --- plugins ---------------------------------------------------------------

    fn start_plugins(&mut self, window: &mut Window, cx: &mut Context<Self>) {
        match NodeHost::spawn(&self.plugin_dir) {
            Ok((host, mut events)) => {
                self.plugins = Plugins::Running(host);
                cx.spawn_in(window, async move |this, cx| {
                    while let Some(event) = events.next().await {
                        let alive = this.update_in(cx, |ws, window, cx| ws.on_host_event(event, window, cx)).is_ok();
                        if !alive {
                            break;
                        }
                    }
                })
                .detach();
            }
            Err(error) => {
                self.push_log(format!("plugins: {error}"));
                self.plugins = Plugins::Stopped { error: error.to_string() };
            }
        }
    }

    fn on_host_event(&mut self, event: HostEvent, window: &mut Window, cx: &mut Context<Self>) {
        match event {
            HostEvent::Message(message) => match message {
                HostMessage::Ready { plugins } => {
                    self.plugin_names = plugins;
                    self.refresh_plugins(cx);
                }
                HostMessage::Rendered { views, .. } => self.plugin_views = views,
                HostMessage::Actions { commands, .. } => {
                    for command in commands {
                        self.execute(AppCommand::from(command), window, cx);
                    }
                }
                HostMessage::Failed { message, .. } => self.push_log(format!("plugin action failed: {message}")),
                HostMessage::Changed { plugins } => {
                    self.push_log(format!("plugins reloaded: {}", plugins.join(", ")));
                    self.plugin_names = plugins;
                    self.refresh_plugins(cx);
                }
                HostMessage::Log { message } => self.push_log(message),
            },
            HostEvent::Exited(reason) => {
                self.push_log(reason.clone());
                self.plugins = Plugins::Stopped { error: reason };
                self.plugin_views.clear();
            }
        }
        cx.notify();
    }

    /// Ask the host to render again; the answer arrives as `Rendered`.
    fn refresh_plugins(&mut self, cx: &App) {
        let state = self.plugin_state(cx);
        let sent = match &mut self.plugins {
            Plugins::Running(host) => host.render(&state).map(drop),
            Plugins::Stopped { .. } => Ok(()),
        };
        if let Err(error) = sent {
            self.push_log(format!("plugins: {error}"));
        }
    }

    fn reload_plugins(&mut self, window: &mut Window, cx: &mut Context<Self>) {
        let sent = match &mut self.plugins {
            Plugins::Running(host) => host.reload(),
            Plugins::Stopped { .. } => {
                self.start_plugins(window, cx);
                Ok(())
            }
        };
        if let Err(error) = sent {
            self.push_log(format!("reload plugins: {error}"));
        }
    }

    fn plugin_action(&mut self, plugin: &str, action: &str, cx: &mut Context<Self>) {
        let state = self.plugin_state(cx);
        let sent = match &mut self.plugins {
            Plugins::Running(host) => host.action(plugin, action, &state).map(drop),
            Plugins::Stopped { .. } => Ok(()),
        };
        if let Err(error) = sent {
            self.push_log(format!("{plugin}: {error}"));
        }
    }

    fn plugin_state(&self, cx: &App) -> PluginState {
        PluginState {
            active_tab: self.active,
            tabs: self
                .tabs
                .iter()
                .map(|tab| TabInfo { id: tab.id.0, title: tab.view.read(cx).title().to_owned() })
                .collect(),
        }
    }

    fn push_log(&mut self, message: String) {
        log::info!("{message}");
        self.log.push_back(message);
        while self.log.len() > LOG_LINES {
            self.log.pop_front();
        }
    }

    /// `cmd-1`..`cmd-9` select a tab; everything else bubbles up untouched.
    fn on_key_down(&mut self, event: &KeyDownEvent, window: &mut Window, cx: &mut Context<Self>) {
        let keystroke = &event.keystroke;
        if !keystroke.modifiers.platform {
            return;
        }
        let Some(number) = keystroke.key.parse::<usize>().ok().filter(|n| (1..=9).contains(n)) else { return };
        self.execute(AppCommand::SelectTab(number - 1), window, cx);
        cx.stop_propagation();
    }

    // --- rendering ---------------------------------------------------------------

    /// The strip where macOS would draw the title: brand, tabs, and our own
    /// minimize/close buttons. Only the title label moves the window
    /// (`start_window_move` hands the mouse to macOS, which swallows any
    /// gpui drag started on the same press); dragging a tab reorders it.
    fn render_titlebar(&self, cx: &mut Context<Self>) -> impl IntoElement {
        let last = self.tabs.len().saturating_sub(1);
        let tabs = self.tabs.iter().enumerate().map(|(index, tab)| {
            let active = index == self.active;
            let title = tab.view.read(cx).title().to_owned();
            let dragged = DraggedTab { index, title: title.clone() };
            div()
                .id(("tab", index))
                .px_3()
                .py_1()
                .rounded_md()
                .cursor_pointer()
                .text_sm()
                .when(active, |el| el.bg(theme::raised()).text_color(theme::text()))
                .when(!active, |el| el.text_color(theme::muted()).hover(|s| s.bg(theme::panel())))
                .child(format!("{}  {}", index + 1, title))
                .on_click(cx.listener(move |ws, _, window, cx| ws.execute(AppCommand::SelectTab(index), window, cx)))
                .on_drag(dragged, |tab: &DraggedTab, position, _, cx| {
                    let title = tab.title.clone();
                    cx.new(|_| TabDragPreview { title, position })
                })
                .drag_over::<DraggedTab>(|style, _, _, _| {
                    style.bg(theme::accent().opacity(0.25)).border_l_2().border_color(theme::accent())
                })
                .on_drop(cx.listener(move |ws, tab: &DraggedTab, window, cx| {
                    ws.execute(AppCommand::MoveTab { from: tab.index, to: index }, window, cx)
                }))
        });
        let window_button = |id: &'static str, glyph: &'static str, hover: gpui::Hsla| {
            div()
                .id(id)
                .size(px(22.0))
                .rounded_full()
                .flex()
                .items_center()
                .justify_center()
                .text_sm()
                .text_color(theme::muted())
                .cursor_pointer()
                .hover(move |s| s.bg(hover).text_color(theme::bg()))
                .child(glyph)
        };
        div()
            .id("titlebar")
            .h(px(theme::TITLEBAR_HEIGHT))
            .w_full()
            .flex()
            .items_center()
            .px_3()
            .gap_3()
            .bg(theme::titlebar())
            .border_b_1()
            .border_color(theme::border())
            .child(
                // The window's grab handle.
                div()
                    .id("brand")
                    .px_2()
                    .py_1()
                    .rounded_md()
                    .text_xs()
                    .text_color(theme::accent())
                    .cursor(CursorStyle::OpenHand)
                    .hover(|s| s.bg(theme::panel()))
                    .on_mouse_down(MouseButton::Left, |_, window, _| crate::titlebar::start_window_move(window))
                    .child("◆ terminal_workflows"),
            )
            .child(
                div()
                    .flex()
                    .items_center()
                    .gap_1()
                    .children(tabs)
                    .child(
                        div()
                            .id("new-tab")
                            .px_2()
                            .py_1()
                            .rounded_md()
                            .cursor_pointer()
                            .text_color(theme::muted())
                            .hover(|s| s.bg(theme::panel()))
                            .child("+")
                            .on_click(cx.listener(|ws, _, window, cx| ws.execute(AppCommand::NewTab, window, cx))),
                    ),
            )
            .child(
                // Empty space: drop a tab on it to send the tab to the end.
                div()
                    .id("titlebar-space")
                    .flex_1()
                    .h_full()
                    .drag_over::<DraggedTab>(|style, _, _, _| style.bg(theme::accent().opacity(0.1)))
                    .on_drop(cx.listener(move |ws, tab: &DraggedTab, window, cx| {
                        ws.execute(AppCommand::MoveTab { from: tab.index, to: last }, window, cx)
                    })),
            )
            .child(
                div()
                    .flex()
                    .items_center()
                    .gap_2()
                    .child(window_button("minimize", "–", theme::warn()).on_click(|_, window, _| window.minimize_window()))
                    .child(window_button("close", "×", theme::error()).on_click(|_, window, _| window.remove_window())),
            )
    }

    fn render_document(&self, document: &Document, window: &Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .flex()
            .flex_col()
            .gap_2()
            .p_3()
            .rounded_md()
            .bg(theme::panel())
            .border_1()
            .border_color(theme::border())
            .child(
                div()
                    .flex()
                    .items_center()
                    .justify_between()
                    .child(div().text_xs().text_color(theme::accent()).child(document.title.clone()))
                    .child(
                        div()
                            .id("close-document")
                            .size(px(18.0))
                            .rounded_full()
                            .flex()
                            .items_center()
                            .justify_center()
                            .text_xs()
                            .text_color(theme::muted())
                            .cursor_pointer()
                            .hover(|s| s.bg(theme::raised()).text_color(theme::text()))
                            .child("×")
                            .on_click(cx.listener(|ws, _, window, cx| ws.execute(AppCommand::CloseDocument, window, cx))),
                    ),
            )
            .child(markdown::render(document, &window.text_style()))
    }

    fn render_sidebar(&self, window: &Window, cx: &mut Context<Self>) -> impl IntoElement {
        let listener = cx.listener(|ws, (plugin, action): &(String, String), _, cx| ws.plugin_action(plugin, action, cx));
        let dispatch: Dispatch =
            Rc::new(move |plugin: &str, action: &str, window, cx| listener(&(plugin.to_owned(), action.to_owned()), window, cx));

        let status = match &self.plugins {
            Plugins::Running(_) => div()
                .text_xs()
                .text_color(theme::muted())
                .child(format!("node · {} loaded · cmd-r reloads", self.plugin_names.len())),
            Plugins::Stopped { error } => div()
                .text_xs()
                .text_color(theme::error())
                .child(format!("plugins stopped · cmd-r restarts\n{error}")),
        };

        let socket = match &self.control {
            Control::Listening(server) => div()
                .text_xs()
                .text_color(theme::muted())
                .child(format!("socket  ·  {}", server.path().display())),
            Control::Failed(error) => div().text_xs().text_color(theme::error()).child(format!("socket  ·  {error}")),
        };

        div()
            .id("sidebar")
            .w(px(theme::SIDEBAR_WIDTH))
            .flex()
            .flex_col()
            .gap_3()
            .p_3()
            .border_l_1()
            .border_color(theme::border())
            .overflow_y_scroll()
            .children(self.document.as_ref().map(|document| self.render_document(document, window, cx)))
            .child(socket)
            .child(div().text_xs().text_color(theme::muted()).child(format!("plugins  ·  {}", self.plugin_dir.display())))
            .child(status)
            .children(self.plugin_views.iter().cloned().map(|view| widgets::plugin_card(view, dispatch.clone())))
            .child(div().text_xs().text_color(theme::muted()).child("log"))
            .children(self.log.iter().rev().take(8).map(|line| div().text_xs().text_color(theme::accent()).child(line.clone())))
    }
}

impl Render for Workspace {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let terminal = self.tabs.get(self.active).map(|tab| tab.view.clone());
        div()
            .key_context(actions::WORKSPACE)
            .track_focus(&self.focus_handle)
            .on_action(cx.listener(|ws, _: &NewTab, window, cx| ws.execute(AppCommand::NewTab, window, cx)))
            .on_action(cx.listener(|ws, _: &CloseTab, window, cx| ws.execute(AppCommand::CloseActiveTab, window, cx)))
            .on_action(cx.listener(|ws, _: &NextTab, window, cx| ws.execute(AppCommand::NextTab, window, cx)))
            .on_action(cx.listener(|ws, _: &PrevTab, window, cx| ws.execute(AppCommand::PrevTab, window, cx)))
            .on_action(cx.listener(|ws, _: &ReloadPlugins, window, cx| ws.execute(AppCommand::ReloadPlugins, window, cx)))
            .on_action(cx.listener(|ws, _: &MoveTabLeft, window, cx| ws.execute(AppCommand::MoveActiveTab(Direction::Left), window, cx)))
            .on_action(cx.listener(|ws, _: &MoveTabRight, window, cx| ws.execute(AppCommand::MoveActiveTab(Direction::Right), window, cx)))
            .on_action(cx.listener(|ws, _: &CloseDocument, window, cx| ws.execute(AppCommand::CloseDocument, window, cx)))
            .on_action(|_: &MinimizeWindow, window, _| window.minimize_window())
            .on_key_down(cx.listener(Self::on_key_down))
            .size_full()
            .flex()
            .flex_col()
            .bg(theme::bg())
            .text_color(theme::text())
            .child(self.render_titlebar(cx))
            .child(
                div()
                    .flex()
                    .flex_1()
                    .min_h_0()
                    .child(div().flex_1().min_w_0().children(terminal))
                    .child(self.render_sidebar(window, cx)),
            )
    }
}
