// Core types for the reactive system using linked lists
// All types defined here to handle circular references

// Bitwise flags for observer state (avoids object property overhead)
let flag_dirty = 1
let flag_pending = 2
let flag_running = 4
// Set on a computed while it is detached from its own sources.
// A computed is attached exactly while it has at least one subscriber.
// Stored as "detached" rather than "attached" so that a settled computed carries
// none of these bits, letting a read test dirty and detached in one mask.
let flag_detached = 8
// A computed with neither bit set is attached and clean: its cached value stands.
let flag_needs_settle = 9
// Set on an effect once its disposer has run. The scheduler's queue holds plain
// references, so an effect disposed while queued is still dequeued once; the
// flag is what makes that dequeue a no-op instead of a run that re-tracks the
// effect's dependencies and brings it back from the dead.
let flag_disposed = 16

// Global tracking version
let trackingVersion: ref<int> = ref(0)
// Global mutation version (increments on real signal writes)
let globalVersion: ref<int> = ref(0)

type kind = [#Effect | #Computed]

module rec Link: {
  type t = {
    // Direct reference to signal's subscriber list (type-erased)
    mutable subs: Subs.t,
    // Direct reference to observer
    mutable observer: Observer.t,
    // Links in the observer's dependency chain
    mutable nextDep: option<Link.t>,
    mutable prevDep: option<Link.t>,
    // Links in the signal's subscriber chain
    mutable nextSub: option<Link.t>,
    mutable prevSub: option<Link.t>,
    // Version stamp for duplicate detection within a compute cycle
    mutable lastTrackedVersion: int,
    // Source's subs.version when this dependency was last read. Lets a cold
    // computed decide whether it is stale without receiving notifications.
    mutable lastSourceVersion: int,
    // Whether this link currently sits in the source's subscriber chain.
    // A cold computed keeps its dependency chain but detaches every link.
    mutable attached: bool,
  }
} = Link

// Signal subscriber list (head/tail of linked list)
// For computeds, this same object also serves as the observer (combined structure)
and Subs: {
  type t = {
    mutable first: option<Link.t>,
    mutable last: option<Link.t>,
    mutable computedSubscriberCount: int,
    mutable version: int,
    // === Observer fields (only used for computeds) ===
    // If compute is Some, this subs is a computed signal. This is the
    // consumer's own function; the scheduler stores what it returns into the
    // cell below and bumps the version, so no wrapper closure is needed.
    mutable compute: option<unit => Obj.t>,
    // The signal record this subs backs, for a computed: where the scheduler
    // writes the recomputed value. Type-erased because the record is defined
    // downstream of this module. Null for a plain signal.
    mutable cell: Obj.t,
    mutable firstDep: option<Link.t>,
    mutable lastDep: option<Link.t>,
    mutable flags: int,
    mutable level: int,
    // A computed with a custom `equals`: effects behind it wait for it to
    // recompute, so an unchanged result stops the propagation there.
    mutable deferEffectsUntilRecompute: bool,
    mutable lastGlobalVersion: int,
  }
} = Subs

// Observer for effects only (computeds use subs directly)
and Observer: {
  type t = {
    id: int,
    kind: kind,
    // The effect body; what it returns is the cleanup to run before the next
    // run and on disposal.
    run: unit => option<unit => unit>,
    mutable cleanup: option<unit => unit>,
    mutable firstDep: option<Link.t>,
    mutable lastDep: option<Link.t>,
    mutable flags: int,
    mutable level: int,
    name: option<string>,
  }
} = Observer

// The signal record, as the scheduler sees it when it writes a computed's
// result. `Signal.t` is this type; it lives here so that `Subs.cell` can be
// read back without a dependency on the `Signal` module.
//
// `raw` is the storage and `value` an accessor over it that subscribes the
// current observer (installed on the prototype by `Signal.makeRecord`). The
// scheduler therefore writes `raw`: writing `value` would recurse into the
// getter, and reading it during a recompute would subscribe the computed to
// itself.
type cell<'a> = {
  id: int,
  mutable raw: 'a,
  value: 'a,
  equals: ('a, 'a) => bool,
  name: option<string>,
  subs: Subs.t,
}

// Type aliases for convenience
type link = Link.t
type subs = Subs.t
type observer = Observer.t

let noCell: Obj.t = %raw(`null`)

