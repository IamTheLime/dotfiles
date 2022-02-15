---
name: evidence-before-conclusions
description: Checking load-bearing assumptions before building on them — tracing real callers before calling code dead, establishing when telemetry started before blaming a regression, reproducing outside dev mode, and pairing a broken trace with a healthy one. Read when investigating a spike or incident, resolving a merge that drops code, or reporting a distributed-tracing finding.
---

# Evidence before conclusions

Most wrong investigations are correct reasoning on top of an unverified premise.
The cheap move is to check the premise first — it usually takes minutes, and it
decides whether the next hour is useful.

## Before calling code dead

"This is handled elsewhere now" is a reading, not a finding. Identify what
triggers the branch today and follow the path to confirm the replacement covers
the same semantics.

Where coverage is uncertain, that's a verification gap worth naming rather than
a deletion worth recommending.

When a dropped branch turns out to have mattered, a narrow fix at the symptom
site is usually better than reopening the original decision — less churn, and it
preserves whatever architectural intent the reviewer had.

## Before blaming a regression

A first-seen date marks when collection started, not when the bug started. "Zero
events before date X" is equally consistent with "the instrumentation was wired
up on date X".

So the first couple of minutes of any spike investigation go to: when did this
telemetry start collecting, and was there any data before the first-seen date?
Check when the DSN was first injected, when the appender or metric started
emitting, when the alert rule was created. `git log -S` over the config is
usually enough.

If telemetry has been live for less than a month, the bug is older than the
data. If it predates first-seen by months, then there's a real trigger to find.

## Before investigating a rendering bug

Development builds render differently — effects double-invoked under strict
mode, extra warnings, no production optimizations. A flicker or layout shift
seen only in dev may not exist at all.

Confirm it reproduces on a production-like build before changing anything.

## When reporting a tracing finding

Give both a searchable healthy trace and its broken counterpart for the same
operation — same caller, callee, method, and path template — with ids or links
for each.

The contrast is the diagnostic. A healthy instance of the same operation proves
the code *can* propagate, which separates an intermittent runtime fault from a
deterministic bug. Without the healthy twin, an orphan span has no baseline.

Where the break is deterministic and there's no healthy twin to find, say that
explicitly — it's a stronger finding, not a missing one.
