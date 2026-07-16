# Proposal 0001 — React & Signals Ergonomics

- **Status:** Draft
- **Author:** brnrdog
- **Created:** 2026-07-16
- **Prototype branch:** `claude/rescript-signals-react-ergonomics-j9oijx`
- **Affects:** `rescript-signals` (core), `rescript-signals-react` (adapter)

## Summary

Improve the day-to-day ergonomics of using signals inside React components while
preserving the two properties the library is built on: **plain-value reads**
(reading a signal in a component yields an ordinary value, not a wrapper) and
**concurrent-mode / StrictMode safety** via `useSyncExternalStore`.

The proposal adds one small **core primitive** (`Tracking`, a notify-only
observer) and organizes the React surface into **three deliberate tiers** —
explicit, explicit-list, and automatic — so users can choose how much
dependency bookkeeping they do by hand versus how much is discovered
automatically, with the tradeoffs made explicit at each tier.

Much of this is already prototyped and tested on the branch above.

## Motivation

Today the React adapter is correct and safe, but a few rough edges add friction:

- **`useSignal` returns a 3-tuple** `(value, signal, setter)`. Most call sites
  need only the value and setter, so the middle element is clutter, and the
  shape doesn't match the `(value, setter)` muscle memory of `useState`.
- **The setter is value-only.** There is no updater form (`setCount(n => n + 1)`),
  which is the common case for counters and toggles.
- **`useComputed` silently goes stale on captured React values.** It memoizes the
  compute once, so a value read from props or `useState` inside the thunk is
  frozen at first render. The failure is silent — the component simply shows a
  stale number.
- **Every reactive read needs its own `useSignalValue` call, and any change
  re-renders the whole component.** There is no way to bind a single signal to a
  leaf node so that only that leaf updates, and no way to opt a component into
  "read these signals freely and re-render when they change" without threading a
  hook per signal.

The goal is to smooth these edges and add an automatic-tracking path, without
giving up plain-value reads or `useSyncExternalStore` safety.

### Why automatic tracking is a runtime concern, not a syntax concern

A natural wish is an annotation that makes a component "just track whatever
signals it reads." It is worth stating up front why that is a runtime problem.

Our reads go through a hook (`useSyncExternalStore`). A purely syntactic rewrite
that turned `Signal.get(x)` into a subscription hook would violate the **rules of
hooks** the moment a read sits inside a callback, a `switch`, a loop, or
`Array.map` — which is most real reads. Automatic tracking therefore cannot be a
mechanical read-rewrite; it requires a **runtime** that can observe which signals
a render touched and subscribe to exactly those. This proposal builds that
runtime first. Any annotation or syntax sugar is a later, optional layer on top
of it (see *Future — `@tracked` annotation*).

## Goals / Non-goals

**Goals**

- Keep plain-value reads and `useSyncExternalStore` safety as the default path.
- Offer an automatic-tracking path for users who want minimal bookkeeping.
- Remove the current footguns (3-tuple, missing updater, stale `useComputed`).
- Make every tier's tradeoff explicit and testable.
- Additive and backward-compatible; no breaking changes to existing hooks.

**Non-goals**

- Shipping a `@tracked` PPX in this proposal (discussed, deferred).
- Replacing `useSyncExternalStore` with an ambient-only runtime.
- Accepting a bare signal as a JSX child — ReScript's typed JSX requires children
  to be `React.element`, so a signal must be converted by a combinator first.

## Design

### Core: `Signals.Tracking` — a notify-only reactive scope

A framework-agnostic primitive for externally-driven consumers such as a UI
render. Unlike an `Effect`, a scope is **not recomputed** by the scheduler when a
dependency changes — it is only **notified**. The driver re-establishes
dependencies by calling `track` again, which brackets an external body as the
current observer and reconciles the dependency set using the same version-based
logic the scheduler already uses for effects.

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

**1b. Leaf-binding combinators.** Signal → element combinators, used inline in
children position, each backed by a tiny internal component so only the leaf
re-renders instead of the whole component:

```rescript
let text:  Signal.t<string> => React.element
let int:   Signal.t<int>    => React.element
let float: Signal.t<float>  => React.element
let render: (Signal.t<'a>, 'a => React.element) => React.element
// <p> {count->SignalsReact.int} </p>
// <li> {user->SignalsReact.render(u => <Avatar user=u />)} </li>
```

This isolates re-renders to the leaf — a real win for lists and hot text nodes —
and reads as a single token in JSX with no render-prop ceremony.

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

List the signals a component depends on once; read them (and props) freely in the
body:

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

