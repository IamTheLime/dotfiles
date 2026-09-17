# terminal_workflows

A native macOS window that renders a real terminal with Ghostty's VT engine
(`libghostty-vt`) and Zed's GPU UI framework (`gpui`), next to a sidebar of
widgets written in TypeScript and run by Node with hot reload.

The end goal is a scriptable surface that Neovim and Ghostty can drive: open
tabs, send text to a shell, show workflow widgets. Everything that changes
the app goes through one command enum, so a keyboard shortcut, a plugin and
(later) a socket client all reach the same code.

Status: **v0 runs**. Phases 0–3 are done and Phase 4 has its first client:
Neovim mirrors `K` hover into the sidebar. "Verified so far" says what
evidence exists.

## Setup (macOS)

Checked on this machine on 2026-09-17 (macOS 26, Xcode 27, Rust 1.98, Node 24).

- **Xcode plus its Metal Toolchain.** gpui compiles Metal shaders at build
  time. Since Xcode 26 the Metal compiler is a separate download:
  `xcodebuild -downloadComponent MetalToolchain` (once, ~10 min). Without it
  the gpui build script fails with "metal shader compilation failed".
- **Rust** stable through rustup (`brew install rustup`).
- **Node >= 22.18** on PATH (or `TW_NODE=/path/to/node`). Node strips
  TypeScript types natively, so plugins need no build step. `plugins/` is a
  normal npm project: `cd plugins && npm install` once, for the editor's
  TypeScript service and `npm run check`.
- **Zig 0.15.2, exactly:** `brew install zig@0.15`. The `libghostty-vt-sys`
  0.2.1 build script clones Ghostty at commit `a887df4` and runs `zig build`;
  that commit's `build.zig.zon` requires Zig 0.15.2. Ghostty `main` already
  requires 0.16, so plain `brew install zig` (0.16) will not build this crate
  until the crate bumps its pin. When you bump `libghostty-vt`, re-check the
  pinned commit's `build.zig.zon`.
- **Command Line Tools** (`xcode-select --install`), for their older SDK. Zig
  0.15's bundled libc++ does not compile against the Xcode 27 SDK (its
  `math.h` defers `INFINITY` to a clang header protocol Zig's LLVM 20 lacks).
  The Command Line Tools ship SDK 26.5, which works. `scripts/build-libghostty.sh`
  builds the one crate with `DEVELOPER_DIR` pointed at the Command Line Tools;
  gpui keeps using Xcode for Metal. Cargo does not fingerprint that variable,
  so one run is enough until `cargo clean`.
- **Network on first build.** The build script clones Ghostty and Zig fetches
  its packages. Later builds are offline.
- **The engine is always built optimised.** `.cargo/config.toml` sets
  `LIBGHOSTTY_VT_SYS_OPTIMIZE=ReleaseFast`; without it a cargo dev build gets
  a Zig Debug build of Ghostty, whose VT parser and image decoding are many
  times slower and stall the UI on large Kitty images. The app logs
  `libghostty <version> built as <mode>` at startup; it must say ReleaseFast.

```bash
export PATH="/opt/homebrew/opt/zig@0.15/bin:/opt/homebrew/opt/rustup/bin:$PATH"
cd terminal_workflows
scripts/build-libghostty.sh   # once per clean checkout
(cd plugins && npm install)   # once, editor support for plugins
cargo run
```

`.envrc` sets the same PATH for direnv users. The first `cargo run` compiles
gpui (~3 min); after that, incremental builds take seconds.

## Try it

`cargo run` opens a window with one shell tab and the plugin sidebar. The
native title bar is gone: the top strip holds the tabs and its own minimize
(–) and close (×) buttons; drag the `◆ terminal_workflows` label to move
the window.

- **Tabs:** `cmd-t` new, `cmd-w` or the tab's × closes, `cmd-shift-]` /
  `cmd-shift-[` next / previous, `cmd-1`..`cmd-9` jump, click a tab or `+`.
  Reorder with `cmd-shift-left` / `cmd-shift-right`, or drag a tab: drop it
  on another tab to take that slot, or on the empty strip to send it to the
  end. Every move or close slides the affected tabs from their old slot to
  the new one (220 ms), so it is visible what went where. The strip scrolls
  sideways when tabs overflow and follows the active tab. The window itself
  moves only by dragging the `◆ terminal_workflows` label.
