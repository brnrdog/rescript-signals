# Proposal 0001 — React & Signals Ergonomics

- **Status:** Draft
- **Author:** brnrdog
- **Created:** 2026-07-16
- **Prototype branch:** `claude/rescript-signals-react-ergonomics-j9oijx`
- **Affects:** `rescript-signals` (core), `rescript-signals-react` (adapter)

## Summary

Close the ergonomics gap between `rescript-signals-react` and
`@preact/signals-react` (and its ReScript bindings) without sacrificing the two
properties that make this library distinct: **plain-value reads** and
**concurrent-mode / StrictMode safety** via `useSyncExternalStore`.

The proposal introduces one small **core primitive** (`Tracking`, a notify-only
observer) and organizes the React surface into **three deliberate tiers** —
explicit, explicit-list, and automatic — so users can trade magic for guarantees
consciously. A `@tracked` PPX is discussed and explicitly **deferred** as
optional sugar over the runtime, not a prerequisite.

Much of this is already prototyped and tested on the branch above.

## Motivation

### Where we stand vs. the field

| Dimension | `@preact/signals-react` | `rescript-preact-signals` | **this library (today)** |
| --- | --- | --- | --- |
| Read a value | `.value` (needs babel/`useSignals`) | `->val` | **plain subscribed value** ✅ |
| Auto-subscribe | ✅ babel transform | ✅ babel transform | ❌ explicit `useSignalValue` |
| `useSignal` shape | one handle | one handle | **3-tuple** ❌ |
| Setter | `.value =` | `->set` | value-only `setter(v)`, no updater ❌ |
| Derive from props | just works | just works | **stale-closure footgun** ❌ |
| Leaf/text binding | `<p>{signal}</p>` | same | ❌ none |
| Concurrent/StrictMode | patchy historically | patchy | ✅ `useSyncExternalStore` |

The honest read: our **reads are already cleaner** (a plain value beats `->val`)
and we are **safer under concurrent React**. We lose on tuple clutter, a missing
updater-form setter, a silent stale-closure trap in `useComputed`, and the lack
of preact's signature move — dropping a signal straight into JSX so only a leaf
updates.

### Why not "just add the preact babel transform"

preact's auto-tracking is **two layers**: a Babel transform that brackets a
component in `useSignals()`, riding on an **ambient runtime** where `.value` is a
getter that registers with the currently-active effect. The transform is
worthless without the runtime.

Our reads are a **hook** (`useSyncExternalStore`), not an ambient getter. A
transform that rewrote `Signal.get(x)` into a hook would violate the **rules of
hooks** the moment a read sits inside a callback, `switch`, loop, or `Array.map`.
So "be like preact" is not a transform project — it is a **runtime** project.
ReScript also has no supported third-party PPX story; PPXes are native binaries
pinned to the compiler's AST and re-audited every release. Conclusion: build the
runtime first; treat any annotation as later sugar.

## Goals / Non-goals

**Goals**

- Keep plain-value reads and `useSyncExternalStore` safety as the default path.
- Offer an automatic-tracking path for users who want preact-like ergonomics.
- Remove the current footguns (3-tuple, missing updater, stale `useComputed`).
- Make every tier's tradeoff explicit and testable.
- Additive and backward-compatible; no breaking changes to existing hooks.

**Non-goals**

- Shipping a `@tracked` PPX in this proposal (discussed, deferred).
- Replacing `useSyncExternalStore` with an ambient-only runtime.
- Matching preact's zero-annotation `<p>{signal}</p>` exactly — ReScript's typed
  JSX cannot accept a bare signal as a child.

## Design

### Core: `Signals.Tracking` — a notify-only reactive scope

A framework-agnostic primitive for externally-driven consumers (a UI render).
Unlike an `Effect`, a scope is **not recomputed** by the scheduler when a
dependency changes — it is only **notified**. The driver re-establishes deps by
calling `track` again, which brackets an external body as the current observer
and reconciles the dep set using the same version-based logic as `retrackEffect`.

```rescript
type scope
let makeScope: (~onInvalidate: unit => unit) => scope
let track: (scope, unit => 'a) => 'a   // run body as observer, reconcile deps, return result
let dispose: scope => unit
let isEmpty: scope => bool
```

