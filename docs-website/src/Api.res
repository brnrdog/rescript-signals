/* The API reference as data.
 *
 * The section body and the table of contents are two renderings of this one
 * list, so they cannot drift apart.
 *
 * Every signature here was read off the installed source in
 * node_modules/rescript-signals, not carried over from the previous version of
 * this site — which documented `Computed.get` and `Computed.peek`, neither of
 * which exists. */

type entry = {
  id: string,
  label: string,
  signature: string,
  summary: string,
  code: string,
  notes: array<string>,
}

type group = {
  id: string,
  name: string,
  lead: string,
  entries: array<entry>,
  closing: array<(string, string)>,
}

let signal = {
  id: "signal",
  name: "Signal",
  lead: "A signal holds a value. Reading one inside a computed or an effect records a dependency, so a write re-runs exactly the things that read it — and nothing else.",
  entries: [
    {
      id: "signal-make",
      label: "Signal.make",
      signature: "Signal.make(value, ~name=?, ~equals=?): Signal.t<'a>",
      summary: "Creates a signal with an initial value.",
      code: `let count = Signal.make(0)
let artist = Signal.make("Gal Costa")

// ~name labels the signal in debugging output
let total = Signal.make(~name="total", 0)

// ~equals decides what counts as a change
let point = Signal.make(
  ~equals=((x1, y1), (x2, y2)) => x1 == x2 && y1 == y2,
  (0, 0),
)`,
      notes: [
        "Without ~equals, values are compared by reference (===). Setting a signal to a value equal to the one it holds notifies nothing, so writing the same primitive twice costs nothing. Records and arrays are compared by identity, so pass ~equals when a structurally equal value should count as unchanged.",
      ],
    },
    {
      id: "signal-get",
      label: "Signal.get",
      signature: "Signal.get(signal): 'a",
      summary: "Reads the value and records a dependency on it.",
      code: `let count = Signal.make(5)

Signal.get(count) // 5

// Inside a computed or an effect, this is what
// creates the link back to count
let doubled = Computed.make(() => Signal.get(count) * 2)`,
      notes: [],
    },
    {
      id: "signal-peek",
      label: "Signal.peek",
      signature: "Signal.peek(signal): 'a",
      summary: "Reads the value without recording a dependency.",
      code: `// Reads the threshold, but does not re-run
// when the threshold changes
Effect.run(() => {
  let value = Signal.get(input)
  let limit = Signal.peek(threshold)
  Console.log(value > limit)
  None
})`,
      notes: [],
    },
    {
      id: "signal-set",
      label: "Signal.set",
      signature: "Signal.set(signal, value): unit",
      summary: "Writes a new value.",
      code: `Signal.set(count, 10)`,
      notes: [],
    },
    {
      id: "signal-update",
      label: "Signal.update",
      signature: "Signal.update(signal, fn): unit",
      summary: "Writes a new value derived from the current one.",
      code: `Signal.update(count, n => n + 1)
Signal.update(lineup, artists => Array.concat(artists, ["Tim Maia"]))`,
      notes: [],
    },
    {
      id: "signal-batch",
      label: "Signal.batch",
      signature: "Signal.batch(fn)",
      summary: "Groups writes so dependents run once at the end instead of once per write.",
      code: `let firstName = Signal.make("Gal")
let lastName = Signal.make("Costa")

// One re-run, not two
Signal.batch(() => {
  Signal.set(firstName, "Elis")
  Signal.set(lastName, "Regina")
})`,
      notes: ["Batches nest: only the outermost one flushes."],
    },
    {
      id: "signal-untrack",
      label: "Signal.untrack",
      signature: "Signal.untrack(fn): 'a",
      summary: "Runs a block without recording any of the dependencies it reads.",
      code: `// Depends on a, but not on b
let sum = Computed.make(() => {
  let a = Signal.get(source)
  let b = Signal.untrack(() => Signal.get(other))
  a + b
})`,
      notes: [
        "Signal.peek does this for a single read; untrack does it for a whole block, including reads inside functions it calls.",
      ],
    },
  ],
  closing: [],
}

