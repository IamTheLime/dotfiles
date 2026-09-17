pub use libghostty_vt::key::{Key, Mods};

/// A key press as the UI saw it, before Ghostty encodes it for the shell.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct KeyInput {
    pub key: Key,
    pub mods: Mods,
    /// The text the OS produced for this press ("a", "A", "ß"), if any.
    pub text: Option<String>,
    /// The character the key produces with no modifiers ('a' for shift-a). The
    /// Kitty keyboard protocol reports it so apps can identify keys by layout.
    pub unshifted: Option<char>,
}

impl KeyInput {
    /// Build from a key name as gpui spells it: "a", "enter", "left", "f5".
    pub fn from_name(name: &str, mods: Mods, text: Option<String>) -> Self {
        Self {
            key: key_from_name(name),
            mods,
            text,
            unshifted: unshifted_codepoint(name),
        }
    }
}

/// Key names are an open set owned by the windowing layer, so this is the one
/// place a catch-all is allowed. Unknown names become `Key::Unidentified`; the
/// encoder then falls back to the text the OS produced.
pub fn key_from_name(name: &str) -> Key {
    match name {
        "a" => Key::A,
        "b" => Key::B,
        "c" => Key::C,
        "d" => Key::D,
        "e" => Key::E,
        "f" => Key::F,
        "g" => Key::G,
        "h" => Key::H,
        "i" => Key::I,
        "j" => Key::J,
        "k" => Key::K,
        "l" => Key::L,
        "m" => Key::M,
        "n" => Key::N,
        "o" => Key::O,
        "p" => Key::P,
        "q" => Key::Q,
        "r" => Key::R,
        "s" => Key::S,
        "t" => Key::T,
        "u" => Key::U,
        "v" => Key::V,
        "w" => Key::W,
        "x" => Key::X,
        "y" => Key::Y,
        "z" => Key::Z,
        "0" => Key::Digit0,
        "1" => Key::Digit1,
        "2" => Key::Digit2,
        "3" => Key::Digit3,
        "4" => Key::Digit4,
        "5" => Key::Digit5,
        "6" => Key::Digit6,
        "7" => Key::Digit7,
        "8" => Key::Digit8,
        "9" => Key::Digit9,
        "`" => Key::Backquote,
        "\\" => Key::Backslash,
        "[" => Key::BracketLeft,
        "]" => Key::BracketRight,
        "," => Key::Comma,
        "=" => Key::Equal,
        "-" => Key::Minus,
        "." => Key::Period,
        "'" => Key::Quote,
        ";" => Key::Semicolon,
        "/" => Key::Slash,
        "space" => Key::Space,
        "tab" => Key::Tab,
        "enter" => Key::Enter,
        "escape" => Key::Escape,
        "backspace" => Key::Backspace,
        "delete" => Key::Delete,
        "insert" => Key::Insert,
        "home" => Key::Home,
        "end" => Key::End,
        "pageup" => Key::PageUp,
        "pagedown" => Key::PageDown,
        "up" => Key::ArrowUp,
        "down" => Key::ArrowDown,
        "left" => Key::ArrowLeft,
        "right" => Key::ArrowRight,
        "f1" => Key::F1,
        "f2" => Key::F2,
        "f3" => Key::F3,
        "f4" => Key::F4,
        "f5" => Key::F5,
        "f6" => Key::F6,
        "f7" => Key::F7,
        "f8" => Key::F8,
        "f9" => Key::F9,
        "f10" => Key::F10,
        "f11" => Key::F11,
        "f12" => Key::F12,
        _ => Key::Unidentified,
    }
}

/// Mouse buttons the terminal cares about. Wheel ticks are a phase
/// ([`MousePhase::Wheel`]), not a button.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MouseButton {
    Left,
    Right,
    Middle,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum MousePhase {
    Press(MouseButton),
    Release(MouseButton),
    /// The pointer moved; `held` is the button being dragged, if any.
    Move { held: Option<MouseButton> },
    /// Wheel ticks; positive shows older output.
    Wheel { lines: f32 },
}

/// A mouse event in terminal coordinates. `x`/`y` are pixels from the top-left
/// of the grid; `col`/`row` are the cell under the pointer, clamped to the grid.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MouseInput {
    pub phase: MousePhase,
    pub col: u16,
    pub row: u16,
    pub x: f32,
    pub y: f32,
    pub mods: Mods,
}

fn unshifted_codepoint(name: &str) -> Option<char> {
    if name == "space" {
        return Some(' ');
    }
    let mut chars = name.chars();
    match (chars.next(), chars.next()) {
        (Some(c), None) => Some(c),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_map_gpui_key_names_to_ghostty_keys() {
        assert_eq!(key_from_name("enter"), Key::Enter);
        assert_eq!(key_from_name("a"), Key::A);
        assert_eq!(key_from_name("["), Key::BracketLeft);
        assert_eq!(key_from_name("f12"), Key::F12);
    }

    #[test]
    fn should_leave_unknown_names_unidentified_but_keep_the_text() {
        let input = KeyInput::from_name("ß", Mods::empty(), Some("ß".to_owned()));
        assert_eq!(input.key, Key::Unidentified);
        assert_eq!(input.text.as_deref(), Some("ß"));
        assert_eq!(input.unshifted, Some('ß'));
    }
}
