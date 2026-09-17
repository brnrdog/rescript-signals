type t<'a> = {
  id: int,
  /* Where the value is actually stored. Every read and write *inside* this
     package goes here; `value` below is an accessor installed over it, and
     keeping the two apart is what stops the accessor recursing into itself. */
  mutable raw: 'a,
  /* A getter delegating to `get`, so `signal.value` subscribes the current
     observer exactly as `Signal.get(signal)` does. It is not mutable, so
     `signal.value = x` does not compile and no write can skip the scheduler. */
  value: 'a,
  equals: ('a, 'a) => bool,
  name: option<string>,
  // Subscriber linked list (replaces signalObservers Map lookup)
  subs: Core.subs,
}

// Optimized get - inlined hot path checks
let get = (signal: t<'a>): 'a => {
  // Ensure computed is fresh
  Scheduler.ensureComputedFresh(signal.subs)

  // Track dependency if we're inside a computed or effect
  Scheduler.trackDep(signal.subs)

  signal.raw
}

let peek = (signal: t<'a>): 'a => {
  Scheduler.ensureComputedFresh(signal.subs)
  signal.raw
}

/* Signals are built by a constructor whose prototype carries the `value`
   getter, rather than by a record literal plus `Object.defineProperty` on each
   instance. The distinction is not cosmetic: an own accessor moves the object
   into dictionary mode, which costs every *other* field access on the signal —
   `subs` and `raw` on the hot `get` path included. Measured on this package's
   benchmark, that was 3x slower reads and 18x slower creation. On the
   prototype every instance keeps one hidden class and the getter is free.

   `get` is passed in rather than named inside the raw body: a %raw that refers
   to a surrounding binding breaks as soon as the compiler renames or inlines
   it. The constructor is built once, on first use, and closed over. */
let makeRecord: (
  int,
  'a,
  ('a, 'a) => bool,
  option<string>,
  Core.subs,
  t<'a> => 'a,
) => t<'a> = %raw(`function alloc(id, raw, equals, name, subs, get) {
  var Ctor = alloc.ctor
  if (Ctor === undefined) {
    Ctor = function (id, raw, equals, name, subs) {
      this.id = id
      this.raw = raw
      this.equals = equals
      this.name = name
      this.subs = subs
    }
    Object.defineProperty(Ctor.prototype, "value", {
      get: function () { return get(this) },
      configurable: true,
    })
    alloc.ctor = Ctor
  }
  return new Ctor(id, raw, equals, name, subs)
}`)

let defaultEquals = (a: 'a, b: 'a): bool => a === b
let neverEquals: ('a, 'a) => bool = (_a, _b) => false

let make = (initialValue: 'a, ~name: option<string>=?, ~equals: option<('a, 'a) => bool>=?): t<
  'a,
> => {
  let id = Id.make()
  let equalsFn = switch equals {
  | Some(eq) => eq
  | None => defaultEquals
  }

  makeRecord(id, initialValue, equalsFn, name, Core.makeSubs(), get)
}

// Optimized signal creation for computed backing signals (no equals check needed)
let makeForComputed = (initialValue: 'a, ~name: option<string>=?): t<'a> => {
  let id = Id.make()
  // Computeds always check freshness via dirty flag, so no equals check
  makeRecord(id, initialValue, neverEquals, name, Core.makeSubs(), get)
}

let set = (signal: t<'a>, newValue: 'a): unit => {
  let shouldUpdate = try {
    !signal.equals(signal.raw, newValue)
  } catch {
  | _ => true
  }

  if shouldUpdate {
    signal.raw = newValue
    signal.subs.version = signal.subs.version + 1
    Core.globalVersion := Core.globalVersion.contents + 1
    Scheduler.notifySubs(signal.subs)
  }
}

let update = (signal: t<'a>, fn: 'a => 'a): unit => signal->set(fn(signal.raw))

let batch = Scheduler.batch

let untrack = Scheduler.untrack
