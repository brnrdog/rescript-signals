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
  let signal: Signal.t<'a> = {
    id,
    // Written by the first run below, before anything can read it.
    value: Obj.magic(Core.noCell),
    equals,
    name,
    subs,
  }
  subs.cell = Obj.magic(signal)
  if Debug.enabled.contents {
    Debug.created(~target=Obj.magic(subs), ~id, ~kind=#Computed, ~name)
  }

  // The first run is an ordinary one: it records the dependencies, and a
  // failure is held for the first read rather than thrown from here. The
  // computed starts detached, so it records them without attaching.
  Scheduler.recomputeAndLevel(subs)

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
  if Debug.enabled.contents {
    Debug.unlinkedAll(Obj.magic(subs), subs.firstDep)
    Debug.disposed(Obj.magic(subs))
  }
  Core.clearSubsDeps(subs)
  Core.markDetached(subs)
  Core.setSubsDirty(subs)
}
