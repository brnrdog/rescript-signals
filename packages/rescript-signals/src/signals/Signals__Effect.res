type disposer = {dispose: unit => unit}

let runWithDisposer = (fn: unit => option<unit => unit>, ~name: option<string>=?): disposer => {
  let observerId = Signals__Id.make()
  let cleanup: ref<option<unit => unit>> = ref(None)

  // Wrapper that handles cleanup
  let runWithCleanup = () => {
    // Run previous cleanup
    switch cleanup.contents {
    | Some(cleanupFn) => cleanupFn()
    | None => ()
    }

    // Run effect and store new cleanup
    cleanup := fn()
  }

  // Create observer using Core types
  let observer = Signals__Core.makeObserver(observerId, #Effect, runWithCleanup, ~name?)

  // Initial run under tracking (no need to clearDeps - observer is fresh)
  let prev = Signals__Scheduler.currentObserver.contents
  Signals__Scheduler.currentObserver := Some(observer)

  try {
    observer.run()
    Signals__Core.clearDirty(observer)
    Signals__Scheduler.currentObserver := prev
  } catch {
  | exn =>
    Signals__Scheduler.currentObserver := prev
    throw(exn)
  }

  // Compute level
  observer.level = Signals__Scheduler.computeLevel(observer)

  // Return disposer - stores observer reference directly (no Map lookup needed)
  let disposed = ref(false)

  let dispose = () => {
    if !disposed.contents {
      disposed := true

      // Run final cleanup
      switch cleanup.contents {
      | Some(cleanupFn) => cleanupFn()
      | None => ()
      }

      Signals__Core.clearDeps(observer)
    }
  }

  {dispose: dispose}
}

let run = (fn: unit => option<unit => unit>, ~name: option<string>=?): unit => {
  let _ = runWithDisposer(fn, ~name?)
}
