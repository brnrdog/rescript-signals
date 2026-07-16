// Authored with the @tracked annotation. NOT compiled directly — the
// tracked-preprocess step expands it into tests/generated/, which is what
// ReScript builds. Edit this file, not the generated copy.

open Signals
open Zekr
open ReactTestingUtils

@send external querySelector: (Dom.element, string) => Dom.element = "querySelector"
@send external click: Dom.element => unit = "click"

// Explicit form: list the signal deps, read them (and a plain prop) freely.
module Explicit = {
  @react.component
  let make = (~a: Signal.t<int>, ~b: Signal.t<int>, ~c: string) => {
    @tracked(a, b)
    <div> {React.string(`${Int.toString(Signal.get(a) + Signal.get(b))}-${c}`)} </div>
  }
}

module ExplicitParent = {
  @react.component
  let make = (~a: Signal.t<int>, ~b: Signal.t<int>) => {
    let (c, setC) = React.useState(() => "x")
    <div>
      <Explicit a b c />
      <button onClick={_ => setC(_ => "y")}> {React.string("setc")} </button>
    </div>
  }
}

// Bare form: automatic discovery, no dep list.
module Auto = {
  @react.component
  let make = (~x: Signal.t<int>) => {
    @tracked
    <div> {React.string(Int.toString(Signal.get(x) * 2))} </div>
  }
}

let rendered = ref(None)

let suite = Suite.make(
  "@tracked annotation (preprocessed)",
  [
    Test.make("explicit @tracked(a, b) subscribes and reads props", () => {
      let a = Signal.make(1)
      let b = Signal.make(2)
      let r = renderComponent(<ExplicitParent a b />)
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
        {
          act(() => r.container->querySelector("button")->click)
          Assert.contains(r.container->textContent, "30-y")
        },
      ])
    }),
    Test.make("bare @tracked auto-discovers dependencies", () => {
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
