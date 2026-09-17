//! One shell session: a PTY, Ghostty's terminal state machine and the key
//! encoder that turns UI key presses into the bytes the shell expects.
//!
//! Nothing here knows about gpui. [`Grid`] is generic over the colour type, so
//! the UI maps [`Rgb`] to its own colour once, when it paints. Every
//! libghostty handle is `!Send`; keep a [`Session`] on the UI thread.

mod grid;
mod input;
mod kitty_placeholder;
mod pty;
mod session;

pub use grid::{
    Attrs, Cell, CellContent, CellWidth, Cursor, CursorShape, Grid, ImageLayer, ImagePixels, ImagePlacement, Rgb, Row,
    SourceRect, UnderlineKind,
};
pub use input::{Key, KeyInput, Mods, MouseButton, MouseInput, MousePhase, key_from_name};
pub use pty::{PtyError, PtyRead, PtySpec};
pub use session::{SearchMatch, Session, SessionError, TerminalEvent};

/// The libghostty-vt version string.
pub fn engine_version() -> String {
    libghostty_vt::build_info::version_string().unwrap_or("unknown").to_owned()
}

/// How the Zig side was compiled. `Debug` is many times slower at parsing
/// escape sequences and image payloads than `ReleaseFast`.
pub fn engine_optimize_mode() -> String {
    libghostty_vt::build_info::optimize_mode().map(|m| format!("{m:?}")).unwrap_or_else(|_| "unknown".to_owned())
}
