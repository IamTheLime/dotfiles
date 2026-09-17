#!/usr/bin/env bash
# Build libghostty-vt once with the Command Line Tools SDK.
#
# Zig 0.15.2 (required by the Ghostty commit the crate pins) bundles LLVM 20
# headers. The Xcode 27 SDK's math.h defers INFINITY/NAN to a newer clang
# protocol, so Zig's own libc++ fails to compile against it. The Command Line
# Tools ship SDK 26.5, which still defines INFINITY directly. gpui needs
# Xcode's Metal compiler, so the override is scoped to this one crate.
#
# Cargo does not fingerprint DEVELOPER_DIR, so after this succeeds a plain
# `cargo build` / `cargo run` reuses the result until `cargo clean` or a bump
# of libghostty-vt.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/opt/zig@0.15/bin:/opt/homebrew/opt/rustup/bin:$PATH"
# LIBGHOSTTY_VT_SYS_OPTIMIZE=ReleaseFast comes from .cargo/config.toml.
DEVELOPER_DIR=/Library/Developer/CommandLineTools cargo build -p libghostty-vt-sys "$@"
