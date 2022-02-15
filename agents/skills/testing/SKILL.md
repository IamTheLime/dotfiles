---
name: testing
description: How tests should read and what they shouldn't distort — should-style naming, asserting on arguments with predicates rather than captures, and guarding temporarily-disabled behaviour with a tripwire instead of inverting assertions or widening production visibility. Read when writing or reviewing tests, or when a test is hard to write because the code isn't reachable.
---

# Testing

Whether a change needs a test at all is a separate question — see
`change-discipline`. This is about the shape of the ones that get written.

## Naming

Test names read as sentences starting with `should`: what the unit does under
the stated conditions, not which method is being called. In Kotlin that's a
backtick name; elsewhere it's whatever the framework's string form is.

Grouping tests per function-under-test, in a nested block, keeps that readable
as a suite grows.

## Asserting on arguments

Prefer a predicate inside the verification over capturing into a slot and
asserting afterwards — the expectation stays at the call site, and there's no
setup to read first.

```kotlin
verify(exactly = 1) {
    repository.save(match<Record> { it.attributes.size == 4 && it.status == PREPARED })
}
```

Capture is still the right tool when the captured object is needed for further
computation. When it's just being asserted on, the predicate says the same thing
in one place.

## Temporarily-disabled behaviour

When a code path is switched off — types sitting in an ignore set, a flag off by
default — the tempting moves both make it worse. Permanently inverting the
original assertions to match the disabled state deletes the record of what the
code is supposed to do. Reshaping production code so the dormant path is
reachable is test-induced design: promoting a private helper to internal, or
moving an instance method to a companion, so a test can call it.

Instead, keep the original assertions and front them with a tripwire that reads
the real source of truth:

```kotlin
if (assertIgnoredWhileExcluded(event)) return
// original assertions follow, untouched
```

While the type is excluded the guard asserts the disabled behaviour and returns
early. The moment it leaves the ignore set the guard fails with an actionable
message — "X was added back to supported products, remove this check to restore
the original tests". Re-enabling is then one edit, and the tripwire forces a
conscious restore rather than a silent behaviour flip.

The helper reads the actual ignore set rather than a hardcoded copy of it, and
lives in the test rather than in production code. Production helpers keep the
visibility that matches their siblings.
