//! One tab: a `Session` painted on a canvas, with keyboard, mouse, clipboard
//! and a find bar.

use std::collections::HashMap;
use std::sync::Arc;

use futures::StreamExt;
use gpui::{
    App, BorderStyle, Bounds, ClipboardItem, ContentMask, Context, Corners, CursorStyle, EventEmitter, FocusHandle,
    Focusable, Font, FontStyle, FontWeight, Hsla, KeyDownEvent, Modifiers, MouseDownEvent, MouseMoveEvent, MouseUpEvent,
    Pixels, Point, Render, RenderImage, ScrollDelta, ScrollWheelEvent, ShapedLine, SharedString, StrikethroughStyle,
    TextRun, UnderlineStyle, Window, canvas, div, fill, font, outline, point, prelude::*, px, size,
};
use tw_terminal::{
    Attrs, CellContent, CellWidth, CursorShape, Grid, ImageLayer, ImagePixels, ImagePlacement, KeyInput, Mods,
    MouseButton, MouseInput, MousePhase, PtyRead, PtySpec, SearchMatch, Session, TerminalEvent, UnderlineKind,
};

use crate::actions::{CloseFind, Copy, Find, FindNext, FindPrev, Paste, SelectAll};
use crate::command::TabId;
use crate::theme;

const PADDING: f32 = 6.0;

/// What the workspace needs to know about a tab.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TerminalViewEvent {
    TitleChanged(String),
    Exited,
}

/// The shell either runs or never started; a tab shows either way.
enum Shell {
    Running(Session),
    Failed(String),
}

/// Where the grid was painted last frame, for turning mouse positions into cells.
#[derive(Clone, Copy)]
struct Layout {
    bounds: Bounds<Pixels>,
    cell_width: f32,
    line_height: f32,
}

struct FindState {
    query: String,
    matches: Vec<SearchMatch>,
    current: usize,
}

/// A Kitty image uploaded to the GPU, valid while its generation matches.
#[derive(Clone)]
struct CachedImage {
    generation: u64,
    width: u32,
    height: u32,
    image: Arc<RenderImage>,
    /// Frame counter of the last frame that painted it; unplaced images age out by it.
    last_used: u64,
}

/// How many images stay on the GPU after they leave the screen, so a picker
/// stepping back to a recent preview does not upload it again.
const RECENT_IMAGES: usize = 8;

pub struct TerminalView {
    pub id: TabId,
    shell: Shell,
    focus_handle: FocusHandle,
    font: Font,
    title: String,
    layout: Option<Layout>,
    find: Option<FindState>,
    /// Kitty images by id: everything placed this frame plus a few recent ones.
    images: HashMap<u32, CachedImage>,
    frame: u64,
}

impl EventEmitter<TerminalViewEvent> for TerminalView {}

impl Focusable for TerminalView {
    fn focus_handle(&self, _: &App) -> FocusHandle {
        self.focus_handle.clone()
    }
}

impl TerminalView {
    pub fn new(id: TabId, cx: &mut Context<Self>) -> Self {
        let shell = match Session::spawn(PtySpec::login_shell(80, 24)) {
            Ok((session, mut output)) => {
                cx.spawn(async move |this, cx| {
                    while let Some(first) = output.next().await {
                        // Drain the burst so one frame covers everything that arrived.
                        let mut batch = vec![first];
                        while let Ok(more) = output.try_recv() {
                            batch.push(more);
                        }
                        let alive = this
                            .update(cx, |view, cx| {
                                if let Shell::Running(session) = &mut view.shell {
                                    let bytes: usize = batch.iter().map(PtyRead::len).sum();
                                    let started = std::time::Instant::now();
                                    for read in batch {
                                        session.feed(read);
                                    }
                                    let took = started.elapsed();
                                    if took.as_millis() >= 5 {
                                        log::debug!("tab {:?}: fed {} bytes in {} ms", view.id, bytes, took.as_millis());
                                    } else {
                                        log::debug!("tab {:?}: {} bytes from the shell", view.id, bytes);
                                    }
                                }
                                view.after_output(cx);
                            })
                            .is_ok();
                        if !alive {
                            break;
                        }
                    }
                })
                .detach();
                Shell::Running(session)
            }
            Err(error) => Shell::Failed(error.to_string()),
        };
        Self {
            id,
            shell,
            focus_handle: cx.focus_handle(),
            font: font(theme::FONT_FAMILY),
            title: String::new(),
            layout: None,
            find: None,
            images: HashMap::new(),
            frame: 0,
        }
    }

