# rescript-signals-react

[![npm version](https://badgen.net/npm/v/rescript-signals-react)](https://www.npmjs.com/package/rescript-signals-react)
[![bundlephobia](https://badgen.net/bundlephobia/min/rescript-signals-react)](https://bundlephobia.com/package/rescript-signals-react)

React adapter for [rescript-signals](https://github.com/brnrdog/rescript-signals) using `useSyncExternalStore`. Concurrent-mode and StrictMode safe.

## Installation

```bash
npm install rescript-signals-react
```

Add it to your `rescript.json`:

```json
{
  "dependencies": ["rescript-signals", "rescript-signals-react", "@rescript/react"]
}
```

## API

### `useSignalValue`

Subscribe a component to a signal and read its current value. Re-renders only when the signal changes.

```rescript
open Signals
open SignalsReact

let count = Signal.make(0)

@react.component
let make = () => {
  let value = useSignalValue(count)
  <span> {React.string(Int.toString(value))} </span>
}
```

### `useSignal`

Create a component-local signal. Returns `(value, signal, setter)` — the signal and setter are referentially stable across re-renders.

```rescript
open SignalsReact

@react.component
let make = () => {
  let (count, _signal, setCount) = useSignal(() => 0)

  <div>
    <span> {React.string(Int.toString(count))} </span>
    <button onClick={_ => setCount(count + 1)}>
      {React.string("Increment")}
    </button>
  </div>
}
```

### `useComputed`

Create a derived signal within a component and subscribe to it. The thunk must only depend on other signals — React values captured in the closure will go stale.

```rescript
@react.component
let make = (~a: Signal.t<int>, ~b: Signal.t<int>) => {
  let sum = SignalsReact.useComputed(() => Signal.get(a) + Signal.get(b))
  <div> {React.string(Int.toString(sum))} </div>
}
```

### `useComputedWithDeps`

Same as `useComputed` but rebuilds the computed when `deps` change, so React-level values can participate without going stale.

```rescript
@react.component
let make = (~signal: Signal.t<int>) => {
  let (multiplier, setMultiplier) = React.useState(() => 2)
  let result = SignalsReact.useComputedWithDeps(
    () => Signal.get(signal) * multiplier,
    multiplier,
  )

  <div>
    <span> {React.string(Int.toString(result))} </span>
    <button onClick={_ => setMultiplier(prev => prev + 1)}>
      {React.string("Change multiplier")}
    </button>
  </div>
}
```

### `useSignalEffect`

Run an effect tied to the component's lifetime. The thunk executes with signal tracking enabled. Return `Some(cleanup)` to install a per-run disposer; the effect is fully disposed on unmount.

```rescript
@react.component
let make = (~signal: Signal.t<int>) => {
  SignalsReact.useSignalEffect(() => {
    Console.log2("Value changed:", Signal.get(signal))
    None // or Some(() => cleanup())
  })

  <div />
}
```

## License

See [LICENSE](LICENSE) for details.
