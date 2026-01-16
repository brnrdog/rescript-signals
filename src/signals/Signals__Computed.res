module Id = Signals__Id
module Signal = Signals__Signal
module Core = Signals__Core
module Scheduler = Signals__Scheduler

let make = (compute: unit => 'a, ~name: option<string>=?): Signal.t<'a> => {
  // Create backing signal with magic initial value
  let backingSignal = Signal.make((Obj.magic(): 'a), ~name?)

  // Create observer ID
  let observerId = Id.make()

  // Recompute function - updates backing signal's value directly
  let recompute = () => {
    let newValue = compute()
    backingSignal.value = newValue
  }

  // Create observer using Core types, with backingSubs for dirty propagation
  let observer = Core.makeObserver(observerId, #Computed(backingSignal.id), recompute, ~name?, ~backingSubs=backingSignal.subs)

  // Initial computation under tracking
  Core.clearDeps(observer)

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

  // Register for lookup by signal ID (needed for ensureComputedFresh and dirty propagation)
  Scheduler.registerComputed(backingSignal.id, observer, backingSignal.subs)

  backingSignal
}

let dispose = (signal: Signal.t<'a>): unit => {
  Scheduler.unregisterComputed(signal.id, signal.subs)
}