Implementation cost in the core:

- One flag bit (`flag_manual`) plus `isManualObs` / `setManualObs` in `Core`.
- A `track` function in `Scheduler` (a variant of `retrackEffect` that takes an
  external body and returns its result).
- One branch in the `flush` effect loop: manual observers are `run()` (notified)
  and cleared, never retracked.

Hot-path impact: **one bitwise check per flushed effect.** `Core`/`Scheduler`
stay package-private; only `Tracking` is re-exported through `Signals`.

> **Status:** implemented and passing (core suite 52/52), commit
> `feat(core): add Tracking notify-only observer`.

### React Tier 1 — clean up the explicit hooks (no magic)

These are the cheap, safe wins. Pure-render, no render-phase tracking, no
footguns.

**1a. `useSignalState` — a `useState`-shaped 2-tuple.** `@rescript/react`'s own
`useState` returns `(value, ('a => 'a) => unit)`; mirror it exactly so muscle
memory transfers and the missing updater form is provided:

```rescript
let useSignalState: (unit => 'a) => ('a, ('a => 'a) => unit)
// let (count, setCount) = useSignalState(() => 0)
// setCount(n => n + 1)
```

Keep the existing 3-tuple `useSignal` for when the underlying signal handle is
genuinely needed to pass down.

**1b. Leaf-binding combinators — our answer to `<p>{signal}</p>`.** Signal →
element combinators, used inline in children position, each backed by a tiny
internal component so only the leaf re-renders:

```rescript
let text:  Signal.t<string> => React.element
let int:   Signal.t<int>    => React.element
let float: Signal.t<float>  => React.element
let render: (Signal.t<'a>, 'a => React.element) => React.element
// <p> {count->SignalsReact.int} </p>
// <li> {user->SignalsReact.render(u => <Avatar user=u />)} </li>
```

This is strictly closer to preact than a render-prop component, drops prop
ceremony, and isolates re-renders to the leaf (a real perf win in lists).

**1c. De-footgun `useComputed`.** Today `useComputed` silently goes stale on
captured React values because it memoizes the compute once. Make the safe,
deps-aware path the default:

```rescript
let useComputed: (unit => 'a, ~deps: 'deps=?) => 'a
```

so React-level inputs participate by default, and the signal-only case is opt-in.
(Decision required — see Open Questions.)

> **Status:** designed, not yet implemented.

### React Tier 2 — `useSignals`, explicit dependency list

The hand-written equivalent of an `@tracked(a, b)` annotation. List the signals
once; read them (and props) freely in the body:

```rescript
type dep
let dep: Signal.t<'a> => dep
let useSignals: array<dep> => unit

// @react.component
// let make = (~a, ~b, ~c) => {
//   useSignals([dep(a), dep(b)])
//   <div> {React.string(Int.toString(Signal.get(a) + Signal.get(b)))}
//         {React.string(c)} </div>
// }
```

`dep` type-erases heterogeneous signals into one array; deps are reconciled every
render, so a dynamic list works. Semantics are **explicit, like a React
dependency array**: a signal read but not listed will not trigger a re-render.

> **Status:** implemented and passing (2 tests, incl. the unlisted-read footgun),
> commit `feat(react): add explicit-deps useSignals helper`.

### React Tier 3 — `useTracked`, automatic discovery

Preact-style: any `Signal.get` inside the thunk auto-subscribes. Single-pass —
the display render **is** the tracking pass (built on `Tracking.track`), so the
thunk runs exactly once per update.

```rescript
let useTracked: (unit => 'a) => 'a

// @react.component
// let make = (~a, ~b) =>
//   useTracked(() => <div> {React.string(Int.toString(Signal.get(a) + Signal.get(b)))} </div>)
```

Dependencies are re-discovered on every change, so conditional reads work, and
the latest closure is used each render, so props never go stale.

> **Status:** implemented and passing (5 tests: auto-track, conditional deps,
> fresh props, single-pass cost = mount 1 / update +1, unmount disposal), commits
> `feat(react): single-pass auto-tracking` (+ the earlier spike it replaced).

### Future — `@tracked` PPX (deferred)

```rescript
@react.component
let make = (~a, ~b, ~c) => {
  @tracked(a, b)
  <div> {React.string(Int.toString(Signal.get(a) + Signal.get(b)))} {React.string(c)} </div>
}
```

