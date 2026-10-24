// Debug hooks for devtools.
//
// Nothing here runs unless a hook is installed. Every instrumentation point in
// the library is guarded by a single read of `enabled`, so the uninstalled cost
// is one load and one branch, and nothing below allocates until `install`.
//
// What a hook sees is a stream of events naming nodes by id. Signals and
// computeds are identified by their subs record and effects by their observer,
// mapped to ids in a WeakMap that only exists while installed. A node created
// before `install` has no id and is invisible: install from the entry module,
// before anything reactive is created.

type nodeKind = [#Signal | #Computed | #Effect]

@tag("type")
type event =
  | Created({id: int, kind: nodeKind, name: option<string>, stack: option<string>})
  // A new dependency edge: `target` read `source` for the first time.
  | Linked({source: int, target: int})
  // Re-tracking found `target` no longer reads `source`.
  | Unlinked({source: int, target: int})
  // A `Signal.set`. `changed` is false when `equals` held and nothing was notified.
  | Written({id: int, changed: bool})
  // A computed recompute or an effect body.
  | RunStart({id: int})
  // `changed` is whether a computed's value moved (always true for an effect).
  | RunEnd({id: int, changed: bool, threw: bool})
  // An effect disposed, or a computed released with `Computed.dispose`.
  | Disposed({id: int})
  // A node the garbage collector reclaimed (where FinalizationRegistry exists).
  | Collected({id: int})
  // The outermost `batch` began or ended.
  | BatchStart
  | BatchEnd

type hook = {
  emit: event => unit,
  // Capture `new Error().stack` for every created node, so a node without a
  // `~name` can still be traced to the code that made it. Costly; off by default.
  captureStacks: bool,
}

type node = {
  id: int,
  kind: nodeKind,
  name: option<string>,
  level: int,
  // The current value of a signal or computed; `None` for an effect.
  value: option<Obj.t>,
  // Ids of the nodes this one reads.
  sources: array<int>,
  // Ids of the nodes that read this one.
  observers: array<int>,
  dirty: bool,
  disposed: bool,
}

// --- State, all of it inert until `install` ---------------------------------

let enabled: ref<bool> = ref(false)
let current: ref<option<hook>> = ref(None)

type weakMap
type weakRef
@new external makeWeakMap: unit => weakMap = "WeakMap"
@send external weakGet: (weakMap, Obj.t) => Nullable.t<int> = "get"
@send external weakSet: (weakMap, Obj.t, int) => unit = "set"

let makeWeakRef: Obj.t => weakRef = %raw(`function (target) {
  return typeof WeakRef === "function" ? new WeakRef(target) : { deref: function () { return target } }
}`)
@send external deref: weakRef => Nullable.t<Obj.t> = "deref"

type registry
let makeRegistry: (int => unit) => Nullable.t<registry> = %raw(`function (onCollect) {
  return typeof FinalizationRegistry === "function" ? new FinalizationRegistry(onCollect) : null
}`)
@send external registerFinalizer: (registry, Obj.t, int) => unit = "register"

// What a node's id leads back to: the record that holds it, held weakly so
// devtools never keep a node alive.
type entry = {
  kind: nodeKind,
  name: option<string>,
  // The subs record for a signal or computed, the observer for an effect.
  target: weakRef,
  // The signal record for a plain signal (whose subs does not point back to it).
  cell: option<weakRef>,
}

let ids: ref<weakMap> = ref(makeWeakMap())
let entries: Map.t<int, entry> = Map.make()
let finalizers: ref<Nullable.t<registry>> = ref(Nullable.null)

let captureStack: unit => string = %raw(`function () { return new Error().stack || "" }`)

let emit = (event: event): unit =>
  switch current.contents {
  | Some(hook) => hook.emit(event)
  | None => ()
  }

let idOf = (node: Obj.t): option<int> => ids.contents->weakGet(node)->Nullable.toOption

// --- Instrumentation, called by the library only when `enabled` -------------

let created = (~target: Obj.t, ~cell: option<Obj.t>=?, ~id: int, ~kind: nodeKind, ~name) => {
  ids.contents->weakSet(target, id)
  entries->Map.set(id, {kind, name, target: makeWeakRef(target), cell: cell->Option.map(makeWeakRef)})
  switch finalizers.contents->Nullable.toOption {
  | Some(registry) => registry->registerFinalizer(target, id)
  | None => ()
  }
  let stack = switch current.contents {
  | Some({captureStacks: true}) => Some(captureStack())
  | _ => None
  }
  emit(Created({id, kind, name, stack}))
}

let linked = (source: Obj.t, target: Obj.t) =>
  switch (idOf(source), idOf(target)) {
  | (Some(source), Some(target)) => emit(Linked({source, target}))
  | _ => ()
  }

let unlinked = (source: Obj.t, target: Obj.t) =>
  switch (idOf(source), idOf(target)) {
  | (Some(source), Some(target)) => emit(Unlinked({source, target}))
  | _ => ()
  }

let written = (subs: Obj.t, changed: bool) =>
  switch idOf(subs) {
  | Some(id) => emit(Written({id, changed}))
  | None => ()
  }

let runStart = (node: Obj.t) =>
  switch idOf(node) {
  | Some(id) => emit(RunStart({id: id}))
  | None => ()
  }

let runEnd = (node: Obj.t, ~changed: bool, ~threw: bool) =>
  switch idOf(node) {
  | Some(id) => emit(RunEnd({id, changed, threw}))
  | None => ()
  }

let disposed = (node: Obj.t) =>
  switch idOf(node) {
  | Some(id) => emit(Disposed({id: id}))
  | None => ()
  }

let batchDepth = ref(0)

let batchStart = () => {
  batchDepth := batchDepth.contents + 1
  if batchDepth.contents == 1 {
    emit(BatchStart)
  }
}

let batchEnd = () => {
  batchDepth := batchDepth.contents - 1
  if batchDepth.contents == 0 {
    emit(BatchEnd)
  }
}

// --- Installing --------------------------------------------------------------

let install = (hook: hook): unit => {
  current := Some(hook)
  if !enabled.contents {
    ids := makeWeakMap()
    entries->Map.clear
    batchDepth := 0
    finalizers := makeRegistry(id => {
      if entries->Map.has(id) {
        entries->Map.delete(id)->ignore
        emit(Collected({id: id}))
      }
    })
  }
  enabled := true
}

let uninstall = (): unit => {
  enabled := false
  current := None
  ids := makeWeakMap()
  entries->Map.clear
  finalizers := Nullable.null
}

// --- Reading the graph ---------------------------------------------------------

// Ids of the nodes that are still reachable, oldest first.
let nodes = (): array<int> => {
  let live = []
  entries->Map.forEachWithKey((entry, id) =>
    switch entry.target->deref->Nullable.toOption {
    | Some(_) => live->Array.push(id)->ignore
    | None => ()
    }
  )
  live
}

let collectDeps = (first: option<Core.link>): array<int> => {
  let out = []
  let link = ref(first)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      switch idOf(Obj.magic(l.subs)) {
      | Some(id) => out->Array.push(id)->ignore
      | None => ()
      }
      link := l.nextDep
    | None => ()
    }
  }
  out
}

