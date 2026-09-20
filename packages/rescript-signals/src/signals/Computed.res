// A computed never compares through `equals` on its own account: freshness is
// decided by the dirty flag, and a custom `equals` is consulted by the
// scheduler when the value is recomputed. This is what the record carries so
// that `Signal.set` on a computed still behaves as it always did.
let neverEquals: ('a, 'a) => bool = (_a, _b) => false

// Build the computed: one subs record (which is also its observer), one signal
// record pointing at it, and the subs pointing back so the scheduler can store
// each recomputed value. The consumer's function is stored as is — no wrapper
// closure per computed.
let makeWith = (
  compute: unit => 'a,
  ~equals: ('a, 'a) => bool,
  ~deferEffectsUntilRecompute: bool,
  ~name: option<string>,
): Signal.t<'a> => {
  let id = Id.make()
  let subs = Core.makeComputedSubs(compute, ~deferEffectsUntilRecompute)

  // Initial computation under tracking to establish dependencies
  let prev = Scheduler.currentComputedSubs.contents
  Scheduler.currentComputedSubs := Some(subs)
  let initialValue = try {
    compute()
  } catch {
  | exn =>
    Scheduler.currentComputedSubs := prev
    throw(exn)
  }
  Scheduler.currentComputedSubs := prev

  // Built through the constructor rather than as a record literal: the `value`
  // accessor lives on the prototype it installs, so a literal would produce a
  // signal whose `.value` is undefined.
  let signal: Signal.t<'a> = Signal.makeRecord(id, initialValue, equals, name, subs, Signal.get)
  subs.cell = Obj.magic(signal)
  subs.lastGlobalVersion = Core.globalVersion.contents
  Core.clearSubsDirty(subs)

  signal
}

let make = (
  compute: unit => 'a,
  ~name: option<string>=?,
  ~equals: option<('a, 'a) => bool>=?,
): Signal.t<'a> =>
  switch equals {
  | Some(equals) => makeWith(compute, ~equals, ~deferEffectsUntilRecompute=true, ~name)
  | None => makeWith(compute, ~equals=neverEquals, ~deferEffectsUntilRecompute=false, ~name)
  }

// Computeds detach from their sources on their own once they lose their last
// subscriber, so this is only needed to release one that is still subscribed.
// The computed stays usable: the next read rebuilds its dependencies.
let dispose = (signal: Signal.t<'a>): unit => {
  let subs = signal.subs
  Core.clearSubsDeps(subs)
  Core.markDetached(subs)
  Core.setSubsDirty(subs)
}
