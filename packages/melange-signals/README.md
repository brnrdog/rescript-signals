# melange-signals

A proof-of-concept port of `rescript-signals` to **OCaml + [Melange](https://melange.re/)**,
targeting the browser. It implements the same primitives — `Signal`, `Computed`,
`Effect` — backed by the same kind of push/pull reactive scheduler, written in
idiomatic OCaml.

```ocaml
open Signals

let count   = Signal.make 0
let doubled = Computed.make (fun () -> Signal.get count * 2)

let () =
  Effect.run (fun () ->
    Printf.printf "doubled = %d\n" (Signal.get doubled);
    None)

let () = Signal.set count 5   (* prints: doubled = 10 *)
```

## What's implemented

Everything from the ReScript core, with the same semantics:

- **`Signal`** — `make` (with optional `~name` / `~equals`), `get`, `peek`,
  `set`, `update`, plus `batch` and `untrack`.
- **`Computed`** — `make` (with optional `~name` / `~equals`), lazily evaluated,
  recomputes only when read after a dependency changed; `dispose`.
- **`Effect`** — `run` and `run_with_disposer`, with optional cleanup functions
  that run before each re-run and on dispose.
- **Scheduler** — a level-ordered, glitch-free scheduler with batching, lazy
  computed propagation, version-based dependency de-duplication, and the
  "defer effects behind a custom-equality computed" optimization that lets an
  unchanged computed cancel downstream effect runs.

## Architecture

The reactive graph is a doubly linked structure. Every reactive thing — a plain
signal, a computed, or an effect — is one `Core.node`. A `Core.link` is an edge
between a **source** node (value being read) and a **target** node (the observer
reading it). Each link lives in two intrusive linked lists at once:

- the source's **subscriber** list (`next_sub` / `prev_sub`)
- the target's **dependency** list (`next_dep` / `prev_dep`)

| role     | shape                                          |
| -------- | ---------------------------------------------- |
| signal   | node with neither `compute` nor `run`          |
| computed | node with `compute = Some _` (source + target) |
| effect   | node with `run = Some _` (target only)         |

Reads inside a running effect/computed are recorded as dependencies; writes walk
the subscriber lists to mark computeds dirty (lazily) and queue effects. The
scheduler processes pending work in **level** order (a node's level is one more
than the deepest computed it depends on), which gives glitch-free updates in
diamond-shaped graphs.

### Difference from the ReScript original

The ReScript version packs a computed's observer and subscriber records into a
single object and reinterprets pointers with `Obj.magic`, relying on JS objects
being keyed by field name. That trick is JS-runtime-specific. This port uses one
unified `node` variant instead, so it carries **no unsafe casts** and the exact
same graph algorithm compiles unchanged for both Melange (browser) and native
OCaml. The micro-optimized fast-path branches in the original tracker are
collapsed into a single cursor-with-fallback-scan here for readability; the
observable behavior is identical.

The full source map:

| ReScript                  | this port                |
| ------------------------- | ------------------------ |
| `src/signals/Core.res`    | `src/signals/core.ml`    |
| `src/signals/Scheduler.res` | `src/signals/scheduler.ml` |
| `src/signals/Signal.res`  | `src/signals/signal.ml`  |
| `src/signals/Computed.res`| `src/signals/computed.ml`|
| `src/signals/Effect.res`  | `src/signals/effect.ml`  |
| `src/signals/Id.res`      | `src/signals/id.ml`      |
| `src/Signals.res`         | `src/signals.ml`         |

## Build, test, demo

The reactive core depends only on the OCaml stdlib, so the test suite runs
**natively** — no Melange toolchain required:

```sh
dune test          # runs test/test_signals.ml natively (33 behavioral checks)
```

To compile to JavaScript you need Melange (`opam install melange`):

```sh
dune build @melange    # emits the library + demo to JS
npm run demo           # builds and bundles demo/app.ml, then open demo/index.html
```

The demo (`demo/app.ml` + `demo/index.html`) is a counter wired entirely through
Signals: a writable `count`, a `doubled` computed, a custom-equality `parity`
computed (so the even/odd label only re-renders when parity flips), and three
effects that keep the DOM text in sync.

## Status

This is a proof of concept: it demonstrates the architecture and full
functional parity with the ReScript core, verified by a behavioral test suite
covering reads/writes, batching, untracking, lazy computeds, chained/diamond
graphs, cleanup ordering, and custom-equality short-circuiting.
