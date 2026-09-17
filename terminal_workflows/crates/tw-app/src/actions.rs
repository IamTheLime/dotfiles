use gpui::{App, KeyBinding, Menu, MenuItem, actions};

actions!(
    terminal_workflows,
    [
        NewTab, CloseTab, NextTab, PrevTab, MoveTabLeft, MoveTabRight, ReloadPlugins, CloseDocument, Quit, MinimizeWindow,
        Copy, Paste, SelectAll, Find, FindNext, FindPrev, CloseFind,
    ]
);

/// Key context of the workspace root; tab bindings only fire inside it.
pub const WORKSPACE: &str = "Workspace";
/// Key context of a terminal tab; editing bindings only fire inside it.
pub const TERMINAL: &str = "Terminal";
/// Key context while the find bar is open, nested inside `Terminal`.
pub const FIND: &str = "Find";

/// Key bindings and the macOS menu. Actions reach the focused view through
/// gpui's dispatch tree; `cmd-1`..`cmd-9` are handled as raw key presses
/// because unit actions cannot carry the tab number.
pub fn install(cx: &mut App) {
    cx.bind_keys([
        KeyBinding::new("cmd-t", NewTab, Some(WORKSPACE)),
        KeyBinding::new("cmd-w", CloseTab, Some(WORKSPACE)),
        KeyBinding::new("cmd-shift-]", NextTab, Some(WORKSPACE)),
        KeyBinding::new("cmd-shift-[", PrevTab, Some(WORKSPACE)),
        KeyBinding::new("cmd-shift-left", MoveTabLeft, Some(WORKSPACE)),
        KeyBinding::new("cmd-shift-right", MoveTabRight, Some(WORKSPACE)),
        KeyBinding::new("cmd-r", ReloadPlugins, Some(WORKSPACE)),
        KeyBinding::new("cmd-m", MinimizeWindow, None),
        KeyBinding::new("cmd-q", Quit, None),
        KeyBinding::new("cmd-c", Copy, Some(TERMINAL)),
        KeyBinding::new("cmd-v", Paste, Some(TERMINAL)),
        KeyBinding::new("cmd-a", SelectAll, Some(TERMINAL)),
        KeyBinding::new("cmd-f", Find, Some(TERMINAL)),
        KeyBinding::new("enter", FindNext, Some(FIND)),
        KeyBinding::new("cmd-g", FindNext, Some(FIND)),
        KeyBinding::new("shift-enter", FindPrev, Some(FIND)),
        KeyBinding::new("cmd-shift-g", FindPrev, Some(FIND)),
        KeyBinding::new("escape", CloseFind, Some(FIND)),
    ]);
    cx.on_action(|_: &Quit, cx| cx.quit());
    cx.set_menus(vec![
        Menu {
            name: "terminal_workflows".into(),
            items: vec![MenuItem::action("Minimize", MinimizeWindow), MenuItem::separator(), MenuItem::action("Quit", Quit)],
        },
        Menu {
            name: "Shell".into(),
            items: vec![
                MenuItem::action("New Tab", NewTab),
                MenuItem::action("Close Tab", CloseTab),
                MenuItem::separator(),
                MenuItem::action("Next Tab", NextTab),
                MenuItem::action("Previous Tab", PrevTab),
                MenuItem::action("Move Tab Left", MoveTabLeft),
                MenuItem::action("Move Tab Right", MoveTabRight),
                MenuItem::separator(),
                MenuItem::action("Reload Plugins", ReloadPlugins),
                MenuItem::action("Close Document", CloseDocument),
            ],
        },
        Menu {
            name: "Edit".into(),
            items: vec![
                MenuItem::action("Copy", Copy),
                MenuItem::action("Paste", Paste),
                MenuItem::action("Select All", SelectAll),
                MenuItem::separator(),
                MenuItem::action("Find", Find),
                MenuItem::action("Find Next", FindNext),
                MenuItem::action("Find Previous", FindPrev),
            ],
        },
    ]);
}
