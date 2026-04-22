type t<'a> = {
  id: int,
  mutable value: 'a,
  equals: ('a, 'a) => bool,
  name: option<string>,
  // Subscriber linked list (replaces signalObservers Map lookup)
  subs: Signals__Core.subs,
}

let defaultEquals = (a: 'a, b: 'a): bool => a === b
let neverEquals: ('a, 'a) => bool = (_a, _b) => false

let make = (initialValue: 'a, ~name: option<string>=?, ~equals: option<('a, 'a) => bool>=?): t<
  'a,
> => {
  let id = Signals__Id.make()
  let equalsFn = switch equals {
  | Some(eq) => eq
  | None => defaultEquals
  }

  {
    id,
    value: initialValue,
    equals: equalsFn,
    name,
    subs: Signals__Core.makeSubs(),
  }
}

// Optimized signal creation for computed backing signals (no equals check needed)
let makeForComputed = (initialValue: 'a, ~name: option<string>=?): t<'a> => {
  let id = Signals__Id.make()
  {
    id,
    value: initialValue,
    equals: neverEquals, // Computeds always check freshness via dirty flag
    name,
    subs: Signals__Core.makeSubs(),
  }
}

// Optimized get - inlined hot path checks
let get = (signal: t<'a>): 'a => {
  // Ensure computed is fresh
  Signals__Scheduler.ensureComputedFresh(signal.subs)

  // Track dependency if we're inside a computed or effect
  Signals__Scheduler.trackDep(signal.subs)

  signal.value
}

let peek = (signal: t<'a>): 'a => {
  Signals__Scheduler.ensureComputedFresh(signal.subs)
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
    Signals__Core.globalVersion := Signals__Core.globalVersion.contents + 1
    Signals__Scheduler.notifySubs(signal.subs)
  }
}

let update = (signal: t<'a>, fn: 'a => 'a): unit => signal->set(fn(signal.value))

let batch = Signals__Scheduler.batch

let untrack = Signals__Scheduler.untrack
