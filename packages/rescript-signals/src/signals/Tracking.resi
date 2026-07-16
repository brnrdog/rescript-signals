/** A reactive scope driven externally (e.g. by a React render) rather than by
    the scheduler. When a tracked dependency changes the scope is *notified*,
    not recomputed — the driver re-establishes dependencies by calling `track`
    again. This enables single-pass dependency tracking during the render that
    displays the values. */
type scope

/** Create a scope. `onInvalidate` fires (synchronously, during the scheduler
    flush) whenever any signal read during the most recent `track` changes. */
let makeScope: (~onInvalidate: unit => unit) => scope

/** Run `body` as the current observer, reconciling this scope's dependency set
    to exactly the signals read during `body`, and return `body`'s result.
    Dependencies are re-discovered on every call, so conditional reads work. */
let track: (scope, unit => 'a) => 'a

/** Unsubscribe the scope from all tracked signals. */
let dispose: scope => unit

/** Whether the scope currently tracks no dependencies. */
let isEmpty: scope => bool
