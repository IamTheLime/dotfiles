---
name: type-driven-design
description: Modelling choices that let the compiler prove a case was handled — sum types over flags and strings, exhaustive dispatch over chained ifs, illegal states made unrepresentable, one owner per concept. Read when designing a type that has variants, adding a case to an existing one, reviewing branching logic, or finding the same value declared in more than one place.
---

# Type-driven design

The recurring goal: when someone adds a variant a year from now, the compiler
should tell them every place that needs updating. An `if`/`else` chain can't do
that. A closed set plus exhaustive dispatch can.

## Model variants as a closed set

A value with a fixed set of shapes wants a sum type, not a struct with optional
fields or a string tag. When two variants carry different data, that difference
belongs in the type rather than in nullable fields the reader has to correlate
by hand.

Strings driving control flow are the usual failure. They admit typos, dead
branches, and case mismatches, and nothing catches the one you forgot. Finding
string keys in a `when`/`switch` is worth stopping over: read the source of
truth, list the call sites, and say what you found before continuing. Propose
the migration rather than performing it silently — the right target (enum,
sealed type, value class, branded type) depends on what the call sites need.

## Dispatch exhaustively

Prefer one dispatch site the compiler checks over branching scattered across
callers.

On a set you own, omit the catch-all arm. A new variant then fails to compile at
every site that needs attention, which is the entire point. Adding `else` to a
closed set buys a runtime throw in exchange for the compile-time guarantee, and
that's a bad trade — the check you gave up was the one that would have found the
site before it shipped.

On a set you don't own — an external API's enum, a wire format, anything that
can grow without a deploy on your side — a catch-all is the honest choice,
because the set really can surprise you. Handle it at the boundary where the
external value is parsed, so the closed internal type stays closed and the rest
of the codebase gets the compile-time guarantee.

The distinction is ownership, not language.

## Make illegal states unrepresentable

Validate at the boundary and return a type that carries the guarantee, so
downstream code can't re-ask the question. A validator that returns the
validated value beats one that returns a boolean and leaves the caller holding
the same loose type it started with.

## Derive, don't restate

One source of truth per set, with the type derived from it. Two hand-maintained
lists of the same thing drift, and the drift is invisible until behaviour
diverges.

## Single owner

A type has a natural owner: the system or module whose invariants define it.
When the same concept is declared in two places, one of them is a copy waiting
to go stale.

Finding a value or type declared in several places is worth raising even
mid-task. Establish which one is the owner — and if there isn't an obvious one,
say so. "No natural owner" is a real finding, not a gap in your reading.

Prefer using the guarantee of the system that owns a concern over reimplementing
it a layer away. Two implementations of one invariant means no way to know which
is right when they disagree.

## Per language

`references/` covers how each of these lands in a given language, and where the
compiler helps versus where you need a linter or a convention:
`kotlin.md`, `typescript.md`, `rust.md`, `go.md`, `zig.md`.
