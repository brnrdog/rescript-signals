// Async values in the graph.
//
// An async value is a computed whose function returns a promise. The function
// runs like any computed's — at creation and again when what it read changes —
// so the signals it reads before its first `await` are its dependencies. Each
// run starts a fetch; when the latest one settles, the value (or the failure)
// is written straight into the computed and its readers are told, without
// running the function again.
//
// Until the first fetch settles there is no value, and a read throws
// `NotReady`. That is an ordinary failure to the rest of the graph: a
// computed that reads it holds it and throws it in turn, and recomputes when
// the value arrives. An effect that ends in `NotReady` is not failing, only
// waiting: it runs again when what it read changes. While a later fetch is in
// flight, a read returns the previous value, and `isPending` reports it.

exception NotReady = Core.NotReady

type tracker = {
  // Bumped by every fetch: only the latest may settle.
  mutable version: int,
  // Whether there is a value to return while fetching again. A failure
  // leaves none.
  mutable hasValue: bool,
}

// Write what a fetch settled with, and tell the readers. Nothing is
// recomputed: the dependencies have not changed, only the value.
let settle = (subs: Core.subs, tracker: tracker, outcome: result<Obj.t, Obj.t>): unit => {
  let cell: Core.cell<Obj.t> = Obj.magic(subs.cell)
  switch outcome {
  | Ok(value) => {
      tracker.hasValue = true
      Core.clearFlag(subs, Core.flag_errored)
      subs.error = Core.noCell
      cell.value = value
    }
  | Error(error) => {
      tracker.hasValue = false
      Core.setFlag(subs, Core.flag_errored)
      subs.error = error
    }
  }
  Core.clearFlag(subs, Core.flag_fetching)
  subs.version = subs.version + 1
  Core.globalVersion := Core.globalVersion.contents + 1
  if Debug.enabled.contents {
    Debug.written(Obj.magic(subs), true)
  }
  Scheduler.notifySubs(subs)
}

let make = (fetch: unit => promise<'a>, ~name: option<string>=?): Signal.t<'a> => {
  let tracker = {version: 0, hasValue: false}
  Computed.make(() => {
    // Running as the computed being created or recomputed.
    let subs = switch Scheduler.currentComputedSubs.contents {
    | Some(subs) => subs
    | None => panic("Async.make: run outside its own computation")
    }
    tracker.version = tracker.version + 1
    let version = tracker.version
    let promise = switch fetch() {
    | promise => promise
    | exception exn => {
        tracker.hasValue = false
        Core.clearFlag(subs, Core.flag_fetching)
        throw(exn)
      }
    }
    Core.setFlag(subs, Core.flag_fetching)
    // The outcome is read first and settled after, so a failure in what
    // settling sets off is not mistaken for the fetch failing.
    promise
    ->Promise.thenResolve(value => Ok(Obj.magic(value)))
    ->Promise.catch(exn => Promise.resolve(Error(Core.thrownValue(exn))))
    ->Promise.thenResolve(outcome =>
      if version == tracker.version {
        settle(subs, tracker, outcome)
      }
    )
    ->ignore
    if tracker.hasValue {
      let cell: Core.cell<'a> = Obj.magic(subs.cell)
      cell.value
    } else {
      throw(NotReady)
    }
  }, ~name?)
}

// Whether `fn` read anything that is not settled: an async value with a
// fetch in flight, or a computed that read one. `fn` ending in `NotReady`
// counts too. Its reads are tracked as usual, so a computed or effect that
// asks is told again when the answer changes. Any other failure of `fn` is
// thrown.
let isPending = (fn: unit => 'a): bool => {
  let before = Scheduler.loadingReads.contents
  switch fn() {
  | _ => Scheduler.loadingReads.contents > before
  | exception NotReady => true
  }
}
