// Current execution context for computeds (subs IS the observer)
let currentComputedSubs: ref<option<Signals__Core.subs>> = ref(None)

// Current execution context for effects
let currentObserver: ref<option<Signals__Core.observer>> = ref(None)

// Current dependency tracking version (shared across nested compute/effect runs)
let currentTrackingVersion: ref<int> = ref(0)

// Per-run dependency cursors (separate from true tail pointers).
let currentComputedDepCursor: ref<option<Signals__Core.link>> = ref(None)
let currentObserverDepCursor: ref<option<Signals__Core.link>> = ref(None)

// Pending effects to execute
let pendingEffects: array<Signals__Core.observer> = []
// Pending computeds to recompute (subs that are dirty)
let pendingComputedSubs: array<Signals__Core.subs> = []
let flushing: ref<bool> = ref(false)
let pendingEffectsNeedsSort: ref<bool> = ref(false)
let pendingComputedNeedsSort: ref<bool> = ref(false)
let lastEnqueuedEffectLevel: ref<int> = ref(0)
let lastEnqueuedComputedLevel: ref<int> = ref(0)

// Queue for iterative dirty marking
let dirtyQueue: array<Signals__Core.subs> = []

// Efficient array clear
let clearArray: array<'a> => unit = %raw(`function(arr) { arr.length = 0 }`)
let drainProcessedPrefix: (array<'a>, int) => unit = %raw(`
function(arr, processedCount) {
  if (processedCount <= 0) return;
  if (processedCount >= arr.length) {
    arr.length = 0;
    return;
  }
  arr.copyWithin(0, processedCount);
  arr.length = arr.length - processedCount;
}
`)

// Add effect to pending if not already there
let addEffectToPending = (observer: Signals__Core.observer): unit => {
  if !Signals__Core.isPending(observer) {
    Signals__Core.setPending(observer)
    let lengthBefore = pendingEffects->Array.length
    if lengthBefore == 0 {
      pendingEffectsNeedsSort := false
    } else if observer.level < lastEnqueuedEffectLevel.contents {
      pendingEffectsNeedsSort := true
    }
    pendingEffects->Array.push(observer)->ignore
    lastEnqueuedEffectLevel := observer.level
  }
}

// Add computed to pending if not already there
let addComputedToPending = (subs: Signals__Core.subs): unit => {
  if !Signals__Core.isSubsPending(subs) {
    Signals__Core.setSubsPending(subs)
    let lengthBefore = pendingComputedSubs->Array.length
    if lengthBefore == 0 {
      pendingComputedNeedsSort := false
    } else if subs.level < lastEnqueuedComputedLevel.contents {
      pendingComputedNeedsSort := true
    }
    pendingComputedSubs->Array.push(subs)->ignore
    lastEnqueuedComputedLevel := subs.level
  }
}

// Track a dependency from a computed (subs tracks subs)
let trackDepFromComputed = (computedSubs: Signals__Core.subs, sourceSubs: Signals__Core.subs): unit => {
  let computedObserver: Signals__Core.observer = Obj.magic(computedSubs)

  if computedSubs.firstDep === None {
    let newLink: Signals__Core.link = Signals__Core.makeLink(sourceSubs, computedObserver)
    newLink.lastTrackedVersion = currentTrackingVersion.contents
    Signals__Core.linkToSubsDeps(computedSubs, newLink)
    Signals__Core.linkToSubs(sourceSubs, newLink)
    currentComputedDepCursor := Some(newLink)
  } else {
    let currentVersion = currentTrackingVersion.contents
    // Fast path: reuse run cursor or cursor.next to avoid scanning in common cases.
    let fastPathFound = ref(false)
    switch currentComputedDepCursor.contents {
    | Some(cursor) =>
      if cursor.subs === sourceSubs && cursor.observer === computedObserver {
        cursor.lastTrackedVersion = currentVersion
        fastPathFound.contents = true
      } else {
        switch cursor.nextDep {
        | Some(nextDep) =>
          if nextDep.subs === sourceSubs && nextDep.observer === computedObserver {
            nextDep.lastTrackedVersion = currentVersion
            currentComputedDepCursor := Some(nextDep)
            fastPathFound.contents = true
          }
        | None => ()
        }
      }
    | None => ()
    }

    if !fastPathFound.contents {
      switch sourceSubs.last {
      | Some(lastSubLink) =>
        if lastSubLink.lastTrackedVersion === currentVersion && lastSubLink.observer === computedObserver {
          lastSubLink.lastTrackedVersion = currentVersion
          currentComputedDepCursor := Some(lastSubLink)
          fastPathFound.contents = true
        }
      | None => ()
      }
    }

    if !fastPathFound.contents {
      // Fall back to full scan
      let found = ref(false)
      let foundLink: ref<option<Signals__Core.link>> = ref(None)
      let link = ref(computedSubs.firstDep)
      while link.contents !== None && !found.contents {
        switch link.contents {
        | Some(l) =>
          if l.subs === sourceSubs {
            l.lastTrackedVersion = currentVersion
            foundLink := Some(l)
            found := true
          } else {
            link := l.nextDep
          }
        | None => ()
        }
      }

      // Create new link only if not found
      if !found.contents {
        let newLink: Signals__Core.link = Signals__Core.makeLink(sourceSubs, computedObserver)
        newLink.lastTrackedVersion = currentVersion
        Signals__Core.linkToSubsDeps(computedSubs, newLink)
        Signals__Core.linkToSubs(sourceSubs, newLink)
        currentComputedDepCursor := Some(newLink)
      } else {
        currentComputedDepCursor := foundLink.contents
      }
    }
  }
}

// Track a dependency from an effect (observer tracks subs)
// Uses version-based duplicate detection within a run cycle
let trackDepFromEffect = (observer: Signals__Core.observer, sourceSubs: Signals__Core.subs): unit => {
  if observer.firstDep === None {
    let newLink: Signals__Core.link = Signals__Core.makeLink(sourceSubs, observer)
    newLink.lastTrackedVersion = currentTrackingVersion.contents
    Signals__Core.linkToDeps(observer, newLink)
    Signals__Core.linkToSubs(sourceSubs, newLink)
    currentObserverDepCursor := Some(newLink)
  } else {
    let currentVersion = currentTrackingVersion.contents
    // Fast path: reuse run cursor or cursor.next to avoid scanning in common cases.
    let fastPathFound = ref(false)
    switch currentObserverDepCursor.contents {
    | Some(cursor) =>
      if cursor.subs === sourceSubs && cursor.observer === observer {
        cursor.lastTrackedVersion = currentVersion
        fastPathFound.contents = true
      } else {
        switch cursor.nextDep {
        | Some(nextDep) =>
          if nextDep.subs === sourceSubs && nextDep.observer === observer {
            nextDep.lastTrackedVersion = currentVersion
            currentObserverDepCursor := Some(nextDep)
            fastPathFound.contents = true
          }
        | None => ()
        }
      }
    | None => ()
    }

    if !fastPathFound.contents {
      switch sourceSubs.last {
      | Some(lastSubLink) =>
        if lastSubLink.lastTrackedVersion === currentVersion && lastSubLink.observer === observer {
          lastSubLink.lastTrackedVersion = currentVersion
          currentObserverDepCursor := Some(lastSubLink)
          fastPathFound.contents = true
        }
      | None => ()
      }
    }

    if !fastPathFound.contents {
      let found = ref(false)
      let foundLink: ref<option<Signals__Core.link>> = ref(None)
      let link = ref(observer.firstDep)
      while link.contents !== None && !found.contents {
        switch link.contents {
        | Some(l) =>
          if l.subs === sourceSubs {
            l.lastTrackedVersion = currentVersion
            foundLink := Some(l)
            found := true
          } else {
            link := l.nextDep
          }
        | None => ()
        }
      }

      // Create new link only if not found
      if !found.contents {
        let newLink: Signals__Core.link = Signals__Core.makeLink(sourceSubs, observer)
        newLink.lastTrackedVersion = currentVersion
        Signals__Core.linkToDeps(observer, newLink)
        Signals__Core.linkToSubs(sourceSubs, newLink)
        currentObserverDepCursor := Some(newLink)
      } else {
        currentObserverDepCursor := foundLink.contents
      }
    }
  }
}

// Track dependency - routes to appropriate function based on current context
let trackDep = (subs: Signals__Core.subs): unit => {
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
let compareEffectsByLevel = (a: Signals__Core.observer, b: Signals__Core.observer): float => {
  Int.toFloat(a.level - b.level)
}

let compareSubsByLevel = (a: Signals__Core.subs, b: Signals__Core.subs): float => {
  Int.toFloat(a.level - b.level)
}

// Compute level for a computed (based on its dependencies)
let computeSubsLevel = (s: Signals__Core.subs): int => {
  let maxLevel = ref(0)
  let link = ref(s.firstDep)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      // Check if the source is a computed
      if Signals__Core.isComputed(l.subs) {
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
let computeLevel = (observer: Signals__Core.observer): int => {
  let maxLevel = ref(0)
  let link = ref(observer.firstDep)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      if Signals__Core.isComputed(l.subs) {
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

// Run one computed recompute cycle with link reuse.
let runComputedCycle = (subs: Signals__Core.subs, ~clearPending: bool): unit => {
  let previousTrackingVersion = currentTrackingVersion.contents
  let previousVersion = subs.version

  // Increment tracking version for this cycle
  Signals__Core.trackingVersion := Signals__Core.trackingVersion.contents + 1
  currentTrackingVersion.contents = Signals__Core.trackingVersion.contents

  // DON'T clear deps - we'll reuse existing links
  if clearPending {
    Signals__Core.clearSubsPending(subs)
  }

  let prev = currentComputedSubs.contents
  let prevCursor = currentComputedDepCursor.contents
  currentComputedSubs := Some(subs)
  currentComputedDepCursor := subs.firstDep

  try {
    switch subs.compute {
    | Some(compute) => compute()
    | None => ()
    }

    // After compute: unlink stale deps (version != current)
    let link = ref(subs.firstDep)
    while link.contents !== None {
      switch link.contents {
      | Some(l) =>
        let next = l.nextDep
        if l.lastTrackedVersion !== currentTrackingVersion.contents {
          // Stale - unlink from source's subscriber list and our dep list
          Signals__Core.unlinkFromSubs(l)
          Signals__Core.unlinkFromSubsDeps(subs, l)
        }
        link := next
      | None => ()
      }
    }

    Signals__Core.clearSubsDirty(subs)
    subs.lastGlobalVersion = Signals__Core.globalVersion.contents

    // Propagate only when computed output changed.
    if subs.first !== None && subs.version !== previousVersion {
      let subLink = ref(subs.first)
      while subLink.contents !== None {
        switch subLink.contents {
        | Some(l) =>
          let linkedSubs = (Obj.magic(l.observer): Signals__Core.subs)
          if Signals__Core.isComputed(linkedSubs) {
            // Mark downstream computed dirty (lazy propagation).
            Signals__Core.setSubsDirty(linkedSubs)
          } else {
            // Effects get queued for execution unless this effect is already running.
            switch currentObserver.contents {
            | Some(currentObserver) =>
              if currentObserver !== l.observer {
                addEffectToPending(l.observer)
              }
            | None => addEffectToPending(l.observer)
            }
          }
          subLink := l.nextSub
        | None => ()
        }
      }
    }

    currentComputedSubs := prev
    currentComputedDepCursor := prevCursor
    currentTrackingVersion.contents = previousTrackingVersion
  } catch {
  | exn =>
    currentComputedSubs := prev
    currentComputedDepCursor := prevCursor
    currentTrackingVersion.contents = previousTrackingVersion
    throw(exn)
  }
}

// Retrack a computed (recompute with link reuse)
let retrackComputed = (s: Signals__Core.subs): unit => {
  let oldLevel = s.level
  runComputedCycle(s, ~clearPending=true)

  if oldLevel == 0 {
    s.level = computeSubsLevel(s)
  }
}

// Retrack an effect (with link reuse)
let retrackEffect = (observer: Signals__Core.observer): unit => {
  let oldLevel = observer.level
  let previousTrackingVersion = currentTrackingVersion.contents

  // Increment tracking version for this cycle
  Signals__Core.trackingVersion := Signals__Core.trackingVersion.contents + 1
  currentTrackingVersion.contents = Signals__Core.trackingVersion.contents

  // DON'T clear deps - we'll reuse existing links
  Signals__Core.clearPending(observer)

  let prev = currentObserver.contents
  let prevCursor = currentObserverDepCursor.contents
  currentObserver := Some(observer)
  currentObserverDepCursor := observer.firstDep

  try {
    observer.run()

    // After run: unlink stale deps (version != current)
    let link = ref(observer.firstDep)
    while link.contents !== None {
      switch link.contents {
      | Some(l) =>
        let next = l.nextDep
        if l.lastTrackedVersion !== currentTrackingVersion.contents {
          // Stale - unlink from source's subscriber list and our dep list
          Signals__Core.unlinkFromSubs(l)
          Signals__Core.unlinkFromDeps(observer, l)
        }
        link := next
      | None => ()
      }
    }

    Signals__Core.clearDirty(observer)
    currentObserver := prev
    currentObserverDepCursor := prevCursor
    currentTrackingVersion.contents = previousTrackingVersion
  } catch {
  | exn =>
    currentObserver := prev
    currentObserverDepCursor := prevCursor
    currentTrackingVersion.contents = previousTrackingVersion
    throw(exn)
  }

  if oldLevel == 0 {
    observer.level = computeLevel(observer)
  }
}

// Flush pending observers
let flush = (): unit => {
  flushing := true

  try {
    while pendingEffects->Array.length > 0 || pendingComputedSubs->Array.length > 0 {
      // Process computeds first (they might trigger more effects)
      if pendingComputedSubs->Array.length > 0 {
        let computedsLength = pendingComputedSubs->Array.length
        if computedsLength > 1 && pendingComputedNeedsSort.contents {
          // Sort by level
          pendingComputedSubs->Array.sort(compareSubsByLevel)->ignore
          pendingComputedNeedsSort := false
        }
        let i = ref(0)
        while i.contents < computedsLength {
          switch pendingComputedSubs->Array.get(i.contents) {
          | Some(subs) => retrackComputed(subs)
          | None => ()
          }
          i := i.contents + 1
        }
        drainProcessedPrefix(pendingComputedSubs, computedsLength)
        if pendingComputedSubs->Array.length == 0 {
          pendingComputedNeedsSort := false
        }
      }

      // Then process effects
      if pendingEffects->Array.length > 0 {
        let effectsLength = pendingEffects->Array.length
        if effectsLength > 1 && pendingEffectsNeedsSort.contents {
          pendingEffects->Array.sort(compareEffectsByLevel)->ignore
          pendingEffectsNeedsSort := false
        }
        let i = ref(0)
        while i.contents < effectsLength {
          switch pendingEffects->Array.get(i.contents) {
          | Some(effect) => retrackEffect(effect)
          | None => ()
          }
          i := i.contents + 1
        }
        drainProcessedPrefix(pendingEffects, effectsLength)
        if pendingEffects->Array.length == 0 {
          pendingEffectsNeedsSort := false
        }
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
// Marks computeds dirty transitively.
// Direct effects are queued immediately.
// Effects reached through dirty computeds are deferred until parent computed recompute.
let notifySubs = (subs: Signals__Core.subs): unit => {
  // Fast path: no subscribers, nothing to notify.
  if subs.first === None {
    ()
  } else if !Signals__Core.isComputed(subs) && subs.computedSubscriberCount == 0 {
    // Fast path for plain signals with direct effect subscribers only.
    let link = ref(subs.first)
    while link.contents !== None {
      switch link.contents {
      | Some(l) =>
        addEffectToPending(l.observer)
        link := l.nextSub
      | None => ()
      }
    }
  } else {
    dirtyQueue->Array.push(subs)->ignore

    let i = ref(0)
    while i.contents < dirtyQueue->Array.length {
      let currentSubs = dirtyQueue->Array.get(i.contents)
      i := i.contents + 1
      switch currentSubs {
      | None => ()
      | Some(s) =>
        let link = ref(s.first)
        while link.contents !== None {
          switch link.contents {
          | Some(l) =>
            // The observer field might be a real observer (effect) or a subs (computed)
            let linkedSubs = (Obj.magic(l.observer): Signals__Core.subs)
            if Signals__Core.isComputed(linkedSubs) {
              // It's a computed - mark dirty and propagate transitively
              if !Signals__Core.isSubsDirty(linkedSubs) {
                Signals__Core.setSubsDirty(linkedSubs)
                dirtyQueue->Array.push(linkedSubs)->ignore
              }
            } else {
              // It's an effect.
              // If reached via a dirty computed, defer effect until computed recompute.
              // This lets computed equality short-circuit downstream effect runs.
              if Signals__Core.isComputed(s) {
                if s.deferEffectsUntilRecompute {
                  addComputedToPending(s)
                } else {
                  addEffectToPending(l.observer)
                }
              } else {
                addEffectToPending(l.observer)
              }
            }
            link := l.nextSub
          | None => ()
          }
        }
      }
    }
    clearArray(dirtyQueue)
  }

  if (pendingEffects->Array.length > 0 || pendingComputedSubs->Array.length > 0) && !flushing.contents {
    flush()
  }
}

// Ensure a computed signal is fresh before reading (with link reuse)
let ensureComputedFresh = (subs: Signals__Core.subs): unit => {
  if Signals__Core.isComputed(subs) {
    if Signals__Core.isSubsDirty(subs) {
      // Dirty without a newer global write means stale dirty flag only.
      if subs.lastGlobalVersion === Signals__Core.globalVersion.contents {
        Signals__Core.clearSubsDirty(subs)
      } else {
        let oldLevel = subs.level
        runComputedCycle(subs, ~clearPending=false)

        if oldLevel == 0 {
          subs.level = computeSubsLevel(subs)
        }
      }
    }
  }
}

// Schedule an effect for execution
let schedule = (observer: Signals__Core.observer): unit => {
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
  let prevComputedCursor = currentComputedDepCursor.contents
  let prevObserverCursor = currentObserverDepCursor.contents
  currentComputedSubs := None
  currentObserver := None
  currentComputedDepCursor := None
  currentObserverDepCursor := None
  try {
    let result = fn()
    currentComputedSubs := prevComputed
    currentObserver := prevObserver
    currentComputedDepCursor := prevComputedCursor
    currentObserverDepCursor := prevObserverCursor
    result
  } catch {
  | exn =>
    currentComputedSubs := prevComputed
    currentObserver := prevObserver
    currentComputedDepCursor := prevComputedCursor
    currentObserverDepCursor := prevObserverCursor
    throw(exn)
  }
}
