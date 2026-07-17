open Signals

// ---------------------------------------------------------------------------
// Automatic signal tracking for React (single-pass).
//
// Reading a signal inside the render thunk subscribes the component
// automatically — no explicit per-signal hook:
//
//   @react.component
//   let make = (~a, ~b) =>
//     useTracked(() => <div> {React.int(Signal.get(a) + Signal.get(b))} </div>)
//
// The display render IS the tracking pass: it is bracketed by the core
// `Tracking` scope — a notify-only observer that the scheduler notifies (but
// never auto-retracks) when a dependency changes. React re-renders, and that
// render re-establishes dependencies via `Tracking.track`, so the thunk runs
// exactly once per update and conditional reads are re-discovered each time.
//
// Tradeoff: dependency tracking happens during render (it reconciles the
// scope's dependency set). A render discarded by concurrent React leaves
// dependencies reflecting the discarded pass until the committed render
// re-tracks; `useSyncExternalStore` still guards against tearing.
// ---------------------------------------------------------------------------

type holder = {
  mutable version: int,
  mutable onStoreChange: unit => unit,
}

type store<'a> = {
  holder: holder,
  scope: Tracking.scope,
  // Latest closure, refreshed every render so any out-of-render re-track
  // (StrictMode repair) still reads current props/context values.
  mutable render: unit => 'a,
}

/** Run `render` with ambient dependency tracking and subscribe the component to
    every signal it reads. Re-renders when any tracked signal changes and
    re-discovers dependencies each render, so conditional reads work. Single
    pass: the thunk runs once per render. Concurrent/StrictMode safe via
    `useSyncExternalStore`, modulo the render-phase-tracking caveat noted above. */
let useTracked = (render: unit => 'a): 'a => {
  let storeRef = React.useRef(None)
  let store = switch storeRef.current {
  | Some(s) => s
  | None =>
    let holder = {version: 0, onStoreChange: () => ()}
    // Notify-only: on a tracked-dep change, bump the snapshot and poke React.
    let scope = Tracking.makeScope(~onInvalidate=() => {
      holder.version = holder.version + 1
      holder.onStoreChange()
    })
    let s: store<'a> = {holder, scope, render}
    storeRef.current = Some(s)
    s
  }
  store.render = render

  let subscribe = React.useCallback(onStoreChange => {
    store.holder.onStoreChange = onStoreChange
    () => store.holder.onStoreChange = () => ()
  }, [store])
  let getSnapshot = React.useCallback(() => store.holder.version, [store])
  let _: int = React.useSyncExternalStore(~subscribe, ~getSnapshot)

  // Lifetime: dispose on unmount. If a previous (StrictMode) cleanup disposed
  // our dependencies, re-establish them so the committed tree stays reactive.
  React.useEffect(() => {
    if Tracking.isEmpty(store.scope) {
      let _ = Tracking.track(store.scope, store.render)
    }
    Some(() => Tracking.dispose(store.scope))
  }, [store])

  // Single pass: this render establishes the dependency set and produces output.
  Tracking.track(store.scope, render)
}

// ---------------------------------------------------------------------------
// Explicit-dependency form.
//
//   @react.component
//   let make = (~a, ~b, ~c) => {
//     useSignals([dep(a), dep(b)])       // subscribe to a and b
//     <div> {React.string(Int.toString(Signal.get(a) + Signal.get(b)))}
//           {React.string(c)} </div>     // read them (and plain props) freely
//   }
//
// List the signal dependencies once, then read them anywhere in the body.
// `dep` type-erases the heterogeneous signals so they fit in one array. Like a
// React dependency array, this is explicit: a signal read but not listed will
// not trigger a re-render. For automatic discovery, use `useTracked`.
// ---------------------------------------------------------------------------

type dep = unit => unit

/** Wrap a signal as an untyped dependency for `useSignals`. */
let dep = (signal: Signal.t<'a>): dep => () => Signal.get(signal)->ignore

/** Subscribe the component to every signal in `deps` and re-render when any of
    them changes. Reads in the body stay plain `Signal.get`. Dependencies are
    reconciled each render, so a dynamic `deps` array is fine. */
let useSignals = (deps: array<dep>): unit => useTracked(() => deps->Array.forEach(d => d()))
