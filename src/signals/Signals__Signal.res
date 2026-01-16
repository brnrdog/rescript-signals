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

let get = (signal: t<'a>): 'a => {
  Scheduler.ensureComputedFresh(signal.id)

  // Track dependency if we're inside an observer
  switch Scheduler.currentObserver.contents {
  | Some(observer) => Scheduler.trackDep(observer, signal.subs)
  | None => ()
  }

  signal.value
}

let peek = (signal: t<'a>): 'a => {
  Scheduler.ensureComputedFresh(signal.id)
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
