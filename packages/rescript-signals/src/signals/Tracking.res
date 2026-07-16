// Framework-agnostic reactive scope for externally-driven consumers (e.g. a
// React render). Unlike an Effect, a scope is NOT recomputed by the scheduler
// when a dependency changes — it is only notified. The driver then re-runs its
// own body through `track`, which reconciles the scope's dependency set. This
// lets a UI framework establish dependencies during the very render that
// displays them (a single tracking pass).

type scope = {observer: Core.observer}

let makeScope = (~onInvalidate: unit => unit): scope => {
  let observer = Core.makeObserver(Id.make(), #Effect, onInvalidate)
  Core.setManualObs(observer)
  {observer: observer}
}

let track = (scope: scope, body: unit => 'a): 'a => Scheduler.track(scope.observer, body)

let dispose = (scope: scope): unit => Core.clearDeps(scope.observer)

let isEmpty = (scope: scope): bool => scope.observer.firstDep === None
