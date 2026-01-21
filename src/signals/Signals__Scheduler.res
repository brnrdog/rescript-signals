module Core = Signals__Core

// Current execution context for computeds (subs IS the observer)
let currentComputedSubs: ref<option<Core.subs>> = ref(None)

// Current execution context for effects
let currentObserver: ref<option<Core.observer>> = ref(None)

// Pending effects to execute
let pendingEffects: array<Core.observer> = []
// Pending computeds to recompute (subs that are dirty)
let pendingComputedSubs: array<Core.subs> = []
let flushing: ref<bool> = ref(false)

// Queue for iterative dirty marking
let dirtyQueue: array<Core.subs> = []

// Efficient array clear
let clearArray: array<'a> => unit = %raw(`function(arr) { arr.length = 0 }`)

// Add effect to pending if not already there
let addEffectToPending = (observer: Core.observer): unit => {
  if !Core.isPending(observer) {
    Core.setPending(observer)
    pendingEffects->Array.push(observer)->ignore
  }
}

// Track a dependency from a computed (subs tracks subs)
// For initial computation (firstDep is None), skip duplicate check since deps are empty
let trackDepFromComputed = (computedSubs: Core.subs, sourceSubs: Core.subs): unit => {
  // Fast path: if no deps yet, no need to check for duplicates
  if computedSubs.firstDep === None {
    let newLink: Core.link = {
      subs: sourceSubs,
      observer: Obj.magic(computedSubs),
      nextDep: None,
      prevDep: None,
      nextSub: None,
      prevSub: None,
    }
    Core.linkToSubsDeps(computedSubs, newLink)
    Core.linkToSubs(sourceSubs, newLink)
  } else {
    // Check if already tracking this signal (walk dep list)
    let found = ref(false)
    let link = ref(computedSubs.firstDep)
    while link.contents !== None && !found.contents {
      switch link.contents {
      | Some(l) =>
        if l.subs === sourceSubs {
          found := true
        } else {
          link := l.nextDep
        }
      | None => ()
      }
    }

    // Only add if not already tracked
    if !found.contents {
      let newLink: Core.link = {
        subs: sourceSubs,
        observer: Obj.magic(computedSubs),
        nextDep: None,
        prevDep: None,
        nextSub: None,
        prevSub: None,
      }
      Core.linkToSubsDeps(computedSubs, newLink)
      Core.linkToSubs(sourceSubs, newLink)
    }
  }
}

// Track a dependency from an effect (observer tracks subs)
// For initial run (firstDep is None), skip duplicate check since deps are empty
let trackDepFromEffect = (observer: Core.observer, subs: Core.subs): unit => {
  // Fast path: if no deps yet, no need to check for duplicates
  if observer.firstDep === None {
    let newLink = Core.makeLink(subs, observer)
    Core.linkToDeps(observer, newLink)
    Core.linkToSubs(subs, newLink)
  } else {
    // Check if already tracking this signal (walk dep list)
    let found = ref(false)
    let link = ref(observer.firstDep)
    while link.contents !== None && !found.contents {
      switch link.contents {
      | Some(l) =>
        if l.subs === subs {
          found := true
        } else {
          link := l.nextDep
        }
      | None => ()
      }
    }

    // Only add if not already tracked
    if !found.contents {
      let newLink = Core.makeLink(subs, observer)
      Core.linkToDeps(observer, newLink)
      Core.linkToSubs(subs, newLink)
    }
  }
}

// Track dependency - routes to appropriate function based on current context
let trackDep = (subs: Core.subs): unit => {
  switch currentComputedSubs.contents {
  | Some(computedSubs) => trackDepFromComputed(computedSubs, subs)
  | None =>
    switch currentObserver.contents {
    | Some(observer) => trackDepFromEffect(observer, subs)
    | None => ()
    }
  }
}

// Compare by level for sorting
let compareEffectsByLevel = (a: Core.observer, b: Core.observer): float => {
  Int.toFloat(a.level - b.level)
}

let compareSubsByLevel = (a: Core.subs, b: Core.subs): float => {
  Int.toFloat(a.level - b.level)
}

// Compute level for a computed (based on its dependencies)
let computeSubsLevel = (s: Core.subs): int => {
  let maxLevel = ref(0)
  let link = ref(s.firstDep)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      // Check if the source is a computed
      if Core.isComputed(l.subs) {
        if l.subs.level > maxLevel.contents {
          maxLevel := l.subs.level
        }
      }
      link := l.nextDep
    | None => ()
    }
  }
  maxLevel.contents + 1
}

// Compute level for an effect
let rec computeLevel = (observer: Core.observer): int => {
  let maxLevel = ref(0)
  let link = ref(observer.firstDep)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      if Core.isComputed(l.subs) {
        if l.subs.level > maxLevel.contents {
          maxLevel := l.subs.level
        }
      }
      link := l.nextDep
    | None => ()
    }
  }
  maxLevel.contents + 1
}

