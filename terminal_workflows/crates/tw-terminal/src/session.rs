use std::cell::RefCell;
use std::collections::HashMap;
use std::io;
use std::rc::Rc;
use std::sync::OnceLock;
use std::time::{Duration, Instant};

use futures::channel::mpsc::UnboundedReceiver;
use libghostty_vt::error::Error as GhosttyError;
use libghostty_vt::fmt::{Format, Formatter, FormatterOptions};
use libghostty_vt::alloc::{Allocator, Bytes};
use libghostty_vt::build_info;
use libghostty_vt::key::{self, Action, Mods, OptionAsAlt};
use libghostty_vt::kitty::graphics::{self as kitty, DecodePng, DecodedImage, ImageFormat, Layer, PlacementIterator};
use libghostty_vt::mouse;
use libghostty_vt::paste;
use libghostty_vt::render::{CellIterator, Dirty, RenderState, RowIterator};
use libghostty_vt::selection::gesture::{Behavior, Behaviors, DragEvent, Geometry, Gesture, PressEvent, ReleaseEvent};
use libghostty_vt::selection::{FormatOptions, Selection};
use libghostty_vt::style::StyleColor;
use libghostty_vt::terminal::{Mode, Options, Point, PointCoordinate, ScrollViewport, Terminal};

use crate::grid::{
    Attrs, Cell, CellContent, CellWidth, Cursor, CursorShape, Grid, ImageLayer, ImagePixels, ImagePlacement, Rgb, Row,
    SourceRect,
};
use crate::input::{KeyInput, MouseButton, MouseInput, MousePhase};
use crate::kitty_placeholder;
use crate::pty::{Pty, PtyError, PtyRead, PtySpec};

/// Something the terminal reported while it processed output.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TerminalEvent {
    TitleChanged(String),
    PwdChanged(String),
    Bell,
    /// The child is gone. `None` when the exit code was not available yet.
    Exited(Option<u32>),
}

