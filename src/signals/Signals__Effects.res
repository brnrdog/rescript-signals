module Id = Signals__Id
module Core = Signals__Core
module Scheduler = Signals__Scheduler

type disposer = {dispose: unit => unit}

let run = (fn: unit => option<unit => unit>, ~name: option<string>=?): disposer => {
  let observerId = Id.make()
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
  let observer = Core.makeObserver(observerId, #Effect, runWithCleanup, ~name?)

  // Initial run under tracking (no need to clearDeps - observer is fresh)
  let prev = Scheduler.currentObserver.contents
  Scheduler.currentObserver := Some(observer)

  try {
    observer.run()
    Core.clearDirty(observer)
    Scheduler.currentObserver := prev
  } catch {
  | exn =>
    Scheduler.currentObserver := prev
    throw(exn)
  }

  // Compute level
  observer.level = Scheduler.computeLevel(observer)

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

      Core.clearDeps(observer)
    }
  }

  {dispose: dispose}
}
