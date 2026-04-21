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
  "dependencies": ["rescript-signals"]
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

If you need to pragmatically dispose the effect, you can use `Effect.runWithDispose`:

```rescript
let disposer = Effect.runWithDispose(() => {
  Console.log(Signal.get(count))
  None
})

// Later
disposer.dispose()
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

## Benchmark Snapshot (CI)

Latest `milomg/js-reactivity-benchmark` report (other popular frameworks + ReScript Signals), ordered by average runtime per test.

| Rank | Framework | Total ms |
| --- | --- | ---: |
| 1 | Alien Signals | 4054.69 |
| 2 | Preact Signals | 4193.43 |
| 3 | ReScript Signals | 5497.12 |
| 4 | Vue | 5909.55 |
| 5 | Svelte v5 | 8163.40 |
| 6 | SolidJS | 10638.23 |

Per-test runtime (ms):

| Framework | 2-10x5 - lazy80% | 25-1000x5 | 3-5x500 | 4-1000x12 - dyn5% | 6-100x15 - dyn50% | 6-10x10 - dyn25% - lazy80% | avoidablePropagation | broadPropagation | cellx1000 | cellx2500 | createComputations | createSignals | deepPropagation | diamond | molBench | mux | repeatedObservers | triangle | unstable | updateSignals |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Alien Signals | 321.62 | 857.38 | 215.96 | 649.03 | 323.65 | 241.78 | 89.86 | 209.09 | 9.44 | 27.88 | 77.39 | 2.69 | 64.15 | 119.16 | 33.33 | 177.25 | 33.39 | 45.73 | 47.95 | 507.98 |
| Preact Signals | 392.88 | 871.31 | 213.01 | 680.89 | 344.58 | 264.95 | 92.54 | 210.91 | 9.71 | 31.13 | 73.09 | 2.07 | 74.11 | 122.93 | 33.17 | 182.45 | 20.35 | 45.69 | 34.15 | 493.50 |
| ReScript Signals | 490.79 | 955.07 | 267.14 | 703.15 | 369.60 | 323.04 | 296.06 | 292.17 | 15.97 | 58.68 | 291.99 | 3.40 | 102.46 | 176.05 | 46.52 | 276.85 | 39.70 | 52.86 | 61.26 | 674.37 |
| Vue | 550.80 | 1156.08 | 300.99 | 904.94 | 451.48 | 361.59 | 197.81 | 267.42 | 24.56 | 74.18 | 117.71 | 2.96 | 123.64 | 181.95 | 72.64 | 268.22 | 27.94 | 64.18 | 51.44 | 709.02 |
| Svelte v5 | 1107.51 | 1192.50 | 300.55 | 1026.17 | 427.26 | 350.29 | 534.55 | 404.05 | 14.86 | 51.73 | 165.07 | 1.81 | 166.14 | 424.79 | 35.19 | 248.15 | 75.66 | 125.05 | 118.99 | 1393.06 |
| SolidJS | 2210.74 | 1650.95 | 510.65 | 1316.11 | 727.56 | 683.84 | 261.95 | 573.50 | 21.75 | 99.62 | 180.46 | 4.36 | 202.17 | 347.05 | 41.07 | 318.85 | 93.33 | 124.10 | 140.36 | 1129.82 |

Note: these are single-machine CI runs and will vary with runner/Node version.

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