#[derive(Debug, thiserror::Error)]
pub enum SessionError {
    #[error(transparent)]
    Pty(#[from] PtyError),
    #[error("libghostty: {0}")]
    Ghostty(#[from] GhosttyError),
    #[error("write to shell: {0}")]
    Io(#[from] io::Error),
}

/// One hit of [`Session::search`], in screen coordinates (row 0 is the oldest
/// scrollback line).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SearchMatch {
    pub row: u32,
    pub col: u16,
    pub len: u16,
}

type SharedPty = Rc<RefCell<Pty>>;
type Events = Rc<RefCell<Vec<TerminalEvent>>>;

#[derive(Clone, Copy, PartialEq, Eq)]
struct Size {
    cols: u16,
    rows: u16,
    cell_width: u16,
    cell_height: u16,
}

/// Ghostty's click/drag state machine for text selection.
struct Gestures {
    gesture: Gesture<'static>,
    press: PressEvent<'static>,
    release: ReleaseEvent<'static>,
    drag: DragEvent<'static>,
    started: Instant,
}

impl Gestures {
    fn new() -> Result<Self, GhosttyError> {
        let mut press = PressEvent::new()?;
        press.set_repeat_interval(Duration::from_millis(500))?.set_behaviors(
            &Behaviors::new()
                .with_single_click_behavior(Behavior::Cell)
                .with_double_click_behavior(Behavior::Word)
                .with_triple_click_behavior(Behavior::Line),
        )?;
        Ok(Self {
            gesture: Gesture::new()?,
            press,
            release: ReleaseEvent::new()?,
            drag: DragEvent::new()?,
            started: Instant::now(),
        })
    }
}

/// Ghostty stores Kitty images as received; PNG payloads need a decoder from
/// the host. libghostty keeps the registered decoder per thread, so it is
/// installed once per thread that creates sessions (in the app: the UI thread).
struct PngDecoder {
    buf: Vec<u8>,
}

impl DecodePng for PngDecoder {
    fn decode_png<'alloc>(&mut self, alloc: &'alloc Allocator<'_>, data: &[u8]) -> Option<DecodedImage<'alloc>> {
        let started = Instant::now();
        let decoded = self.decode(alloc, data);
        if let Some(image) = &decoded {
            log::debug!("png: {} bytes -> {}x{} in {} ms", data.len(), image.width, image.height, started.elapsed().as_millis());
        }
        decoded
    }
}

impl PngDecoder {
    fn decode<'alloc>(&mut self, alloc: &'alloc Allocator<'_>, data: &[u8]) -> Option<DecodedImage<'alloc>> {
        use png::{Decoder, Transformations};
        let mut decoder = Decoder::new(std::io::Cursor::new(data));
        decoder.set_transformations(Transformations::ALPHA | Transformations::STRIP_16);
        let mut reader = decoder.read_info().ok()?;
        let size = reader.output_buffer_size()?;
        self.buf.resize(size, 0);
        let info = reader.next_frame(&mut self.buf).ok()?;
        let mut bytes = Bytes::new_with_alloc(alloc, info.buffer_size()).ok()?;
        bytes.copy_from_slice(&self.buf[..info.buffer_size()]);
        Some(DecodedImage { width: info.width, height: info.height, data: bytes })
    }
}

thread_local! {
    static PNG_DECODER_INSTALLED: std::cell::Cell<bool> = const { std::cell::Cell::new(false) };
}

fn xtversion() -> &'static str {
    static VERSION: OnceLock<String> = OnceLock::new();
    VERSION.get_or_init(|| format!("ghostty {} (terminal_workflows)", build_info::version_string().unwrap_or("0.0.0")))
}

fn install_png_decoder() {
    PNG_DECODER_INSTALLED.with(|installed| {
        if installed.get() {
            return;
        }
        match kitty::set_png_decoder(Some(Box::new(PngDecoder { buf: Vec::new() }))) {
            Ok(()) => installed.set(true),
            Err(error) => log::warn!("kitty graphics: no PNG decoder: {error}"),
        }
    });
}

/// A shell on a PTY and the Ghostty terminal that interprets its output.
pub struct Session {
    terminal: Terminal<'static, 'static>,
    render: RenderState<'static>,
    rows: RowIterator<'static>,
    cells: CellIterator<'static>,
    placements: PlacementIterator<'static>,
    key_encoder: key::Encoder<'static>,
    key_event: key::Event<'static>,
    mouse_encoder: mouse::Encoder<'static>,
    mouse_event: mouse::Event<'static>,
    gestures: Gestures,
    pty: SharedPty,
    events: Events,
    size: Size,
    /// Which button is down, for drag selection and motion reports.
    button_down: Option<MouseButton>,
    has_selection: bool,
    exited: bool,
}

impl Session {
    /// Start the shell. The receiver yields its output; feed it back with [`Session::feed`].
    pub fn spawn(spec: PtySpec) -> Result<(Self, UnboundedReceiver<PtyRead>), SessionError> {
        install_png_decoder();
        let (pty, output) = Pty::spawn(&spec)?;
        let pty = Rc::new(RefCell::new(pty));
        let events: Events = Rc::default();

        let mut terminal = Terminal::new(Options {
            cols: spec.cols,
            rows: spec.rows,
            max_scrollback: 10_000,
        })?;
        // Local app: let images arrive by file, temp file or shared memory, as `kitten icat` sends them.
        terminal
            .set_kitty_image_from_file_allowed(true)?
            .set_kitty_image_from_temp_file_allowed(true)?
            .set_kitty_image_from_shared_mem_allowed(true)?;
        // Query responses (cursor position, device attributes, ...) go straight back to the shell.
        let writer = pty.clone();
        terminal.on_pty_write(move |_, data| {
            if let Err(e) = writer.borrow_mut().write(data) {
                log::warn!("pty write-back failed: {e}");
            }
        })?;
        // Tools such as snacks.image ask XTVERSION (`CSI > q`) and enable Kitty
        // graphics only for terminals they know; the engine really is Ghostty's.
        terminal.on_xtversion(|_| Some(xtversion()))?;
        let sink = events.clone();
        terminal.on_bell(move |_| sink.borrow_mut().push(TerminalEvent::Bell))?;
        let sink = events.clone();
        terminal.on_title_changed(move |t| {
            let title = t.title().unwrap_or_default().to_owned();
            sink.borrow_mut().push(TerminalEvent::TitleChanged(title));
        })?;
        let sink = events.clone();
        terminal.on_pwd_changed(move |t| {
            let pwd = t.pwd().unwrap_or_default().to_owned();
            sink.borrow_mut().push(TerminalEvent::PwdChanged(pwd));
        })?;

        let session = Self {
            terminal,
            render: RenderState::new()?,
            rows: RowIterator::new()?,
            cells: CellIterator::new()?,
            placements: PlacementIterator::new()?,
            key_encoder: key::Encoder::new()?,
            key_event: key::Event::new()?,
            mouse_encoder: mouse::Encoder::new()?,
            mouse_event: mouse::Event::new()?,
            gestures: Gestures::new()?,
            pty,
            events,
            size: Size { cols: spec.cols, rows: spec.rows, cell_width: 0, cell_height: 0 },
            button_down: None,
            has_selection: false,
            exited: false,
        };
        Ok((session, output))
    }

    /// Feed what the reader thread produced. `Eof` marks the session as exited.
    pub fn feed(&mut self, read: PtyRead) {
        match read {
            PtyRead::Data(bytes) => self.terminal.vt_write(&bytes),
            PtyRead::Eof => {
                self.exited = true;
                let code = self.pty.borrow_mut().try_wait().ok().flatten().map(|s| s.exit_code());
                self.events.borrow_mut().push(TerminalEvent::Exited(code));
            }
        }
    }

    /// Events collected since the last call, oldest first.
    pub fn take_events(&mut self) -> Vec<TerminalEvent> {
        std::mem::take(&mut *self.events.borrow_mut())
    }

    pub fn has_exited(&self) -> bool {
        self.exited
    }

    pub fn has_selection(&self) -> bool {
        self.has_selection
    }

    pub fn title(&self) -> String {
        self.terminal.title().unwrap_or_default().to_owned()
    }

    /// Resize both the terminal grid and the PTY. Returns whether anything changed.
    pub fn resize(&mut self, cols: u16, rows: u16, cell_width: u16, cell_height: u16) -> Result<bool, SessionError> {
        let size = Size { cols, rows, cell_width, cell_height };
        if size == self.size || cols == 0 || rows == 0 {
            return Ok(false);
        }
        self.terminal.resize(cols, rows, u32::from(cell_width), u32::from(cell_height))?;
        self.pty.borrow().resize(cols, rows, cell_width, cell_height)?;
        self.size = size;
        Ok(true)
    }