    pub fn title(&self) -> &str {
        if self.title.is_empty() { "shell" } else { &self.title }
    }

    /// Send text as if typed (used by plugins and, later, the socket).
    pub fn write(&mut self, text: &str, cx: &mut Context<Self>) {
        if let Shell::Running(session) = &mut self.shell {
            if let Err(error) = session.write(text.as_bytes()) {
                log::warn!("write to shell: {error}");
            }
            cx.notify();
        }
    }

    fn after_output(&mut self, cx: &mut Context<Self>) {
        let Shell::Running(session) = &mut self.shell else { return };
        for event in session.take_events() {
            match event {
                TerminalEvent::TitleChanged(title) => {
                    self.title = title.clone();
                    cx.emit(TerminalViewEvent::TitleChanged(title));
                }
                TerminalEvent::PwdChanged(_) | TerminalEvent::Bell => {}
                TerminalEvent::Exited(_) => cx.emit(TerminalViewEvent::Exited),
            }
        }
        cx.notify();
    }

    // --- keyboard -----------------------------------------------------------

    fn on_key_down(&mut self, event: &KeyDownEvent, _: &mut Window, cx: &mut Context<Self>) {
        let keystroke = &event.keystroke;
        // cmd combinations belong to the app (tabs, quit, copy), never to the shell.
        if keystroke.modifiers.platform {
            return;
        }
        if self.find.is_some() {
            let edited = match (keystroke.key.as_str(), typed_text(keystroke.key_char.as_deref())) {
                ("backspace", _) => self.find.as_mut().map(|find| find.query.pop()).is_some(),
                (_, Some(text)) => {
                    if let Some(find) = &mut self.find {
                        find.query.push_str(&text);
                    }
                    true
                }
                (_, None) => false,
            };
            if edited {
                cx.stop_propagation();
                self.run_search(cx);
            }
            return;
        }
        let Shell::Running(session) = &mut self.shell else { return };
        let input = KeyInput::from_name(&keystroke.key, mods_from(&keystroke.modifiers), typed_text(keystroke.key_char.as_deref()));
        if let Err(error) = session.key(&input) {
            log::warn!("key: {error}");
        }
        session.scroll_to_bottom();
        cx.stop_propagation();
        cx.notify();
    }

    // --- mouse ---------------------------------------------------------------

    fn on_mouse_down(&mut self, event: &MouseDownEvent, window: &mut Window, cx: &mut Context<Self>) {
        window.focus(&self.focus_handle);
        let Some(button) = button_from(event.button) else { return };
        self.send_mouse(MousePhase::Press(button), event.position, &event.modifiers, cx);
    }

    fn on_mouse_up(&mut self, event: &MouseUpEvent, _: &mut Window, cx: &mut Context<Self>) {
        let Some(button) = button_from(event.button) else { return };
        self.send_mouse(MousePhase::Release(button), event.position, &event.modifiers, cx);
    }

    fn on_mouse_move(&mut self, event: &MouseMoveEvent, _: &mut Window, cx: &mut Context<Self>) {
        let held = event.pressed_button.and_then(button_from);
        self.send_mouse(MousePhase::Move { held }, event.position, &event.modifiers, cx);
    }

