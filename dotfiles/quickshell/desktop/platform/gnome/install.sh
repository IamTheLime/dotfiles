#!/usr/bin/env bash
set -euo pipefail
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/extension"
target_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/quickshell-bridge@dotfiles.local"
install -d "$target_dir"
for file in metadata.json extension.js protocol.js; do
    install -m 644 "$source_dir/$file" "$target_dir/$file"
done
cat <<'MESSAGE'
Installed the experimental GNOME bridge.
Log out and back in, then run:
  gnome-extensions enable quickshell-bridge@dotfiles.local
Launch Quickshell with the repository's quickshell/run.sh.
To remove the integration:
  gnome-extensions disable quickshell-bridge@dotfiles.local
MESSAGE