let computed = {
  id: "computed",
  name: "Computed",
  lead: "A computed derives a value from other signals. It recomputes only when one of them changes, and only when something asks for the result.",
  entries: [
    {
      id: "computed-make",
      label: "Computed.make",
      signature: "Computed.make(fn, ~name=?, ~equals=?): Signal.t<'a>",
      summary: "Creates a derived value. Dependencies are whatever fn reads.",
      code: `let count = Signal.make(5)
let doubled = Computed.make(() => Signal.get(count) * 2)

// ~equals stops a downstream re-run when the derived
// value comes out the same
let bucket = Computed.make(
  ~equals=(a, b) => a == b,
  () => Signal.get(count) / 10,
)`,
      notes: [],
    },
    {
      id: "computed-read",
      label: "Reading a computed",
      signature: "Signal.get(computed) / Signal.peek(computed)",
      summary: "A computed is a Signal.t, so it is read with the Signal functions.",
      code: `let doubled = Computed.make(() => Signal.get(count) * 2)

Signal.get(doubled)  // reads, and records a dependency
Signal.peek(doubled) // reads without recording one`,
      notes: [
        "There is no Computed.get or Computed.peek. Computed.make returns a Signal.t<'a>, which is what makes a computed usable anywhere a signal is — including as the source of another computed.",
      ],
    },
    {
      id: "computed-dispose",
      label: "Computed.dispose",
      signature: "Computed.dispose(computed): unit",
      summary: "Detaches a computed from its sources.",
      code: `// Only needed for a computed that still has subscribers
Computed.dispose(doubled)

// Still usable — the next read rebuilds its dependencies
Signal.get(doubled)`,
      notes: [
        "Rarely needed. A computed attaches to its sources only while something is subscribed to it and detaches on its own once the last subscriber goes away, so a computed you create and drop needs no cleanup.",
      ],
    },
  ],
  closing: [
    (
      "Cached",
      "The result is held until a dependency changes. Reading a computed repeatedly costs one recomputation, not one per read.",
    ),
    (
      "Lazy",
      "The computation runs when the value is read, not when a dependency is written.",
    ),
    (
      "Self-releasing",
      "A computed attaches to its sources only while it has a subscriber. Deriving a value inline is safe: one you drop keeps nothing alive and costs its sources nothing on write.",
    ),
    (
      "Glitch-free",
      "Computeds recompute in dependency order, so no observer sees a value derived from a half-applied update.",
    ),
  ],
}

let effect = {
  id: "effect",
  name: "Effect",
  lead: "An effect runs a function now, and again whenever a signal it read has changed. It is where reactive state meets the world outside it.",
  entries: [
    {
      id: "effect-run",
      label: "Effect.run",
      signature: "Effect.run(fn, ~name=?): unit",
      summary: "Runs fn immediately, then again on every change to what it read.",
      code: `let count = Signal.make(0)

Effect.run(() => {
  Console.log(Signal.get(count))
  None
})
// logs 0

Signal.set(count, 1)
// logs 1`,
      notes: [],
    },
    {
      id: "effect-cleanup",
      label: "Cleanup",
      signature: "() => option<unit => unit>",
      summary: "The return value is an optional cleanup, run before each re-run and on disposal.",
      code: `Effect.run(() => {
  let id = setInterval(tick, Signal.get(interval))
  Some(() => clearInterval(id))
})

// Changing interval clears the old timer
// before starting the new one
Signal.set(interval, 500)`,
      notes: [
        "Return None when there is nothing to undo. An effect that acquires something — a timer, a listener, a subscription — should return the release for it, or the acquisition leaks on every re-run.",
      ],
    },
    {
      id: "effect-dispose",
      label: "Effect.runWithDisposer",
      signature: "Effect.runWithDisposer(fn, ~name=?): disposer",
      summary: "Same as Effect.run, but returns a handle that stops the effect.",
      code: `let disposer = Effect.runWithDisposer(() => {
  Console.log(Signal.get(count))
  Some(() => Console.log("cleaned up"))
})

disposer.dispose()
// logs "cleaned up"; later writes to count do nothing`,
      notes: ["type disposer = {dispose: unit => unit}. Disposing twice is safe."],
    },
  ],
  closing: [],
}

