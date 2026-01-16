// Core types for the reactive system using linked lists
// All types defined here to handle circular references

// Bitwise flags for observer state (avoids object property overhead)
let flag_dirty = 1
let flag_pending = 2
let flag_running = 4

// Observer kind tag
type kind = [#Effect | #Computed(int)]

// Forward declare mutually recursive types
type rec link = {
  // Direct reference to signal's subscriber list (type-erased)
  mutable subs: subs,
  // Direct reference to observer
  mutable observer: observer,
  // Links in the observer's dependency chain
  mutable nextDep: option<link>,
  mutable prevDep: option<link>,
  // Links in the signal's subscriber chain
  mutable nextSub: option<link>,
  mutable prevSub: option<link>,
}

// Signal subscriber list (head/tail of linked list)
and subs = {
  mutable first: option<link>,
  mutable last: option<link>,
  mutable version: int, // signal version for freshness check
  // For computed signals: direct reference to backing observer (avoids Map lookup)
  mutable computedObserver: option<observer>,
}

// Observer with dependency list
and observer = {
  id: int,
  kind: kind,
  run: unit => unit,
  // Dependency linked list (replaces Set<int>)
  mutable firstDep: option<link>,
  mutable lastDep: option<link>,
  // State flags (replaces dirty: bool)
  mutable flags: int,
  mutable level: int,
  name: option<string>,
  // For computed observers: direct reference to backing signal's subs (avoids Map lookup)
  mutable backingSubs: option<subs>,
}

// Create empty subscriber list
let makeSubs = (): subs => {first: None, last: None, version: 0, computedObserver: None}

// Create observer
let makeObserver = (id: int, kind: kind, run: unit => unit, ~name: option<string>=?, ~backingSubs: option<subs>=?): observer => {
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

// Flag operations (using Int.Bitwise module)
let isDirty = (o: observer): bool => Int.Bitwise.land(o.flags, flag_dirty) !== 0
let setDirty = (o: observer): unit => o.flags = Int.Bitwise.lor(o.flags, flag_dirty)
let clearDirty = (o: observer): unit => o.flags = Int.Bitwise.land(o.flags, Int.Bitwise.lnot(flag_dirty))
let isPending = (o: observer): bool => Int.Bitwise.land(o.flags, flag_pending) !== 0
let setPending = (o: observer): unit => o.flags = Int.Bitwise.lor(o.flags, flag_pending)
let clearPending = (o: observer): unit => o.flags = Int.Bitwise.land(o.flags, Int.Bitwise.lnot(flag_pending))

// Create a link node
let makeLink = (subs: subs, observer: observer): link => {
  subs,
  observer,
  nextDep: None,
  prevDep: None,
  nextSub: None,
  prevSub: None,
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
