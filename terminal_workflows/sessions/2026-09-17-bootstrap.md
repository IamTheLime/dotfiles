# Session 2026-09-17: from empty folder to a working terminal with plugins

Compressed log of the first session. The README is the source of truth for
how things work; this file records why they are the way they are, what bit
us, and how to pick the work up again.

## Where things stand

- Branch `claude/ghostty-gpui-terminal-555100` of the public dotfiles repo,
  checked out as a worktree under `dotfiles/nvim/.claude/worktrees/relaxed-maxwell-7ac5f1/`.
  Not merged. A branch cannot be hidden on GitHub; the alternative is a
  separate private repo.
- Four crates (`tw-terminal`, `tw-scripting`, `tw-control`, `tw-app`), a
  `plugins/` npm project run by Node, a Neovim client in `clients/nvim`, and
  the lazy.nvim spec at `dotfiles/nvim/lua/plugins/terminal_workflows.lua`.
  A copy of that spec was also dropped, untracked, into the `main` checkout's
  `dotfiles/nvim/lua/plugins/` so the user's live Neovim loads the client
  before the merge. Delete that copy if a merge complains about it.
- 20 tests, clippy clean, `npm run check` clean. Verified live: shell, tabs,
  plugin buttons, socket, Neovim `K` mirror, image.nvim, fff previews.
- Not verified by hand in this session (no Screen Recording or Accessibility
  permission): the look of the title strip, tab drag-and-drop feel, the find
  bar, mouse selection in the live window. The user confirmed `K` mirrors
  and fff previews are "blazingly fast". Tab dragging was NOT confirmed: the
  `mouseDownCanMoveWindow` override did not stop AppKit from moving the
  window, so a later session must take a different route (see the follow-up
  session log).

## What the user asked for, in order

1. Rust app on libghostty + gpui, README plan first, tabs, generics/enums/
   exhaustive matches, a TypeScript plugin example with hot reload.
2. Plugins must run on real TypeScript tooling, not an embedded QuickJS.
3. Terminal basics are must-haves: mouse selection, copy/paste, search.
4. No native title bar; own minimize and close buttons; "looking cool".
5. Reorder tabs (keyboard and drag); mirror Neovim `K` hover into the
   sidebar as rendered markdown next to the popup.
6. Kitty graphics (PNG previews) like Ghostty.
7. Everything as fast as Ghostty.

## Decisions and their reasons

- `libghostty-vt` 0.2.1 (crates.io, `uzaaft/libghostty-rs`): Terminal,
  RenderState, encoders, selection gestures, formatter, Kitty storage. We
  paint; the full libghostty owns a Metal layer and cannot share gpui's window.
- `gpui` 0.2.2 from crates.io, not Zed git: docs.rs and a stable API matter
  for handing work to other agents. Last publish 2025-10.
- Plugin runtime = Node child process (`plugins/host.ts`) over JSON lines.
  QuickJS + oxc worked but was rejected for ergonomics; the JSON protocol was
  kept and now also serves the socket.
- One command enum per boundary: `AppCommand` (UI, single `execute`),
  `HostCommand` (plugins and socket). Parse strings at the boundary; closed
  sets are enums with exhaustive matches; external enums (gpui, libghostty
  `#[non_exhaustive]`) get a catch-all only at the conversion.
- Search is ours (formatter dump + `Point::Screen` coordinates), selection is
  Ghostty's (gestures, `is_selected`, `format_selection`).
- Markdown: pulldown-cmark to blocks, gpui `StyledText` highlights, syntect
  per code line so fences never reflow.
- Title strip: transparent native titlebar keeps rounded corners, shadow and
  edge resize; traffic lights hidden with objc; window drag only from the
  brand label.

## Traps, each as symptom → cause → fix

- Zig build of libghostty fails with `INFINITY` undeclared → Xcode 27 SDK
  defers it to a clang protocol Zig 0.15's LLVM 20 lacks → build that one
  crate with `DEVELOPER_DIR=/Library/Developer/CommandLineTools` (SDK 26.5):
  `scripts/build-libghostty.sh`. Cargo does not fingerprint that variable.
- gpui build: "metal shader compilation failed" → Xcode 26+ ships the Metal
  compiler separately → `xcodebuild -downloadComponent MetalToolchain`.
- libghostty-rs README says Zig 0.16 → the published 0.2.1 crate pins a
  Ghostty commit needing 0.15.2 → `brew install zig@0.15`; re-check
  `build.zig.zon` on every crate bump.
- Control test passed alone, failed in the workspace → another crate enables
  serde_json `preserve_order`, changing key order → never assert on JSON text.
- Kitty test flaky → macOS drops PTY output when the child exits at once →
  `sleep 0.3` after `printf` in tests.
