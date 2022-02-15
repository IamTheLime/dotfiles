#!/usr/bin/env bash
# Symlink the agent instructions and skills in this repo into the places the
# various CLI agents look for them. Safe to re-run.
#
# Never escalates. Anything that needs root is printed for you to run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CODEX_BUNDLE="personal-agent-skills"

linked=0
skipped=0
pending=()

info() { printf '  %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }

# link <source> <destination>
#
# Replaces an existing symlink into this repo, backs up a non-empty regular
# file, removes an empty one, and refuses to touch a real directory or a
# symlink pointing somewhere else. A destination we can't write to is queued
# as a sudo command rather than attempted.
link() {
    local src="$1" dest="$2" parent
    parent="$(dirname "$dest")"

    if [[ ! -e "$src" ]]; then
        warn "missing source, skipping: $src"
        skipped=$((skipped + 1))
        return
    fi

    if [[ -e "$parent" && ! -w "$parent" ]]; then
        pending+=("sudo ln -sfn '$src' '$dest'")
        info "needs root, queued: $dest"
        skipped=$((skipped + 1))
        return
    fi

    mkdir -p "$parent"

    if [[ -L "$dest" ]]; then
        local current
        current="$(readlink "$dest")"
        if [[ "$current" == "$src" ]]; then
            info "ok       $dest"
            return
        fi
        if [[ "$current" != "$ROOT"/* ]]; then
            warn "points outside this repo, leaving alone: $dest -> $current"
            skipped=$((skipped + 1))
            return
        fi
        rm "$dest"
    elif [[ -d "$dest" ]]; then
        warn "real directory, leaving alone: $dest"
        skipped=$((skipped + 1))
        return
    elif [[ -f "$dest" ]]; then
        if [[ -s "$dest" ]]; then
            mv "$dest" "$dest.bak.$STAMP"
            info "backed up $dest -> $dest.bak.$STAMP"
        else
            rm "$dest"
        fi
    fi

    ln -s "$src" "$dest"
    info "linked   $dest"
    linked=$((linked + 1))
}

echo "claude"
for skill in "$ROOT"/skills/*/; do
    [[ -f "$skill/SKILL.md" ]] || continue
    link "${skill%/}" "$CLAUDE_HOME/skills/$(basename "$skill")"
done
link "$ROOT/instructions/AGENTS.md" "$CLAUDE_HOME/CLAUDE.md"

echo
echo "codex"
if [[ -d "$CODEX_HOME" ]]; then
    # Codex takes a bundle directory of skills plus a manifest beside it, so the
    # whole skills/ tree links as one unit rather than skill by skill.
    link "$ROOT/skills" "$CODEX_HOME/skills/$CODEX_BUNDLE"
    link "$ROOT/codex-bundle.json" "$CODEX_HOME/skills/$CODEX_BUNDLE.json"
    link "$ROOT/instructions/AGENTS.md" "$CODEX_HOME/AGENTS.md"
else
    info "no $CODEX_HOME, skipping"
fi

echo
echo "$linked linked, $skipped skipped"

if ((${#pending[@]})); then
    echo
    echo "$CODEX_HOME is root-owned. To finish, run:"
    printf '  %s\n' "${pending[@]}"
fi