    fn on_scroll(&mut self, event: &ScrollWheelEvent, _: &mut Window, cx: &mut Context<Self>) {
        let lines = match event.delta {
            ScrollDelta::Lines(delta) => delta.y,
            ScrollDelta::Pixels(delta) => f32::from(delta.y) / (theme::FONT_SIZE * theme::LINE_HEIGHT_FACTOR),
        };
        if lines.abs() < 0.01 {
            return;
        }
        self.send_mouse(MousePhase::Wheel { lines }, event.position, &event.modifiers, cx);
    }

    fn send_mouse(&mut self, phase: MousePhase, position: Point<Pixels>, modifiers: &Modifiers, cx: &mut Context<Self>) {
        let Some(input) = self.mouse_input(phase, position, modifiers) else { return };
        let Shell::Running(session) = &mut self.shell else { return };
        if let Err(error) = session.mouse(&input) {
            log::warn!("mouse: {error}");
        }
        // Plain pointer motion changes nothing visible; everything else may.
        if !matches!(phase, MousePhase::Move { held: None }) {
            cx.notify();
        }
    }

    fn mouse_input(&self, phase: MousePhase, position: Point<Pixels>, modifiers: &Modifiers) -> Option<MouseInput> {
        let layout = self.layout?;
        let x = f32::from(position.x - layout.bounds.origin.x).max(0.0);
        let y = f32::from(position.y - layout.bounds.origin.y).max(0.0);
        Some(MouseInput {
            phase,
            col: (x / layout.cell_width).floor() as u16,
            row: (y / layout.line_height).floor() as u16,
            x,
            y,
            mods: mods_from(modifiers),
        })
    }

    // --- clipboard and find ----------------------------------------------------

    fn copy(&mut self, _: &Copy, _: &mut Window, cx: &mut Context<Self>) {
        let Shell::Running(session) = &self.shell else { return };
        match session.selected_text() {
            Ok(Some(text)) => cx.write_to_clipboard(ClipboardItem::new_string(text)),
            Ok(None) => {}
            Err(error) => log::warn!("copy: {error}"),
        }
    }

    fn paste(&mut self, _: &Paste, _: &mut Window, cx: &mut Context<Self>) {
        let Some(text) = cx.read_from_clipboard().and_then(|item| item.text()) else { return };
        let Shell::Running(session) = &mut self.shell else { return };
        if let Err(error) = session.paste(&text) {
            log::warn!("paste: {error}");
        }
        session.scroll_to_bottom();
        cx.notify();
    }

    fn select_all(&mut self, _: &SelectAll, _: &mut Window, cx: &mut Context<Self>) {
        let Shell::Running(session) = &mut self.shell else { return };
        if let Err(error) = session.select_all() {
            log::warn!("select all: {error}");
        }
        cx.notify();
    }

    fn find(&mut self, _: &Find, _: &mut Window, cx: &mut Context<Self>) {
        if self.find.is_none() {
            self.find = Some(FindState { query: String::new(), matches: Vec::new(), current: 0 });
        }
        cx.notify();
    }

    fn find_next(&mut self, _: &FindNext, _: &mut Window, cx: &mut Context<Self>) {
        self.step_find(1, cx);
    }

    fn find_prev(&mut self, _: &FindPrev, _: &mut Window, cx: &mut Context<Self>) {
        self.step_find(-1, cx);
    }

    fn close_find(&mut self, _: &CloseFind, _: &mut Window, cx: &mut Context<Self>) {
        self.find = None;
        if let Shell::Running(session) = &mut self.shell {
            if let Err(error) = session.clear_selection() {
                log::warn!("clear selection: {error}");
            }
            session.scroll_to_bottom();
        }
        cx.notify();
    }

    fn run_search(&mut self, cx: &mut Context<Self>) {
        let (Some(find), Shell::Running(session)) = (&mut self.find, &mut self.shell) else { return };
        match session.search(&find.query) {
            Ok(matches) => {
                find.matches = matches;
                find.current = 0;
                let shown = match find.matches.first() {
                    Some(first) => session.show_match(first),
                    None => session.clear_selection(),
                };
                if let Err(error) = shown {
                    log::warn!("find: {error}");
                }
            }
            Err(error) => log::warn!("find: {error}"),
        }
        cx.notify();
    }