- Kitty test passed alone, failed after other tests → libghostty stores the
  PNG decoder in a thread-local and libtest runs each test on its own
  thread → register the decoder per thread.
- Dragging a tab moved the window → gpui 0.2.2's `start_window_move` is a
  no-op on macOS and AppKit drags the window on any title-region mouse-down
  when the view answers YES to `mouseDownCanMoveWindow` → `titlebar.rs` adds
  a NO answer to gpui's view class with `class_addMethod` and starts
  `performWindowDragWithEvent:` itself from the label.
- Neovim never loaded the plugin → the spec lived only on the branch, and
  Vim's `**` glob skips hidden folders like `.claude/worktrees` → explicit
  patterns, spec copied into the live config, `:checkhealth terminal_workflows`.
- fff previews blank while image.nvim worked → fff uses snacks.image, which
  needs an XTVERSION reply naming a known terminal and draws with Unicode
  placeholders → `on_xtversion` answers `ghostty <version> (terminal_workflows)`;
  libghostty lists virtual placements but reports no geometry, so
  `kitty_placeholder.rs` decodes the U+10EEEE cells (diacritics table from
  Ghostty's `graphics_unicode.zig`) and merges rows into paint runs.
- Image switching "almost crashed" → three stacked causes: engine built in
  Zig Debug (fixed by `.cargo/config.toml` `LIBGHOSTTY_VT_SYS_OPTIMIZE=ReleaseFast`),
  the texture cache missed entries added in the same frame so every
  placeholder row re-uploaded (16 ms x 40 rows x every frame), and the two
  frame-path crates ran unoptimised (dev `opt-level = 2` for `tw-terminal`
  and `tw-app`). Result: 1600x1000 PNG in 3 ms decode + under 1 ms upload,
  nothing on the way back thanks to an 8-entry recent-texture cache.

## Follow-up in the same day: tab dragging, take three

The user reported tabs still moved the window and asked for a scrollable tab
strip. Root cause of the drag: AppKit drags a window from the transparent
title region on its own, ignores `mouseDownCanMoveWindow` on gpui's view,
and gpui 0.2.2's `start_window_move` is a no-op on macOS. Fix: create the
window with `is_movable: false` so AppKit never drags it, and move it by
hand from the title label (`titlebar::WindowDrag`: pointer and frame origin
in screen space via `cocoa`, frame origin follows each mouse-move). Tabs
live in an `overflow_x_scroll` container with a `ScrollHandle` that
`scroll_to_item`s the active tab. Then: a × on each tab (its mouse-down
stops propagation so it neither selects nor drags), and a FLIP slide
animation on move and close (bounds measured with `on_children_prepainted`,
new positions predicted from widths + gap, `with_animation` + `ease_out_quint`,
keyed by a generation counter). None of these could be verified by mouse
from the agent session; the user tests them.

## How the app was tested without a mouse

- Start a second instance on its own socket: `TW_SOCKET=/tmp/tw-test.sock
  RUST_LOG=debug ./target/debug/terminal-workflows`, log through
  `grep --line-buffered | tee`.
- Drive it through the socket with `writeToTerminal` (type `nvim file`,
  `;f`, a query, `ctrl-n`, `:qa!`) and read the debug log: grid size,
  bytes fed and their time, `N kitty image(s) on screen`, decode, swap and
  upload times. That loop found every performance problem above.
- Neovim side: `nvim --headless --clean -c "luafile script.lua"` with
  `vim.wait` loops; a real `lua-language-server` attached from Mason gave a
  real hover. `-l` exits before timers fire; use `-c luafile`.
- Window presence via a Swift `CGWindowListCopyWindowInfo` snippet; shell
  and Node children via `pgrep -P`.

## Next steps the user has mentioned or that follow naturally

- Phase 4 remainder: a `tw` CLI for Ghostty keybinds, events back out of the
  terminal (title, pwd, bell) to plugins and socket, several documents in the
  sidebar instead of one.
- Kitty: animation frames; placement ids from the underline colour when one
  image has several placements.
- Terminal polish: middle-click paste, link detection, bold/italic font
  variants, split panes.
- Consider moving PNG decode and texture upload off the UI thread if a
  workload ever shows it in the timers.

## Resume checklist

```bash
export PATH="/opt/homebrew/opt/zig@0.15/bin:/opt/homebrew/opt/rustup/bin:$PATH"
cd terminal_workflows
scripts/build-libghostty.sh          # only after cargo clean or a crate bump
cargo test --workspace && cargo clippy --workspace --all-targets
(cd plugins && npm run check)
RUST_LOG=debug cargo run             # startup must log: built as "ReleaseFast"
```

In Neovim: `:TW status` must show the socket reachable and `K` wrapped.