    /// Encode a key press the way Ghostty would and send it to the shell.
    /// Typing also drops the selection, as in Ghostty.
    pub fn key(&mut self, input: &KeyInput) -> Result<(), SessionError> {
        if self.has_selection {
            self.clear_selection()?;
        }
        // Shift is "consumed" when the OS already applied it to the text ('a' became 'A').
        let consumed = if input.text.is_some() { input.mods & Mods::SHIFT } else { Mods::empty() };
        self.key_event
            .set_action(Action::Press)
            .set_key(input.key)
            .set_mods(input.mods)
            .set_consumed_mods(consumed)
            .set_unshifted_codepoint(input.unshifted.unwrap_or('\0'))
            .set_utf8(input.text.as_deref());
        self.key_encoder
            .set_options_from_terminal(&self.terminal)
            .set_macos_option_as_alt(OptionAsAlt::True);
        let mut bytes = Vec::with_capacity(16);
        self.key_encoder.encode_to_vec(&self.key_event, &mut bytes)?;
        if bytes.is_empty() {
            return Ok(());
        }
        self.write(&bytes)
    }

    /// Send raw bytes to the shell (scripted text; use [`Session::paste`] for clipboard text).
    pub fn write(&mut self, bytes: &[u8]) -> Result<(), SessionError> {
        self.pty.borrow_mut().write(bytes)?;
        Ok(())
    }

    /// Send clipboard text, bracketed when the application asked for it.
    pub fn paste(&mut self, text: &str) -> Result<(), SessionError> {
        let bracketed = self.terminal.mode(Mode::BRACKETED_PASTE)?;
        let mut data = text.as_bytes().to_vec();
        let mut buf = vec![0u8; data.len() + 32];
        let written = match paste::encode(&mut data, bracketed, &mut buf) {
            Ok(n) => n,
            Err(GhosttyError::OutOfSpace { required }) => {
                buf.resize(required, 0);
                paste::encode(&mut data, bracketed, &mut buf)?
            }
            Err(e) => return Err(e.into()),
        };
        self.write(&buf[..written])
    }

    /// Positive `lines` shows older output.
    pub fn scroll(&mut self, lines: isize) {
        self.terminal.scroll_viewport(ScrollViewport::Delta(-lines));
    }

    pub fn scroll_to_bottom(&mut self) {
        self.terminal.scroll_viewport(ScrollViewport::Bottom);
    }

    /// Route a mouse event: to the application when it asked for mouse
    /// reports (shift overrides that), otherwise to text selection.
    pub fn mouse(&mut self, input: &MouseInput) -> Result<(), SessionError> {
        match input.phase {
            MousePhase::Press(button) => self.button_down = Some(button),
            MousePhase::Release(_) => self.button_down = None,
            MousePhase::Move { .. } | MousePhase::Wheel { .. } => {}
        }
        let reporting = self.terminal.is_mouse_tracking()? && !input.mods.contains(Mods::SHIFT);
        match (input.phase, reporting) {
            (MousePhase::Press(button), true) => self.report(input, mouse::Action::Press, Some(ghostty_button(button))),
            (MousePhase::Release(button), true) => self.report(input, mouse::Action::Release, Some(ghostty_button(button))),
            (MousePhase::Move { held }, true) => self.report(input, mouse::Action::Motion, held.map(ghostty_button)),
            (MousePhase::Wheel { lines }, true) => self.report_wheel(input, lines),
            (MousePhase::Wheel { lines }, false) => {
                self.scroll(lines.round() as isize);
                Ok(())
            }
            (MousePhase::Press(MouseButton::Left), false) => self.select_press(input),
            (MousePhase::Release(MouseButton::Left), false) => self.select_release(input),
            (MousePhase::Move { held: Some(MouseButton::Left) }, false) => self.select_drag(input),
            (
                MousePhase::Press(MouseButton::Right | MouseButton::Middle)
                | MousePhase::Release(MouseButton::Right | MouseButton::Middle)
                | MousePhase::Move { held: None | Some(MouseButton::Right | MouseButton::Middle) },
                false,
            ) => Ok(()),
        }
    }

    pub fn select_all(&mut self) -> Result<(), SessionError> {
        let selection = self.terminal.select_all()?;
        self.terminal.set_selection(selection.as_ref())?;
        self.has_selection = selection.is_some();
        Ok(())
    }

    pub fn clear_selection(&mut self) -> Result<(), SessionError> {
        self.terminal.set_selection(None)?;
        self.has_selection = false;
        Ok(())
    }

    /// The selected text as Ghostty would copy it: unwrapped, trailing space trimmed.
    pub fn selected_text(&self) -> Result<Option<String>, SessionError> {
        let options = FormatOptions::new().with_emit_format(Format::Plain).with_unwrap(true).with_trim(true);
        let bytes = self.terminal.format_selection_alloc(None, options)?;
        Ok(bytes.map(|b| String::from_utf8_lossy(&b).into_owned()))
    }

