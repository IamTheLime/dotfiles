# dotfiles

Personal shell, editor and agent config. Two installers, both idempotent and
backing up anything they replace.

## Install

```sh
./setup_environment.sh   # shell + app configs (prompts per app)
agents/install.sh        # agent instructions + skills
```

Trial in a container instead: `./docker_build_local.sh && ./docker_run_local.sh`
(fzf-tab under tmux is flaky there — Docker default shell).

## Required CLIs

Hard deps (`setup_environment.sh` refuses without them): `fd` `bat` `eza`
`nvim` `git` `curl`. Also needs `zsh` + `fzf`. On Debian/Ubuntu `fd`/`bat` are
`fdfind`/`batcat`; the zshrc aliases them.

Pulled in automatically: oh-my-zsh and the `fzf-tab`, `zsh-autosuggestions`,
`zsh-syntax-highlighting` plugins (git-cloned by the installer).

Config-only (installed if you have the app): Ghostty, Zed, Sioyek, Hyprland,
tmux, IntelliJ (ideavim), Quickshell.

## Where things land

| Source                     | Symlinked to                                   |
| -------------------------- | ---------------------------------------------- |
| `dotfiles/zshrc`           | `~/.zshrc_dotfiles` (sourced from `~/.zshrc`)  |
| `dotfiles/nvim`            | `~/.config/nvim`                               |
| `dotfiles/ghostty`         | `~/.config/ghostty`                            |
| `dotfiles/starship.toml`   | `~/.config/starship.toml`                      |
| `dotfiles/opencode/themes/ember-grove.json` | `~/.config/opencode/themes/ember-grove.json` |
| `dotfiles/zed`             | `~/.config/zed`                                |
| `dotfiles/hyprland`        | `~/.config/hypr`                               |
| `dotfiles/sioyek`          | `~/.config/sioyek` (Linux) / Application Support (macOS) |

## Palette library

Point a theme-generating agent at [`palettes/README.md`](palettes/README.md)
and [`palettes/ember-grove/`](palettes/ember-grove/). The library contains exact
hex colours, semantic roles, ANSI slots, background rules and a reusable agent
prompt, independent of any application's config format.

## Ember Grove theme

Neovim and Ghostty default to **Ember Grove**, a local dark theme using the
Aether/Omarchy palette from the SDL examples site: green-black surfaces with
gold, amber and copper syntax colours, plus a restrained sage green borrowed
from OpenCode Matrix. No theme download or Omarchy install is required.

- Neovim: `dotfiles/nvim/themes/ember-grove`. The editor, sidebars and floats
  have transparent backgrounds so Ghostty supplies the matching green-black.
  Completion menus and selections retain solid backgrounds for readability.
  Set `transparent = false` in `lua/plugins/theme.lua` for an opaque editor.
  Variables are sage, parameters sage italic, fields gold, constants bold gold,
  functions copper and keywords orange. Markdown bold is mint and headings/links
  are teal, so key text differs in hue as well as weight.
  LSP readonly variables/properties use
  the constant colour when the language server supplies those semantic tokens.
- Ghostty: `dotfiles/ghostty/themes/Ember Grove`. Uses all 16 palette colours;
  selection text is light gold for contrast. Reload with **Ctrl+Shift+,**
  (Linux) or **Cmd+Shift+,** (macOS).
- Change Neovim's startup theme with `active_theme` in `lua/plugins/theme.lua`,
  or use `:colorscheme <name>` during a session. Lualine reads the active
  highlights and interpolates matching section backgrounds on each
  colourscheme/background change, including light themes.

Theme regression checks (using locally installed lualine):

```sh
nvim --headless -u NONE -l dotfiles/nvim/tests/theme.lua
ghostty +validate-config
```

## OpenCode theme

`dotfiles/opencode/themes/ember-grove.json` is a complete dark TUI theme, not
the terminal-derived `system` theme. Its main background is transparent, so
Ghostty's existing background remains untouched; solid panels use the palette's
subtle green-black surfaces rather than adding a green overlay.
Body text stays gold, while bold key
phrases are mint, italic emphasis/inline code copper, and headings/links teal.
Mode/agent colours use a restrained teal/copper/sage-family sequence rather
than repeating the body colour.

The installer links this theme file into `~/.config/opencode/themes/` and merges
the theme selection from `dotfiles/opencode/cli.json` into your global CLI
settings, backing up changes and preserving other settings/plugins. The
repository's CLI file deliberately contains no machine-specific plugin paths.
For a newly added theme file, open a fresh TUI so it discovers the file.
Use `/themes` to switch between **ember-grove**, **system** and **matrix**.
CLI setting edits reload automatically.

Prompt, theme-reference and installer-merge checks:

```sh
python3 -m unittest discover -s tests -v
```

## Starship prompt

`dotfiles/starship.toml` matches Ember Grove without background blocks.
An orange vertical rail and a blank line make command boundaries stand out:

```text
│ …/sebenta/main [!?]  main — 14:32
│ ❯
```

Git modifiers precede the sage branch (`!` modified, `+` staged, `?` untracked,
`×` deleted, `»` renamed, `≡` stashed, `=` conflicted, `⇡`/`⇣` ahead/behind).
Clean trees omit the modifiers. Detached commits and in-progress Git operations
remain visible; the clock uses local 24-hour time. Failed commands show `✗`,
and continuation prompts keep the same rail.

The installer offers to link this config; an existing Starship installation
reads changes automatically at the next prompt.

## Where the agents land

`agents/install.sh` (see `agents/README.md` for the full story):

| Target       | Gets                                                          |
| ------------ | ------------------------------------------------------------ |
| Claude Code  | one symlink per skill in `~/.claude/skills/`, plus `~/.claude/CLAUDE.md` -> `agents/instructions/AGENTS.md` |
| Codex        | whole tree as `~/.codex/skills/personal-agent-skills/` + `.json` manifest, plus `~/.codex/AGENTS.md` |

Override targets with `CLAUDE_HOME` / `CODEX_HOME`. A root-owned `~/.codex`
isn't touched — the `sudo ln` lines are printed for you to run.

## Quickshell on KDE

See [installation, launch and customization](dotfiles/quickshell/README.md).
The optional installer links the named `desktop` configuration; it does not
enable autostart or change Plasma settings.
