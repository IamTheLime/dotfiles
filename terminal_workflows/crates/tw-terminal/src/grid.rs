use libghostty_vt::render::CursorVisualStyle;
use libghostty_vt::screen::CellWide;
use libghostty_vt::style::{RgbColor, Underline};

/// A snapshot of the visible screen, ready to paint. Generic over the colour
/// type so the UI decides how colours are represented.
#[derive(Clone, Debug)]
pub struct Grid<C> {
    pub cols: u16,
    pub rows: Vec<Row<C>>,
    pub cursor: Option<Cursor<C>>,
    pub background: C,
    pub foreground: C,
    /// Kitty graphics placements visible in the viewport, in paint order within each layer.
    pub images: Vec<ImagePlacement>,
}

/// Where a Kitty image sits in the viewport. Pixel values are in the
/// terminal's own pixel space (cell size times cells). `source` is the part of
/// the image that is visible; scrolling can cut an image at the viewport edge.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ImagePlacement {
    pub image_id: u32,
    /// Changes whenever the image's pixels change; key texture caches on it.
    pub generation: u64,
    pub layer: ImageLayer,
    pub col: u16,
    pub row: u16,
    pub x_offset_px: u32,
    pub y_offset_px: u32,
    pub cols: u32,
    pub rows: u32,
    pub source: SourceRect,
}

/// Which paint pass an image belongs to (Kitty `z` index buckets).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ImageLayer {
    BelowBackground,
    BelowText,
    AboveText,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SourceRect {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
}

/// Decoded pixels of one Kitty image, straight-alpha RGBA, row-major.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ImagePixels {
    pub width: u32,
    pub height: u32,
    pub generation: u64,
    pub rgba: Vec<u8>,
}

#[derive(Clone, Debug, Default)]
pub struct Row<C> {
    pub cells: Vec<Cell<C>>,
}

#[derive(Clone, Debug)]
pub struct Cell<C> {
    pub content: CellContent,
    /// Already resolved: palette lookups, inverse video and selection are applied.
    pub fg: C,
    /// `None` means the terminal background shows through.
    pub bg: Option<C>,
    pub width: CellWidth,
    pub attrs: Attrs,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CellContent {
    Blank,
    /// One grapheme cluster as UTF-8; may be several code points.
    Text(String),
}

/// How many columns a cell covers. Spacers are the columns a wide character
/// already covers; the painter skips them.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CellWidth {
    Single,
    Double,
    Spacer,
}

impl From<CellWide> for CellWidth {
    fn from(wide: CellWide) -> Self {
        match wide {
            CellWide::Narrow => Self::Single,
            CellWide::Wide => Self::Double,
            CellWide::SpacerTail | CellWide::SpacerHead => Self::Spacer,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Attrs {
    pub bold: bool,
    pub italic: bool,
    pub faint: bool,
    pub strikethrough: bool,
    pub underline: UnderlineKind,
}

impl Default for Attrs {
    fn default() -> Self {
        Self {
            bold: false,
            italic: false,
            faint: false,
            strikethrough: false,
            underline: UnderlineKind::None,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UnderlineKind {
    None,
    Single,
    Double,
    Curly,
    Dotted,
    Dashed,
}

impl From<Underline> for UnderlineKind {
    fn from(underline: Underline) -> Self {
        match underline {
            Underline::None => Self::None,
            Underline::Single => Self::Single,
            Underline::Double => Self::Double,
            Underline::Curly => Self::Curly,
            Underline::Dotted => Self::Dotted,
            Underline::Dashed => Self::Dashed,
            // libghostty marks the enum non-exhaustive; a new style still needs a line under the text.
            _ => Self::Single,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Cursor<C> {
    pub col: u16,
    pub row: u16,
    pub shape: CursorShape,
    pub color: C,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CursorShape {
    Block,
    Bar,
    Underline,
    Hollow,
}

impl From<CursorVisualStyle> for CursorShape {
    fn from(style: CursorVisualStyle) -> Self {
        match style {
            CursorVisualStyle::Block => Self::Block,
            CursorVisualStyle::Bar => Self::Bar,
            CursorVisualStyle::Underline => Self::Underline,
            CursorVisualStyle::BlockHollow => Self::Hollow,
            // Non-exhaustive upstream; a block is the safe default for anything new.
            _ => Self::Block,
        }
    }
}

/// An 8-bit RGB colour as the terminal resolved it.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub struct Rgb {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl From<RgbColor> for Rgb {
    fn from(c: RgbColor) -> Self {
        Self { r: c.r, g: c.g, b: c.b }
    }
}