    fn step_find(&mut self, delta: isize, cx: &mut Context<Self>) {
        let (Some(find), Shell::Running(session)) = (&mut self.find, &mut self.shell) else { return };
        let count = find.matches.len() as isize;
        if count == 0 {
            return;
        }
        find.current = (find.current as isize + delta).rem_euclid(count) as usize;
        if let Err(error) = session.show_match(&find.matches[find.current]) {
            log::warn!("find: {error}");
        }
        cx.notify();
    }

    // --- layout and paint --------------------------------------------------------

    /// Runs inside the canvas prepaint: fit the grid to the bounds, then
    /// snapshot it into something paint can draw without touching `self`.
    fn layout(&mut self, bounds: Bounds<Pixels>, window: &mut Window, cx: &mut Context<Self>) -> Option<PaintPlan> {
        let Shell::Running(session) = &mut self.shell else { return None };
        let font_size = px(theme::FONT_SIZE);
        let font_id = cx.text_system().resolve_font(&self.font);
        let cell_width = cx
            .text_system()
            .advance(font_id, font_size, 'M')
            .map(|advance| advance.width)
            .unwrap_or(font_size * 0.6);
        let line_height = (font_size * theme::LINE_HEIGHT_FACTOR).round();
        self.layout = Some(Layout { bounds, cell_width: f32::from(cell_width), line_height: f32::from(line_height) });

        let cols = (f32::from(bounds.size.width) / f32::from(cell_width)).floor().max(2.0) as u16;
        let rows = (f32::from(bounds.size.height) / f32::from(line_height)).floor().max(1.0) as u16;
        match session.resize(cols, rows, f32::from(cell_width) as u16, f32::from(line_height) as u16) {
            Ok(true) => log::debug!("tab {:?}: grid {cols}x{rows}, cell {cell_width:?}x{line_height:?}", self.id),
            Ok(false) => {}
            Err(error) => log::warn!("resize: {error}"),
        }

        let started = std::time::Instant::now();
        let grid = match session.grid(theme::term) {
            Ok(grid) => grid,
            Err(error) => {
                log::warn!("grid: {error}");
                return None;
            }
        };
        let grid_took = started.elapsed();
        let mut plan = PaintPlan::build(&grid, &self.font, font_size, cell_width, line_height, window);
        let plan_took = started.elapsed() - grid_took;
        if grid_took.as_millis() + plan_took.as_millis() >= 10 {
            log::debug!("tab {:?}: grid {} ms, text layout {} ms", self.id, grid_took.as_millis(), plan_took.as_millis());
        }

        // Upload new or changed images once, keep the ones still placed plus a few recent
        // ones, forget the rest. One image usually has many placements (a virtual placement
        // is one run per row), so entries added earlier in this same pass count as hits too.
        self.frame += 1;
        let frame = self.frame;
        let mut kept: HashMap<u32, CachedImage> = HashMap::new();
        let mut placed = 0;
        for placement in &grid.images {
            let hit = kept
                .get(&placement.image_id)
                .or_else(|| self.images.get(&placement.image_id))
                .filter(|c| c.generation == placement.generation)
                .cloned();
            let mut cached = match hit {
                Some(cached) => cached,
                None => match session.image_pixels(placement.image_id) {
                    Ok(Some(pixels)) => {
                        let started = std::time::Instant::now();
                        let (w, h) = (pixels.width, pixels.height);
                        let cached = upload(pixels, frame);
                        log::debug!("tab {:?}: uploaded image {} ({w}x{h}) in {} ms", self.id, placement.image_id, started.elapsed().as_millis());
                        cached
                    }
                    Ok(None) => continue,
                    Err(error) => {
                        log::warn!("kitty image {}: {error}", placement.image_id);
                        continue;
                    }
                },
            };
            cached.last_used = frame;
            plan.images.push(ImagePaint::new(placement, &cached, cell_width, line_height));
            if kept.insert(placement.image_id, cached).is_none() {
                placed += 1;
            }
        }
        // Carry over the most recently used unplaced images, newest first, up to the limit.
        let mut recent: Vec<(u32, CachedImage)> =
            self.images.iter().filter(|(id, _)| !kept.contains_key(id)).map(|(id, c)| (*id, c.clone())).collect();
        recent.sort_by_key(|(_, c)| std::cmp::Reverse(c.last_used));
        for (id, cached) in recent.into_iter().take(RECENT_IMAGES.saturating_sub(placed)) {
            kept.insert(id, cached);
        }
        let previously_placed = self.images.values().filter(|c| c.last_used == frame - 1).count();
        if placed != previously_placed {
            log::debug!("tab {:?}: {placed} kitty image(s) on screen", self.id);
        }
        // Textures that fell out of the cache (or were re-transmitted) leave the GPU atlas.
        for (id, old) in std::mem::replace(&mut self.images, kept) {
            let still_cached = self.images.get(&id).is_some_and(|new| Arc::ptr_eq(&new.image, &old.image));
            if !still_cached && let Err(error) = window.drop_image(old.image) {
                log::debug!("drop image {id}: {error}");
            }
        }
        Some(plan)
    }

