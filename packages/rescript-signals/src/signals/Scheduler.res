// Current execution context for computeds (subs IS the observer)
let currentComputedSubs: ref<option<Core.subs>> = ref(None)

// Current execution context for effects
let currentObserver: ref<option<Core.observer>> = ref(None)

// Current dependency tracking version (shared across nested compute/effect runs)
let currentTrackingVersion: ref<int> = ref(0)

// Per-run dependency cursors (separate from true tail pointers).
let currentComputedDepCursor: ref<option<Core.link>> = ref(None)
let currentObserverDepCursor: ref<option<Core.link>> = ref(None)

// Pending effects to execute
let pendingEffects: array<Core.observer> = []
// Pending computeds to recompute (subs that are dirty)
let pendingComputedSubs: array<Core.subs> = []
let flushing: ref<bool> = ref(false)
let pendingEffectsNeedsSort: ref<bool> = ref(false)
let pendingComputedNeedsSort: ref<bool> = ref(false)
let lastEnqueuedEffectLevel: ref<int> = ref(0)
let lastEnqueuedComputedLevel: ref<int> = ref(0)

// Queue for iterative dirty marking
let dirtyQueue: array<Core.subs> = []

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
let addEffectToPending = (observer: Core.observer): unit => {
  if !Core.isPending(observer) {
    Core.setPending(observer)
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
let addComputedToPending = (subs: Core.subs): unit => {
  if !Core.isSubsPending(subs) {
    Core.setSubsPending(subs)
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
let trackDepFromComputed = (computedSubs: Core.subs, sourceSubs: Core.subs): unit => {
  let computedObserver: Core.observer = Obj.magic(computedSubs)
  // Dependency reuse below stays exactly as cheap as it was before detaching
  // existed: lastSourceVersion is not maintained here at all. Only a detached
  // computed reads it, and ensureComputedFresh stamps the whole chain right
  // after a detached recompute, which is O(deps) on a path that already ran the
  // compute function.

  if computedSubs.firstDep === None {
    let newLink: Core.link = Core.makeLink(sourceSubs, computedObserver)
    newLink.lastTrackedVersion = currentTrackingVersion.contents
    newLink.lastSourceVersion = sourceSubs.version
    Core.linkToSubsDeps(computedSubs, newLink)
    // A detached computed records what it depends on but does not attach to it.
    if !Core.isDetached(computedSubs) {
      Core.linkToSubs(sourceSubs, newLink)
    }
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
      let foundLink: ref<option<Core.link>> = ref(None)
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
        let newLink: Core.link = Core.makeLink(sourceSubs, computedObserver)
        newLink.lastTrackedVersion = currentVersion
        newLink.lastSourceVersion = sourceSubs.version
        Core.linkToSubsDeps(computedSubs, newLink)
        if !Core.isDetached(computedSubs) {
          Core.linkToSubs(sourceSubs, newLink)
        }
        currentComputedDepCursor := Some(newLink)
      } else {
        currentComputedDepCursor := foundLink.contents
      }
    }
  }
}

// Track a dependency from an effect (observer tracks subs)
// Uses version-based duplicate detection within a run cycle
let trackDepFromEffect = (observer: Core.observer, sourceSubs: Core.subs): unit => {
  if observer.firstDep === None {
    let newLink: Core.link = Core.makeLink(sourceSubs, observer)
    newLink.lastTrackedVersion = currentTrackingVersion.contents
    Core.linkToDeps(observer, newLink)
    Core.linkToSubs(sourceSubs, newLink)
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
      let foundLink: ref<option<Core.link>> = ref(None)
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
        let newLink: Core.link = Core.makeLink(sourceSubs, observer)
        newLink.lastTrackedVersion = currentVersion
        Core.linkToDeps(observer, newLink)
        Core.linkToSubs(sourceSubs, newLink)
        currentObserverDepCursor := Some(newLink)
      } else {
        currentObserverDepCursor := foundLink.contents
      }
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
let computeLevel = (observer: Core.observer): int => {
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

// Run one computed recompute cycle with link reuse.
let runComputedCycle = (subs: Core.subs, ~clearPending: bool): unit => {
  let previousTrackingVersion = currentTrackingVersion.contents
  let previousVersion = subs.version

  // Increment tracking version for this cycle
  Core.trackingVersion := Core.trackingVersion.contents + 1
  currentTrackingVersion.contents = Core.trackingVersion.contents

  // DON'T clear deps - we'll reuse existing links
  if clearPending {
    Core.clearSubsPending(subs)
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
          Core.unlinkFromSubs(l)
          Core.unlinkFromSubsDeps(subs, l)
        }
        link := next
      | None => ()
      }
    }

    Core.clearSubsDirty(subs)
    subs.lastGlobalVersion = Core.globalVersion.contents

    // Propagate only when computed output changed.
    if subs.first !== None && subs.version !== previousVersion {
      let subLink = ref(subs.first)
      while subLink.contents !== None {
        switch subLink.contents {
        | Some(l) =>
          let linkedSubs = (Obj.magic(l.observer): Core.subs)
          if Core.isComputed(linkedSubs) {
            // Mark downstream computed dirty (lazy propagation).
            Core.setSubsDirty(linkedSubs)
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
let retrackComputed = (s: Core.subs): unit => {
  let oldLevel = s.level
  runComputedCycle(s, ~clearPending=true)

  if oldLevel == 0 {
    s.level = computeSubsLevel(s)
  }
}

// Retrack an effect (with link reuse)
let retrackEffect = (observer: Core.observer): unit => {
  let oldLevel = observer.level
  let previousTrackingVersion = currentTrackingVersion.contents

  // Increment tracking version for this cycle
  Core.trackingVersion := Core.trackingVersion.contents + 1
  currentTrackingVersion.contents = Core.trackingVersion.contents

  // DON'T clear deps - we'll reuse existing links
  Core.clearPending(observer)

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
          Core.unlinkFromSubs(l)
          Core.unlinkFromDeps(observer, l)
        }
        link := next
      | None => ()
      }
    }

    Core.clearDirty(observer)
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
let notifySubs = (subs: Core.subs): unit => {
  // Fast path: no subscribers, nothing to notify.
  if subs.first === None {
    ()
  } else if !Core.isComputed(subs) && subs.computedSubscriberCount == 0 {
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
            let linkedSubs = (Obj.magic(l.observer): Core.subs)
            if Core.isComputed(linkedSubs) {
              // It's a computed - mark dirty and propagate transitively
              if !Core.isSubsDirty(linkedSubs) {
                Core.setSubsDirty(linkedSubs)
                dirtyQueue->Array.push(linkedSubs)->ignore
              }
            } else {
              // It's an effect.
              // If reached via a dirty computed, defer effect until computed recompute.
              // This lets computed equality short-circuit downstream effect runs.
              if Core.isComputed(s) {
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

let recomputeAndLevel = (subs: Core.subs): unit => {
  let oldLevel = subs.level
  runComputedCycle(subs, ~clearPending=false)

  if oldLevel == 0 {
    subs.level = computeSubsLevel(subs)
  }
}

// Record where every source stands right now. A detached computed receives no
// notifications, so these stamps are the only thing that later tells it whether
// anything actually moved.
let stampSources = (s: Core.subs): unit => {
  let link = ref(s.firstDep)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      l.lastSourceVersion = l.subs.version
      link := l.nextDep
    | None => ()
    }
  }
}

// Ensure a computed signal is fresh before reading (with link reuse).
// Plain signals and settled computeds carry no flags in the mask, so the common
// read costs a single test - the same as before computeds could detach.
let rec ensureComputedFresh = (subs: Core.subs): unit => {
  if Int.bitwiseAnd(subs.flags, Core.flag_needs_settle) !== 0 && Core.isComputed(subs) {
    let detached = Core.isDetached(subs)
    if Core.isSubsDirty(subs) {
      // An attached computed hears about every write, so a set dirty flag is
      // authoritative. A detached one is told this way too, when it was marked
      // before detaching or has never been computed.
      if !detached && subs.lastGlobalVersion === Core.globalVersion.contents {
        // Dirty without a newer global write means stale dirty flag only.
        Core.clearSubsDirty(subs)
      } else {
        recomputeAndLevel(subs)
        if detached {
          stampSources(subs)
        }
      }
    } else if subs.lastGlobalVersion !== Core.globalVersion.contents {
      // Detached (the mask left nothing else it could be), so being un-dirty
      // proves nothing. No write anywhere since the last compute is the cheap
      // way out; otherwise compare each source against its recorded version.
      if sourcesChanged(subs) {
        recomputeAndLevel(subs)
        stampSources(subs)
      } else {
        // Verified fresh - re-stamp so the next read takes the cheap path.
        subs.lastGlobalVersion = Core.globalVersion.contents
      }
    }
  }
}

// Whether any source of a cold computed has moved since it was last read.
// A source that is itself a cold computed has to be settled first.
and sourcesChanged = (s: Core.subs): bool => {
  let changed = ref(false)
  let link = ref(s.firstDep)
  while link.contents !== None && !changed.contents {
    switch link.contents {
    | Some(l) =>
      ensureComputedFresh(l.subs)
      if l.subs.version !== l.lastSourceVersion {
        changed := true
      } else {
        link := l.nextDep
      }
    | None => ()
    }
  }
  changed.contents
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
