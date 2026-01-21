module Id = Signals__Id
module Signal = Signals__Signal
module Core = Signals__Core
module Scheduler = Signals__Scheduler

let make = (compute: unit => 'a, ~name: option<string>=?): Signal.t<'a> => {
  let id = Id.make()

  // Create a mutable ref to hold the signal so the compute function can update it
  // Using Obj.magic to avoid Option wrapper overhead
  let signalRef: ref<Signal.t<'a>> = ref(Obj.magic())

  // Recompute function - updates the signal's value directly
  let recompute = () => {
    signalRef.contents.value = compute()
  }

  // Create combined subs (this IS the observer for the computed)
  let subs = Core.makeComputedSubs(recompute)

  // Initial computation under tracking to establish dependencies
  let prev = Scheduler.currentComputedSubs.contents
  Scheduler.currentComputedSubs := Some(subs)
  let initialValue = compute()
  Scheduler.currentComputedSubs := prev

  // Create the signal with the initial value
  let signal: Signal.t<'a> = {
    id,
    value: initialValue,
    equals: (_, _) => false, // Computeds always check freshness via dirty flag
    name,
    subs,
  }

  // Set the ref so recompute can access the signal
  signalRef := signal
  Core.clearSubsDirty(subs)

  signal
}

let dispose = (signal: Signal.t<'a>): unit => {
  Core.clearSubsDeps(signal.subs)
}