`dep` type-erases heterogeneous signals into one array; dependencies are
reconciled every render, so a dynamic list works. Semantics are **explicit, like
a React dependency array**: a signal read but not listed will not trigger a
re-render. This is a middle ground — less bookkeeping than one hook per signal,
more control (and more responsibility) than automatic discovery.

> **Status:** implemented and passing (2 tests, incl. the unlisted-read footgun),
> commit `feat(react): add explicit-deps useSignals helper`.

### React Tier 3 — `useTracked`, automatic discovery

Any `Signal.get` inside the thunk auto-subscribes the component. Single-pass —
the display render **is** the tracking pass (built on `Tracking.track`), so the
thunk runs exactly once per update.

```rescript
let useTracked: (unit => 'a) => 'a

// @react.component
// let make = (~a, ~b) =>
//   useTracked(() => <div> {React.string(Int.toString(Signal.get(a) + Signal.get(b)))} </div>)
```

Dependencies are re-discovered on every change, so conditional reads work, and
the latest closure is used each render, so props never go stale. This is the
lowest-bookkeeping tier: no dependency list, no per-signal hook.

> **Status:** implemented and passing (5 tests: auto-track, conditional deps,
> fresh props, single-pass cost = mount 1 / update +1, unmount disposal), commit
> `feat(react): single-pass auto-tracking` (+ the earlier spike it replaced).

### Future — `@tracked` annotation (deferred)

An attribute form is an appealing shorthand:

```rescript
@react.component
let make = (~a, ~b, ~c) => {
  @tracked(a, b)
  <div> {React.string(Int.toString(Signal.get(a) + Signal.get(b)))} {React.string(c)} </div>
}
```

A bare attribute is inert — the ReScript compiler erases unknown attributes
before JS emission, so nothing subscribes. Realizing it requires a ReScript PPX,
which in ReScript is a native binary pinned to the compiler's AST and re-audited
each release — a real, ongoing maintenance cost.

Crucially, whatever the PPX emitted would just be **sugar** over the tiers above:

- `@tracked(a, b)` → `useSignals([dep(a), dep(b)])` (Tier 2)
- `@tracked` (no args) → `useTracked(() => body)` (Tier 3)

Because both targets already exist and are tested, the annotation is optional and
can be decided later based on which tier users actually reach for.
**Recommendation:** do not build it now.

## Tradeoffs

| Tier | Reads | Deps | Passes/update | Render purity | Footgun |
| --- | --- | --- | --- | --- | --- |
| Explicit (`useSignalValue`, combinators) | plain value | typed, per-signal | 1 | pure | none |
| Explicit list (`useSignals`) | plain `Signal.get` | manual array | 1 | pure | unlisted read won't re-render |
| Automatic (`useTracked`) | plain `Signal.get` | auto-discovered | 1 | **tracks during render** | render-impurity caveat |

**`useTracked`'s one real caveat:** to achieve a single pass, dependency tracking
happens *during* render, which mutates the scope's dependency set — React renders
are expected to be pure. A render that concurrent React **discards** leaves
dependencies reflecting the discarded pass until the committed render's `track`
overwrites them. `useSyncExternalStore` still guards against visible tearing, and
a `useEffect` disposes the scope on unmount and repairs dependencies after a
StrictMode remount. Tiers 1 and 2 avoid this entirely, which is why they remain
the recommended default; Tier 3 trades a little render purity for the least
bookkeeping.

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
4. **Revisit the `@tracked` annotation** only if adoption data shows it saves
   enough over Tiers 2/3 to justify a compiler plugin.

## Backward compatibility

Entirely additive. Existing hooks (`useSignalValue`, `useSignal`,
`useComputed`, `useComputedWithDeps`, `useSignalEffect`) are unchanged. The one
API-shape decision is whether `useComputed` gains an optional `~deps` (a safe
superset) — no removals either way.

## Open questions

1. **`useComputed` default:** add optional `~deps` to the existing hook, or
   introduce `useComputedSignal` for the signal-only case and make `useComputed`
   deps-aware? (Preference: optional `~deps`, non-breaking.)
2. **Module placement:** promote Tier 2/3 into `SignalsReact` directly, or keep a
   `SignalsReact.Auto` namespace to keep the automatic path opt-in and greppable?
3. **`Tracking` visibility:** expose it as a supported public primitive (enabling
   other UI adapters and custom renderers) or keep it internal to the React
   adapter for now?
4. **Concurrent validation:** the current tests use `act`, not `<StrictMode>` /
   `startTransition`. Tier 3 needs tests that actually exercise the render-phase
   caveat before it leaves experimental.
