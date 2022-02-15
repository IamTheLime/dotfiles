---
name: idempotency-and-recovery
description: Designing handlers that survive redelivery and partial failure — idempotency mechanisms and what each costs, when caching is and isn't a correctness tool, letting things fail loudly, and keeping transactions small enough that replay converges. Read when writing or reviewing a message or event handler, a retry path, a backfill, or anything that can run twice.
---

# Idempotency and recovery

At-least-once delivery means every handler runs twice eventually. The question
is never whether it'll be redelivered — it's what happens when it is.

## Use the guarantee that already exists

Before building a check, look at what the owning system already promises: a
database unique constraint, a broker's ordering guarantee, an upstream service's
own deduplication. Reimplementing one of those a layer away leaves two sources
of truth for one invariant, and nothing to arbitrate when they disagree.

## Mechanisms, cheapest correct first

A read-before-write check is the obvious move and the one that quietly races —
two concurrent deliveries both read "not yet processed", both proceed. It's only
sound when something else is serializing them.

A unique constraint on the idempotency key is usually the right answer. The
database arbitrates, the loser gets a constraint violation it can treat as
"already done", and there's no window between the check and the write. It costs
one insert and a well-chosen key.

Pessimistic locking (`SELECT … FOR UPDATE`) serializes handlers over the same
aggregate when the work genuinely can't be expressed as a single constrained
write. It's correct, and it costs throughput: connections held for the duration,
contention under load, and deadlocks when lock ordering isn't consistent between
paths. Optimistic locking via a version column is often enough and much cheaper.

`references/mechanisms.md` has the detail — key choice, the outbox pattern for
external side effects, and what each mechanism does under concurrency.

## Caching buys latency, not correctness

An in-process cache is per-replica. Under autoscaling, two replicas processing
duplicate deliveries share nothing, so it doesn't deduplicate — it just makes
the common case faster. Redis gives shared state, which is what's needed when
handlers on different replicas have to agree.

Either way it's best-effort: entries expire, caches evict under pressure, Redis
restarts. Put a cache in front of a durable check to skip the round-trip, not in
place of one. Where latency genuinely forces a cache onto the critical path,
that's a tradeoff worth naming in the design rather than discovering during an
incident.

## Let it fail

Throwing is a valid response. The broker redelivers, and a handler that's
idempotent converges. Catching an error to invent local recovery usually
produces something less reliable than the retry it suppressed, and hides the
failure from whoever is watching the dashboards.

Keeping services dumb is part of this. A handler that does one thing and fails
loudly is easier to reason about than one that tries to repair the world.

Transient and permanent failures need opposite handling, so make the distinction
explicit. Transient — a timeout, a dependency restarting — should throw and be
retried. Permanent — a malformed payload, a referent that will never exist —
shouldn't be retried forever. One clean way to express this: throwing means
redeliver, and returning without acting means it's parked for a human. The
decision then lives in control flow rather than a flag threaded through the
error type.

## Transactions small enough to replay

Wrapping a whole handler in one transaction is the reflex and usually the wrong
shape. It holds a connection across external calls, makes partial progress
impossible so a late failure discards work that had already succeeded, and rolls
back nothing that mattered when the side effect was an outbound API call.

Prefer several small transactions, each independently idempotent. Redelivery
then skips the completed steps and resumes at the one that failed, which is what
makes a handler self-healing rather than all-or-nothing.

## Recovery is a design requirement

Assume every message will need reingesting at some point — after a bad deploy, a
dead-letter drain, a backfill. A handler that only works on fresh messages will
need a person at the worst possible moment.

Where a process genuinely can't self-heal after a dead-letter, that's a decision
rather than an oversight, and it should be named while the design is being
proposed instead of found later.
