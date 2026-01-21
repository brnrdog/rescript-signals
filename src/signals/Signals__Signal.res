module Id = Signals__Id
module Scheduler = Signals__Scheduler
module Core = Signals__Core

type t<'a> = {
  id: int,
  mutable value: 'a,
  equals: ('a, 'a) => bool,
  name: option<string>,
  // Subscriber linked list (replaces signalObservers Map lookup)
  subs: Core.subs,
}

let make = (initialValue: 'a, ~name: option<string>=?, ~equals: option<('a, 'a) => bool>=?): t<
  'a,
> => {
  let id = Id.make()

  {
    id,
    value: initialValue,
    equals: equals->Option.getOr((a, b) => a === b),
    name,
    subs: Core.makeSubs(),
  }
}

// Optimized signal creation for computed backing signals (no equals check needed)
let makeForComputed = (initialValue: 'a, ~name: option<string>=?): t<'a> => {
  let id = Id.make()
  {
    id,
    value: initialValue,
    equals: (_, _) => false, // Computeds always check freshness via dirty flag
    name,
    subs: Core.makeSubs(),
  }
}

// Optimized get - inlined hot path checks
let get = (signal: t<'a>): 'a => {
  // Ensure computed is fresh
  Scheduler.ensureComputedFresh(signal.subs)

  // Track dependency if we're inside a computed or effect
  Scheduler.trackDep(signal.subs)

  signal.value
}

let peek = (signal: t<'a>): 'a => {
  Scheduler.ensureComputedFresh(signal.subs)
  signal.value
}

let set = (signal: t<'a>, newValue: 'a): unit => {
  let shouldUpdate = try {
    !signal.equals(signal.value, newValue)
  } catch {
  | _ => true
  }

  if shouldUpdate {
    signal.value = newValue
    signal.subs.version = signal.subs.version + 1
    Scheduler.notifySubs(signal.subs)
  }
}

let update = (signal: t<'a>, fn: 'a => 'a): unit => signal->set(fn(signal.value))

let batch = Scheduler.batch

let untrack = Scheduler.untrack
