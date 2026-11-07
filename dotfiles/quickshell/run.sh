#!/usr/bin/env bash
set -euo pipefail
config_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${QS_PLATFORM:-}" ]]; then
    session_desktop="${XDG_CURRENT_DESKTOP:-}"
    case "${session_desktop,,}" in
        *gnome*) export QS_PLATFORM=gnome ;;
        *kde*|*plasma*) export QS_PLATFORM=kde ;;
        *) echo 'Set QS_PLATFORM=kde or QS_PLATFORM=gnome for this session.' >&2; exit 1 ;;
    esac
fi
case "$QS_PLATFORM" in
    gnome)
        export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
        if ! gdbus introspect --session --dest org.gnome.Shell --object-path /org/dotfiles/Quickshell 2>/dev/null | grep -q org.dotfiles.Quickshell.Desktop; then
            echo 'Enable quickshell-bridge@dotfiles.local in GNOME before launching. See README.md.' >&2
            exit 1
        fi
        ;;
    kde) ;;
    *) echo "Unsupported QS_PLATFORM: $QS_PLATFORM" >&2; exit 1 ;;
esac
exec qs -p "$config_dir/desktop" "$@"