let debug = {
  id: "debug",
  name: "Debug",
  lead: "Debug lets a tool observe the library: it reports nodes as they are created, the dependencies between them, writes and runs. Nothing is reported until a hook is installed.",
  entries: [
    {
      id: "debug-install",
      label: "Debug.install",
      signature: "Debug.install({emit, captureStacks}): unit",
      summary: "Starts reporting events to emit.",
      code: `Debug.install({
  captureStacks: false,
  emit: event =>
    switch event {
    | Created({id, kind, name}) => Console.log3("created", id, name)
    | Written({id, changed}) => Console.log3("write", id, changed)
    | RunStart({id}) => Console.log2("run", id)
    | _ => ()
    },
})`,
      notes: [
        "Install before creating anything reactive. A node created earlier has no id and is never reported.",
        "captureStacks records new Error().stack for every created node, so one without a ~name can still be traced to the code that made it. It costs a stack capture per node, so leave it off unless you need it.",
        "Installing again replaces the hook.",
      ],
    },
    {
      id: "debug-event",
      label: "Debug.event",
      signature: "type event",
      summary: "What a hook receives, in the order it happens.",
      code: `type event =
  | Created({id: int, kind: nodeKind, name: option<string>, stack: option<string>})
  | Linked({source: int, target: int})   // target read source for the first time
  | Unlinked({source: int, target: int}) // re-tracking dropped the dependency
  | Written({id: int, changed: bool})    // Signal.set, after the value is stored; changed is false when equals held
  | RunStart({id: int})                  // a computed recomputes or an effect runs
  | RunEnd({id: int, changed: bool, threw: bool})
  | Disposed({id: int})                  // after an Unlinked for each dependency it drops
  | Collected({id: int})                 // reclaimed by the garbage collector
  | BatchStart                           // the outermost Signal.batch
  | BatchEnd

type nodeKind = [#Signal | #Computed | #Effect]`,
      notes: [
        "Computeds are lazy, so one often recomputes inside the effect that reads it: its RunStart and RunEnd nest within the effect's.",
        "RunEnd reports whether a computed's value changed (always true for an effect). A computed whose ~equals held reports changed: false, and nothing downstream hears about it.",
        "A batch's events end after its flush, so one batch is the writes in it and everything they caused.",
      ],
    },
    {
      id: "debug-uninstall",
      label: "Debug.uninstall",
      signature: "Debug.uninstall(): unit",
      summary: "Stops reporting and forgets every id.",
      code: `Debug.uninstall()`,
      notes: ["Ids belong to one install: after uninstalling, the same node gets a new id the next time."],
    },
    {
      id: "debug-nodes",
      label: "Debug.nodes",
      signature: "Debug.nodes(): array<int>",
      summary: "The ids of every node still alive, oldest first.",
      code: `let alive = Debug.nodes()
Console.log(Array.length(alive))`,
      notes: ["nodes and inspect need WeakRef, which every current engine has. Without it they return nothing, and events still flow, rather than holding every node alive."],
    },
    {
      id: "debug-inspect",
      label: "Debug.inspect",
      signature: "Debug.inspect(id): option<node>",
      summary: "Reads one node: its value, its level, what it reads and what reads it.",
      code: `type node = {
  id: int,
  kind: nodeKind,
  name: option<string>,
  level: int,             // the scheduler's run order
  value: option<Obj.t>,   // None for an effect
  sources: array<int>,    // ids of the nodes this one reads
  observers: array<int>,  // ids of the nodes that read this one
  dirty: bool,
  disposed: bool,
}

switch Debug.inspect(id) {
| Some({name, sources}) => Console.log2(name, sources)
| None => () // collected, or created before install
}`,
      notes: ["inspect reads the live graph, so call it when you want a value, rather than expecting every write to carry one."],
    },
    {
      id: "debug-id-of-signal",
      label: "Debug.idOfSignal",
      signature: "Debug.idOfSignal(signal): option<int>",
      summary: "Finds a signal or computed in the graph, given the value itself.",
      code: `let count = Signal.make(0, ~name="count")

switch Debug.idOfSignal(count) {
| Some(id) => Debug.inspect(id)
| None => None // created before install
}`,
      notes: ["For a tool that holds a Signal.t some other library handed back, and wants to know which node it is."],
    },
    {
      id: "debug-discovery",
      label: "Finding the hooks",
      signature: "globalThis[Symbol.for(\"rescript-signals.debug\")]",
      summary: "Every loaded copy of the library announces itself, so a tool can find it without importing it.",
      code: `// JavaScript
const copies = globalThis[Symbol.for("rescript-signals.debug")] ?? []

for (const copy of copies) {
  // copy.version, copy.install, copy.uninstall,
  // copy.nodes, copy.inspect, copy.idOfSignal
  copy.install({ captureStacks: false, emit: event => console.log(event) })
}`,
      notes: [
        "A page can hold several copies of the library, say an app and a component library built against separate ones. Installing into each instruments them all.",
        "Check copy.version before relying on the shape: it is 1 today.",
      ],
    },
  ],
  closing: [
    ("Cost", "While no hook is installed, each instrumentation point is one boolean check, and nothing allocates."),
    ("Lifetime", "Nodes are held weakly, so a tool never keeps one alive."),
    ("Behavior", "Installing a hook does not change how signals, computeds or effects behave."),
  ],
}

/* The library itself. */
let groups: array<group> = [signal, computed, effect]

/* Modules for tools rather than apps, documented after the main ones. */
let tooling: array<group> = [debug]