    fn render_find_bar(&self, find: &FindState) -> impl IntoElement {
        let status = match (find.query.is_empty(), find.matches.len()) {
            (true, _) => "type to search".to_owned(),
            (false, 0) => "no matches".to_owned(),
            (false, total) => format!("{} of {total}", find.current + 1),
        };
        div()
            .flex()
            .items_center()
            .gap_3()
            .px_3()
            .py_1()
            .bg(theme::panel())
            .border_b_1()
            .border_color(theme::border())
            .text_sm()
            .child(div().text_color(theme::accent()).child("find"))
            .child(
                div()
                    .min_w(px(220.0))
                    .px_2()
                    .rounded_sm()
                    .bg(theme::bg())
                    .text_color(theme::text())
                    .font_family(theme::FONT_FAMILY)
                    .child(format!("{}▏", find.query)),
            )
            .child(div().text_color(theme::muted()).child(status))
            .child(div().text_xs().text_color(theme::muted()).child("enter next · shift-enter previous · esc close"))
    }
}

impl Render for TerminalView {
    fn render(&mut self, _: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let key_context = if self.find.is_some() { "Terminal Find" } else { "Terminal" };
        let find_bar = self.find.as_ref().map(|find| self.render_find_bar(find));
        let body = match &self.shell {
            Shell::Running(_) => {
                let view = cx.entity();
                canvas(
                    move |bounds, window, cx| view.update(cx, |this, cx| this.layout(bounds, window, cx)),
                    |bounds, plan, window, cx| {
                        if let Some(plan) = plan {
                            plan.paint(bounds, window, cx);
                        }
                    },
                )
                .size_full()
                .into_any_element()
            }
            Shell::Failed(error) => div()
                .p_4()
                .text_color(theme::error())
                .child(format!("could not start the shell: {error}"))
                .into_any_element(),
        };
        div()
            .key_context(key_context)
            .track_focus(&self.focus_handle)
            .on_action(cx.listener(Self::copy))
            .on_action(cx.listener(Self::paste))
            .on_action(cx.listener(Self::select_all))
            .on_action(cx.listener(Self::find))
            .on_action(cx.listener(Self::find_next))
            .on_action(cx.listener(Self::find_prev))
            .on_action(cx.listener(Self::close_find))
            .on_key_down(cx.listener(Self::on_key_down))
            .on_scroll_wheel(cx.listener(Self::on_scroll))
            .on_mouse_down(gpui::MouseButton::Left, cx.listener(Self::on_mouse_down))
            .on_mouse_down(gpui::MouseButton::Right, cx.listener(Self::on_mouse_down))
            .on_mouse_down(gpui::MouseButton::Middle, cx.listener(Self::on_mouse_down))
            .on_mouse_up(gpui::MouseButton::Left, cx.listener(Self::on_mouse_up))
            .on_mouse_up(gpui::MouseButton::Right, cx.listener(Self::on_mouse_up))
            .on_mouse_up(gpui::MouseButton::Middle, cx.listener(Self::on_mouse_up))
            .on_mouse_up_out(gpui::MouseButton::Left, cx.listener(Self::on_mouse_up))
            .on_mouse_move(cx.listener(Self::on_mouse_move))
            .cursor(CursorStyle::IBeam)
            .size_full()
            .flex()
            .flex_col()
            .bg(theme::bg())
            .children(find_bar)
            .child(div().flex_1().min_h_0().p(px(PADDING)).child(body))
    }
}

