# rescript-signals

[![Release](https://github.com/brnrdog/rescript-signals/actions/workflows/release.yml/badge.svg)](https://github.com/brnrdog/rescript-signals/actions/workflows/release.yml)
[![npm version](https://badgen.net/npm/v/rescript-signals)](https://www.npmjs.com/package/rescript-signals)
[![bundlephobia](https://badgen.net/bundlephobia/minzip/rescript-signals)](https://bundlephobia.com/package/rescript-signals)

A lightweight, high-performance reactive signals library for ReScript with zero dependencies. Build reactive applications with fine-grained updates, automatic dependency tracking, and minimal re-computation.

## Installation

```bash
npm install rescript-signals
```

Add to your `rescript.json`:

```json
{
  "dependencies": ["rescript-signals"]
}
```

## Key Features

- **Reactive State**: Signals track changes and notify dependents automatically
- **Computed Values**: Derived state with lazy evaluation and automatic caching
- **Side Effects**: Run code in response to signal changes with automatic cleanup
- **Dependency Tracking**: No manual subscriptions—dependencies are tracked automatically
- **Batched Updates**: Group multiple updates to prevent redundant computations
- **Untracked Reads**: Access signal values without creating dependencies
- **Fine-grained Updates**: Only affected computations re-run, nothing more
- **Type-safe**: Full ReScript type safety with zero runtime overhead
- **Debuggable**: Optional naming for signals, computed values, and effects

## Quick Start

```rescript
open Signals

// Create a signal
let count = Signal.make(0)

// Create a computed value (updates automatically)
let doubled = Computed.make(() => Signal.get(count) * 2)

// Run a side effect (executes when dependencies change)
let disposer = Effect.run(() => {
  Console.log(`Count: ${Int.toString(Signal.get(count))}, Doubled: ${Int.toString(Signal.get(doubled))}`)
  None
})

// Update the signal
Signal.set(count, 5) // Logs: "Count: 5, Doubled: 10"

// Clean up when done
disposer.dispose()
```

## Usage

### Signals

Signals are reactive containers for values. When a signal's value changes, all dependent computations and effects are automatically updated.

#### Creating and Reading Signals

```rescript
open Signals

// Create a signal with an initial value
let count = Signal.make(0)

// Read the value with dependency tracking
let value = Signal.get(count)

// Read without tracking (in effects/computed)
let value = Signal.peek(count)
```

#### Updating Signals

```rescript
// Set a new value
Signal.set(count, 1)

// Update based on current value
Signal.update(count, n => n + 1)
```

#### Advanced Signal Options

```rescript
// Custom equality to prevent unnecessary updates
let position = Signal.make(
  {x: 0, y: 0},
  ~equals=(a, b) => a.x === b.x && a.y === b.y
)

// Named signals for debugging
let userCount = Signal.make(0, ~name="userCount")
```

### Computed Values

Computed signals derive their value from other signals. They're lazily evaluated and automatically cache results until dependencies change.

#### Basic Computed

```rescript
let count = Signal.make(5)
let doubled = Computed.make(() => Signal.get(count) * 2)

Console.log(Signal.peek(doubled)) // 10

Signal.set(count, 10)
Console.log(Signal.peek(doubled)) // 20
```

#### Computed from Multiple Signals

```rescript
let firstName = Signal.make("John")
let lastName = Signal.make("Doe")

let fullName = Computed.make(() =>
  Signal.get(firstName) ++ " " ++ Signal.get(lastName)
)

Console.log(Signal.peek(fullName)) // "John Doe"
```

#### Chained Computed Values

```rescript
let base = Signal.make(2)
let doubled = Computed.make(() => Signal.get(base) * 2)
let quadrupled = Computed.make(() => Signal.get(doubled) * 2)

Console.log(Signal.peek(quadrupled)) // 8
Signal.set(base, 3)
Console.log(Signal.peek(quadrupled)) // 12
```

#### Named Computed for Debugging

```rescript
let total = Computed.make(
  () => Signal.get(price) * Signal.get(quantity),
  ~name="orderTotal"
)
```

#### Disposal

Computed values are automatically cleaned up when no longer referenced, but you can manually dispose of them:

```rescript
Computed.dispose(doubled)
```

### Effects

Effects run side effects in response to signal changes. They execute immediately and re-run whenever tracked dependencies change.

#### Basic Effect

```rescript
let count = Signal.make(0)

let disposer = Effect.run(() => {
  Console.log(`Count is: ${Int.toString(Signal.get(count))}`)
  None
})

Signal.set(count, 1) // Logs: "Count is: 1"
disposer.dispose()
```

#### Effect with Cleanup

Effects can return a cleanup function that runs before the next execution and on disposal:

```rescript
let url = Signal.make("/api/data")

let disposer = Effect.run(() => {
  let currentUrl = Signal.get(url)

  // Start async operation
  let abortController = fetchData(currentUrl)

  // Return cleanup function
  Some(() => {
    Console.log("Cancelling previous fetch")
    abortController.abort()
  })
})

Signal.set(url, "/api/other") // Cleanup runs, then effect re-executes
disposer.dispose() // Final cleanup
```

#### Named Effects for Debugging

```rescript
let disposer = Effect.run(
  () => {
    Console.log(Signal.get(count))
    None
  },
  ~name="countLogger"
)
```

#### Conditional Dependencies

Effects only track signals read during execution:

```rescript
let showDetails = Signal.make(false)
let userData = Signal.make({name: "John"})
let adminData = Signal.make({role: "admin"})

let disposer = Effect.run(() => {
  if Signal.get(showDetails) {
    Console.log(Signal.get(userData)) // Tracked
  } else {
    Console.log("Hidden")
    // adminData is not tracked in this branch
  }
  None
})
```

## Advanced Features

### Batching Updates

Batch multiple signal updates to prevent redundant effect executions. All updates within a batch are applied before any effects run:

```rescript
let firstName = Signal.make("John")
let lastName = Signal.make("Doe")
let runCount = ref(0)

let disposer = Effect.run(() => {
  Console.log(Signal.get(firstName) ++ " " ++ Signal.get(lastName))
  runCount := runCount.contents + 1
  None
})

// Without batching: effect runs twice (once per update)
Signal.set(firstName, "Jane")
Signal.set(lastName, "Smith")

// With batching: effect runs only once
Signal.batch(() => {
  Signal.set(firstName, "Alice")
  Signal.set(lastName, "Johnson")
})

// Batches can be nested and return values
let result = Signal.batch(() => {
  Signal.set(firstName, "Bob")
  Signal.set(lastName, "Brown")
  "Updated!"
})
```

### Untracked Reads

Read signal values without creating dependencies. Useful when you need a value but don't want to re-run when it changes:

```rescript
let count = Signal.make(0)
let threshold = Signal.make(10)

let disposer = Effect.run(() => {
  let current = Signal.get(count)
  let limit = Signal.untrack(() => Signal.get(threshold))

  if current > limit {
    Console.log("Count exceeds threshold!")
  }
  None
})

// This triggers the effect (count is tracked)
Signal.set(count, 15)

// This does NOT trigger the effect (threshold is untracked)
Signal.set(threshold, 20)
```

Untracked reads can be nested and return values:

```rescript
let value = Signal.untrack(() => {
  let a = Signal.get(signalA)
  let b = Signal.get(signalB)
  a + b
})
```

## Performance

- **Lazy Evaluation**: Computed values only recalculate when read
- **Smart Caching**: Results are cached until dependencies actually change
- **Minimal Re-renders**: Equality checking prevents unnecessary updates
- **Glitch-free**: Derived values never see inconsistent intermediate state
- **Scales Well**: Optimized for large dependency graphs with many signals

### Benchmarks

| Operation | Ops/sec |
|-----------|---------|
| Signal update with effect | ~2,400,000 |
| Update signal with 100 computed observers | ~170,000 |
| Update 1 of 100 source signals | ~80,000 |
| Batch update 100 signals | ~60,000 |

Run benchmarks yourself with `node benchmark.mjs`.

## API Reference

### `Signal`

The core reactive primitive for storing state.

```rescript
type t<'a>

// Create a new signal
let make: (
  'a,
  ~name: option<string>=?,
  ~equals: option<('a, 'a) => bool>=?
) => t<'a>

// Read with dependency tracking
let get: t<'a> => 'a

// Read without dependency tracking
let peek: t<'a> => 'a

// Set a new value
let set: (t<'a>, 'a) => unit

// Update based on current value
let update: (t<'a>, 'a => 'a) => unit

// Batch multiple updates
let batch: (unit => 'a) => 'a

// Read without tracking dependencies
let untrack: (unit => 'a) => 'a
```

**Parameters:**
- `initialValue`: The initial value for the signal
- `~name`: Optional name for debugging
- `~equals`: Optional custom equality function (default: `===`)

**Returns:** A signal that can be read and updated

### `Computed`

Create derived values that update automatically.

```rescript
// Create a computed value
let make: (
  unit => 'a,
  ~name: option<string>=?
) => Signal.t<'a>

// Manually dispose a computed value
let dispose: Signal.t<'a> => unit
```

**Parameters:**
- `fn`: Function that computes the derived value
- `~name`: Optional name for debugging

**Returns:** A signal containing the computed value (read-only)

**Note:** Computed values use lazy evaluation—they only recalculate when read after dependencies change.

### `Effect`

Run side effects in response to signal changes.

```rescript
type disposer = {dispose: unit => unit}

// Run an effect
let run: (
  unit => option<unit => unit>,
  ~name: option<string>=?
) => disposer
```

**Parameters:**
- `fn`: Effect function to execute. Can return `None` or `Some(cleanupFn)`
- `~name`: Optional name for debugging

**Returns:** A disposer object with a `dispose()` method

**Note:** Effects run immediately and re-run whenever tracked dependencies change. Cleanup functions run before re-execution and on disposal.

## Common Patterns

### Form State Management

```rescript
type formData = {
  name: string,
  email: string,
  age: int,
}

let formData = Signal.make({name: "", email: "", age: 0})

// Computed validation
let isValid = Computed.make(() => {
  let data = Signal.get(formData)
  data.name !== "" && data.email->String.includes("@") && data.age >= 18
})

// Effect for auto-save
let disposer = Effect.run(() => {
  if Signal.get(isValid) {
    saveToLocalStorage(Signal.get(formData))
  }
  None
})
```

### Async Data Fetching

```rescript
let userId = Signal.make(1)
let userData = Signal.make(None)
let isLoading = Signal.make(false)

let disposer = Effect.run(() => {
  let id = Signal.get(userId)

  Signal.set(isLoading, true)

  fetchUser(id)->Promise.then(user => {
    Signal.set(userData, Some(user))
    Signal.set(isLoading, false)
  })->ignore

  Some(() => {
    // Cancel previous request if needed
    cancelFetch(id)
  })
})
```

### Derived Collections

```rescript
let todos = Signal.make([
  {id: 1, text: "Learn ReScript", completed: false},
  {id: 2, text: "Build an app", completed: true},
])

let filter = Signal.make("all") // "all" | "active" | "completed"

let filteredTodos = Computed.make(() => {
  let items = Signal.get(todos)
  let currentFilter = Signal.get(filter)

  switch currentFilter {
  | "active" => items->Array.filter(t => !t.completed)
  | "completed" => items->Array.filter(t => t.completed)
  | _ => items
  }
})

let completedCount = Computed.make(() =>
  Signal.get(todos)->Array.filter(t => t.completed)->Array.length
)
```

### Coordinated Updates

```rescript
let x = Signal.make(0)
let y = Signal.make(0)
let z = Signal.make(0)

// Update all coordinates atomically
let movePoint = (dx, dy, dz) => {
  Signal.batch(() => {
    Signal.update(x, v => v + dx)
    Signal.update(y, v => v + dy)
    Signal.update(z, v => v + dz)
  })
}

// Effect only runs once per movePoint call
let disposer = Effect.run(() => {
  Console.log(
    `Position: (${Int.toString(Signal.get(x))}, ${Int.toString(Signal.get(y))}, ${Int.toString(Signal.get(z))})`
  )
  None
})
```

### Performance Optimization with Untrack

```rescript
// Expensive configuration that rarely changes
let config = Signal.make({theme: "dark", locale: "en"})

// Frequently changing data
let data = Signal.make([])

let disposer = Effect.run(() => {
  let items = Signal.get(data)

  // Read config without tracking—we'll manually refresh when config changes
  let currentConfig = Signal.untrack(() => Signal.get(config))

  renderUI(items, currentConfig)
  None
})
```

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

### Running Tests

```bash
npm test
```

### Building

```bash
npm run build
```

### Watching for Changes

```bash
npm run watch
```

## License

See [LICENSE](LICENSE) for details.