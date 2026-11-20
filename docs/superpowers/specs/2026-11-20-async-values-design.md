# Async values, and computeds that hold failures

**Date:** 2026-11-20
**Scope:** `packages/rescript-signals/`
**Status:** built, unreleased. A breaking change: it ships as a major version.

## Goal

Let a promise be a node in the graph. A computed that reads an async value should be
"not ready" while it loads, without the code that reads it matching on a loading
state, and should recompute by itself when the value arrives. An effect that reads it
should wait rather than fail.

This is step 3 of the async work in Xote (`docs/proposals/` in brnrdog/xote): steps 1
and 2 built loading state for Suspense boundaries and derived resources on top of the
library; this step puts async values in the library itself, so derivation is ordinary
code (`Signal.get(user).name`) rather than `Resource.map`.

## Why computeds have to hold failures first

A read of an async value with no value yet has to throw — `Signal.get` returns `'a`,
and there is no `'a` to return. So "not ready" travels through the graph the way a
failure does, and the graph has to handle failures well enough for that. It did not:

- **A computed that threw stayed dirty.** `notifySubs` treats a dirty computed as
  already notified and walks past it, so a later change to its sources never reached
  the effects behind it.
- **A read that threw did not subscribe.** `Signal.get` settles the computed before
  tracking it, so a throw skipped `trackDep`, and the reader's next sweep dropped the
  dependency it had.

Together: an effect that read a computed which threw once never ran again, even after
the computed recovered (`[10, "threw"]` where `[10, "threw", 30, 40]` was right). With
async values this would be the normal case — every value starts not ready.

## Design

### Computeds hold failures

A computed's run ends in a value or a failure, and both are results:

- `runComputedCycle` catches what the function throws, stores it in the subs record
  (`error`, raw — a JavaScript error is unwrapped from ReScript's `JsExn` so it is
  thrown again as itself), sets `flag_errored`, bumps the version and propagates like
  a changed value. It clears the dirty flag either way, which fixes the first bug.
- `Signal.get` tracks before it throws, which fixes the second.
- Reads throw the stored failure until a dependency changes and a run succeeds. The
  function does not run again per read.
- `Computed.make` runs its first computation through the same cycle, so it never
  throws; the first read does.
- Recovering always counts as a change, even to a value `~equals` calls equal to the
  one before the failure.

This changes behaviour that callers can observe — `Computed.make` used to throw, and a
failed computed used to recompute on every read — so it is a breaking change. It was
chosen over holding only "not ready" because that would have left two failure paths:
async failures held, every other failure not, and the stuck-effect bug in place for
the second kind.

### `Async.make`

`Async.make(fetch)` is a `Computed.make` whose function calls `fetch()` — under
tracking, so what it reads before its first `await` is its dependencies — and returns:

- the previous value, if there is one (a fetch again);
- otherwise throws `NotReady`, which the cycle holds like any failure.

The fetch settles outside any run: the latest one (a version counter) writes the value
or the failure straight into the computed's cell, bumps its version and calls
`notifySubs`. Nothing re-runs `fetch`, since the dependencies have not changed.

A fetch that rejects, or `fetch` throwing before it returns a promise, is a failure,
and leaves no value: the next fetch reads as `NotReady` until it settles, as Xote's
`Resource` goes from `Failed` to `Pending`.

It is lazy, as computeds are: with nothing reading it, a dependency change fetches
again at the next read. An attached one fetches again as soon as the change happens.

### `NotReady` in effects

`runEffectBodyUntraced` catches `NotReady`: the run ends with no cleanup, having
subscribed to what it read, and the effect runs again when that changes. Any other
failure propagates as before.

### Loading, and `Async.isPending`

Two flags: `flag_fetching` on an async value with a fetch of its own in flight, and
`flag_deps_loading` on a computed whose last run read something loading. A read of
either increments `loadingReads`; `runComputedCycle` compares the counter before and
after the function to set or clear `flag_deps_loading`, so loading travels through
computeds without re-running them. `Async.isPending(fn)` compares it around `fn`, and
answers `true` for an `fn` that ends in `NotReady`. Its reads are tracked, so the
observer that asks is told when the answer changes.

### Cost

`Signal.get` and `Signal.peek` test one mask (`flag_slow_read`: dirty, detached,
errored, loading) and take a separate slow path only when it is set, so a read of a
plain signal or of a settled, attached computed is one test. The flag constants are
`@inline`, since the compiler otherwise loads each from the module at runtime.

Measured on the four cases below (minimum of 5–6 alternating runs, mixed value types,
Node 22): plain signal reads about 10% faster than before, computed reads (detached,
`peek`) about 6% slower, writes through a computed and an effect unchanged, and a
100-wide fan-out within the run-to-run noise of a few percent. Removing either the
inner `try` or the loading bookkeeping from the cycle made no measurable difference.

## Not done

- **Xote.** Xote wraps effect bodies and sends every failure to an error boundary, so
  `NotReady` would reach a boundary rather than a `Suspense`. Its renderer, Suspense
  and error boundaries need to learn the difference before Xote can use `Async`.
- **The queue after a throw.** An effect that throws out of a flush stays queued and
  can run twice on the next write. Older than this change, and left alone.
- **Cancellation.** A superseded fetch keeps running; only its result is ignored.