- **Terminal:** drag to select (double-click a word, triple-click a line,
  hold `alt` for a rectangle), `cmd-c` copy, `cmd-v` paste (bracketed when
  the app asked for it), `cmd-a` select all, wheel to scroll the
  scrollback. Apps that ask for mouse reports (vim, tmux, htop) get them;
  hold `shift` to select text anyway.
- **Find:** `cmd-f` opens a bar above the terminal. Type to search the
  screen and scrollback (case-insensitive), `enter` / `shift-enter` step
  through matches, `escape` closes. The current match is selected, so
  `cmd-c` copies it.
- **Plugins:** `cmd-r` reloads them. Saving any file under `plugins/` does
  the same. Edit `plugins/hello.ts` and watch the sidebar change.
- **Window:** `cmd-m` minimizes, `cmd-q` quits.
- **Documents:** anything can push a markdown document into the sidebar
  through the control socket (below); × or the Shell menu closes it.
- **Images:** the Kitty graphics protocol, both direct placements
  (`kitten icat`, image.nvim) and Unicode-placeholder placements (snacks.image,
  and through it fff's file preview). PNG, RGB, RGBA and grayscale payloads;
  z-index layers below the background, below the text and above the text;
  images scroll with the text and are cropped at the viewport edge. The
  terminal answers XTVERSION as `ghostty <version> (terminal_workflows)`,
  which is what snacks.image checks before it draws anything.

## Neovim: hover in the sidebar

`clients/nvim` is a small plugin. It wraps `vim.lsp.buf.hover`, so your
existing `K` mapping keeps its popup and the same hover text also appears in
the app's sidebar, rendered as markdown with highlighted code. It also adds
`:TW` for sending anything else.

The dotfiles already carry the lazy.nvim spec
(`dotfiles/nvim/lua/plugins/terminal_workflows.lua`). It points at
`~/Documents/personal/dotfiles/terminal_workflows/clients/nvim` and only
loads when that folder exists, so it is inert until this branch is merged
or checked out there. On another machine:

```lua
{ dir = "/path/to/terminal_workflows/clients/nvim", name = "terminal_workflows",
  event = "LspAttach", opts = {} }
```

Test it in three steps:

0. The spec must be in the config Neovim reads (`~/.config/nvim` points at
   the `main` checkout, so on this machine a copy was placed there until the
   branch merges). It looks in the main checkout and in `.claude/worktrees`
   folders (a `**` glob skips hidden folders, so those are listed
   explicitly). Restart Neovim after adding it; `:TW status` must say the
   app is reachable and `K` is wrapped.
1. `cargo run` here. The sidebar shows `socket · <path>`. The socket file
   disappears when the app quits, so a `K` with the app closed only shows
   a "Is the app running?" notice in Neovim.
2. In Neovim (same login session, so `$TMPDIR` matches), open any file with
   an LSP attached and press `K`. The popup opens as before and the sidebar
   shows the same content with a `file:line  word` title.
3. Without Neovim: `printf '{"type":"showMarkdown","title":"hi","markdown":"# Hello\n\n`code` and **bold**"}\n' | nc -U "$TMPDIR/terminal_workflows.sock"`.
   The app answers `{"type":"ok"}` per line.

If nothing shows up, `:checkhealth terminal_workflows` (or `:TW status`)
reports whether the socket is reachable, whether `K` is wrapped, and which
hover-capable servers are attached. Plugins that replace
`vim.lsp.buf.hover` (noice, hover.nvim) are re-wrapped on every LspAttach.

`:TW hover` mirrors once without the popup, `:TW md README.md` shows a file,
`:TW tab` opens a tab, `:TW send make test` types into the active shell,
`:TW json {...}` sends a raw command. Set `TW_SOCKET` in both processes to
use a different socket path. The Kotlin-specific `K` in
`lua/lima_the_lime/kotlin_lsp.lua` calls the server directly and is not
mirrored; call `:TW hover` there or route it through `require("terminal_workflows").hover`.

## Architecture

```
                 ┌───────────────────────────────────────────────┐
                 │ tw-app (binary, gpui)                         │
                 │                                               │
  keyboard ──▶   │  actions ─┐                                   │
  plugin  ──▶    │  HostCommand ──▶ AppCommand ──▶ Workspace     │
  nvim/socket ─▶ │  (tw-control)┘       (one match)   │          │
                 │                                    ▼          │
                 │   ┌────────────┐  ┌───────────┐  ┌──────────┐ │
                 │   │ title strip│  │ terminal  │  │ sidebar  │ │
                 │   │ tabs – ×   │  │ view      │  │ widgets  │ │
                 │   └────────────┘  └─────┬─────┘  └────┬─────┘ │
                 └─────────────────────────┼─────────────┼───────┘
                                           │             │ stdin/stdout, JSON lines
                 ┌─────────────────────────▼───┐   ┌─────▼──────────────────┐
                 │ tw-terminal                 │   │ tw-scripting            │
                 │ PTY (portable-pty)          │   │ NodeHost: spawns Node   │
                 │ libghostty-vt Terminal      │   │ on plugins/host.ts      │
                 │ RenderState → Grid          │   │ HostRequest → render,   │
                 │ key/mouse encoders          │   │   action, reload        │
                 │ selection gestures, search  │   │ HostMessage ← rendered, │
                 │ reader thread → channel     │   │   actions, changed, log │
                 └─────────────────────────────┘   └────────────────────────┘
                                                            │
                                                   ┌────────▼───────────────┐
                                                   │ plugins/ (npm project) │
                                                   │ host.ts  runtime       │
                                                   │ api.ts   types+helpers │
                                                   │ hello.ts example       │
                                                   │ fs.watch → re-import   │
                                                   └────────────────────────┘
```

Four crates. The dependency direction is enforced by Cargo: only `tw-app`
knows gpui exists.

- **`crates/tw-terminal`** — one shell session. Spawns the user's `$SHELL` on
  a PTY, feeds its output into a `libghostty_vt::Terminal`, and exposes a
  `Grid` snapshot (rows of styled cells plus the cursor) for painting. Turns
  a `KeyInput` into the bytes the shell expects with Ghostty's key encoder,
  routes `MouseInput` either to Ghostty's mouse encoder (when the app asked
  for reports) or to Ghostty's selection gestures, formats the selection for
  the clipboard, encodes pastes, and searches the formatter's plain-text dump
  of the screen plus scrollback. Kitty graphics: Ghostty stores the images
  (a `png` decoder is registered once per process); the session lists the
  visible placements per layer in `Grid::images` and hands out decoded RGBA
  pixels by image id, keyed by Ghostty's generation stamp. Virtual
  placements are rebuilt from their placeholder cells (`kitty_placeholder.rs`
  decodes the U+10EEEE cells' diacritics and colour into image, row and
  column; runs of adjacent cells become one paint each), because libghostty
  lists them but reports no geometry for them. A reader thread blocks on the PTY and sends
  bytes over a channel; the UI drains it on its own thread. All libghostty
  handles are `!Send`, so they live in the UI thread.
