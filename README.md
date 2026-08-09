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
tmux, IntelliJ (ideavim).

## Where things land

| Source                     | Symlinked to                                   |
| -------------------------- | ---------------------------------------------- |
| `dotfiles/zshrc`           | `~/.zshrc_dotfiles` (sourced from `~/.zshrc`)  |
| `dotfiles/nvim`            | `~/.config/nvim`                               |
| `dotfiles/ghostty`         | `~/.config/ghostty`                            |
| `dotfiles/zed`             | `~/.config/zed`                                |
| `dotfiles/hyprland`        | `~/.config/hypr`                               |
| `dotfiles/sioyek`          | `~/.config/sioyek` (Linux) / Application Support (macOS) |

## Where the agents land

`agents/install.sh` (see `agents/README.md` for the full story):

| Target       | Gets                                                          |
| ------------ | ------------------------------------------------------------ |
| Claude Code  | one symlink per skill in `~/.claude/skills/`, plus `~/.claude/CLAUDE.md` -> `agents/instructions/AGENTS.md` |
| Codex        | whole tree as `~/.codex/skills/personal-agent-skills/` + `.json` manifest, plus `~/.codex/AGENTS.md` |

Override targets with `CLAUDE_HOME` / `CODEX_HOME`. A root-owned `~/.codex`
isn't touched — the `sudo ln` lines are printed for you to run.