// Create empty subscriber list (for plain signals)
let makeSubs = (): subs => {
  first: None,
  last: None,
  computedSubscriberCount: 0,
  version: 0,
  compute: None,
  cell: noCell,
  firstDep: None,
  lastDep: None,
  flags: 0,
  level: 0,
  deferEffectsUntilRecompute: false,
  lastGlobalVersion: 0,
}

// Create subs for a computed (with compute function)
let makeComputedSubs = (compute: unit => 'a, ~deferEffectsUntilRecompute: bool=false): subs => {
  first: None,
  last: None,
  computedSubscriberCount: 0,
  version: 0,
  compute: Some(Obj.magic(compute)),
  cell: noCell,
  firstDep: None,
  lastDep: None,
  flags: Int.bitwiseOr(flag_dirty, flag_detached), // start dirty and detached
  level: 0,
  deferEffectsUntilRecompute,
  lastGlobalVersion: 0,
}

// Create observer
let makeObserver = (
  id: int,
  kind: kind,
  run: unit => option<unit => unit>,
  ~name: option<string>=?,
): observer => {
  id,
  kind,
  run,
  cleanup: None,
  firstDep: None,
  lastDep: None,
  flags: flag_dirty, // start dirty
  level: 0,
  name,
}

// Flag operations for observer
let isDirty = (o: observer): bool => Int.bitwiseAnd(o.flags, flag_dirty) !== 0
let setDirty = (o: observer): unit => o.flags = Int.bitwiseOr(o.flags, flag_dirty)
let clearDirty = (o: observer): unit =>
  o.flags = Int.bitwiseAnd(o.flags, Int.bitwiseNot(flag_dirty))
let isPending = (o: observer): bool => Int.bitwiseAnd(o.flags, flag_pending) !== 0
let setPending = (o: observer): unit => o.flags = Int.bitwiseOr(o.flags, flag_pending)
let clearPending = (o: observer): unit =>
  o.flags = Int.bitwiseAnd(o.flags, Int.bitwiseNot(flag_pending))
let isDisposed = (o: observer): bool => Int.bitwiseAnd(o.flags, flag_disposed) !== 0
let setDisposed = (o: observer): unit => o.flags = Int.bitwiseOr(o.flags, flag_disposed)

// Flag operations for subs
let isSubsDirty = (s: subs): bool => Int.bitwiseAnd(s.flags, flag_dirty) !== 0
let setSubsDirty = (s: subs): unit => s.flags = Int.bitwiseOr(s.flags, flag_dirty)
let clearSubsDirty = (s: subs): unit =>
  s.flags = Int.bitwiseAnd(s.flags, Int.bitwiseNot(flag_dirty))
let isSubsPending = (s: subs): bool => Int.bitwiseAnd(s.flags, flag_pending) !== 0
let setSubsPending = (s: subs): unit => s.flags = Int.bitwiseOr(s.flags, flag_pending)
let clearSubsPending = (s: subs): unit =>
  s.flags = Int.bitwiseAnd(s.flags, Int.bitwiseNot(flag_pending))

// Whether a computed is currently detached from its sources
let isDetached = (s: subs): bool => Int.bitwiseAnd(s.flags, flag_detached) !== 0
let markDetached = (s: subs): unit => s.flags = Int.bitwiseOr(s.flags, flag_detached)
let markAttached = (s: subs): unit =>
  s.flags = Int.bitwiseAnd(s.flags, Int.bitwiseNot(flag_detached))

// Check if subs is a computed
let isComputed = (s: subs): bool => s.compute !== None

// Create a link node
let makeLink = (sourceSubs: subs, linkedObserver: observer): link => {
  {
    subs: sourceSubs,
    observer: linkedObserver,
    nextDep: None,
    prevDep: None,
    nextSub: None,
    prevSub: None,
    lastTrackedVersion: 0,
    lastSourceVersion: -1,
    attached: false,
  }
}

// Add link to signal's subscriber list.
// If this is the first subscriber of a cold computed, that computed goes hot:
// it re-attaches to its own sources so notifications can reach it again.
let rec linkToSubs = (subs: subs, link: link): unit => {
  if !link.attached {
    link.attached = true
    let wasEmpty = subs.first === None

    link.prevSub = subs.last
    link.nextSub = None
    switch subs.last {
    | Some(last) => last.nextSub = Some(link)
    | None => subs.first = Some(link)
    }
    subs.last = Some(link)

    let linkedSubs = (Obj.magic(link.observer): subs)
    if isComputed(linkedSubs) {
      subs.computedSubscriberCount = subs.computedSubscriberCount + 1
    }

    if wasEmpty && isComputed(subs) && isDetached(subs) {
      attachToSources(subs)
    }
  }
}