/// Only text the shell should receive as typed characters. Control characters
/// ("\n" for enter, "\t" for tab) and macOS private-use code points for arrows
/// are dropped so Ghostty's encoder decides what those keys send.
fn typed_text(key_char: Option<&str>) -> Option<String> {
    key_char
        .filter(|text| !text.is_empty() && text.chars().all(|c| !c.is_control() && !('\u{e000}'..='\u{f8ff}').contains(&c)))
        .map(str::to_owned)
}

fn mods_from(modifiers: &Modifiers) -> Mods {
    let mut mods = Mods::empty();
    if modifiers.shift {
        mods |= Mods::SHIFT;
    }
    if modifiers.control {
        mods |= Mods::CTRL;
    }
    if modifiers.alt {
        mods |= Mods::ALT;
    }
    if modifiers.platform {
        mods |= Mods::SUPER;
    }
    mods
}

/// gpui's buttons are an open set (it also has navigation buttons); only these three matter here.
fn button_from(button: gpui::MouseButton) -> Option<MouseButton> {
    match button {
        gpui::MouseButton::Left => Some(MouseButton::Left),
        gpui::MouseButton::Right => Some(MouseButton::Right),
        gpui::MouseButton::Middle => Some(MouseButton::Middle),
        _ => None,
    }
}

/// Everything paint needs, computed in prepaint where `self` is available.
struct PaintPlan {
    line_height: Pixels,
    background: Hsla,
    quads: Vec<(Bounds<Pixels>, Hsla)>,
    segments: Vec<Segment>,
    cursor: Option<CursorPaint>,
    images: Vec<ImagePaint>,
}

/// One placed Kitty image. gpui paints whole images, so the full image is
/// scaled so that the visible source rectangle lands on `clip`, and the paint
/// is clipped to `clip`.
struct ImagePaint {
    layer: ImageLayer,
    clip: Bounds<Pixels>,
    full: Bounds<Pixels>,
    image: Arc<RenderImage>,
}

impl ImagePaint {
    fn new(placement: &ImagePlacement, cached: &CachedImage, cell_width: Pixels, line_height: Pixels) -> Self {
        let origin = point(
            cell_width * f32::from(placement.col) + px(placement.x_offset_px as f32),
            line_height * f32::from(placement.row) + px(placement.y_offset_px as f32),
        );
        let clip = Bounds { origin, size: size(cell_width * placement.cols as f32, line_height * placement.rows as f32) };
        let scale_x = f32::from(clip.size.width) / placement.source.width as f32;
        let scale_y = f32::from(clip.size.height) / placement.source.height as f32;
        let full = Bounds {
            origin: point(
                origin.x - px(placement.source.x as f32 * scale_x),
                origin.y - px(placement.source.y as f32 * scale_y),
            ),
            size: size(px(cached.width as f32 * scale_x), px(cached.height as f32 * scale_y)),
        };
        Self { layer: placement.layer, clip, full, image: cached.image.clone() }
    }
}

