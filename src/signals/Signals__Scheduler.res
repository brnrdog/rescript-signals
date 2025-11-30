module Observer = Signals__Observer

// Observer registry: observer ID → Observer.t (mutable)
let observers: Map.t<int, Observer.t> = Map.make()

// Bidirectional index: signal ID → set of observer IDs (mutable)
let signalObservers: Map.t<int, Set.t<int>> = Map.make()

// Computed tracking: signal ID → observer ID (mutable)
let computedToObserver: Map.t<int, int> = Map.make()

// Current execution context (which observer is running)
let currentObserverId: ref<option<int>> = ref(None)

// Scheduler state
let pending: Set.t<int> = Set.make()
let flushing: ref<bool> = ref(false)
let retracking: ref<bool> = ref(false)

// ============================================================================
// PHASE 2: DEPENDENCY TRACKING
// ============================================================================

// Ensure signal has an entry in signalObservers map
let ensureSignalBucket = (signalId: int): unit => {
  switch signalObservers->Map.get(signalId) {
  | Some(_) => ()
  | None => signalObservers->Map.set(signalId, Set.make())
  }
}

// Add dependency: observer depends on signal
let addDep = (observerId: int, signalId: int): unit => {
  ensureSignalBucket(signalId)

  switch (currentObserverId.contents, observers->Map.get(observerId)) {
  | (Some(currentId), Some(observer)) if currentId == observerId =>
    // Only track if this observer is currently executing
    if !(observer.deps->Set.has(signalId)) {
      // Add signal to observer's dependency set
      observer.deps->Set.add(signalId)

      // Add observer to signal's subscriber set
      switch signalObservers->Map.get(signalId) {
      | Some(obsSet) => obsSet->Set.add(observerId)
      | None => () // Should not happen due to ensureSignalBucket
      }
    }
  | _ => ()
  }
}

// Forward declaration for mutual recursion
let rec autoDisposeComputed = (signalId: int): unit => {
  switch computedToObserver->Map.get(signalId) {
  | Some(observerId) => {
      // Remove from tracking map
      computedToObserver->Map.delete(signalId)->ignore

      // Dispose the observer
      switch observers->Map.get(observerId) {
      | Some(obs) => {
          clearDeps(obs)
          observers->Map.delete(observerId)->ignore
        }
      | None => ()
      }
    }
  | None => () // Not a computed signal
  }
}

// Clear all dependencies for an observer
and clearDeps = (observer: Observer.t): unit => {
  observer.deps->Set.forEach(signalId => {
    switch signalObservers->Map.get(signalId) {
    | Some(obsSet) => {
        obsSet->Set.delete(observer.id)->ignore

        // Auto-disposal: check if computed has no more subscribers
        if obsSet->Set.size == 0 && !retracking.contents {
          autoDisposeComputed(signalId)
        }
      }
    | None => ()
    }
  })

  // Clear observer's dependency set
  Set.clear(observer.deps)
}

// Compute topological level for execution ordering
let computeLevel = (observer: Observer.t): int => {
  switch observer.kind {
  | #Effect => {
      // Effects run after all computeds
      let maxDepLevel = ref(0)

      observer.deps->Set.forEach(signalId => {
        switch signalObservers->Map.get(signalId) {
        | Some(obsSet) =>
          obsSet->Set.forEach(depObsId => {
            switch observers->Map.get(depObsId) {
            | Some(depObs) if depObs.level > maxDepLevel.contents => maxDepLevel := depObs.level
            | _ => ()
            }
          })
        | None => ()
        }
      })

      maxDepLevel.contents + 1000 // Large offset to ensure effects run last
    }

  | #Computed(_) => {
      // Computeds run based on dependency depth
      let maxDepLevel = ref(0)

      observer.deps->Set.forEach(signalId => {
        switch signalObservers->Map.get(signalId) {
        | Some(obsSet) =>
          obsSet->Set.forEach(depObsId => {
            if depObsId != observer.id {
              // Avoid self-reference
              switch observers->Map.get(depObsId) {
              | Some(depObs) =>
                switch depObs.kind {
                | #Computed(_) if depObs.level > maxDepLevel.contents => maxDepLevel := depObs.level
                | #Effect => () // Ignore effects in computed level calculation
                | _ => ()
                }
              | None => ()
              }
            }
          })
        | None => ()
        }
      })

      maxDepLevel.contents + 1
    }
  }
}

// ============================================================================
// PHASE 3: SCHEDULER EXECUTION
// ============================================================================

// Iterative flush - execute pending observers with topological ordering
let flush = (): unit => {
  // Iterative loop to prevent stack overflow
  while pending->Set.size > 0 {
    // Convert to array and sort by level (lower first)
    let arr = pending->Set.values->Core__Iterator.toArray
    Set.clear(pending)
    arr
    ->Array.sort((a, b) => {
      switch (observers->Map.get(a), observers->Map.get(b)) {
      | (Some(obsA), Some(obsB)) => Int.toFloat(obsA.level - obsB.level)
      | (Some(_), None) => -1.0
      | (None, Some(_)) => 1.0
      | (None, None) => 0.0
      }
    })
    ->ignore

    // Execute observers in topological order
    arr->Array.forEach(observerId => {
      switch observers->Map.get(observerId) {
      | Some(observer) => {
          // Set retracking flag to prevent auto-disposal during re-track
          retracking := true

          // Clear old dependencies
          clearDeps(observer)

          // Set current context
          let prev = currentObserverId.contents
          currentObserverId := Some(observerId)

          // Execute observer with exception handling
          try {
            observer.run()
            retracking := false
          } catch {
          | exn => {
              currentObserverId := prev
              retracking := false
              throw(exn)
            }
          }

          currentObserverId := prev

          // Recompute level after re-tracking
          observer.level = computeLevel(observer)
        }
      | None => ()
      }
    })
  }
}

// Schedule an observer for execution
let schedule = (observerId: int): unit => {
  pending->Set.add(observerId)

  if !flushing.contents {
    flushing := true
    flush()
    flushing := false
  }
}

// Notify all observers that depend on a signal
let notify = (signalId: int): unit => {
  ensureSignalBucket(signalId)

  switch signalObservers->Map.get(signalId) {
  | Some(obsSet) => {
      // Schedule all dependent observers
      obsSet->Set.forEach(observerId => {
        pending->Set.add(observerId)
      })

      // Flush if not already flushing
      if !flushing.contents {
        flushing := true
        flush()
        flushing := false
      }
    }
  | None => ()
  }
}

// ============================================================================
// PHASE 7: UTILITIES
// ============================================================================

// Run function without tracking dependencies
let untrack = (fn: unit => 'a): 'a => {
  let prev = currentObserverId.contents
  currentObserverId := None

  try {
    let result = fn()
    currentObserverId := prev
    result
  } catch {
  | exn => {
      currentObserverId := prev
      throw(exn)
    }
  }
}