- **`crates/tw-scripting`** — the plugin runtime. `NodeHost` spawns
  `plugins/host.ts` under Node and exchanges one JSON object per line over
  stdin/stdout. Requests are fire-and-forget with an id; answers come back as
  `HostEvent`s on a channel. `protocol.rs` holds every message as a serde
  enum, mirrored by `plugins/api.ts`.
- **`crates/tw-control`** — the Unix socket at `$TMPDIR/terminal_workflows.sock`
  (`TW_SOCKET` overrides). One accept thread, one thread per client, one
  JSON `HostCommand` per line in, one `{"type":"ok"}` or
  `{"type":"error",..}` line out. A stale socket file from a crash is
  replaced; a live one makes the second instance report "already running".
- **`crates/tw-app`** — the gpui binary. `Workspace` owns the tabs and the
  plugin host and is the single place that executes `AppCommand`.
  `TerminalView` owns one session, paints its grid on a `canvas` element,
  handles keys, mouse, clipboard and the find bar. `titlebar.rs` hides the
  macOS traffic lights so the strip's own buttons are the only ones.
  `markdown.rs` parses markdown (pulldown-cmark) into blocks and renders
  them; fenced code is highlighted with syntect (base16-ocean.dark).
- **`clients/nvim`** — the Neovim plugin: `send(command)`, `hover()`,
  `mirror_hover()`, `show_file()`, and the `:TW` command.
