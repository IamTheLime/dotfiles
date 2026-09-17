//! gpui window: tabs of Ghostty terminals plus a TypeScript widget sidebar.

mod actions;
mod command;
mod markdown;
mod terminal_view;
mod theme;
mod titlebar;
mod widgets;
mod workspace;

use std::path::PathBuf;

use gpui::{App, Application, Bounds, TitlebarOptions, WindowBounds, WindowOptions, prelude::*, px, size};

use crate::workspace::Workspace;

fn main() {
    env_logger::init();
    let plugin_dir = plugin_dir();
    log::info!("plugins: {}", plugin_dir.display());
    log::info!("libghostty {} built as {:?}", tw_terminal::engine_version(), tw_terminal::engine_optimize_mode());

    Application::new().run(move |cx: &mut App| {
        actions::install(cx);
        let bounds = Bounds::centered(None, size(px(1240.), px(780.)), cx);
        cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                // Transparent title bar: the content view fills the window and
                // our tab strip lives where the title would be.
                titlebar: Some(TitlebarOptions { title: None, appears_transparent: true, traffic_light_position: None }),
                // AppKit must not drag the window itself (that steals tab drags); titlebar.rs moves it.
                is_movable: false,
                ..Default::default()
            },
            |window, cx| {
                titlebar::prepare(window);
                cx.new(|cx| Workspace::new(plugin_dir, window, cx))
            },
        )
        .expect("open the main window");
        cx.activate(true);
        cx.on_window_closed(|cx| {
            if cx.windows().is_empty() {
                cx.quit();
            }
        })
        .detach();
    });
}

/// `TW_PLUGINS` wins; otherwise the `plugins/` folder next to the workspace
/// `Cargo.toml`, so `cargo run` from anywhere finds the examples.
fn plugin_dir() -> PathBuf {
    let dir = std::env::var_os("TW_PLUGINS")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../plugins"));
    dir.canonicalize().unwrap_or(dir)
}
