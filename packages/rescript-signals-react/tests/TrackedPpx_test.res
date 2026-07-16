open Signals
open Zekr
open ReactTestingUtils

// Compiled directly through rescript-tracked-ppx: the @tracked([...]) attribute
// is expanded to SignalsReactAuto.useSignals([dep(...), ...]) at compile time.

@send external querySelector: (Dom.element, string) => Dom.element = "querySelector"
@send external click: Dom.element => unit = "click"

module Counter = {
  @react.component
  let make = (~a: Signal.t<int>, ~b: Signal.t<int>, ~c: string) => {
    @tracked([a, b])
    <div> {React.string(`${Int.toString(Signal.get(a) + Signal.get(b))}-${c}`)} </div>
  }
}

module Parent = {
  @react.component
  let make = (~a: Signal.t<int>, ~b: Signal.t<int>) => {
    let (c, setC) = React.useState(() => "x")
    <div>
      <Counter a b c />
      <button onClick={_ => setC(_ => "y")}> {React.string("setc")} </button>
    </div>
  }
}

// Bare @tracked() — automatic discovery, no dependency list.
module Auto = {
  @react.component
  let make = (~x: Signal.t<int>) => {
    @tracked()
    <div> {React.string(Int.toString(Signal.get(x) * 2))} </div>
  }
}

let rendered = ref(None)

let suite = Suite.make(
  "tracked annotation (ppx)",
  [
    Test.make("@tracked([a, b]) subscribes to listed signals", () => {
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
    Test.make("@tracked() auto-discovers dependencies", () => {
      let x = Signal.make(5)
      let r = renderComponent(<Auto x />)
      rendered := Some(r)
      Assert.combineResults([
        Assert.equal(r.container->textContent, "10"),
        {
          act(() => Signal.set(x, 7))
          Assert.equal(r.container->textContent, "14")
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

Runner.runSuites([suite])
