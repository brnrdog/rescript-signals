open Signals

/** Subscribe a React component to a signal and read its current value.
    Re-renders when the signal changes. Uses useSyncExternalStore under
    the hood, so it is concurrent-mode and StrictMode safe. */
let useSignalValue: Signal.t<'a> => 'a

/** Create a signal whose identity is stable across re-renders and return
    (value, signal, setter). The value is subscribed, so the component
    re-renders on change. The signal and setter are referentially stable. */
let useSignal: (unit => 'a) => ('a, Signal.t<'a>, 'a => unit)

/** Build a memoized Computed from a thunk and subscribe to it. The thunk
    must only depend on other signals — React values captured in the
    closure will go stale. For React-prop-derived values, put the prop
    into a signal first or use `useComputedWithDeps`. */
let useComputed: (unit => 'a) => 'a

/** Same as `useComputed` but rebuilds the Computed when `deps` change,
    so React-level inputs can participate. */
let useComputedWithDeps: (unit => 'a, 'deps) => 'a

/** Run an effect tied to the component's lifetime. The thunk is executed
    with signal tracking enabled; returning `Some(cleanup)` installs a
    per-run disposer. The full effect is disposed on unmount. */
let useSignalEffect: (unit => option<unit => unit>) => unit
