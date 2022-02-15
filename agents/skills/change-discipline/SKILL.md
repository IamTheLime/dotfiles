---
name: change-discipline
description: Sizing a change so it lands — surgical diffs, when a test is actually warranted, whether a refactor has earned its push, and keeping a PR's review surface to what was asked for. Read before adding tests alongside a fix, before starting a refactor, and when deciding how much of a nearby problem to pull into the current change.
---

# Change discipline

The reviewer's attention is the scarce resource. Every line in a diff spends
some of it, so the question for anything beyond the fix itself is what it buys.

## Surgical by default

A fix should touch what it needs to and stop. Cleanups noticed along the way are
worth mentioning; folding them in makes a reviewer reconstruct which parts were
the point.

## Tests

For a small, surgical change the default is no new tests. The existing suite is
the contract — if it still passes, code review is what verifies a one-line
change, and defensive additions cost maintenance forever.

New tests earn their place when an existing test now fails and the failure is a
real regression worth catching long-term, when the change introduces a genuinely
new code path with no coverage, or when they've been asked for.

The tempting one to skip is the test written to guard against someone reverting
the change later. The commit message and the reviewer are that guard.

New features are a different case — new code paths need coverage.

## Refactors

A refactor ships when it measurably shrinks the diff against the same merge-base
*and* is structurally simpler — fewer abstractions, fewer files to keep in step,
existing logic reused rather than new helpers introduced.

Measure both sides before pushing. When the numbers don't land, keeping it local
and reporting them is the more useful outcome: "this didn't get smaller" is real
information about the shape of the code.

## Scope

When a review flags that a value now lives in two places, extract it at the size
the new consumer needs and point only that consumer at it. Leave existing copies
alone with a note recording where they are.

The pre-existing duplication isn't this change's fault, and migrating it drags
untouched code into a review opened for something narrower. Fixing it "while
we're here" is how a two-file PR becomes a twelve-file one.

## Proportion

Correctness and production risk deserve the effort. Harmless redundancy and
stylistic preference mostly don't. Sorting findings by which is which — in a
review, in a plan, in a summary — is more useful than listing everything at the
same volume.
