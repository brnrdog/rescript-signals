type disposer = {dispose: unit => unit}

// One record for the effect, one closure for its disposer, and the record the
// disposer travels in: everything else the effect needs — its cleanup, whether
// it has been disposed — lives on the observer, where the scheduler can see it.
let runWithDisposer = (fn: unit => option<unit => unit>, ~name: option<string>=?): disposer => {
  let observer = Core.makeObserver(Id.make(), #Effect, fn, ~name?)

  // Initial run under tracking (no need to clearDeps - observer is fresh)
  let prev = Scheduler.currentObserver.contents
  Scheduler.currentObserver := Some(observer)

  try {
    Scheduler.runEffectBody(observer)
    Core.clearDirty(observer)
    Scheduler.currentObserver := prev
  } catch {
  | exn =>
    Scheduler.currentObserver := prev
    throw(exn)
  }

  // Compute level
  observer.level = Scheduler.computeLevel(observer)

  {dispose: () => Scheduler.disposeEffect(observer)}
}

let run = (fn: unit => option<unit => unit>, ~name: option<string>=?): unit => {
  let _ = runWithDisposer(fn, ~name?)
}