    /// The whole screen, scrollback included, one line per screen row.
    pub fn screen_text(&self) -> Result<String, SessionError> {
        let options = FormatterOptions::new().with_format(Format::Plain).with_unwrap(false).with_trim(false);
        let mut formatter = Formatter::new(&self.terminal, options)?;
        let bytes = formatter.format_alloc(None)?;
        Ok(String::from_utf8_lossy(&bytes).into_owned())
    }

    /// Case-insensitive plain-text search over the screen and scrollback.
    pub fn search(&self, query: &str) -> Result<Vec<SearchMatch>, SessionError> {
        let needle: Vec<char> = query.chars().flat_map(char::to_lowercase).collect();
        if needle.is_empty() {
            return Ok(Vec::new());
        }
        let text = self.screen_text()?;
        let mut matches = Vec::new();
        for (row, line) in text.lines().enumerate() {
            let hay: Vec<char> = line.chars().map(|c| c.to_lowercase().next().unwrap_or(c)).collect();
            let mut col = 0;
            while col + needle.len() <= hay.len() {
                if hay[col..col + needle.len()] == needle[..] {
                    matches.push(SearchMatch { row: row as u32, col: col as u16, len: needle.len() as u16 });
                    col += needle.len();
                } else {
                    col += 1;
                }
            }
        }
        Ok(matches)
    }

    /// Scroll a match into view and select it.
    pub fn show_match(&mut self, found: &SearchMatch) -> Result<(), SessionError> {
        let rows = self.terminal.rows()?;
        let top = found.row.saturating_sub(u32::from(rows / 2));
        self.terminal.scroll_viewport(ScrollViewport::Row(top as usize));
        let start = self.terminal.grid_ref(Point::Screen(PointCoordinate { x: found.col, y: found.row }))?;
        let end = self
            .terminal
            .grid_ref(Point::Screen(PointCoordinate { x: found.col + found.len.saturating_sub(1), y: found.row }))?;
        let selection = Selection::new(start, end, false);
        self.terminal.set_selection(Some(&selection))?;
        self.has_selection = true;
        Ok(())
    }

    fn viewport_point(&self, input: &MouseInput) -> Point {
        Point::Viewport(PointCoordinate {
            x: input.col.min(self.size.cols.saturating_sub(1)),
            y: u32::from(input.row.min(self.size.rows.saturating_sub(1))),
        })
    }

    fn select_press(&mut self, input: &MouseInput) -> Result<(), SessionError> {
        let grid_ref = self.terminal.grid_ref(self.viewport_point(input))?;
        let gestures = &mut self.gestures;
        let selection = gestures
            .press
            .set_repeat_distance(f64::from(self.size.cell_width))?
            .set_time(gestures.started.elapsed())?
            .set_position(f64::from(input.x), f64::from(input.y))?
            .apply(&mut gestures.gesture, &self.terminal, grid_ref)?;
        self.terminal.set_selection(selection.as_ref())?;
        self.has_selection = selection.is_some();
        Ok(())
    }

    fn select_release(&mut self, input: &MouseInput) -> Result<(), SessionError> {
        let grid_ref = self.terminal.grid_ref(self.viewport_point(input)).ok();
        self.gestures.release.apply(&mut self.gestures.gesture, &self.terminal, grid_ref)?;
        Ok(())
    }

    fn select_drag(&mut self, input: &MouseInput) -> Result<(), SessionError> {
        if self.gestures.gesture.click_count(&self.terminal)? == 0 {
            return Ok(());
        }
        let grid_ref = self.terminal.grid_ref(self.viewport_point(input))?;
        let geometry = Geometry {
            columns: u32::from(self.size.cols),
            cell_width: u32::from(self.size.cell_width),
            padding_left: 0,
            screen_height: u32::from(self.size.rows) * u32::from(self.size.cell_height),
        };
        let gestures = &mut self.gestures;
        let selection = gestures
            .drag
            .set_rectangle(input.mods.contains(Mods::ALT))?
            .set_position(f64::from(input.x), f64::from(input.y))?
            .apply(&mut gestures.gesture, &self.terminal, grid_ref, geometry)?;
        self.terminal.set_selection(selection.as_ref())?;
        self.has_selection = selection.is_some();
        Ok(())
    }

    fn report(&mut self, input: &MouseInput, action: mouse::Action, button: Option<mouse::Button>) -> Result<(), SessionError> {
        self.mouse_event
            .set_action(action)
            .set_button(button)
            .set_mods(input.mods)
            .set_position(mouse::Position { x: input.x, y: input.y });
        self.mouse_encoder
            .set_options_from_terminal(&self.terminal)
            .set_size(mouse::EncoderSize {
                screen_width: u32::from(self.size.cols) * u32::from(self.size.cell_width),
                screen_height: u32::from(self.size.rows) * u32::from(self.size.cell_height),
                cell_width: u32::from(self.size.cell_width),
                cell_height: u32::from(self.size.cell_height),
                padding_top: 0,
                padding_bottom: 0,
                padding_right: 0,
                padding_left: 0,
            })
            .set_any_button_pressed(self.button_down.is_some())
            .set_track_last_cell(true);
        let mut bytes = Vec::with_capacity(16);
        self.mouse_encoder.encode_to_vec(&self.mouse_event, &mut bytes)?;
        if bytes.is_empty() {
            return Ok(());
        }
        self.write(&bytes)
    }

