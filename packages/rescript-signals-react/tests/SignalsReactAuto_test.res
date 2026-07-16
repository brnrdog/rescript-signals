open Signals
open Zekr
open Types
open ReactTestingUtils

@send external querySelector: (Dom.element, string) => Dom.element = "querySelector"
@send external click: Dom.element => unit = "click"

// ---------------------------------------------------------------------------
// Auto-tracking: Signal.get inside useTracked subscribes the component
// ---------------------------------------------------------------------------

module AutoTrackTest = {
  module Sum = {
    @react.component
    let make = (~a: Signal.t<int>, ~b: Signal.t<int>, ~renderCount: ref<int>) => {
      SignalsReactAuto.useTracked(() => {
        renderCount := renderCount.contents + 1
        <div> {React.string(Int.toString(Signal.get(a) + Signal.get(b)))} </div>
      })
    }
  }

  // Reads `other` only while `flag` is true — exercises dynamic dependencies.
  module Conditional = {
    @react.component
    let make = (~flag: Signal.t<bool>, ~other: Signal.t<int>) => {
      SignalsReactAuto.useTracked(() =>
        <div>
          {React.string(Signal.get(flag) ? Int.toString(Signal.get(other)) : "off")}
        </div>
      )
    }
  }

  // A React prop drives one part, a signal the other — proves no stale props.
  module PropAndSignal = {
    @react.component
    let make = (~label: string, ~signal: Signal.t<int>) => {
      SignalsReactAuto.useTracked(() =>
        <div> {React.string(`${label}:${Int.toString(Signal.get(signal))}`)} </div>
      )
    }
  }

  module PropParent = {
    @react.component
    let make = (~signal: Signal.t<int>) => {
      let (label, setLabel) = React.useState(() => "a")
      <div>
        <PropAndSignal label signal />
        <button onClick={_ => setLabel(_ => "b")}> {React.string("relabel")} </button>
      </div>
    }
  }

  let rendered = ref(None)

