# Zig

## Closed sets

A tagged union pairs an enum tag with per-variant payloads:

```zig
const FailureReason = enum { timed_out, rejected };

const JobOutcome = union(enum) {
    succeeded: []const u8,
    failed: FailureReason,
    pending,
};
```

`union(enum)` infers the tag enum from the field names, so there's one list to
maintain rather than two.

## Exhaustiveness

`switch` is exhaustive by default — a missing prong is a compile error.

```zig
fn describe(outcome: JobOutcome) []const u8 {
    return switch (outcome) {
        .succeeded => |reference| reference,
        .failed => |reason| @tagName(reason),
        .pending => "pending",
    };
}
```

`else => ...` turns that off, so leave it out on a union you own. Where a case
genuinely cannot occur, `unreachable` documents the claim and traps in safe
builds instead of quietly continuing.

`_ => ...` is the separate opt-in for non-exhaustive enums — it says "values
outside the named set are possible", which is the right marker for something
that came off the wire.

## Illegal states

A single-field struct is the newtype:

```zig
const JobId = struct {
    value: []const u8,

    fn parse(raw: []const u8) !JobId { ... }
};
```

Errors belong in the return type as an error union (`!T`), so a caller has to
acknowledge failure — `try` propagates, `catch` handles, and neither is
skippable by accident.

`comptime` is available when a set needs deriving rather than restating —
generating a lookup from `@typeInfo(SomeEnum).Enum.fields` keeps it tied to the
declaration.
