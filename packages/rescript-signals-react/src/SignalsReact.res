open Signals

let useSignalValue = (signal: Signal.t<'a>): 'a => {
  let subscribe = React.useCallback((listener: unit => unit) => {
    let firstRun = ref(true)
    let disposer = Effect.runWithDisposer(() => {
      let _ = Signal.get(signal)
      if firstRun.contents {
        firstRun := false
      } else {
        listener()
      }
      None
    })
    () => disposer.dispose()
  }, [signal])

  let getSnapshot = React.useCallback(() => Signal.peek(signal), [signal])

  React.useSyncExternalStore(~subscribe, ~getSnapshot)
}

let useSignal = (init: unit => 'a): ('a, Signal.t<'a>, 'a => unit) => {
  let signalRef = React.useRef(None)
  let signal = switch signalRef.current {
  | Some(s) => s
  | None =>
    let s = Signal.make(init())
    signalRef.current = Some(s)
    s
  }
  let setter = React.useCallback(next => Signal.set(signal, next), [signal])
  let value = useSignalValue(signal)
  (value, signal, setter)
}

let useComputed = (compute: unit => 'a): 'a => {
  let computed = React.useMemo(() => Computed.make(compute), [])
  useSignalValue(computed)
}

let useComputedWithDeps = (compute: unit => 'a, deps: 'deps): 'a => {
  let computed = React.useMemo(() => Computed.make(compute), [deps])
  useSignalValue(computed)
}

let useSignalEffect = (fn: unit => option<unit => unit>): unit => {
  React.useEffect(() => {
    let disposer = Effect.runWithDisposer(fn)
    Some(() => disposer.dispose())
  }, [])
}
