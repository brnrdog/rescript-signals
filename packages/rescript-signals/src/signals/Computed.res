let makeWithoutEquals = (
  compute: unit => 'a,
  ~name: option<string>=?,
): Signal.t<'a> => {
  let id = Id.make()
  let equalsFn: ('a, 'a) => bool = (_a, _b) => false

  // Create a mutable ref to hold the signal so the compute function can update it
  // Using Obj.magic to avoid Option wrapper overhead
  let signalRef: ref<Signal.t<'a>> = ref(Obj.magic())

  // Fast recompute path for default behavior (no custom equality checks)
  let recompute = () => {
    let currentSignal = signalRef.contents
    let newValue = compute()
    currentSignal.value = newValue
    currentSignal.subs.version = currentSignal.subs.version + 1
  }

  // Create combined subs (this IS the observer for the computed)
  let subs = Core.makeComputedSubs(recompute, ~deferEffectsUntilRecompute=false)

  // Initial computation under tracking to establish dependencies
  let prev = Scheduler.currentComputedSubs.contents
  Scheduler.currentComputedSubs := Some(subs)
  let initialValue = compute()
  Scheduler.currentComputedSubs := prev

  // Create the signal with the initial value
  let signal: Signal.t<'a> = {
    id,
    value: initialValue,
    equals: equalsFn,
    name,
    subs,
  }

  // Set the ref so recompute can access the signal
  signalRef := signal
  subs.lastGlobalVersion = Core.globalVersion.contents
  Core.clearSubsDirty(subs)

  signal
}

let makeWithEquals = (
  compute: unit => 'a,
  equalsFn: ('a, 'a) => bool,
  ~name: option<string>=?,
): Signal.t<'a> => {
  let id = Id.make()

  // Create a mutable ref to hold the signal so the compute function can update it
  // Using Obj.magic to avoid Option wrapper overhead
  let signalRef: ref<Signal.t<'a>> = ref(Obj.magic())

  // Recompute function - updates the signal's value and tracks if it changed
  let recompute = () => {
    let currentSignal = signalRef.contents
    let previousValue = currentSignal.value
    let newValue = compute()
    let shouldUpdate = try {
      !currentSignal.equals(previousValue, newValue)
    } catch {
    | _ => true
    }
    if shouldUpdate {
      currentSignal.value = newValue
      currentSignal.subs.version = currentSignal.subs.version + 1
    }
  }

  // Create combined subs (this IS the observer for the computed)
  let subs = Core.makeComputedSubs(recompute, ~deferEffectsUntilRecompute=true)

  // Initial computation under tracking to establish dependencies
  let prev = Scheduler.currentComputedSubs.contents
  Scheduler.currentComputedSubs := Some(subs)
  let initialValue = compute()
  Scheduler.currentComputedSubs := prev

  // Create the signal with the initial value
  let signal: Signal.t<'a> = {
    id,
    value: initialValue,
    equals: equalsFn,
    name,
    subs,
  }

  // Set the ref so recompute can access the signal
  signalRef := signal
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
  | Some(eq) => makeWithEquals(compute, eq, ~name?)
  | None => makeWithoutEquals(compute, ~name?)
  }

let dispose = (signal: Signal.t<'a>): unit => {
  Core.clearSubsDeps(signal.subs)
}