    fn report_wheel(&mut self, input: &MouseInput, lines: f32) -> Result<(), SessionError> {
        // xterm convention: button 4 scrolls up (older output), button 5 scrolls down.
        let button = if lines > 0.0 { mouse::Button::Four } else { mouse::Button::Five };
        let ticks = (lines.abs().round() as usize).clamp(1, 10);
        for _ in 0..ticks {
            self.report(input, mouse::Action::Press, Some(button))?;
            self.report(input, mouse::Action::Release, Some(button))?;
        }
        Ok(())
    }

    /// Snapshot the visible screen. `color` maps each resolved RGB value once.
    pub fn grid<C>(&mut self, color: impl Fn(Rgb) -> C) -> Result<Grid<C>, SessionError> {
        let (mut grid, placeholders) = self.grid_cells(&color)?;
        grid.images = self.image_placements(&placeholders)?;
        Ok(grid)
    }

    fn grid_cells<C>(&mut self, color: &impl Fn(Rgb) -> C) -> Result<(Grid<C>, Vec<PlaceholderCell>), SessionError> {
        let snapshot = self.render.update(&self.terminal)?;
        let colors = snapshot.colors()?;
        let cols = snapshot.cols()?;
        let mut rows = Vec::with_capacity(usize::from(snapshot.rows()?));
        let mut text = String::with_capacity(8);
        let mut placeholders = Vec::new();

        let mut row_iter = self.rows.update(&snapshot)?;
        while let Some(row) = row_iter.next() {
            let row_index = rows.len() as u16;
            let has_placeholders = row.raw_row()?.has_kitty_virtual_placeholder()?;
            let mut previous: Option<PlaceholderCell> = None;
            let mut cells = Vec::with_capacity(usize::from(cols));
            let mut cell_iter = self.cells.update(row)?;
            while let Some(cell) = cell_iter.next() {
                let raw = cell.raw_cell()?;
                let width = CellWidth::from(raw.wide()?);
                if has_placeholders && raw.codepoint()? == kitty_placeholder::PLACEHOLDER as u32 {
                    let col_index = cells.len() as u16;
                    if let Some(found) = placeholder_cell(cell, row_index, col_index, previous)? {
                        placeholders.push(found);
                        previous = Some(found);
                    }
                    // The placeholder glyph itself must not be drawn; the image covers the cell.
                    cells.push(Cell { content: CellContent::Blank, fg: color(colors.foreground.into()), bg: None, width, attrs: Attrs::default() });
                    continue;
                }
                let mut fg = cell.fg_color()?.unwrap_or(colors.foreground);
                let mut bg = cell.bg_color()?;
                let mut attrs = Attrs::default();
                if cell.has_styling()? {
                    let style = cell.style()?;
                    attrs = Attrs {
                        bold: style.bold,
                        italic: style.italic,
                        faint: style.faint,
                        strikethrough: style.strikethrough,
                        underline: style.underline.into(),
                    };
                    if style.inverse {
                        let shown_bg = bg.unwrap_or(colors.background);
                        bg = Some(fg);
                        fg = shown_bg;
                    }
                }
                if cell.is_selected()? {
                    let shown_bg = bg.unwrap_or(colors.background);
                    bg = Some(fg);
                    fg = shown_bg;
                }
                let content = if cell.graphemes_len()? == 0 {
                    CellContent::Blank
                } else {
                    text.clear();
                    cell.graphemes_utf8(&mut text)?;
                    CellContent::Text(text.clone())
                };
                cells.push(Cell {
                    content,
                    fg: color(fg.into()),
                    bg: bg.map(|c| color(c.into())),
                    width,
                    attrs,
                });
            }
            row.set_dirty(false)?;
            rows.push(Row { cells });
        }

        let cursor = match (snapshot.cursor_visible()?, snapshot.cursor_viewport()?) {
            (true, Some(vp)) => Some(Cursor {
                col: vp.x,
                row: vp.y,
                shape: CursorShape::from(snapshot.cursor_visual_style()?),
                color: color(colors.cursor.unwrap_or(colors.foreground).into()),
            }),
            (true, None) | (false, _) => None,
        };
        snapshot.set_dirty(Dirty::Clean)?;

        let grid = Grid {
            cols,
            rows,
            cursor,
            background: color(colors.background.into()),
            foreground: color(colors.foreground.into()),
            images: Vec::new(),
        };
        Ok((grid, placeholders))
    }

