open Signals

// ---------------------------------------------------------------------------
// EXPERIMENTAL — Path B spike: ambient auto-tracking
//
// Goal: get close to preact-signals ergonomics, where reading a signal inside
// a component subscribes the component automatically — no explicit
// `useSignalValue(signal)` per signal.
//
// preact does this with a Babel transform that brackets the whole component
// body in `useSignals()` (start/stop an ambient effect). ReScript has no
// supported third-party transform, and — more importantly — our reads are a
// *hook* (`useSyncExternalStore`), not an ambient getter, so we can't track
// during the component's own render without a core bracketing primitive.
//
// This spike takes the callback form instead: you wrap the reactive part of
// your render in `useTracked(() => ...)`. Any `Signal.get` inside auto-
// subscribes. A future transform could rewrite a top-level `useSignals()` +
// body into exactly this call, so `useTracked` is the runtime foundation and
// the transform would be pure sugar over it.
//
// Cost of the no-core-change approach (measured, honest): the thunk runs
// twice per reactive update — once in a tracking effect (to discover deps and
// schedule the re-render) and once in React's render (to produce the output).
// A production version would add a small `track`/`untrack` bracket to the core
// scheduler so the display render itself establishes deps (single pass, like
// preact). See notes at the bottom of this file.
// ---------------------------------------------------------------------------

type store<'a> = {
  mutable version: int,
  mutable onStoreChange: unit => unit,
  mutable disposer: option<Effect.disposer>,
  // Latest closure, refreshed every render so the tracking effect never sees
  // stale props/context values.
  mutable compute: unit => 'a,
}

/** Run `compute` with ambient dependency tracking and subscribe the component
    to every signal it reads. Re-renders when any tracked signal changes, and
    re-discovers dependencies on each change so conditional reads work. Backed
    by `useSyncExternalStore`, so it is concurrent-mode and StrictMode safe. */
let useTracked = (compute: unit => 'a): 'a => {
  let storeRef = React.useRef(None)
  let store = switch storeRef.current {
  | Some(s) => s
  | None =>
    let s: store<'a> = {
      version: 0,
      onStoreChange: () => (),
      disposer: None,
      compute,
    }
    storeRef.current = Some(s)
    s
  }
  // Keep the freshest closure so the tracking effect reads current props.
  store.compute = compute

  let subscribe = React.useCallback(onStoreChange => {
    store.onStoreChange = onStoreChange
    let firstRun = ref(true)
    // The effect re-runs on every change to a tracked signal. Its reads
    // register (and, on later runs, re-register) this effect as a subscriber,
    // so dynamically-conditional dependencies are handled automatically.
    let disposer = Effect.runWithDisposer(() => {
      let _ = store.compute()
      if firstRun.contents {
        firstRun := false
      } else {
        store.version = store.version + 1
        store.onStoreChange()
      }
      None
    })
    store.disposer = Some(disposer)
    () => {
      switch store.disposer {
      | Some(d) => d.dispose()
      | None => ()
      }
      store.disposer = None
    }
  }, [store])

  let getSnapshot = React.useCallback(() => store.version, [store])
  let _: int = React.useSyncExternalStore(~subscribe, ~getSnapshot)

  // Display pass — runs on every React render (signal- or prop-driven) with the
  // freshest values. `currentObserver` is None during React's render, so these
  // reads do not leak tracking into other components.
  compute()
}
