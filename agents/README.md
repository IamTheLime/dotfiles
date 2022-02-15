# agents

Personal, tool-agnostic guidance for coding agents. Nothing here is specific to
an employer, a repo, or a service — that belongs in the repo it describes.

## Layout

- **`instructions/AGENTS.md`** — always-on context. Loaded every session,
  regardless of task, so it stays short. `AGENTS.md` is the filename Codex,
  Cursor, Zed and others read; Claude Code reads `CLAUDE.md`, which `install.sh`
  symlinks to the same file.
- **`skills/<name>/SKILL.md`** — on-demand. Only the `name` and `description`
  sit in context; the body loads when the description matches the task. Deeper
  material goes in `references/` alongside, loaded only if the skill points at
  it.
- **`codex-bundle.json`** — Codex's manifest for the skills directory, which it
  loads as a named bundle rather than skill by skill.
- **`install.sh`** — symlinks everything into place. Idempotent, never escalates.

The split is about loading, not importance. Anything that applies to every turn
goes in the instructions; anything that applies to *a kind of task* is a skill,
because paying for it on unrelated turns is what makes context expensive.

## Skills

- **`type-driven-design`** — closed sets over string tags, exhaustive dispatch
  over chained ifs, illegal states made unrepresentable, one owner per concept.
  Per-language references for Kotlin, TypeScript, Rust, Go and Zig.
- **`idempotency-and-recovery`** — handlers that survive redelivery, the cost of
  each idempotency mechanism, caching as latency rather than correctness, and
  transactions small enough that replay converges.
- **`change-discipline`** — diff sizing, when a test is warranted, whether a
  refactor has earned its push, keeping review surface to what was asked for.
- **`evidence-before-conclusions`** — verifying load-bearing assumptions before
  building on them.
- **`testing`** — how tests read, and what they shouldn't distort.

## Install

```sh
./install.sh
```

Existing symlinks into this repo are replaced, a non-empty `CLAUDE.md` is backed
up with a timestamp, and anything else — a real directory, a symlink pointing
somewhere else — is left alone and reported. Set `CLAUDE_HOME` or `CODEX_HOME`
to target somewhere other than the defaults.

Claude Code gets one symlink per skill in `~/.claude/skills/`, plus `CLAUDE.md`
pointing at the instructions. Codex takes the whole `skills/` tree as a single
bundle in `~/.codex/skills/`, with `codex-bundle.json` beside it as the
manifest — the shape managed bundles already use there.

Where `~/.codex` is owned by root — it often is, if something provisions skills
into it — the script won't write there and won't ask for a password. It prints
the `sudo ln -sfn` lines and leaves them to you. Re-running after that reports
them as already done.

## Writing style

These files are written for current-generation models, which means guidance
rather than prohibition. "Match the surrounding comment density" beats "DO NOT
add comments" — the first survives contact with a codebase that has a house
style, the second gets applied to a file where comments were the right call.

Practically: no ALL CAPS, no "IMPORTANT", no rule repeated across three files,
few worked examples where a clear statement of intent does the same job. When a
skill starts accumulating every case it might encounter, that's the signal to
split it or cut it — an over-specified skill is worse than a short one, because
it gets loaded in full every time it matches.
