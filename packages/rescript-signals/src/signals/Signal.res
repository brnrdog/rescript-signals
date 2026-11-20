// The record itself is declared in `Core` so the scheduler can write a
// computed's result into it; this is the same type.
type t<'a> = Core.cell<'a> = {
  id: int,
  mutable value: 'a,
  equals: ('a, 'a) => bool,
  name: option<string>,
  // Subscriber linked list (replaces signalObservers Map lookup)
  subs: Core.subs,
}

let defaultEquals = (a: 'a, b: 'a): bool => a === b
let neverEquals: ('a, 'a) => bool = (_a, _b) => false

let make = (initialValue: 'a, ~name: option<string>=?, ~equals: option<('a, 'a) => bool>=?): t<
  'a,
> => {
  let id = Id.make()
  let equalsFn = switch equals {
  | Some(eq) => eq
  | None => defaultEquals
  }

  let signal = {
    id,
    value: initialValue,
    equals: equalsFn,
    name,
    subs: Core.makeSubs(),
  }
  if Debug.enabled.contents {
    Debug.created(~target=Obj.magic(signal.subs), ~cell=Obj.magic(signal), ~id, ~kind=#Signal, ~name)
  }
  signal
}

// Optimized signal creation for computed backing signals (no equals check needed)
let makeForComputed = (initialValue: 'a, ~name: option<string>=?): t<'a> => {
  let id = Id.make()
  {
    id,
    value: initialValue,
    equals: neverEquals, // Computeds always check freshness via dirty flag
    name,
    subs: Core.makeSubs(),
  }
}

// A read that has more to do than track and return: bring a computed up to
// date, then count a loading node or throw what a failed one holds. Tracking
// comes before the throw, so a reader of a failed computed hears when it
// recovers.
let getSlow = (signal: t<'a>): 'a => {
  Scheduler.ensureComputedFresh(signal.subs)
  Scheduler.trackDep(signal.subs)
  if Int.bitwiseAnd(signal.subs.flags, Core.flag_status) !== 0 {
    Scheduler.readStatus(signal.subs)
  }
  signal.value
}

// The common read is one test: nothing to settle and nothing to report.
let get = (signal: t<'a>): 'a =>
  if Int.bitwiseAnd(signal.subs.flags, Core.flag_slow_read) === 0 {
    Scheduler.trackDep(signal.subs)
    signal.value
  } else {
    getSlow(signal)
  }

let peek = (signal: t<'a>): 'a => {
  if Int.bitwiseAnd(signal.subs.flags, Core.flag_slow_read) !== 0 {
    Scheduler.ensureComputedFresh(signal.subs)
    if Int.bitwiseAnd(signal.subs.flags, Core.flag_status) !== 0 {
      Scheduler.readStatus(signal.subs)
    }
  }
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
    Core.globalVersion := Core.globalVersion.contents + 1
    // After the value is stored, so a hook can inspect it, and before anything
    // it causes runs.
    if Debug.enabled.contents {
      Debug.written(Obj.magic(signal.subs), true)
    }
    Scheduler.notifySubs(signal.subs)
  } else if Debug.enabled.contents {
    Debug.written(Obj.magic(signal.subs), false)
  }
}

let update = (signal: t<'a>, fn: 'a => 'a): unit => signal->set(fn(signal.value))

let batch = Scheduler.batch

let untrack = Scheduler.untrack
