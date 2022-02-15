# Go

Go has no sum types and no exhaustiveness checking. Everything below is a
convention or a linter standing in for a compiler guarantee, so the honest
framing is: you can get most of the readability, and none of the proof.

## Closest thing to a closed set

An interface with an unexported marker method. Only types in the declaring
package can satisfy it, so the set is sealed at the package boundary:

```go
type JobOutcome interface {
	isJobOutcome()
}

type Succeeded struct{ Reference string }
type Failed struct{ Reason FailureReason }
type Pending struct{}

func (Succeeded) isJobOutcome() {}
func (Failed) isJobOutcome()    {}
func (Pending) isJobOutcome()   {}
```

Dispatch with a type switch:

```go
func Describe(outcome JobOutcome) string {
	switch o := outcome.(type) {
	case Succeeded:
		return fmt.Sprintf("succeeded %s", o.Reference)
	case Failed:
		return fmt.Sprintf("failed: %s", o.Reason)
	case Pending:
		return "pending"
	default:
		panic(fmt.Sprintf("unhandled outcome %T", outcome))
	}
}
```

The `default` panic is a runtime backstop, not a check. Adding a fourth type
compiles cleanly and fails in production. `go-check-sumtype` will flag it in CI
if the interface is annotated, which is the closest available substitute.

## Constant sets

The `iota` const-block idiom gives named constants but not a distinct type the
compiler enforces — any `int` of the underlying type is assignable.

```go
type LogLevel string

const (
	LogLevelDebug LogLevel = "debug"
	LogLevelInfo  LogLevel = "info"
)
```

A defined string type at least stops a bare `string` being passed, and keeps the
values readable in logs. `exhaustive` catches switches over such a const group
that miss a member — worth enabling, since it's the only exhaustiveness signal
available.

## Illegal states

Unexported fields plus a constructor is the available pattern:

```go
type JobID struct{ value string }

func ParseJobID(raw string) (JobID, error) { /* ... */ }
```

The zero value is always constructible in Go, so `var j JobID` bypasses
the constructor. Where that matters, make the zero value either valid or
obviously invalid, and check it at use — this is a genuine gap, not something to
paper over.
