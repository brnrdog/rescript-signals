open Signals
open Zekr
open Types
open ReactTestingUtils

// ---------------------------------------------------------------------------
// DOM query helpers
// ---------------------------------------------------------------------------

@send external querySelector: (Dom.element, string) => Dom.element = "querySelector"
@send @return(nullable)
external querySelectorOpt: (Dom.element, string) => option<Dom.element> = "querySelector"
@send external click: Dom.element => unit = "click"

// ---------------------------------------------------------------------------
// Suite 1: useSignalValue — Core subscription
// ---------------------------------------------------------------------------

module UseSignalValueTest = {
  module ReadValue = {
    @react.component
    let make = (~signal: Signal.t<int>) => {
      let value = SignalsReact.useSignalValue(signal)
      <div> {React.string(Int.toString(value))} </div>
    }
  }

  module TwoSignals = {
    @react.component
    let make = (~a: Signal.t<int>, ~b: Signal.t<string>) => {
      let aVal = SignalsReact.useSignalValue(a)
      let bVal = SignalsReact.useSignalValue(b)
      <div> {React.string(`${Int.toString(aVal)}-${bVal}`)} </div>
    }
  }

  let rendered = ref(None)

  let suite = Suite.make(
    "useSignalValue",
    [
      Test.make("reads current signal value", () => {
        let signal = Signal.make(42)
        let r = renderComponent(<ReadValue signal />)
        rendered := Some(r)
        Assert.equal(r.container->textContent, "42")
      }),
      Test.make("re-renders on signal change", () => {
        let signal = Signal.make(0)
        let r = renderComponent(<ReadValue signal />)
        rendered := Some(r)
        act(() => Signal.set(signal, 99))
        Assert.equal(r.container->textContent, "99")
      }),
      Test.make("tracks multiple signals", () => {
        let a = Signal.make(1)
        let b = Signal.make("hello")
        let r = renderComponent(<TwoSignals a b />)
        rendered := Some(r)
        Assert.combineResults([
          Assert.equal(r.container->textContent, "1-hello"),
          {
            act(() => {
              Signal.set(a, 5)
              Signal.set(b, "world")
            })
            Assert.equal(r.container->textContent, "5-world")
          },
        ])
      }),
      Test.make("stops notifying after unmount", () => {
        let signal = Signal.make(0)
        let r = renderComponent(<ReadValue signal />)
        cleanup(r)
        // Update signal after unmount — should not throw
        Signal.set(signal, 999)
        Pass
      }),
    ],
    ~afterEach=() => {
      switch rendered.contents {
      | Some(r) =>
        cleanup(r)
        rendered := None
      | None => ()
      }
    },
  )
}

// ---------------------------------------------------------------------------
// Suite 2: useSignal — Component-local state
// ---------------------------------------------------------------------------

module UseSignalTest = {
  module LocalSignal = {
    @react.component
    let make = (~init: int) => {
      let (value, _, setter) = SignalsReact.useSignal(() => init)
      <div>
        <span> {React.string(Int.toString(value))} </span>
        <button onClick={_ => setter(value + 1)}> {React.string("inc")} </button>
      </div>
    }
  }

  module BatchTest = {
    @react.component
    let make = () => {
      let (value, signal, setter) = SignalsReact.useSignal(() => 0)
      <div>
        <span> {React.string(Int.toString(value))} </span>
        <button
          onClick={_ =>
            Signal.batch(() => {
              setter(10)
              Signal.update(signal, n => n + 5)
            })}>
          {React.string("batch")}
        </button>
      </div>
    }
  }

  let rendered = ref(None)

  let suite = Suite.make(
    "useSignal",
    [
      Test.make("initializes with provided value", () => {
        let r = renderComponent(<LocalSignal init=7 />)
        rendered := Some(r)
        Assert.equal(r.container->querySelector("span")->textContent, "7")
      }),
      Test.make("setter updates value", () => {
        let r = renderComponent(<LocalSignal init=0 />)
        rendered := Some(r)
        let btn = r.container->querySelector("button")
        act(() => btn->click)
        Assert.equal(r.container->querySelector("span")->textContent, "1")
      }),
      Test.make("batched set + update", () => {
        let r = renderComponent(<BatchTest />)
        rendered := Some(r)
        let btn = r.container->querySelector("button")
        act(() => btn->click)
        // setter(10) then update(+5) => 15
        Assert.equal(r.container->querySelector("span")->textContent, "15")
      }),
    ],
    ~afterEach=() => {
      switch rendered.contents {
      | Some(r) =>
        cleanup(r)
        rendered := None
      | None => ()
      }
    },
  )
}

// ---------------------------------------------------------------------------
// Suite 3: useComputed — Derived signals
// ---------------------------------------------------------------------------

module UseComputedTest = {
  module Derived = {
    @react.component
    let make = (~a: Signal.t<int>, ~b: Signal.t<int>) => {
      let sum = SignalsReact.useComputed(() => Signal.get(a) + Signal.get(b))
      <div> {React.string(Int.toString(sum))} </div>
    }
  }

