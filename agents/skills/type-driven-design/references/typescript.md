# TypeScript

## Closed sets

Discriminated unions, with a literal-typed property as the discriminant:

```ts
type JobOutcome =
  | { kind: 'succeeded'; reference: string }
  | { kind: 'failed'; reason: FailureReason }
  | { kind: 'pending' };
```

Narrowing on `kind` gives each branch the right payload type, which is the part
a `status: string` field plus optional fields can't do.

## Exhaustiveness

TypeScript won't complain about a missing case on its own. Force it by assigning
the narrowed value to `never` in the default branch:

```ts
const assertNever = (value: never): never => {
  throw new Error(`Unhandled variant: ${JSON.stringify(value)}`);
};

const describe = (outcome: JobOutcome): string => {
  switch (outcome.kind) {
    case 'succeeded':
      return `succeeded ${outcome.reference}`;
    case 'failed':
      return `failed: ${outcome.reason}`;
    case 'pending':
      return 'pending';
    default:
      return assertNever(outcome);
  }
};
```

Add a variant and `outcome` is no longer `never` at that call, so it fails to
compile. This is the one case where a `default` branch preserves the check
rather than defeating it.

`switch` with a `return` per case gives the narrowing for free. A chain of `if`s
works too but has to be written carefully to leave `never` at the end.

## Deriving

Declare the values once and derive the type, rather than maintaining a union
alongside a runtime list:

```ts
const LOG_LEVELS = ['debug', 'info', 'warn', 'error'] as const;
type LogLevel = (typeof LOG_LEVELS)[number];
```

`satisfies` checks a literal against a type without widening it, so the
inferred key and value types survive:

```ts
const SEVERITY = { debug: 10, info: 20, warn: 30, error: 40 } satisfies Record<LogLevel, number>;
// SEVERITY.debug is number, and a missing level is a compile error
```

When the values arrive at runtime, parse them into the type at the boundary —
a zod schema plus `z.infer` keeps schema and type from drifting.

## Illegal states

Branded types stop a bare `string` standing in for something validated:

```ts
type JobId = string & { readonly __brand: 'JobId' };

const toJobId = (raw: string): JobId => {
  if (!/^JOB-\d{8}$/.test(raw)) throw new Error(`Malformed job id: ${raw}`);
  return raw as JobId;
};
```

The single `as` inside the constructor is the whole point — every other site
gets a type it can trust.