A bare attribute is inert — the compiler erases it before JS emission. Realizing
it needs a ReScript PPX (native binary, pinned AST, per-release maintenance).
Crucially it would only be **sugar** over Tier 2/3:

- `@tracked(a, b)` → `useSignals([dep(a), dep(b)])` (Tier 2)
- `@tracked` (no args) → `useTracked(() => body)` (Tier 3)

Because both targets already exist and are tested, the PPX is optional and can be
decided later based on which tier users actually reach for. **Recommendation:**
do not build it now.

## Tradeoffs

| Tier | Reads | Deps | Passes/update | Render purity | Footgun |
| --- | --- | --- | --- | --- | --- |
| Explicit (`useSignalValue`, combinators) | plain value | typed, per-signal | 1 | pure | none |
| Explicit list (`useSignals`) | plain `Signal.get` | manual array | 1 | pure | unlisted read won't re-render |
| Automatic (`useTracked`) | plain `Signal.get` | auto-discovered | 1 | **tracks during render** | render-impurity caveat |

**`useTracked`'s one real caveat:** to achieve a single pass, dependency tracking
happens *during* render, which mutates the scope's dep set — React renders are
supposed to be pure. A render that concurrent React **discards** leaves deps
reflecting the discarded pass until the committed render's `track` overwrites
them. `useSyncExternalStore` still guards against visible tearing, and a
`useEffect` disposes the scope on unmount and repairs deps after a StrictMode
remount. This is the same render-phase-tracking tradeoff preact accepts; Tiers 1
and 2 avoid it entirely, which is why they remain the recommended default.

## Prototype status

On branch `claude/rescript-signals-react-ergonomics-j9oijx`:

- **Core:** `Tracking` primitive — implemented, `Signals.Tracking`, 52/52 core
  tests green.
- **React Tier 3:** `useTracked` single-pass — implemented, 5/5 tests green,
  single-pass cost pinned by test.
- **React Tier 2:** `useSignals` / `dep` — implemented, 2/2 tests green.
- **React Tier 1:** designed only (`useSignalState`, combinators, `useComputed`
  de-footgun) — not yet implemented.

New React APIs currently live in an experimental `SignalsReactAuto` module to
keep the stable `SignalsReact` surface untouched during evaluation.

## Rollout plan

1. **Land Tier 1** (`useSignalState`, `text/int/float/render`, `useComputed`
   de-footgun) in `SignalsReact`. Low risk, immediate ergonomic wins, no core
   change. Ship first.
2. **Stabilize the core `Tracking` primitive.** Benchmark the `flush` branch
   against `main` (`js-reactivity-benchmark`) to confirm the bitwise check is
   free. Document `Signals.Tracking`.
3. **Promote Tier 2/3** from `SignalsReactAuto` into `SignalsReact` (or a
   `SignalsReact.Auto` submodule) marked experimental, with the render-phase
   caveat documented, once real `<StrictMode>` / concurrent tests are added.
4. **Revisit the `@tracked` PPX** only if adoption data shows the annotation
   saves enough over Tiers 2/3 to justify a compiler plugin.

## Backward compatibility

Entirely additive. Existing hooks (`useSignalValue`, `useSignal`,
`useComputed`, `useComputedWithDeps`, `useSignalEffect`) are unchanged. The one
API-shape decision is whether `useComputed` gains an optional `~deps` (safe
superset) — no removals either way.

## Open questions

1. **`useComputed` default:** add optional `~deps` to the existing hook, or
   introduce `useComputedSignal` for the signal-only case and make `useComputed`
   deps-aware? (Preference: optional `~deps`, non-breaking.)
2. **Module placement:** promote Tier 2/3 into `SignalsReact` directly, or keep a
   `SignalsReact.Auto` namespace to keep the "magic" opt-in and greppable?
3. **`Tracking` visibility:** expose it as a supported public primitive (enables
   other UI adapters — Vue-style, custom renderers) or keep it internal to the
   React adapter for now?
4. **Concurrent validation:** the current tests use `act`, not `<StrictMode>` /
   `startTransition`. Tier 3 needs tests that actually exercise the render-phase
   caveat before it leaves experimental.