/// gpui textures are BGRA with straight alpha (see how its `img` element
/// converts decoded frames), so swap the red and blue channels.
fn upload(pixels: ImagePixels, frame: u64) -> CachedImage {
    let ImagePixels { width, height, generation, mut rgba } = pixels;
    let started = std::time::Instant::now();
    for pixel in rgba.as_chunks_mut::<4>().0 {
        pixel.swap(0, 2);
    }
    log::debug!("bgra swap of {}x{} in {} ms", width, height, started.elapsed().as_millis());
    let buffer = image::RgbaImage::from_raw(width, height, rgba).expect("session checked the buffer length");
    CachedImage {
        generation,
        width,
        height,
        image: Arc::new(RenderImage::new(vec![image::Frame::new(buffer)])),
        last_used: frame,
    }
}

/// A run of cells shaped as one line. Wide characters get their own segment so
/// a fallback glyph with an odd advance cannot shift the cells after it.
struct Segment {
    origin: Point<Pixels>,
    line: ShapedLine,
}

enum CursorPaint {
    Filled(Bounds<Pixels>, Hsla),
    Hollow(Bounds<Pixels>, Hsla),
}

/// Text being accumulated for the current segment.
struct SegmentBuilder {
    origin: Point<Pixels>,
    text: String,
    runs: Vec<TextRun>,
    last_key: Option<(Attrs, Hsla)>,
    has_text: bool,
}

impl SegmentBuilder {
    fn new(origin: Point<Pixels>) -> Self {
        Self { origin, text: String::new(), runs: Vec::new(), last_key: None, has_text: false }
    }

    fn push(&mut self, piece: &str, attrs: Attrs, color: Hsla, base: &Font) {
        let key = (attrs, color);
        match (&mut self.runs.last_mut(), self.last_key == Some(key)) {
            (Some(run), true) => run.len += piece.len(),
            _ => {
                self.runs.push(text_run(piece.len(), attrs, color, base));
                self.last_key = Some(key);
            }
        }
        self.text.push_str(piece);
    }

    fn finish(self, font_size: Pixels, window: &Window) -> Option<Segment> {
        if !self.has_text {
            return None;
        }
        let line = window.text_system().shape_line(SharedString::from(self.text), font_size, &self.runs, None);
        Some(Segment { origin: self.origin, line })
    }
}

impl PaintPlan {
    fn build(grid: &Grid<Hsla>, base: &Font, font_size: Pixels, cell_width: Pixels, line_height: Pixels, window: &Window) -> Self {
        let mut quads = Vec::new();
        let mut segments = Vec::new();
        let block_cursor_at = grid
            .cursor
            .as_ref()
            .filter(|c| c.shape == CursorShape::Block)
            .map(|c| (usize::from(c.row), usize::from(c.col)));

        for (row_index, row) in grid.rows.iter().enumerate() {
            let y = line_height * row_index as f32;
            let mut segment = SegmentBuilder::new(point(px(0.0), y));
            for (col, cell) in row.cells.iter().enumerate() {
                let x = cell_width * col as f32;
                let span = match cell.width {
                    CellWidth::Single => 1.0,
                    CellWidth::Double => 2.0,
                    CellWidth::Spacer => continue,
                };
                if let Some(bg) = cell.bg {
                    quads.push((Bounds { origin: point(x, y), size: size(cell_width * span, line_height) }, bg));
                }
                let color = if block_cursor_at == Some((row_index, col)) {
                    grid.background
                } else if cell.attrs.faint {
                    cell.fg.opacity(0.6)
                } else {
                    cell.fg
                };
                match (&cell.content, cell.width) {
                    (CellContent::Blank, _) => segment.push(" ", cell.attrs, color, base),
                    (CellContent::Text(text), CellWidth::Single) => {
                        segment.has_text = true;
                        segment.push(text, cell.attrs, color, base);
                    }
                    (CellContent::Text(text), CellWidth::Double | CellWidth::Spacer) => {
                        // Close the narrow run, shape the wide glyph alone at its own x, start a fresh run after it.
                        let done = std::mem::replace(&mut segment, SegmentBuilder::new(point(x, y)));
                        segments.extend(done.finish(font_size, window));
                        segment.has_text = true;
                        segment.push(text, cell.attrs, color, base);
                        let done = std::mem::replace(&mut segment, SegmentBuilder::new(point(x + cell_width * 2.0, y)));
                        segments.extend(done.finish(font_size, window));
                    }
                }
            }
            segments.extend(segment.finish(font_size, window));
        }

        let cursor = grid.cursor.as_ref().map(|c| {
            let origin = point(cell_width * f32::from(c.col), line_height * f32::from(c.row));
            let cell = Bounds { origin, size: size(cell_width, line_height) };
            match c.shape {
                CursorShape::Block => CursorPaint::Filled(cell, c.color),
                CursorShape::Bar => CursorPaint::Filled(Bounds { origin, size: size(px(2.0), line_height) }, c.color),
                CursorShape::Underline => CursorPaint::Filled(
                    Bounds { origin: point(origin.x, origin.y + line_height - px(2.0)), size: size(cell_width, px(2.0)) },
                    c.color,
                ),
                CursorShape::Hollow => CursorPaint::Hollow(cell, c.color),
            }
        });

        Self { line_height, background: grid.background, quads, segments, cursor, images: Vec::new() }
    }

