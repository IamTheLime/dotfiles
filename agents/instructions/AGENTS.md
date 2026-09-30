# Working agreements

Cross-language, cross-project defaults. Facts about a specific repo belong in
that repo's own instructions file; deeper topics live in skills and load when
they're relevant.

## Languages

Kotlin (Spring Boot) and TypeScript (Next.js) are the day job. Zig, Rust and Go
show up occasionally. Lean into what each language is genuinely good at rather
than translating one language's idioms into another.

When you reach for a construct that isn't beginner-obvious — scope functions,
receiver types, reified generics, conditional or template-literal types,
`satisfies`, branded types — say a sentence in chat about what it does and why
it fits there. In chat, not as a code comment. The point is to learn the
construct from real usage, so skip the ones that are already obvious.

## Writing code

Aim for the fewest lines that stay typesafe and readable. Where the type system
can prove something, prefer that over a runtime assertion.

Code should be understandable from a small window. An abstraction that makes the
reader jump between three files to follow one decision has cost more than it
saved.

Share a value when it must not deviate — config, derivations, validators. Don't
share when reuse forces conditional logic that obscures the business rule
underneath. Three similar lines beat a premature abstraction.

Default to composition. Inheritance earns its place for utility types (`Result`
and friends), for extending the type system cleanly, and for incrementing a
type — not for varying behaviour between siblings, where it scatters the logic
across files and makes call sites lie about what runs.

Handle exceptions rather than swallowing them or letting them surface as noise.
A typed result, a structured log, or a domain error all beat a bare catch.

Write code that reads like the code around it — match the surrounding comment
density, naming, and idiom. Where that baseline is "no comments", the diff and
the commit message carry the why. A `TODO(TICKET)` marker or a pointer to
something genuinely uninferrable (a workaround for an external bug) is worth
writing down; narrating the next line isn't.

## Logging

`ERROR` is a signal that an operator needs to do something, so it belongs to
server-side failures — our bugs, dead integrations, infrastructure. A client
error is normal traffic in a healthy system. Auth failures and permission
denials sit at `WARN`, where rate-based alerting can still find them; malformed
requests sit at `INFO` or `DEBUG`.

An `error` log immediately before throwing a 4xx is nearly always a downgrade
candidate, as is an `error` inside an auth filter or interceptor.

## Working together

When reviewing PR comments, reply to every `To agent:` comment in its original
thread, prefixed with `From agent: Codex` (or the responding agent name).
Explain the actual change and reference its commit when available; if it is
pending or deferred, say so rather than claiming it is done. This is standing
authorization to post those replies. Never auto-resolve review threads; resolve
them only when explicitly asked.

Show the plan and wait for agreement before editing files.

Ask before `git commit` and before `git push`, and propose the commit message
first. Approval to start a multi-step piece of work isn't standing approval to
push each step of it — ask once per push unless told otherwise.

Never close a PR without asking. Watch for the indirect route too: force-pushing
a branch whose diff has collapsed to empty will close its PR as a side effect,
so verify a rebase replayed what you expected before pushing it.

When a review flags that a value now lives in two places, extract it and point
the new consumer at it. Leave the pre-existing consumers alone with a note —
migrating them expands a diff that reviewers opened expecting something
narrower.

Prefer lists with bold labels over markdown tables; tables render badly in a
monospace terminal. Multi-PR stacks are the exception — a table is the right
shape for navigating those.

## Toolchain

Java and Gradle are managed through SDKMAN. Select versions with `sdk use`
rather than reaching for `/usr/libexec/java_home` or assuming a system JDK.

## Skills

Deeper guidance lives in skills, which load when they're relevant rather than
every turn. Claude Code and Codex find them on their own. Anywhere without a
skills loader, read the file directly when the situation calls for it — they
live under `~/Documents/personal/dotfiles/agents/skills/`.

- **`type-driven-design/`** — closed sets over string tags, exhaustive dispatch,
  illegal states, one owner per concept. Per-language references.
- **`idempotency-and-recovery/`** — handlers that survive redelivery, what each
  idempotency mechanism costs, transactions small enough to replay.
- **`change-discipline/`** — diff sizing, when a test is warranted, whether a
  refactor has earned its push.
- **`evidence-before-conclusions/`** — checking load-bearing assumptions before
  building on them.
- **`testing/`** — how tests read, and what they shouldn't distort.