// Re-attach a computed to every source in its dependency chain.
// The value needs no reconciliation here: attaching only ever happens from inside
// Signal.get, which settles freshness before tracking, so a computed going hot is
// already up to date. Marking it dirty would also be actively wrong - notifySubs
// treats the dirty flag as its "already propagated" marker, so a computed dirtied
// out of band swallows later notifications instead of passing them downstream.
and attachToSources = (s: subs): unit => {
  // Clear first: guards against re-entering through the recursive linkToSubs below.
  markAttached(s)

  let link = ref(s.firstDep)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      let next = l.nextDep
      linkToSubs(l.subs, l)
      link := next
    | None => ()
    }
  }
}

// Add link to observer's dependency list
let linkToDeps = (observer: observer, link: link): unit => {
  link.prevDep = observer.lastDep
  link.nextDep = None
  switch observer.lastDep {
  | Some(last) => last.nextDep = Some(link)
  | None => observer.firstDep = Some(link)
  }
  observer.lastDep = Some(link)
}

// Remove link from subscriber list.
// If this was the last subscriber of a computed, that computed goes cold:
// it detaches from its own sources so neither it nor its cached value keeps
// them alive, and so writes stop paying to walk over it.
let rec unlinkFromSubs = (link: link): unit => {
  if link.attached {
    link.attached = false
    let subs = link.subs
    switch link.prevSub {
    | Some(prev) => prev.nextSub = link.nextSub
    | None => subs.first = link.nextSub
    }
    switch link.nextSub {
    | Some(next) => next.prevSub = link.prevSub
    | None => subs.last = link.prevSub
    }
    link.prevSub = None
    link.nextSub = None

    let linkedSubs = (Obj.magic(link.observer): subs)
    if isComputed(linkedSubs) && subs.computedSubscriberCount > 0 {
      subs.computedSubscriberCount = subs.computedSubscriberCount - 1
    }

    if subs.first === None && isComputed(subs) && !isDetached(subs) {
      detachFromSources(subs)
    }
  }
}

// Detach a computed from every source in its dependency chain.
// The chain itself is preserved, so the computed can go hot again later.
and detachFromSources = (s: subs): unit => {
  // Set first: guards against re-entering through the recursive unlink below.
  markDetached(s)

  let link = ref(s.firstDep)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      let next = l.nextDep
      unlinkFromSubs(l)
      link := next
    | None => ()
    }
  }
}

// Remove link from dependency list
let unlinkFromDeps = (observer: observer, link: link): unit => {
  switch link.prevDep {
  | Some(prev) => prev.nextDep = link.nextDep
  | None => observer.firstDep = link.nextDep
  }
  switch link.nextDep {
  | Some(next) => next.prevDep = link.prevDep
  | None => observer.lastDep = link.prevDep
  }
  link.prevDep = None
  link.nextDep = None
}

// Remove link from subs's dependency list (for computeds - subs IS the observer)
let unlinkFromSubsDeps = (s: subs, link: link): unit => {
  switch link.prevDep {
  | Some(prev) => prev.nextDep = link.nextDep
  | None => s.firstDep = link.nextDep
  }
  switch link.nextDep {
  | Some(next) => next.prevDep = link.prevDep
  | None => s.lastDep = link.prevDep
  }
  link.prevDep = None
  link.nextDep = None
}

// Clear all dependencies from observer (unlinks from all signals)
let clearDeps = (observer: observer): unit => {
  let link = ref(observer.firstDep)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      let next = l.nextDep
      unlinkFromSubs(l)
      link := next
    | None => ()
    }
  }
  observer.firstDep = None
  observer.lastDep = None
}

// Clear all dependencies from subs (for computeds - subs IS the observer)
let clearSubsDeps = (s: subs): unit => {
  let link = ref(s.firstDep)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      let next = l.nextDep
      unlinkFromSubs(l)
      link := next
    | None => ()
    }
  }
  s.firstDep = None
  s.lastDep = None
}

// Add link to subs's dependency list (for computeds - subs IS the observer)
let linkToSubsDeps = (s: subs, link: link): unit => {
  link.prevDep = s.lastDep
  link.nextDep = None
  switch s.lastDep {
  | Some(last) => last.nextDep = Some(link)
  | None => s.firstDep = Some(link)
  }
  s.lastDep = Some(link)
}