    fn paint(self, bounds: Bounds<Pixels>, window: &mut Window, cx: &mut App) {
        let origin = bounds.origin;
        let place = |b: Bounds<Pixels>| Bounds { origin: b.origin + origin, size: b.size };
        let paint_images = |layer: ImageLayer, window: &mut Window| {
            for image in self.images.iter().filter(|image| image.layer == layer) {
                let clip = place(image.clip).intersect(&bounds);
                window.with_content_mask(Some(ContentMask { bounds: clip }), |window| {
                    if let Err(error) = window.paint_image(place(image.full), Corners::default(), image.image.clone(), 0, false) {
                        log::warn!("paint image: {error}");
                    }
                });
            }
        };

        window.paint_quad(fill(bounds, self.background));
        paint_images(ImageLayer::BelowBackground, window);
        for (b, color) in &self.quads {
            window.paint_quad(fill(place(*b), *color));
        }
        paint_images(ImageLayer::BelowText, window);
        if let Some(CursorPaint::Filled(b, color)) = &self.cursor {
            window.paint_quad(fill(place(*b), *color));
        }
        for segment in &self.segments {
            if let Err(error) = segment.line.paint(segment.origin + origin, self.line_height, window, cx) {
                log::warn!("paint line: {error}");
            }
        }
        paint_images(ImageLayer::AboveText, window);
        if let Some(CursorPaint::Hollow(b, color)) = &self.cursor {
            window.paint_quad(outline(place(*b), *color, BorderStyle::Solid));
        }
    }
}

fn text_run(len: usize, attrs: Attrs, color: Hsla, base: &Font) -> TextRun {
    let underline = match attrs.underline {
        UnderlineKind::None => None,
        UnderlineKind::Single | UnderlineKind::Double | UnderlineKind::Dotted | UnderlineKind::Dashed => {
            Some(UnderlineStyle { thickness: px(1.0), color: Some(color), wavy: false })
        }
        UnderlineKind::Curly => Some(UnderlineStyle { thickness: px(1.0), color: Some(color), wavy: true }),
    };
    TextRun {
        len,
        font: Font {
            weight: if attrs.bold { FontWeight::BOLD } else { FontWeight::NORMAL },
            style: if attrs.italic { FontStyle::Italic } else { FontStyle::Normal },
            ..base.clone()
        },
        color,
        background_color: None,
        underline,
        strikethrough: attrs.strikethrough.then(|| StrikethroughStyle { thickness: px(1.0), color: Some(color) }),
    }
}
