# Kotlin

## Closed sets

`enum class` for a set of constants with no per-variant data. `sealed interface`
or `sealed class` when variants carry different payloads — subclasses can live
anywhere in the same module, so the hierarchy doesn't have to be one file.

```kotlin
sealed interface JobOutcome {
    data class Succeeded(val reference: String) : JobOutcome
    data class Failed(val reason: FailureReason) : JobOutcome
    data object Pending : JobOutcome
}
```

## Exhaustiveness

`when` on a sealed or enum subject is checked by the compiler — as an expression
always, and as a statement since 1.7. Omit `else` and adding a variant becomes a
compile error at each site.

```kotlin
fun describe(outcome: JobOutcome) = when (outcome) {
    is JobOutcome.Succeeded -> "succeeded ${outcome.reference}"
    is JobOutcome.Failed -> "failed: ${outcome.reason}"
    JobOutcome.Pending -> "pending"
}
```

Assigning or returning the `when` is the habit worth keeping — an expression is
checked under every compiler version, so it never depends on the language level
of the module you're in.

## External enums

Parse at the boundary with a companion factory, and keep the catch-all there
rather than in the domain.

```kotlin
enum class UpstreamStatus {
    RUNNING, STOPPED;

    companion object {
        fun of(raw: String): UpstreamStatus? = entries.firstOrNull { it.name.equals(raw, ignoreCase = true) }
    }
}
```

A nullable return forces the caller to decide what an unknown value means. If
the decision is always "reject", `?: throw` at that one site reads better than
an `else -> throw` repeated in every `when` downstream.

## Illegal states

Validators return the validated value rather than a boolean, so the type carries
the result:

```kotlin
fun requireSupported(format: Format): SupportedFormat =
    SupportedFormat.of(format) ?: throw UnsupportedFormatException(format)
```

`@JvmInline value class` gives a zero-overhead wrapper when a raw `String` or
`Long` is flowing somewhere it could be confused with another of the same
underlying type.

## Deriving

`entries` is the source of truth for an enum's members — build lookups from it
rather than restating the list:

```kotlin
private val byCode = FailureReason.entries.associateBy { it.code }
```
