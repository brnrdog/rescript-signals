@@warning("-44")
open Zekr
open Signals

// Randomized property test over generated graphs, driven by a fixed-seed LCG so
// every run is reproducible.
//
// The property: once an operation has settled, every subscribed effect must have
// observed the current value of the node it watches. Subscribe/unsubscribe churn
// is the interesting part - it moves computeds between attached and detached, and
// a detached computed that fails to re-attach correctly silently stops delivering
// updates rather than throwing.

type liveEffect = {
  node: Signal.t<int>,
  last: ref<int>,
  disposer: Effect.disposer,
}

// Plain LCG on floats: the modulus does not fit in ReScript's 32-bit int, and the
// intermediate product stays well inside the exact range of a double.
let makeRng = (seed: int) => {
  let modulus = 4294967296.0
  let state = ref(seed->Int.toFloat)
  () => {
    let next = state.contents *. 1664525.0 +. 1013904223.0
    state := next -. Math.floor(next /. modulus) *. modulus
    (state.contents /. 65536.0)->Math.floor->Float.toInt
  }
}

let runTrials = (~seed: int, ~trials: int): int => {
  let violations = ref(0)
  let rng = makeRng(seed)
  let below = n => mod(rng(), n)

  for _ in 1 to trials {
    let signals = []
    for _ in 1 to 3 + below(3) {
      signals->Array.push(Signal.make(below(10)))
    }

    let nodes = []
    signals->Array.forEach(s => nodes->Array.push(s))
    let computeds = []

    for _ in 1 to 2 + below(6) {
      let a = nodes->Array.getUnsafe(below(nodes->Array.length))
      let b = nodes->Array.getUnsafe(below(nodes->Array.length))
      let op = below(3)
      let compute = () => {
        let x = Signal.get(a)
        let y = Signal.get(b)
        switch op {
        | 0 => x + y
        | 1 => x * 2 - y
        | _ => x > y ? x : y
        }
      }
      // Mix plain computeds with equality-carrying ones: they take different
      // notification paths (equality computeds defer their effects).
      let c = below(10) < 3 ? Computed.make(compute, ~equals=(p, n) => p == n) : Computed.make(compute)
      computeds->Array.push(c)
      nodes->Array.push(c)
    }

    let live: array<liveEffect> = []

    for _ in 1 to 40 {
      switch below(6) {
      | 0 =>
        let node = computeds->Array.getUnsafe(below(computeds->Array.length))
        let last = ref(0)
        let disposer = Effect.runWithDisposer(() => {
          last := Signal.get(node)
          None
        })
        live->Array.push({node, last, disposer})
      | 1 =>
        if live->Array.length > 0 {
          let idx = below(live->Array.length)
          switch live->Array.get(idx) {
          | Some(entry) =>
            entry.disposer.dispose()
            let _ = live->Array.splice(~start=idx, ~remove=1, ~insert=[])
          | None => ()
          }
        }
      | 2 =>
        let target = signals->Array.getUnsafe(below(signals->Array.length))
        Signal.set(target, below(20))
      | 3 =>
        let _ = Signal.get(computeds->Array.getUnsafe(below(computeds->Array.length)))
      | 4 =>
        let count = 1 + below(3)
        Signal.batch(() => {
          for _ in 1 to count {
            let target = signals->Array.getUnsafe(below(signals->Array.length))
            Signal.set(target, below(20))
          }
        })
      | _ =>
        let _ = Signal.peek(computeds->Array.getUnsafe(below(computeds->Array.length)))
      }

      live->Array.forEach(entry => {
        if entry.last.contents !== Signal.get(entry.node) {
          violations := violations.contents + 1
        }
      })
    }

    live->Array.forEach(entry => entry.disposer.dispose())
  }

  violations.contents
}

let tests = Suite.make(
  "Reactivity Property Tests",
  [
    Test.make("subscribed effects always observe the settled value", () => {
      let results = [1, 2, 3, 4, 5, 6, 7, 8]->Array.map(seed => {
        let violations = runTrials(~seed, ~trials=150)
        Assert.equal(
          violations,
          0,
          ~message=`Seed ${seed->Int.toString} produced ${violations->Int.toString} stale-effect violations`,
        )
      })
      Assert.combineResults(results)
    }),
  ],
)