  module StaleClosureDemo = {
    @react.component
    let make = (~signal: Signal.t<int>) => {
      let (multiplier, setMultiplier) = React.useState(() => 2)
      let result = SignalsReact.useComputed(() => Signal.get(signal) * multiplier)
      <div>
        <span className="result"> {React.string(Int.toString(result))} </span>
        <button onClick={_ => setMultiplier(prev => prev + 1)}>
          {React.string("inc-mult")}
        </button>
      </div>
    }
  }

  let rendered = ref(None)

  let suite = Suite.make(
    "useComputed",
    [
      Test.make("derives value from source signals", () => {
        let a = Signal.make(3)
        let b = Signal.make(4)
        let r = renderComponent(<Derived a b />)
        rendered := Some(r)
        Assert.equal(r.container->textContent, "7")
      }),
      Test.make("updates when source signal changes", () => {
        let a = Signal.make(3)
        let b = Signal.make(4)
        let r = renderComponent(<Derived a b />)
        rendered := Some(r)
        act(() => Signal.set(a, 10))
        Assert.equal(r.container->textContent, "14")
      }),
      Test.make("stale closure captures React state once", () => {
        let signal = Signal.make(5)
        let r = renderComponent(<StaleClosureDemo signal />)
        rendered := Some(r)
        // Initial: 5 * 2 = 10
        let initial = r.container->querySelector(".result")->textContent
        // Click button to change multiplier from 2 -> 3
        let btn = r.container->querySelector("button")
        act(() => btn->click)
        // useComputed captured multiplier=2 in its closure and won't update
        let afterClick = r.container->querySelector(".result")->textContent
        Assert.combineResults([
          Assert.equal(initial, "10"),
          // Should still be 10 (5*2) because the closure is stale
          Assert.equal(afterClick, "10"),
        ])
      }),
    ],
    ~afterEach=() => {
      switch rendered.contents {
      | Some(r) =>
        cleanup(r)
        rendered := None
      | None => ()
      }
    },
  )
}

// ---------------------------------------------------------------------------
// Suite 4: useComputedWithDeps — Deps-aware derived signals
// ---------------------------------------------------------------------------

module UseComputedWithDepsTest = {
  module WithDeps = {
    @react.component
    let make = (~signal: Signal.t<int>) => {
      let (multiplier, setMultiplier) = React.useState(() => 2)
      let result = SignalsReact.useComputedWithDeps(
        () => Signal.get(signal) * multiplier,
        multiplier,
      )
      <div>
        <span className="result"> {React.string(Int.toString(result))} </span>
        <button onClick={_ => setMultiplier(prev => prev + 1)}>
          {React.string("inc-mult")}
        </button>
      </div>
    }
  }

  let rendered = ref(None)

  let suite = Suite.make(
    "useComputedWithDeps",
    [
      Test.make("rebuilds when deps change", () => {
        let signal = Signal.make(5)
        let r = renderComponent(<WithDeps signal />)
        rendered := Some(r)
        // Initial: 5 * 2 = 10
        let initial = r.container->querySelector(".result")->textContent
        // Change multiplier from 2 -> 3
        let btn = r.container->querySelector("button")
        act(() => btn->click)
        let afterClick = r.container->querySelector(".result")->textContent
        Assert.combineResults([
          Assert.equal(initial, "10"),
          // Should be 15 (5*3) because deps changed and computed rebuilt
          Assert.equal(afterClick, "15"),
        ])
      }),
      Test.make("still reacts to signal changes", () => {
        let signal = Signal.make(5)
        let r = renderComponent(<WithDeps signal />)
        rendered := Some(r)
        act(() => Signal.set(signal, 10))
        // 10 * 2 = 20
        Assert.equal(r.container->querySelector(".result")->textContent, "20")
      }),
    ],
    ~afterEach=() => {
      switch rendered.contents {
      | Some(r) =>
        cleanup(r)
        rendered := None
      | None => ()
      }
    },
  )
}

// ---------------------------------------------------------------------------
// Suite 5: useSignalEffect — Signal-tracking effects
// ---------------------------------------------------------------------------

module UseSignalEffectTest = {
  module EffectWriter = {
    @react.component
    let make = (~signal: Signal.t<int>, ~target: ref<int>) => {
      SignalsReact.useSignalEffect(() => {
        target := Signal.get(signal)
        None
      })
      <div> {React.string("effect-host")} </div>
    }
  }

  module EffectWithDisposal = {
    @react.component
    let make = (~disposed: ref<bool>) => {
      SignalsReact.useSignalEffect(() => {
        Some(() => disposed := true)
      })
      <div> {React.string("disposable")} </div>
    }
  }

  let rendered = ref(None)

