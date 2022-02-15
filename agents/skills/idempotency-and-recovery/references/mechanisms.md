# Idempotency mechanisms

## Choosing the key

The key has to be stable across redeliveries of the same logical event. A broker
message id usually isn't — republishing after a drain mints a new one, and the
same business event then processes twice.

Prefer something the producer derives from the event itself: a document id, an
`(aggregate_id, sequence)` pair, a provider's own event id. Where the producer
offers nothing stable, a hash of the semantically meaningful fields beats a
delivery id, with the caveat that it changes if the payload shape changes.

## Unique constraint

The default. A table of processed keys, with the insert as the claim:

```sql
create table processed_event (
    idempotency_key text primary key,
    processed_at    timestamptz not null default now()
);
```

Insert first; a violation means someone else already has it. Under concurrency
exactly one caller wins, with no check-then-act window.

Two details decide whether this is actually correct:

- **The claim and the work belong in the same transaction.** Claiming first and
  committing separately means a crash between them leaves the key marked done
  and the work never performed — the failure mode that's hardest to detect,
  because redelivery now skips it silently.
- **Losing the race isn't always "do nothing".** If the first delivery is still
  in flight, the loser returning success may be a lie to whoever is waiting on
  it. Decide explicitly whether the loser returns, waits, or throws to be
  redelivered later.

Where the work itself writes a naturally unique row, the constraint can live on
that table instead and no separate ledger is needed. That's strictly better —
one write, and the business data is the ledger.

## Upsert

`INSERT … ON CONFLICT DO UPDATE` makes the write itself idempotent, which is
often enough for state-shaped events where the last writer should win. It needs
care with out-of-order delivery: an older message can overwrite a newer state
unless the update is guarded on a version or timestamp.

```sql
insert into document (id, status, version) values ($1, $2, $3)
on conflict (id) do update set status = excluded.status, version = excluded.version
where document.version < excluded.version;
```

## Pessimistic locking

`SELECT … FOR UPDATE` when the decision spans several rows and can't be reduced
to one constrained write. Holds until the transaction ends, so keep external
calls outside it.

Deadlocks come from inconsistent lock ordering across paths — if one handler
locks parent-then-child and another locks child-then-parent, they'll
eventually meet. Pick an ordering and apply it everywhere.

`FOR UPDATE SKIP LOCKED` is the queue-worker variant: competing consumers each
grab a different row rather than queueing behind one.

## Optimistic locking

A version column, incremented on write, with the update conditional on the value
read. Cheaper than a lock and usually sufficient when conflicts are rare — the
loser gets zero rows updated and retries. It degrades badly under high contention
on the same row, where a lock is the better fit.

## External side effects

Nothing above helps when the side effect is an outbound call — no rollback, and
a timeout leaves you genuinely unsure whether it happened.

Options, roughly in order of preference:

- **Provider-side idempotency.** Many third-party APIs accept an
  idempotency key. Use it, and derive the key from the event rather than
  generating one per attempt.
- **Transactional outbox.** Write the intent to an outbox table in the same
  transaction as the state change; a separate process reads and dispatches it.
  The dispatch is at-least-once, so the receiver still needs to be idempotent —
  the outbox buys atomicity between state and intent, not exactly-once delivery.
- **Record the attempt before making it.** Turns "did it happen?" into a
  question the database can answer on redelivery, at the cost of a write.

## Cache layering

A cache in front of a durable check is a latency optimization: a hit skips the
round-trip, a miss falls through, and correctness rests entirely on the check
underneath. In-process caches don't span replicas, so under autoscaling they
reduce load without deduplicating anything. Redis spans replicas but isn't
durable — treat an unexpected miss as normal, never as "not processed".

## Dead letters

A dead letter is a message that exhausted its retries, so the queue is a work
list rather than an archive. Draining it means republishing, which is the moment
handler idempotency gets tested for real — and the moment a key derived from the
delivery id stops working.

Where a handler can't tolerate replay, that limitation belongs in the design
discussion, not in the incident.