- **`plugins/`** — a small npm project. `host.ts` imports every other `.ts`
  file, watches the folder, and re-imports on change (cache-busted `import()`).
  `api.ts` exports the types and small builders (`text`, `button`, `column`,
  `row`). Plugins may be async, import npm packages, use `fetch` and timers.

### Data flow per frame

1. PTY bytes arrive on the channel; the foreground task drains everything
   available, calls `Terminal::vt_write` once per chunk, then `cx.notify()`.
2. `TerminalView::layout` (canvas prepaint) measures the cell size from the
   font, resizes the terminal and the PTY if the bounds imply a new grid,
   and remembers the bounds for mouse math.
3. `RenderState::update` gives a snapshot; rows and cells become background
   quads, one shaped text segment per run of narrow cells, then the cursor.
   Kitty placements become `paint_image` calls: the whole texture is scaled
   so the visible source rectangle lands on the placement's cells and the
   paint is clipped to them. Textures are cached per image generation and
   dropped when no longer placed.
4. A key press becomes `KeyInput`, then bytes through Ghostty's encoder,
   then a write to the PTY. Query responses the terminal must answer itself
   go back through the `on_pty_write` callback.

### Plugin round trip

1. Something changes (tab opened, title changed, host said `changed`) and
   the workspace sends `render {id, state}` to the host.
2. `host.ts` calls every plugin's `render(state)` and answers
   `rendered {id, views}`; the workspace stores the views and redraws.
3. A button click sends `action {id, plugin, action, state}`; the host
   answers `actions {id, commands}`; each command becomes an `AppCommand`.
4. A saved file triggers `fs.watch` → re-import → `changed`, which loops back
   to step 1. `cmd-r` sends `reload`. If Node dies, the sidebar shows its
   last stderr lines and `cmd-r` respawns it.

### Threads and processes

- **UI thread**: gpui, every libghostty handle.
- **One reader thread per tab**: blocking `read` on the PTY.
- **Node child process** with two reader threads (stdout → messages,
  stderr → log tail).

## Core types

The closed sets are enums and every dispatch is a `match` with no catch-all,
so adding a variant fails to compile at every site that has to care. Values
that come from outside (key names from the OS, gpui's mouse buttons, JSON
from the host) are parsed at the boundary into these enums and nothing
downstream re-checks strings.

```rust
// tw-app: the single dispatch point. Every producer converts into this.
enum AppCommand {
    NewTab, CloseTab(TabId), CloseActiveTab, SelectTab(usize), NextTab, PrevTab,
    WriteToTerminal { tab: Option<TabId>, text: String },
    MoveActiveTab(Direction), MoveTab { from, to },
    ReloadPlugins, Log(String),
    ShowDocument { title, markdown }, CloseDocument,
}

// tw-scripting: the wire format. `HostCommand` is what a plugin may ask for.
enum HostRequest<'a> { Render { id, state }, Action { id, plugin, action, state }, Reload }
enum HostMessage { Ready { plugins }, Rendered { id, views }, Actions { id, commands },
                   Failed { id, message }, Changed { plugins }, Log { message } }
enum HostCommand { WriteToTerminal { text }, NewTab, SelectTab { index }, Log { message },
                   ShowMarkdown { title, markdown } }
enum WidgetNode { Column { children, gap }, Row { children, gap },
                  Text { text, color, size }, Button { label, action } }

// tw-terminal: input as the UI saw it, before Ghostty encodes it.
struct KeyInput { key: Key, mods: Mods, text: Option<String>, unshifted: Option<char> }
struct MouseInput { phase: MousePhase, col, row, x, y, mods }
enum MousePhase { Press(MouseButton), Release(MouseButton), Move { held }, Wheel { lines } }
enum PtyRead { Data(Vec<u8>), Eof }
```