  let suite = Suite.make(
    "useTracked (auto-tracking)",
    [
      Test.make("subscribes to every signal read in the thunk", () => {
        let a = Signal.make(3)
        let b = Signal.make(4)
        let rc = ref(0)
        let r = renderComponent(<Sum a b renderCount=rc />)
        rendered := Some(r)
        Assert.combineResults([
          Assert.equal(r.container->textContent, "7"),
          {
            act(() => Signal.set(a, 10))
            Assert.equal(r.container->textContent, "14")
          },
          {
            act(() => Signal.set(b, 100))
            Assert.equal(r.container->textContent, "110")
          },
        ])
      }),
      Test.make("re-discovers dependencies (conditional reads)", () => {
        let flag = Signal.make(false)
        let other = Signal.make(1)
        let r = renderComponent(<Conditional flag other />)
        rendered := Some(r)
        Assert.combineResults([
          // flag=false: `other` is not read, so changing it must NOT re-render
          Assert.equal(r.container->textContent, "off"),
          {
            act(() => Signal.set(other, 42))
            Assert.equal(r.container->textContent, "off")
          },
          // flip flag on -> now `other` is tracked
          {
            act(() => Signal.set(flag, true))
            Assert.equal(r.container->textContent, "42")
          },
          {
            act(() => Signal.set(other, 99))
            Assert.equal(r.container->textContent, "99")
          },
        ])
      }),
      Test.make("no stale props: prop change re-renders with fresh value", () => {
        let signal = Signal.make(5)
        let r = renderComponent(<PropParent signal />)
        rendered := Some(r)
        let btn = r.container->querySelector("button")
        Assert.combineResults([
          Assert.contains(r.container->textContent, "a:5"),
          // change the signal -> tracked
          {
            act(() => Signal.set(signal, 6))
            Assert.contains(r.container->textContent, "a:6")
          },
          // change the React prop -> fresh label, signal value preserved
          {
            act(() => btn->click)
            Assert.contains(r.container->textContent, "b:6")
          },
          // still reactive after the prop-driven render
          {
            act(() => Signal.set(signal, 7))
            Assert.contains(r.container->textContent, "b:7")
          },
        ])
      }),
      Test.make("cost: single pass — thunk runs once per update", () => {
        let a = Signal.make(0)
        let b = Signal.make(0)
        let rc = ref(0)
        let r = renderComponent(<Sum a b renderCount=rc />)
        rendered := Some(r)
        // Mount: the display render is the tracking pass = 1
        let afterMount = rc.contents
        act(() => Signal.set(a, 1))
        // Each update: one React render, which re-establishes deps = 1
        let afterOneUpdate = rc.contents
        Assert.combineResults([
          Assert.equal(afterMount, 1),
          Assert.equal(afterOneUpdate - afterMount, 1),
        ])
      }),
      Test.make("stops notifying after unmount", () => {
        let a = Signal.make(0)
        let b = Signal.make(0)
        let rc = ref(0)
        let r = renderComponent(<Sum a b renderCount=rc />)
        cleanup(r)
        // Should not throw and should not re-render a disposed tree.
        Signal.set(a, 999)
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
// Explicit-dependency form: useSignals([dep(a), dep(b)])
// ---------------------------------------------------------------------------

module ExplicitDepsTest = {
  // Lists a and b, reads a, b, and a plain string prop c.
  module Listed = {
    @react.component
    let make = (~a: Signal.t<int>, ~b: Signal.t<int>, ~c: string) => {
      SignalsReactAuto.useSignals([SignalsReactAuto.dep(a), SignalsReactAuto.dep(b)])
      <div> {React.string(`${Int.toString(Signal.get(a) + Signal.get(b))}-${c}`)} </div>
    }
  }

  module Parent = {
    @react.component
    let make = (~a: Signal.t<int>, ~b: Signal.t<int>) => {
      let (c, setC) = React.useState(() => "x")
      <div>
        <Listed a b c />
        <button onClick={_ => setC(_ => "y")}> {React.string("setc")} </button>
      </div>
    }
  }

  // Reads `unlisted` but only lists `listed` — demonstrates the dep-array
  // footgun: the unlisted read does not cause a re-render.
  module ForgotToList = {
    @react.component
    let make = (~listed: Signal.t<int>, ~unlisted: Signal.t<int>) => {
      SignalsReactAuto.useSignals([SignalsReactAuto.dep(listed)])
      <div> {React.string(`${Int.toString(Signal.get(listed))}/${Int.toString(Signal.get(unlisted))}`)} </div>
    }
  }

  let rendered = ref(None)

  let suite = Suite.make(
    "useSignals (explicit deps)",
    [
      Test.make("re-renders when any listed signal changes", () => {
        let a = Signal.make(1)
        let b = Signal.make(2)
        let r = renderComponent(<Parent a b />)
        rendered := Some(r)
        Assert.combineResults([
          Assert.contains(r.container->textContent, "3-x"),
          {
            act(() => Signal.set(a, 10))
            Assert.contains(r.container->textContent, "12-x")
          },
          {
            act(() => Signal.set(b, 20))
            Assert.contains(r.container->textContent, "30-x")
          },
          // plain prop still flows through
          {
            act(() => r.container->querySelector("button")->click)
            Assert.contains(r.container->textContent, "30-y")
          },
        ])
      }),
      Test.make("does NOT re-render for a read-but-unlisted signal", () => {
        let listed = Signal.make(1)
        let unlisted = Signal.make(1)
        let r = renderComponent(<ForgotToList listed unlisted />)
        rendered := Some(r)
        Assert.combineResults([
          Assert.contains(r.container->textContent, "1/1"),
          // unlisted change: read value is stale until a listed change re-renders
          {
            act(() => Signal.set(unlisted, 99))
            Assert.contains(r.container->textContent, "1/1")
          },
          // listed change re-renders and picks up the latest unlisted value too
          {
            act(() => Signal.set(listed, 2))
            Assert.contains(r.container->textContent, "2/99")
          },
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

Runner.runSuites([AutoTrackTest.suite, ExplicitDepsTest.suite])
