use gpui::{Hsla, Rgba, rgb};
use tw_scripting::HexColor;
use tw_terminal::Rgb;

/// Used when installed; gpui falls back to the system monospace otherwise.
pub const FONT_FAMILY: &str = "IosevkaTiago Nerd Font";
pub const FONT_SIZE: f32 = 14.0;
pub const LINE_HEIGHT_FACTOR: f32 = 1.3;
pub const SIDEBAR_WIDTH: f32 = 380.0;
pub const TITLEBAR_HEIGHT: f32 = 40.0;

pub fn hex(value: u32) -> Hsla {
    rgb(value).into()
}

pub fn bg() -> Hsla {
    hex(0x14161c)
}
pub fn titlebar() -> Hsla {
    hex(0x191c24)
}
pub fn panel() -> Hsla {
    hex(0x1b1e26)
}
pub fn raised() -> Hsla {
    hex(0x2a2f3b)
}
pub fn border() -> Hsla {
    hex(0x2e3340)
}
pub fn text() -> Hsla {
    hex(0xd6d9e0)
}
pub fn muted() -> Hsla {
    hex(0x8a90a0)
}
pub fn accent() -> Hsla {
    hex(0x7aa2f7)
}
pub fn error() -> Hsla {
    hex(0xf7768e)
}
pub fn warn() -> Hsla {
    hex(0xe0af68)
}
pub fn button() -> Hsla {
    hex(0x33405e)
}
pub fn button_hover() -> Hsla {
    hex(0x40507a)
}
pub fn code_bg() -> Hsla {
    hex(0x0f1116)
}

/// The terminal's own colours, resolved by libghostty.
pub fn term(color: Rgb) -> Hsla {
    Rgba {
        r: f32::from(color.r) / 255.0,
        g: f32::from(color.g) / 255.0,
        b: f32::from(color.b) / 255.0,
        a: 1.0,
    }
    .into()
}

pub fn plugin(color: HexColor) -> Hsla {
    hex(color.0)
}
