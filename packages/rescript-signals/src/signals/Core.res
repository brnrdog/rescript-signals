// Core types for the reactive system using linked lists
// All types defined here to handle circular references

// Bitwise flags for observer state (avoids object property overhead)
let flag_dirty = 1
let flag_pending = 2
let flag_running = 4

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
    // If compute is Some, this subs is a computed signal
    mutable compute: option<unit => unit>,
    mutable firstDep: option<Link.t>,
    mutable lastDep: option<Link.t>,
    mutable flags: int,
    mutable level: int,
    mutable deferEffectsUntilRecompute: bool,
    mutable lastGlobalVersion: int,
  }
} = Subs

// Observer for effects only (computeds use subs directly)
and Observer: {
  type t = {
    id: int,
    kind: kind,
    run: unit => unit,
    mutable firstDep: option<Link.t>,
    mutable lastDep: option<Link.t>,
    mutable flags: int,
    mutable level: int,
    name: option<string>,
    // For computed observers: direct reference to backing subs (the combined object)
    mutable backingSubs: option<Subs.t>,
  }
} = Observer

// Type aliases for convenience
type link = Link.t
type subs = Subs.t
type observer = Observer.t

// Create empty subscriber list (for plain signals)
let makeSubs = (): subs => {
  first: None,
  last: None,
  computedSubscriberCount: 0,
  version: 0,
  compute: None,
  firstDep: None,
  lastDep: None,
  flags: 0,
  level: 0,
  deferEffectsUntilRecompute: false,
  lastGlobalVersion: 0,
}

// Create subs for a computed (with compute function)
let makeComputedSubs = (compute: unit => unit, ~deferEffectsUntilRecompute: bool=false): subs => {
  first: None,
  last: None,
  computedSubscriberCount: 0,
  version: 0,
  compute: Some(compute),
  firstDep: None,
  lastDep: None,
  flags: flag_dirty, // start dirty
  level: 0,
  deferEffectsUntilRecompute,
  lastGlobalVersion: 0,
}

// Create observer
let makeObserver = (
  id: int,
  kind: kind,
  run: unit => unit,
  ~name: option<string>=?,
  ~backingSubs: option<subs>=?,
): observer => {
  id,
  kind,
  run,
  firstDep: None,
  lastDep: None,
  flags: flag_dirty, // start dirty
  level: 0,
  name,
  backingSubs,
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

// Flag operations for subs
let isSubsDirty = (s: subs): bool => Int.bitwiseAnd(s.flags, flag_dirty) !== 0
let setSubsDirty = (s: subs): unit => s.flags = Int.bitwiseOr(s.flags, flag_dirty)
let clearSubsDirty = (s: subs): unit =>
  s.flags = Int.bitwiseAnd(s.flags, Int.bitwiseNot(flag_dirty))
let isSubsPending = (s: subs): bool => Int.bitwiseAnd(s.flags, flag_pending) !== 0
let setSubsPending = (s: subs): unit => s.flags = Int.bitwiseOr(s.flags, flag_pending)
let clearSubsPending = (s: subs): unit =>
  s.flags = Int.bitwiseAnd(s.flags, Int.bitwiseNot(flag_pending))

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
  }
}

// Add link to signal's subscriber list
let linkToSubs = (subs: subs, link: link): unit => {
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

// Remove link from subscriber list
let unlinkFromSubs = (link: link): unit => {
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
