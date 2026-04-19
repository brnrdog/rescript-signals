# [rescript-signals](https://brnrdog.github.io/rescript-signals/)

[![Release](https://github.com/brnrdog/rescript-signals/actions/workflows/release.yml/badge.svg)](https://github.com/brnrdog/rescript-signals/actions/workflows/release.yml)
[![npm version](https://badgen.net/npm/v/rescript-signals)](https://www.npmjs.com/package/rescript-signals)
[![bundlephobia](https://badgen.net/bundlephobia/minzip/rescript-signals)](https://bundlephobia.com/package/rescript-signals)

rescript-signals is a lightweight, high-performance reactive signals library for [ReScript](https://rescript-lang.org/) with zero dependencies. Build reactive applications with fine-grained updates, automatic dependency tracking, and minimal re-computation, while leveraging ReScript's powerful type system.

## Getting Started

### Installation

```bash
npm install rescript-signals
```

Then, add it to your ReScript project's `rescript.json`:

```json
{
  "bs-dependencies": ["rescript-signals"]
}
```

### Quick Example

```rescript
open Signals

// Create reactive state
let count = Signal.make(0)

// Create a derived state
let doubled = Computed.make(() => Signal.get(count) * 2)

// Logs every time count changes:
Effect.run(() => {
  Console.log2("Count is", Signal.get(count))

  None // Optional cleanup function
})

// Update the signal
Signal.set(count, 5) // Effect logs: "Count is 5"
```

## Core Concepts

rescript-signals focuses on clarity, control, and performance. The goal is to offer precise, fine-grained updates and predictable behavior with a minimal set of abstractions.

### Signal

Reactive state container. Signals track changes and notify dependents automatically when their value changes.

```rescript
let count = Signal.make(0)

Signal.get(count)           // Read with dependency tracking
Signal.peek(count)          // Read without tracking
Signal.set(count, 1)        // Set a new value
Signal.update(count, n => n + 1) // Update based on current value
```

### Computed

Derived reactive values that update automatically. Computed values are lazily evaluated and cached until their dependencies change.

```rescript
let firstName = Signal.make("Ada")
let lastName = Signal.make("Lovelace")

let fullName = Computed.make(() =>
  Signal.get(firstName) ++ " " ++ Signal.get(lastName)
)
```

### Effect

Side-effect functions that re-run when dependencies change. Effects execute immediately and track any signals read during execution.

```rescript
Effect.run(() => {
  Console.log(Signal.get(count))

  Some(() => Console.log("cleanup")) // Optional cleanup
})
```

### Batching and Untracked Reads

Group multiple updates with `Signal.batch` to prevent redundant computations, or skip tracking inside an effect with `Signal.untrack`:

```rescript
Signal.batch(() => {
  Signal.set(firstName, "Alan")
  Signal.set(lastName, "Turing")
}) // Effects run only once

let value = Signal.untrack(() => Signal.get(threshold)) // Read without tracking
```

All reactive primitives feature automatic dependency tracking — no manual subscriptions needed.

Check the [documentation website](https://brnrdog.github.io/rescript-signals/) for the full API reference and examples.

## React Integration

[**rescript-signals-react**](packages/rescript-signals-react) provides React hooks for using signals in your components via `useSyncExternalStore`:

```bash
npm install rescript-signals-react
```

```rescript
open SignalsReact

let value = useSignalValue(mySignal)          // Subscribe to a signal
let (value, signal, setter) = useSignal(() => 0) // Component-local signal
let derived = useComputed(() => Signal.get(a) + Signal.get(b))
```

See the [rescript-signals-react README](packages/rescript-signals-react) for full documentation.

## Packages

| Package | Description |
|---------|-------------|
| [rescript-signals](packages/rescript-signals) | Core reactive signals library |
| [rescript-signals-react](packages/rescript-signals-react) | React adapter hooks |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

See [LICENSE](LICENSE) for details.
