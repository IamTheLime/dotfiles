# Rust

## Closed sets

`enum` is a real sum type — variants carry their own data, and the compiler
tracks which one you have.

```rust
enum JobOutcome {
    Succeeded { reference: String },
    Failed(FailureReason),
    Pending,
}
```

## Exhaustiveness

`match` is exhaustive by default; a missing arm is a compile error with no
opt-in required. The thing to avoid is reintroducing the gap:

```rust
fn describe(outcome: &JobOutcome) -> String {
    match outcome {
        JobOutcome::Succeeded { reference } => format!("succeeded {reference}"),
        JobOutcome::Failed(reason) => format!("failed: {reason}"),
        JobOutcome::Pending => "pending".to_string(),
    }
}
```

A `_ => ...` arm on an enum you own silently absorbs new variants. Bindings like
`other => ...` do the same thing and read as if they're handling something.

## External sets

`#[non_exhaustive]` on an enum you publish tells downstream crates the set can
grow, which forces them to write a catch-all. Matching on someone else's
`#[non_exhaustive]` enum requires one from you — that's the boundary doing its
job, and it belongs at the parse site rather than spread through the domain.

## Illegal states

Newtypes cost nothing at runtime and stop same-shaped values being swapped:

```rust
struct JobId(String);

impl JobId {
    fn parse(raw: &str) -> Result<Self, MalformedJobId> { /* ... */ }
}
```

Keep the field private and the only way in is through `parse`, so possessing a
`JobId` is proof it was validated.

`Option` and `Result` are the idiomatic way to make absence and failure part of
the type rather than a convention. Reaching for `unwrap` in library code throws
that away.