    /// Every visible Kitty placement, per paint layer. Direct placements come
    /// with their geometry; virtual ones are rebuilt from the placeholder cells.
    fn image_placements(&mut self, placeholders: &[PlaceholderCell]) -> Result<Vec<ImagePlacement>, SessionError> {
        let Ok(graphics) = self.terminal.kitty_graphics() else { return Ok(Vec::new()) };
        let mut out = Vec::new();
        let mut virtual_placements: HashMap<u32, VirtualPlacement> = HashMap::new();
        let layers = [
            (ImageLayer::BelowBackground, Layer::BelowBg),
            (ImageLayer::BelowText, Layer::BelowText),
            (ImageLayer::AboveText, Layer::AboveText),
        ];
        for (layer, ghostty_layer) in layers {
            let mut placements = self.placements.update(&graphics)?;
            placements.set_layer(ghostty_layer)?;
            while let Some(placement) = placements.next() {
                let image_id = placement.image_id()?;
                let Some(image) = graphics.image(image_id) else { continue };
                let info = placement.placement_render_info(&image, &self.terminal)?;
                if placement.is_virtual()? {
                    if info.grid_cols > 0 && info.grid_rows > 0 && info.source_width > 0 && info.source_height > 0 {
                        virtual_placements.insert(
                            image_id,
                            VirtualPlacement {
                                generation: image.generation()?,
                                layer,
                                cols: info.grid_cols,
                                rows: info.grid_rows,
                                source: SourceRect {
                                    x: info.source_x,
                                    y: info.source_y,
                                    width: info.source_width,
                                    height: info.source_height,
                                },
                            },
                        );
                    }
                    continue;
                }
                if !info.viewport_visible
                    || info.grid_cols == 0
                    || info.grid_rows == 0
                    || info.source_width == 0
                    || info.source_height == 0
                {
                    continue;
                }
                out.push(ImagePlacement {
                    image_id,
                    generation: image.generation()?,
                    layer,
                    col: info.viewport_col.max(0) as u16,
                    row: info.viewport_row.max(0) as u16,
                    x_offset_px: placement.x_offset()?,
                    y_offset_px: placement.y_offset()?,
                    cols: info.grid_cols,
                    rows: info.grid_rows,
                    source: SourceRect {
                        x: info.source_x,
                        y: info.source_y,
                        width: info.source_width,
                        height: info.source_height,
                    },
                });
            }
        }
        out.extend(virtual_runs(placeholders, &virtual_placements));
        Ok(out)
    }

    /// The pixels of one Kitty image as straight-alpha RGBA, or `None` when
    /// the image is gone or in a format we do not convert.
    pub fn image_pixels(&self, image_id: u32) -> Result<Option<ImagePixels>, SessionError> {
        let graphics = self.terminal.kitty_graphics()?;
        let Some(image) = graphics.image(image_id) else { return Ok(None) };
        let (width, height, generation) = (image.width()?, image.height()?, image.generation()?);
        let pixels = (width as usize) * (height as usize);
        let data = image.data()?;
        let rgba: Option<Vec<u8>> = match image.format()? {
            ImageFormat::Rgba => data.get(..pixels * 4).map(<[u8]>::to_vec),
            ImageFormat::Rgb => data.get(..pixels * 3).map(|d| d.as_chunks::<3>().0.iter().flat_map(|p| [p[0], p[1], p[2], 255]).collect()),
            ImageFormat::GrayAlpha => {
                data.get(..pixels * 2).map(|d| d.as_chunks::<2>().0.iter().flat_map(|p| [p[0], p[0], p[0], p[1]]).collect())
            }
            ImageFormat::Gray => data.get(..pixels).map(|d| d.iter().flat_map(|&g| [g, g, g, 255]).collect()),
            // PNG is decoded into RGBA on receipt; anything else upstream adds later is skipped.
            ImageFormat::Png | _ => None,
        };
        Ok(rgba.map(|rgba| ImagePixels { width, height, generation, rgba }))
    }
}

/// A placeholder cell, fully resolved (row/column inferred where the cell omitted them).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct PlaceholderCell {
    grid_row: u16,
    grid_col: u16,
    image_id: u32,
    image_row: u32,
    image_col: u32,
}

/// What Ghostty knows about a virtual placement: how the image is cut into
/// a grid of cells, and which slice of it is placed.
#[derive(Clone, Copy, Debug)]
struct VirtualPlacement {
    generation: u64,
    layer: ImageLayer,
    cols: u32,
    rows: u32,
    source: SourceRect,
}

/// Decode one placeholder cell. The image id lives in the foreground colour
/// (palette index, or the 24-bit RGB value); a third diacritic adds the top byte.
fn placeholder_cell(
    cell: &libghostty_vt::render::CellIteration<'_, '_>,
    grid_row: u16,
    grid_col: u16,
    previous: Option<PlaceholderCell>,
) -> Result<Option<PlaceholderCell>, SessionError> {
    let cluster = cell.graphemes()?;
    let Some(decoded) = kitty_placeholder::decode(&cluster) else { return Ok(None) };
    let mut image_id = match cell.style()?.fg_color {
        StyleColor::Palette(index) => u32::from(index.0),
        StyleColor::Rgb(rgb) => (u32::from(rgb.r) << 16) | (u32::from(rgb.g) << 8) | u32::from(rgb.b),
        StyleColor::None => return Ok(None),
    };
    if let Some(high) = decoded.id_high {
        image_id |= high << 24;
    }
    // Cells without diacritics continue the run to their left: same row, next column.
    let continues = previous.filter(|p| p.image_id == image_id && p.grid_col + 1 == grid_col);
    let image_row = decoded.row.or(continues.map(|p| p.image_row)).unwrap_or(0);
    let image_col = decoded.col.or(continues.map(|p| p.image_col + 1)).unwrap_or(0);
    Ok(Some(PlaceholderCell { grid_row, grid_col, image_id, image_row, image_col }))
}