// Retrack a computed (recompute and rebuild deps)
and retrackComputed = (s: Core.subs): unit => {
  let oldLevel = s.level

  Core.clearSubsDeps(s)
  Core.clearSubsPending(s)

  let prev = currentComputedSubs.contents
  currentComputedSubs := Some(s)

  try {
    switch s.compute {
    | Some(compute) => compute()
    | None => ()
    }
    Core.clearSubsDirty(s)
    currentComputedSubs := prev
  } catch {
  | exn =>
    currentComputedSubs := prev
    throw(exn)
  }

  if oldLevel == 0 {
    s.level = computeSubsLevel(s)
  }
}

// Retrack an effect
and retrackEffect = (observer: Core.observer): unit => {
  let oldLevel = observer.level

  Core.clearDeps(observer)
  Core.clearPending(observer)

  let prev = currentObserver.contents
  currentObserver := Some(observer)

  try {
    observer.run()
    Core.clearDirty(observer)
    currentObserver := prev
  } catch {
  | exn =>
    currentObserver := prev
    throw(exn)
  }

  if oldLevel == 0 {
    observer.level = computeLevel(observer)
  }
}

// Flush pending observers
and flush = (): unit => {
  flushing := true

  try {
    while pendingEffects->Array.length > 0 || pendingComputedSubs->Array.length > 0 {
      // Process computeds first (they might trigger more effects)
      if pendingComputedSubs->Array.length > 0 {
        // Sort by level
        pendingComputedSubs->Array.sort(compareSubsByLevel)->ignore
        let computeds = pendingComputedSubs->Array.copy
        clearArray(pendingComputedSubs)
        computeds->Array.forEach(retrackComputed)
      }

      // Then process effects
      if pendingEffects->Array.length > 0 {
        pendingEffects->Array.sort(compareEffectsByLevel)->ignore
        let effects = pendingEffects->Array.copy
        clearArray(pendingEffects)
        effects->Array.forEach(retrackEffect)
      }
    }

    flushing := false
  } catch {
  | exn =>
    flushing := false
    throw(exn)
  }
}

// Notify all subscribers of a signal (traverse linked list)
let notifySubs = (subs: Core.subs): unit => {
  dirtyQueue->Array.push(subs)->ignore

  while dirtyQueue->Array.length > 0 {
    let currentSubs = dirtyQueue->Array.pop
    switch currentSubs {
    | None => ()
    | Some(s) =>
      let link = ref(s.first)
      while link.contents !== None {
        switch link.contents {
        | Some(l) =>
          // The observer field might be a real observer (effect) or a subs (computed)
          // We detect by checking if the subs the link came FROM is a computed
          let linkedSubs = (Obj.magic(l.observer): Core.subs)
          if Core.isComputed(linkedSubs) {
            // It's a computed - mark dirty and propagate
            if !Core.isSubsDirty(linkedSubs) {
              Core.setSubsDirty(linkedSubs)
              dirtyQueue->Array.push(linkedSubs)->ignore
            }
          } else {
            // It's an effect
            let observer = l.observer
            addEffectToPending(observer)
          }
          link := l.nextSub
        | None => ()
        }
      }
    }
  }

  if (pendingEffects->Array.length > 0 || pendingComputedSubs->Array.length > 0) && !flushing.contents {
    flush()
  }
}

// Ensure a computed signal is fresh before reading
let ensureComputedFresh = (subs: Core.subs): unit => {
  if Core.isComputed(subs) && Core.isSubsDirty(subs) {
    let oldLevel = subs.level

    Core.clearSubsDeps(subs)

    let prev = currentComputedSubs.contents
    currentComputedSubs := Some(subs)

    try {
      switch subs.compute {
      | Some(compute) => compute()
      | None => ()
      }
      Core.clearSubsDirty(subs)
      currentComputedSubs := prev
    } catch {
    | exn =>
      currentComputedSubs := prev
      throw(exn)
    }

    if oldLevel == 0 {
      subs.level = computeSubsLevel(subs)
    }
  }
}

// Schedule an effect for execution
let schedule = (observer: Core.observer): unit => {
  addEffectToPending(observer)
  if !flushing.contents {
    flush()
  }
}

// Batch multiple updates
let batch = fn => {
  let wasFlushing = flushing.contents
  flushing := true

  try {
    let result = fn()
    if !wasFlushing {
      flushing := false
      if pendingEffects->Array.length > 0 || pendingComputedSubs->Array.length > 0 {
        flush()
      }
    }
    result
  } catch {
  | exn =>
    if !wasFlushing {
      flushing := false
    }
    throw(exn)
  }
}

// Execute without tracking dependencies
let untrack = (fn: unit => 'a): 'a => {
  let prevComputed = currentComputedSubs.contents
  let prevObserver = currentObserver.contents
  currentComputedSubs := None
  currentObserver := None
  try {
    let result = fn()
    currentComputedSubs := prevComputed
    currentObserver := prevObserver
    result
  } catch {
  | exn =>
    currentComputedSubs := prevComputed
    currentObserver := prevObserver
    throw(exn)
  }
}
