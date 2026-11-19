#!/bin/bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$(uname -s)" in
    Darwin) FONT_DIR="$HOME/Library/Fonts" ;;
    Linux) FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/picker-icons" ;;
    *) echo "Unsupported font installation platform" >&2; exit 1 ;;
esac

SOURCE="$SOURCE_DIR/PickerIcons.ttf"
TARGET="$FONT_DIR/PickerIcons.ttf"
[[ -f "$SOURCE" ]] || { echo "Build the font first: uv run $SOURCE_DIR/build.py" >&2; exit 1; }
mkdir -p "$FONT_DIR"
if [[ -e "$TARGET" || -L "$TARGET" ]]; then
    if [[ ! -L "$TARGET" || "$(readlink "$TARGET")" != "$SOURCE" ]]; then
        mv "$TARGET" "$TARGET.backup.$(date +%Y%m%d-%H%M%S)"
    fi
fi
ln -sfn "$SOURCE" "$TARGET"
if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$FONT_DIR"
fi
echo "Installed Picker Icons: $TARGET"
echo "Restart Ghostty to load the font; new tabs may reuse its old font cache."