/// Merge placeholder cells into horizontal runs, one paint each.
fn virtual_runs(cells: &[PlaceholderCell], placements: &HashMap<u32, VirtualPlacement>) -> Vec<ImagePlacement> {
    let mut runs: Vec<ImagePlacement> = Vec::new();
    let mut run: Option<(PlaceholderCell, PlaceholderCell)> = None; // (first, last)
    let flush = |run: Option<(PlaceholderCell, PlaceholderCell)>, runs: &mut Vec<ImagePlacement>| {
        let Some((first, last)) = run else { return };
        let Some(placement) = placements.get(&first.image_id) else { return };
        if first.image_row >= placement.rows || first.image_col >= placement.cols {
            return;
        }
        let span = (last.image_col - first.image_col + 1).min(placement.cols - first.image_col);
        let slice_w = placement.source.width / placement.cols;
        let slice_h = placement.source.height / placement.rows;
        if slice_w == 0 || slice_h == 0 {
            return;
        }
        runs.push(ImagePlacement {
            image_id: first.image_id,
            generation: placement.generation,
            layer: placement.layer,
            col: first.grid_col,
            row: first.grid_row,
            x_offset_px: 0,
            y_offset_px: 0,
            cols: span,
            rows: 1,
            source: SourceRect {
                x: placement.source.x + first.image_col * slice_w,
                y: placement.source.y + first.image_row * slice_h,
                width: span * slice_w,
                height: slice_h,
            },
        });
    };
    for &cell in cells {
        match run {
            Some((first, last))
                if last.grid_row == cell.grid_row
                    && last.grid_col + 1 == cell.grid_col
                    && last.image_id == cell.image_id
                    && last.image_row == cell.image_row
                    && last.image_col + 1 == cell.image_col =>
            {
                run = Some((first, cell));
            }
            _ => {
                flush(run, &mut runs);
                run = Some((cell, cell));
            }
        }
    }
    flush(run, &mut runs);
    runs
}