  let suite = Suite.make(
    "useSignalEffect",
    [
      Test.make("runs effect on mount", () => {
        let signal = Signal.make(42)
        let target = ref(0)
        let r = renderComponent(<EffectWriter signal target />)
        rendered := Some(r)
        Assert.equal(target.contents, 42)
      }),
      Test.make("disposes on unmount", () => {
        let disposed = ref(false)
        let r = renderComponent(<EffectWithDisposal disposed />)
        cleanup(r)
        Assert.isTrue(disposed.contents)
      }),
    ],
    ~afterEach=() => {
      switch rendered.contents {
      | Some(r) =>
        cleanup(r)
        rendered := None
      | None => ()
      }
    },
  )
}

// ---------------------------------------------------------------------------
// Suite 6: Edge Cases
// ---------------------------------------------------------------------------

module EdgeCaseTest = {
  module DiamondDisplay = {
    @react.component
    let make = (~combined: Signal.t<int>) => {
      let combinedVal = SignalsReact.useSignalValue(combined)
      <div>
        <span className="combined"> {React.string(Int.toString(combinedVal))} </span>
      </div>
    }
  }

  module RenderCounter = {
    @react.component
    let make = (~a: Signal.t<int>, ~b: Signal.t<int>, ~c: Signal.t<int>, ~renderCount: ref<int>) => {
      let aVal = SignalsReact.useSignalValue(a)
      let bVal = SignalsReact.useSignalValue(b)
      let cVal = SignalsReact.useSignalValue(c)
      renderCount := renderCount.contents + 1
      <div> {React.string(`${Int.toString(aVal)}-${Int.toString(bVal)}-${Int.toString(cVal)}`)} </div>
    }
  }

  module RemountChild = {
    @react.component
    let make = () => {
      let (value, _, _) = SignalsReact.useSignal(() => 42)
      <span> {React.string(Int.toString(value))} </span>
    }
  }

  module RemountParent = {
    @react.component
    let make = () => {
      let (show, setShow) = React.useState(() => true)
      <div>
        {show ? <RemountChild /> : React.null}
        <button onClick={_ => setShow(prev => !prev)}> {React.string("toggle")} </button>
      </div>
    }
  }

  let rendered = ref(None)

  let suite = Suite.make(
    "Edge Cases",
    [
      Test.make("diamond dependency - no glitch", () => {
        let root = Signal.make(1)
        let left = Computed.make(() => Signal.get(root) * 2)
        let right = Computed.make(() => Signal.get(root) * 3)
        let recomputeCount = Signal.make(0)
        let combined = Computed.make(() => {
          Signal.update(recomputeCount, n => n + 1)
          Signal.get(left) + Signal.get(right)
        })
        let r = renderComponent(<DiamondDisplay combined />)
        rendered := Some(r)
        // Initial: left=2, right=3, combined=5
        let initialCombined = r.container->querySelector(".combined")->textContent
        // Reset recompute count after initial render
        Signal.set(recomputeCount, 0)
        // Increment root from 1 -> 2
        act(() => Signal.set(root, 2))
        let newCombined = r.container->querySelector(".combined")->textContent
        // left=4, right=6, combined=10
        Assert.combineResults([
          Assert.equal(initialCombined, "5"),
          Assert.equal(newCombined, "10"),
          // Combined should have recomputed exactly once for this update
          Assert.equal(Signal.peek(recomputeCount), 1),
        ])
      }),
      Test.make("batched updates - single notification", () => {
        let a = Signal.make(0)
        let b = Signal.make(0)
        let c = Signal.make(0)
        let renderCount = ref(0)
        let r = renderComponent(<RenderCounter a b c renderCount />)
        rendered := Some(r)
        let rendersAfterMount = renderCount.contents
        act(() => {
          Signal.batch(() => {
            Signal.set(a, 1)
            Signal.set(b, 2)
            Signal.set(c, 3)
          })
        })
        let rendersAfterBatch = renderCount.contents
        Assert.combineResults([
          Assert.equal(r.container->textContent, "1-2-3"),
          // Should have rendered at most once more after the batch
          Assert.lessThanOrEqual(rendersAfterBatch - rendersAfterMount, 1),
        ])
      }),
      Test.make("mount/unmount/remount cycle", () => {
        let r = renderComponent(<RemountParent />)
        rendered := Some(r)
        // Initial: child mounted with value 42
        let initialText = r.container->textContent
        // Unmount child
        let btn = r.container->querySelector("button")
        act(() => btn->click)
        let spanAfterUnmount = r.container->querySelectorOpt("span")
        // Remount child
        act(() => btn->click)
        let afterRemount = r.container->textContent
        Assert.combineResults([
          Assert.contains(initialText, "42"),
          Assert.none(spanAfterUnmount),
          Assert.contains(afterRemount, "42"),
        ])
      }),
    ],
    ~afterEach=() => {
      switch rendered.contents {
      | Some(r) =>
        cleanup(r)
        rendered := None
      | None => ()
      }
    },
  )
}

// ---------------------------------------------------------------------------
// Run all suites
// ---------------------------------------------------------------------------

Runner.runSuites([
  UseSignalValueTest.suite,
  UseSignalTest.suite,
  UseComputedTest.suite,
  UseComputedWithDepsTest.suite,
  UseSignalEffectTest.suite,
  EdgeCaseTest.suite,
])
