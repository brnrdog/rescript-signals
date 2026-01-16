module Core = Signals__Core

// Current execution context - direct observer reference (no Map lookup needed)
let currentObserver: ref<option<Core.observer>> = ref(None)

// Pending observers to execute (direct references)
let pending: array<Core.observer> = []
let flushing: ref<bool> = ref(false)

// Queue for iterative dirty marking
let dirtyQueue: array<Core.subs> = []

// Efficient array clear
let clearArray: array<'a> => unit = %raw(`function(arr) { arr.length = 0 }`)

// Pre-allocated arrays for flush to avoid repeated allocations
let pendingComputeds: array<Core.observer> = []
let pendingEffects: array<Core.observer> = []

// Add observer to pending if not already there
let addToPending = (observer: Core.observer): unit => {
  if !Core.isPending(observer) {
    Core.setPending(observer)
    pending->Array.push(observer)->ignore
  }
}

// Track a dependency: create Link between observer and signal's subs
let trackDep = (observer: Core.observer, subs: Core.subs): unit => {
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

// Compare observers by level for sorting
let compareByLevel = (a: Core.observer, b: Core.observer): float => {
  Int.toFloat(a.level - b.level)
}

// Compute level based on dependencies
let rec computeLevel = (observer: Core.observer): int => {
  let maxLevel = ref(0)

  // Walk dependency list
  let link = ref(observer.firstDep)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      // Check if the source is a computed
      // Walk the subs to find observers that are computeds
      let subLink = ref(l.subs.first)
      while subLink.contents !== None {
        switch subLink.contents {
        | Some(sl) =>
          switch sl.observer.kind {
          | #Computed(_) =>
            if sl.observer.level > maxLevel.contents {
              maxLevel := sl.observer.level
            }
          | #Effect => ()
          }
          subLink := sl.nextSub
        | None => ()
        }
      }
      link := l.nextDep
    | None => ()
    }
  }

  maxLevel.contents + 1
}

// Retrack an observer: clear deps, run, rebuild deps
and retrack = (observer: Core.observer): unit => {
  // Save old level to check if recomputation is needed
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

  // Only recompute level if this is a new observer (level 0) or we need accuracy
  // For most cases, level stays stable after first computation
  if oldLevel == 0 {
    observer.level = computeLevel(observer)
  }
}

// Flush pending observers
and flush = (): unit => {
  flushing := true

  try {
    while pending->Array.length > 0 {
      // Clear reusable arrays efficiently
      clearArray(pendingComputeds)
      clearArray(pendingEffects)

      // Separate computeds and effects into pre-allocated arrays
      pending->Array.forEach(observer => {
        switch observer.kind {
        | #Computed(_) => pendingComputeds->Array.push(observer)->ignore
        | #Effect => pendingEffects->Array.push(observer)->ignore
        }
      })
      clearArray(pending)

      // Sort by level
      pendingComputeds->Array.sort(compareByLevel)->ignore
      pendingEffects->Array.sort(compareByLevel)->ignore

      // Execute computeds first, then effects
      pendingComputeds->Array.forEach(retrack)
      pendingEffects->Array.forEach(retrack)
    }

    flushing := false
  } catch {
  | exn =>
    flushing := false
    throw(exn)
  }
}

// Notify all subscribers of a signal (traverse linked list)
// Must be defined after flush since it calls flush
let notifySubs = (subs: Core.subs): unit => {
  // Seed the dirty queue
  dirtyQueue->Array.push(subs)->ignore

  // Process iteratively to avoid stack overflow
  while dirtyQueue->Array.length > 0 {
    let currentSubs = dirtyQueue->Array.pop
    switch currentSubs {
    | None => ()
    | Some(s) =>
      // Walk subscriber list
      let link = ref(s.first)
      while link.contents !== None {
        switch link.contents {
        | Some(l) =>
          let observer = l.observer
          switch observer.kind {
          | #Effect =>
            addToPending(observer)
          | #Computed(_) =>
            if !Core.isDirty(observer) {
              Core.setDirty(observer)
              // Propagate to the computed's subscribers using direct reference
              switch observer.backingSubs {
              | Some(backingSubs) => dirtyQueue->Array.push(backingSubs)->ignore
              | None => ()
              }
            }
          }
          link := l.nextSub
        | None => ()
        }
      }
    }
  }

  // Trigger flush
  if pending->Array.length > 0 && !flushing.contents {
    flush()
  }
}

// Ensure a computed signal is fresh before reading (uses subs.computedObserver directly)
let ensureComputedFresh = (subs: Core.subs): unit => {
  switch subs.computedObserver {
  | Some(observer) =>
    if Core.isDirty(observer) {
      let oldLevel = observer.level

      Core.clearDeps(observer)

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

      // Only recompute level on first run
      if oldLevel == 0 {
        observer.level = computeLevel(observer)
      }
    }
  | None => ()
  }
}

// Schedule an observer for execution
let schedule = (observer: Core.observer): unit => {
  addToPending(observer)
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
      if pending->Array.length > 0 {
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
  let prev = currentObserver.contents
  currentObserver := None
  try {
    let result = fn()
    currentObserver := prev
    result
  } catch {
  | exn =>
    currentObserver := prev
    throw(exn)
  }
}

// Register a computed's observer on subs (no Map needed, backingSubs is on observer)
let registerComputed = (_signalId: int, observer: Core.observer, subs: Core.subs): unit => {
  subs.computedObserver = Some(observer)
}

// Unregister a computed (for disposal)
let unregisterComputed = (_signalId: int, subs: Core.subs): unit => {
  switch subs.computedObserver {
  | Some(observer) =>
    Core.clearDeps(observer)
    subs.computedObserver = None
  | None => ()
  }
}