fn ghostty_button(button: MouseButton) -> mouse::Button {
    match button {
        MouseButton::Left => mouse::Button::Left,
        MouseButton::Right => mouse::Button::Right,
        MouseButton::Middle => mouse::Button::Middle,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use futures::StreamExt;

    fn row_text<C>(row: &Row<C>) -> String {
        row.cells
            .iter()
            .map(|c| match &c.content {
                CellContent::Text(t) => t.as_str(),
                CellContent::Blank => " ",
            })
            .collect::<String>()
            .trim_end()
            .to_owned()
    }

    /// Run `program args` in a `cols`x`rows` terminal and feed everything it printed.
    fn run(program: &str, args: &[&str], cols: u16, rows: u16) -> Session {
        let spec = PtySpec {
            program: program.to_owned(),
            args: args.iter().map(|a| (*a).to_owned()).collect(),
            cwd: None,
            cols,
            rows,
        };
        let (mut session, mut output) = Session::spawn(spec).unwrap();
        futures::executor::block_on(async {
            while let Some(read) = output.next().await {
                let eof = matches!(read, PtyRead::Eof);
                session.feed(read);
                if eof {
                    break;
                }
            }
        });
        session
    }

    #[test]
    fn should_show_child_output_in_the_grid_and_report_exit() {
        let mut session = run("/bin/echo", &["hello"], 20, 4);
        let grid = session.grid(|c| c).unwrap();
        assert_eq!(grid.cols, 20);
        assert_eq!(row_text(&grid.rows[0]), "hello");
        assert!(session.has_exited());
        assert!(session.take_events().iter().any(|e| matches!(e, TerminalEvent::Exited(_))));
    }

    #[test]
    fn should_apply_inverse_video_by_swapping_colours() {
        let mut session = run("/usr/bin/printf", &["\\033[7mX\\033[0m"], 10, 2);
        let grid = session.grid(|c| c).unwrap();
        let cell = &grid.rows[0].cells[0];
        assert_eq!(cell.content, CellContent::Text("X".to_owned()));
        assert_eq!(cell.fg, grid.background);
        assert_eq!(cell.bg, Some(grid.foreground));
    }

    #[test]
    fn should_search_the_scrollback_and_select_the_match() {
        // 30 numbered lines in a 5-row terminal: most of them live in scrollback.
        let script = "for i in $(seq 1 30); do echo \"line $i\"; done";
        let mut session = run("/bin/sh", &["-c", script], 20, 5);
        let text = session.screen_text().unwrap();
        assert!(text.lines().count() >= 30, "formatter should include scrollback, got:\n{text}");

        let matches = session.search("LINE 27").unwrap();
        assert_eq!(matches.len(), 1);
        let found = matches[0];
        assert_eq!((found.col, found.len), (0, 7));

        session.show_match(&found).unwrap();
        let grid = session.grid(|c| c).unwrap();
        let selected_row = grid
            .rows
            .iter()
            .find(|row| row.cells.iter().take(7).all(|c| c.bg == Some(grid.foreground)))
            .expect("the match row should be selected and visible");
        assert_eq!(row_text(selected_row), "line 27");
        assert_eq!(session.selected_text().unwrap().as_deref(), Some("line 27"));
    }

    #[test]
    fn should_place_and_decode_a_png_sent_with_the_kitty_protocol() {
        use base64::Engine;
        // A 2x2 RGBA PNG: red, green / blue, white.
        let mut png = Vec::new();
        {
            let mut encoder = png::Encoder::new(&mut png, 2, 2);
            encoder.set_color(png::ColorType::Rgba);
            encoder.set_depth(png::BitDepth::Eight);
            let mut writer = encoder.write_header().unwrap();
            writer
                .write_image_data(&[255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255])
                .unwrap();
        }
        let payload = base64::engine::general_purpose::STANDARD.encode(&png);
        // APC G: transmit and display (a=T) a PNG (f=100) as image 7, quietly (q=2).
        // macOS can drop PTY output still in flight when the child exits at once, so linger a moment.
        let script = format!("printf '\\033_Ga=T,f=100,i=7,q=2;{payload}\\033\\\\'; sleep 0.3");
        let mut session = run("/bin/sh", &["-c", &script], 20, 4);
        session.resize(20, 4, 8, 16).unwrap();

        let grid = session.grid(|c| c).unwrap();
        assert_eq!(grid.images.len(), 1, "one placement expected, got {:?}", grid.images);
        let placement = grid.images[0];
        assert_eq!(placement.image_id, 7);
        // Kitty's default z=0 is drawn above the text; negative z goes below it.
        assert_eq!(placement.layer, ImageLayer::AboveText);
        assert_eq!((placement.col, placement.row), (0, 0));
        assert_eq!((placement.source.width, placement.source.height), (2, 2));

        let pixels = session.image_pixels(7).unwrap().expect("the PNG was decoded");
        assert_eq!((pixels.width, pixels.height), (2, 2));
        assert_eq!(pixels.generation, placement.generation);
        assert_eq!(&pixels.rgba[..8], &[255, 0, 0, 255, 0, 255, 0, 255]);
        assert_eq!(session.image_pixels(8).unwrap(), None);
    }

    #[test]
    fn should_draw_a_virtual_placement_from_its_placeholder_cells() {
        use base64::Engine;
        let mut png = Vec::new();
        {
            let mut encoder = png::Encoder::new(&mut png, 4, 2);
            encoder.set_color(png::ColorType::Rgba);
            encoder.set_depth(png::BitDepth::Eight);
            let mut writer = encoder.write_header().unwrap();
            writer.write_image_data(&[255u8; 32]).unwrap();
        }
        let payload = base64::engine::general_purpose::STANDARD.encode(&png);
        // Transmit as a virtual placement (U=1) spanning 2 columns x 1 row, then write the
        // two placeholder cells: U+10EEEE + row diacritic (U+0305 = 0) + column diacritic
        // (U+0305 = 0, U+030D = 1), with the image id in the foreground colour (38;5;7).
        // `sh printf` does not know \U escapes, so the placeholder cells are real UTF-8 in the script.
        let cells = "\u{10EEEE}\u{0305}\u{0305}\u{10EEEE}\u{0305}\u{030D}";
        let script = format!(
            "printf '\\033_Ga=T,U=1,f=100,i=7,c=2,r=1,q=2;{payload}\\033\\\\'; printf '\\033[38;5;7m%s\\033[0m\\n' '{cells}'; sleep 0.3"
        );
        let mut session = run("/bin/sh", &["-c", &script], 20, 4);
        session.resize(20, 4, 8, 16).unwrap();
        let grid = session.grid(|c| c).unwrap();
        // The two placeholder cells are blank (no tofu glyph) and become one run of two cells.
        assert_eq!(row_text(&grid.rows[0]), "");
        assert_eq!(grid.images.len(), 1, "got {:?}", grid.images);
        let run = grid.images[0];
        assert_eq!((run.image_id, run.col, run.row, run.cols, run.rows), (7, 0, 0, 2, 1));
        assert_eq!(run.source, SourceRect { x: 0, y: 0, width: 4, height: 2 });
        assert_eq!(run.layer, ImageLayer::AboveText);
        assert_eq!(session.image_pixels(7).unwrap().unwrap().rgba.len(), 32);
    }

    #[test]
    fn should_select_with_a_mouse_drag_and_copy_it() {
        let mut session = run("/bin/echo", &["hello world"], 20, 3);
        session.resize(20, 3, 8, 16).unwrap();
        let mods = Mods::empty();
        // Ghostty snaps each end of a drag to the nearest cell edge: press in the left
        // half of the first cell and release in the right half of the last one.
        let at = |phase, col: u16, offset: f32| MouseInput { phase, col, row: 0, x: f32::from(col) * 8.0 + offset, y: 8.0, mods };
        session.mouse(&at(MousePhase::Press(MouseButton::Left), 0, 1.0)).unwrap();
        session.mouse(&at(MousePhase::Move { held: Some(MouseButton::Left) }, 4, 7.0)).unwrap();
        session.mouse(&at(MousePhase::Release(MouseButton::Left), 4, 7.0)).unwrap();
        assert!(session.has_selection());
        assert_eq!(session.selected_text().unwrap().as_deref(), Some("hello"));

        session.select_all().unwrap();
        assert_eq!(session.selected_text().unwrap().as_deref(), Some("hello world"));
        session.clear_selection().unwrap();
        assert_eq!(session.selected_text().unwrap(), None);
    }
}