let collectSubs = (first: option<Core.link>): array<int> => {
  let out = []
  let link = ref(first)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      switch idOf(Obj.magic(l.observer)) {
      | Some(id) => out->Array.push(id)->ignore
      | None => ()
      }
      link := l.nextSub
    | None => ()
    }
  }
  out
}

let inspect = (id: int): option<node> =>
  switch entries->Map.get(id) {
  | None => None
  | Some(entry) =>
    switch entry.target->deref->Nullable.toOption {
    | None => None
    | Some(target) =>
      switch entry.kind {
      | #Effect =>
        let observer: Core.observer = Obj.magic(target)
        Some({
          id,
          kind: #Effect,
          name: entry.name,
          level: observer.level,
          value: None,
          sources: collectDeps(observer.firstDep),
          observers: [],
          dirty: Core.isDirty(observer) || Core.isPending(observer),
          disposed: Core.isDisposed(observer),
        })
      | kind =>
        let subs: Core.subs = Obj.magic(target)
        let cell: Nullable.t<Core.cell<Obj.t>> = switch entry.cell {
        | Some(cell) => Obj.magic(cell->deref)
        | None => Obj.magic(subs.cell)
        }
        Some({
          id,
          kind,
          name: entry.name,
          level: subs.level,
          value: cell->Nullable.toOption->Option.map(cell => cell.value),
          sources: collectDeps(subs.firstDep),
          observers: collectSubs(subs.first),
          dirty: Core.isSubsDirty(subs),
          disposed: false,
        })
      }
    }
  }

// --- Discovery from outside --------------------------------------------------

// Each loaded copy of the library announces itself on a global array, so a
// devtool can install into every copy in the page (an app and a library built
// against separate copies, say) without importing this module itself.
type api = {
  version: int,
  install: hook => unit,
  uninstall: unit => unit,
  nodes: unit => array<int>,
  inspect: int => option<node>,
  /* The id of a signal or computed, given its record: how a tool that holds
     a `Signal.t` finds it in the graph. */
  idOfSignal: Obj.t => option<int>,
}

let register: api => unit = %raw(`function (api) {
  try {
    var key = Symbol.for("rescript-signals.debug")
    var copies = globalThis[key] || (globalThis[key] = [])
    copies.push(api)
  } catch (_) {}
}`)

// The id of a signal or computed (`Core.cell` is `Signal.t`).
let idOfSignal = (signal: Core.cell<'a>): option<int> => idOf(Obj.magic(signal.subs))

register({
  version: 1,
  install,
  uninstall,
  nodes,
  inspect,
  // Untyped across the registry: a caller may hand over anything.
  idOfSignal: signal => {
    let cell: Nullable.t<Core.cell<Obj.t>> = Obj.magic(signal)
    switch cell->Nullable.toOption {
    | Some(cell) => idOfSignal(cell)
    | None => None
    }
  },
})