`Grid<C>` is generic over the colour type so `tw-terminal` stays free of
gpui's `Hsla`; `tw-app` passes a `Rgb -> Hsla` closure when it snapshots.

## Plugin API (TypeScript)

`plugins/api.ts` is the contract; `crates/tw-scripting/src/protocol.rs` is
its Rust twin and the host test round-trips both through the real host.

```ts
import { button, column, row, text, type Plugin } from "./api.ts";

const plugin: Plugin = {
  name: "hello",
  render(state) {
    return column([
      text(`${state.tabs.length} tabs, active #${state.activeTab + 1}`),
      row([button("Say hi", "hi"), button("New tab", "tab")], 6),
    ], 8);
  },
  onAction(action) {
    switch (action) {
      case "hi": return [{ type: "writeToTerminal", text: "echo hi\n" }];
      case "tab": return [{ type: "newTab" }];
      default: return [];
    }
  },
};
export default plugin;
```

- Node strips the types, so plugins use erasable syntax only (no `enum`,
  `namespace` or parameter properties; `tsconfig.json` enforces it) and
  import other files with their `.ts` extension. `npm run check` type-checks.
- `render` and `onAction` may be `async`. npm packages, `fetch` and timers
  work; `console.log` shows up in the sidebar log.
- A plugin that throws or fails to import shows its error in its card and
  does not affect the others.
- Plugin state does not survive a reload; keep state in module scope only
  if losing it on save is fine.

Why this shape: gpui itself has no scripting layer. The project usually
called "TypeScript for GPUI" is GPUIX (`remorses/gpuix`), a Node/Bun N-API
binding where a React tree in JS drives a GPUI window. That is the inverse
of what we want (JS host, Rust renderer). Here the host is Rust and the
plugins describe widgets as data, but they still run on a real Node with
the normal TypeScript toolchain. An earlier in-process QuickJS runtime was
replaced for that reason.

## Plan of action

Phase 0 — skeleton
- [x] Workspace, three crates, deps pinned, `.envrc`, this README.
- [x] `cargo build` succeeds with gpui 0.2.2 and a Zig-built libghostty-vt.

Phase 1 — terminal engine (`tw-terminal`)
- [x] `Session::spawn` opens a PTY, starts the reader thread, wires
      `on_pty_write` back to the PTY.
- [x] `Session::grid()` returns rows of cells with resolved fg/bg, bold,
      italic, underline, wide flag, plus cursor position and default colours.
- [x] `KeyInput` → bytes through Ghostty's key encoder; parsing of gpui key
      names happens at the boundary.
- [x] Mouse: selection gestures (cell/word/line, rectangle with `alt`),
      mouse reports for applications, wheel scrolling either way.
- [x] Clipboard: selection formatted like Ghostty copies it; bracketed paste.
- [x] Search over screen plus scrollback; a match scrolls into view and is
      selected.
- [x] Kitty graphics: direct and Unicode-placeholder placements in three
      layers, PNG decoding, cropping at the viewport edge, texture cache by
      generation, XTVERSION reply for snacks.image.

Phase 2 — window (`tw-app`)
- [x] `Workspace` with tab strip, `cmd-t/w/1..9`, next/prev, quit.
- [x] `TerminalView` paints on `canvas`, resizes the PTY to the element's
      bounds, forwards keys and mouse, find bar with `cmd-f`.
- [x] Custom title strip: no native bar, hidden traffic lights, own – and ×,
      drag to move. Tabs reorder by keyboard or drag and drop.
- [x] `AppCommand` is the only way to change state; keyboard actions and
      `HostCommand` convert into it.

Phase 3 — plugins (`tw-scripting` + `plugins/`)
- [x] Node child process host, JSON lines, async requests.
- [x] `WidgetNode` → gpui elements in the sidebar; button clicks dispatch.
- [x] `fs.watch` hot reload; `cmd-r` reload/restart; errors in the sidebar.
- [x] `plugins/hello.ts` example, `api.ts` contract, `tsconfig.json`.

Verified so far (2026-09-17)
- `cargo test --workspace`: 17 tests. A real `/bin/echo` on a PTY lands in
  the grid; inverse video swaps colours; a mouse drag selects "hello" and
  the clipboard text matches; `select_all` and `clear_selection` behave;
  30 lines in a 5-row terminal are all searchable, "LINE 27" is found in
  scrollback, scrolled into view and selected; the real `host.ts` under
  Node answers `ready`, renders `hello.ts` and dispatches its actions.
- `cargo run`: the window opens, each tab runs `zsh -l` on its own PTY,
  Node runs `host.ts` as a child, and a click on the plugin's "New tab"
  button opened a tab (earlier build, same command path). A headless
  Neovim loading `clients/nvim` sent `newTab` through the socket and a
  second shell appeared, so the Lua client reaches the app.
- Socket: `tw-control` tests write three lines through a real Unix socket
  and get the two commands, the bad-line report and the three replies back;
  `nc -U` against the running app shows a document in the sidebar.
- Markdown: parser tests cover code fences (highlighted into coloured runs,
  tabs expanded, blank lines kept), rules, headings, bold, inline code,
  lists and quotes.
- Kitty: a 2x2 PNG sent by `printf` as an APC `G` command shows up as one
  placement at the cursor, in the above-text layer, and decodes to the
  expected RGBA bytes; a `U=1` transmission followed by two placeholder
  cells becomes one two-cell run with the right image slice. Live: image.nvim
  in a markdown buffer and fff's preview (snacks.image) both placed an image
  in a debug instance and removed it on close. Stepping between a 1600x1000
  and a 320x200 preview in fff costs 3 ms to decode the big PNG, 5 ms to feed
  the command, under 1 ms to upload, and nothing when stepping back to an
  image still in the recent-texture cache. Two earlier causes of multi-second
  stalls are gone: the engine was a Zig Debug build, and every placeholder
  row re-uploaded the texture.
- Not yet checked by hand: the look of the title strip, typing into the
  shell, mouse selection in the live window, the find bar, drag-and-drop of
  tabs, the Neovim `K` path end to end, and wide glyph alignment.
  `RUST_LOG=debug cargo run` prints grid size and PTY byte counts.

Phase 4 — external control
- [x] Unix socket at `$TMPDIR/terminal_workflows.sock`, JSON lines, each line
      a `HostCommand`. Same enum as plugins, so nothing new to dispatch.
- [x] Neovim client: `vim.uv` pipe, hover mirroring, `:TW hover|tab|send|md|json`.
- [x] Markdown documents in the sidebar with highlighted code.
- [ ] Ghostty → app: a Ghostty keybind that runs a tiny `tw` CLI which writes
      one JSON line to the socket. Ghostty has no plugin API; a shell command
      is the bridge. Until then: `nc -U`.
- [ ] Events back out: `Terminal` callbacks (`on_title_changed`,
      `on_pwd_changed`, `on_bell`) become plugin events and socket lines.
- [ ] Documents as a stack or tabs in the sidebar instead of one at a time.

Phase 5 — terminal polish (later)
- [ ] Middle-click paste, link detection and `cmd-click`.
- [ ] Bold/italic font variants when the family has them.
- [ ] Kitty animation frames and placements that need the placement id
      (underline colour) to tell two placements of one image apart.
- [ ] Split panes.

## Decisions and the facts they rest on

- **`libghostty-vt` 0.2.1 from crates.io** (`uzaaft/libghostty-rs`). It is
  the crate Mitchell Hashimoto pointed at as the Rust front for libghostty-vt.
  It gives `Terminal`, `RenderState`, row/cell iterators with resolved
  colours, key and mouse encoders, selection gestures and a formatter. The
  repo's `example/ghostling_rs` is a complete 1400-line terminal on macroquad
  and is the reference for how those pieces are meant to be used.
- **We render, Ghostty does not.** The full libghostty (the one the Ghostty
  macOS app links) owns a Metal layer and cannot share a gpui window.
  libghostty-vt is state only, which is exactly the split gpui wants.
- **`gpui` 0.2.2 from crates.io**, not Zed's git `main`. crates.io gives a
  stable API with docs.rs, which matters when handing this to other agents.
  The last publish was 2025-10; if a needed feature only exists on `main`,
  switch to a pinned git rev and note it here.
- **Node as the plugin runtime.** Real TypeScript ergonomics (tsserver,
  npm, async, source positions in errors) beat an embedded engine. The cost
  is one child process and a JSON hop per render; the same JSON serves the
  future socket.
- **Search is ours, selection is Ghostty's.** libghostty-vt has no search
  API yet, so search runs over the formatter's plain-text dump and uses
  `Point::Screen` coordinates, which match the dump line by line. The match
  is shown by scrolling the viewport and setting a Ghostty selection.
- **Tab moves animate with FLIP.** The strip reports its children's bounds
  after every layout (`on_children_prepainted`); on a move or close the
  new x of each tab is predicted from the measured widths and the gap, and
  each tab that changed slot starts at `old_x - new_x` and eases to zero
  with gpui's `with_animation`, keyed by a generation counter so every
  change restarts it. Nothing else in the layout is touched.
- **Markdown is rendered, not embedded.** pulldown-cmark gives blocks,
  gpui's `StyledText` highlights give bold, italic, inline code and links,
  and each code line is one text element with syntect's colours, so nothing
  wraps or re-flows inside a fence. Tables become one line per row.
- **Title strip over native bar.** gpui's transparent title bar keeps the
  native rounded corners, shadow and edge resizing; hiding the three
  standard buttons is a short Objective-C call in `titlebar.rs`. AppKit's own
  title-region dragging swallowed tab drags and ignored a
  `mouseDownCanMoveWindow` override on gpui's view, and gpui 0.2.2's
  `start_window_move` is a no-op on macOS. So the window is created with
  `is_movable: false` and moved by hand: a mouse-down on the title label
  records the pointer and frame origin in screen space (`cocoa`), and every
  mouse-move while the button is down sets the frame origin to follow.

## Risks and open questions

- gpui 0.2.2 is a year old; a newer macOS SDK or Rust may break its build. If
  it does, move to a git pin and record the rev above.
- libghostty-vt is pre-1.0; each crate bump may change the API. Keep the
  `Session` wrapper thin so the churn stays in one file.
- Everything on the UI thread is measured: `RUST_LOG=debug` prints how long
  feeding PTY bytes, building the grid, laying out text and uploading an
  image took whenever any of them exceeds a few milliseconds.
- Node type stripping only covers erasable syntax. A plugin that needs
  `enum` or decorators needs a build step; none is wired.
- Font: `IosevkaTiago Nerd Font` if installed, otherwise gpui falls back to
  the system monospace. Cell width is measured from the font, so any
  monospace works. Wide glyphs are shaped alone at their own x, but a
  fallback font with a narrower advance will still look off.

## Working conventions for agents

- Read this file, then the latest log in `sessions/` (decisions, traps and
  the socket-driven test loop), then `crates/*/src/lib.rs` and
  `plugins/api.ts`, then the file you are changing. Add a new `sessions/`
  entry at the end of a session.
- New behaviour enters through `AppCommand` (UI) or `HostCommand` (plugins,
  socket). Do not add a second path.
- Closed sets are enums with exhaustive `match`; parse strings at the
  boundary only. Generic over the payload before duplicating a type.
- `cargo test --workspace` must pass; `cargo clippy --workspace --all-targets`
  should be clean; `cd plugins && npm run check` should be clean.
- The wire format lives in three places that must move together:
  `crates/tw-scripting/src/protocol.rs`, `plugins/api.ts`, and
  `clients/nvim/lua/terminal_workflows/init.lua`.
- This session had no Screen Recording or Accessibility permission, so the
  window was checked through CoreGraphics window lists, process trees and
  logs rather than screenshots. Grant those to the terminal you run agents
  from if you want them to see the window.
- This lives on a branch of the dotfiles repo. Never push to `main`; the repo
  is public, so nothing here is private once pushed.
