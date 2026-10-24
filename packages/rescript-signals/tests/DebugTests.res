@@warning("-44")
open Zekr
open Signals

// Record every event while `fn` runs, rendered as short strings that name nodes
// by their `~name` so the assertions read as the scenario they describe.
let record = (~captureStacks=false, fn: unit => unit): array<string> => {
  let names: Map.t<int, string> = Map.make()
  let log = []
  let nameOf = id => names->Map.get(id)->Option.getOr("#" ++ Int.toString(id))
  Debug.install({
    captureStacks,
    emit: event =>
      switch event {
      | Created({id, kind, name, stack}) =>
        let label = name->Option.getOr("#" ++ Int.toString(id))
        names->Map.set(id, label)
        let kind = switch kind {
        | #Signal => "signal"
        | #Computed => "computed"
        | #Effect => "effect"
        }
        let stack = stack->Option.isSome ? " +stack" : ""
        log->Array.push(`create ${kind} ${label}${stack}`)
      | Linked({source, target}) => log->Array.push(`link ${nameOf(source)} -> ${nameOf(target)}`)
      | Unlinked({source, target}) =>
        log->Array.push(`unlink ${nameOf(source)} -> ${nameOf(target)}`)
      | Written({id, changed}) =>
        log->Array.push(`write ${nameOf(id)}${changed ? "" : " (unchanged)"}`)
      | RunStart({id}) => log->Array.push(`run ${nameOf(id)}`)
      | RunEnd({id, changed, threw}) =>
        log->Array.push(
          `end ${nameOf(id)}${changed ? "" : " (same)"}${threw ? " (threw)" : ""}`,
        )
      | Disposed({id}) => log->Array.push(`dispose ${nameOf(id)}`)
      | Collected({id}) => log->Array.push(`collect ${nameOf(id)}`)
      | BatchStart => log->Array.push("batch {")
      | BatchEnd => log->Array.push("}")
      }->ignore,
  })
  try {
    fn()
  } catch {
  | exn =>
    Debug.uninstall()
    throw(exn)
  }
  Debug.uninstall()
  log
}

let tests = Suite.make(
  "Debug Hook Tests",
  [
    Test.make("nothing is emitted without a hook", () => {
      let count = Signal.make(0, ~name="count")
      Signal.set(count, 1)
      Assert.isFalse(Debug.enabled.contents, ~message="Debug should start disabled")
    }),
    Test.make("creation, linking and runs are reported in order", () => {
      let log = record(() => {
        let count = Signal.make(1, ~name="count")
        let doubled = Computed.make(() => Signal.get(count) * 2, ~name="doubled")
        Effect.run(() => {
          let _ = Signal.get(doubled)
          None
        }, ~name="log")
        Signal.set(count, 2)
      })
      Assert.equal(
        log,
        [
          "create signal count",
          "create computed doubled",
          "run doubled",
          "link count -> doubled",
          "end doubled",
          "create effect log",
          "run log",
          "link doubled -> log",
          "end log",
          "write count",
          /* Computeds are lazy: `doubled` recomputes when `log` pulls it. */
          "run log",
          "run doubled",
          "end doubled",
          "end log",
        ],
      )
    }),
    Test.make("an unchanged write is reported and causes nothing", () => {
      let log = record(() => {
        let count = Signal.make(1, ~name="count")
        Effect.run(() => {
          let _ = Signal.get(count)
          None
        }, ~name="log")
        Signal.set(count, 1)
      })
      Assert.equal(log->Array.slice(~start=-1), ["write count (unchanged)"])
    }),
    Test.make("a computed whose equals holds reports no change", () => {
      let log = record(() => {
        let count = Signal.make(1, ~name="count")
        let parity = Computed.make(() => mod(Signal.get(count), 2), ~name="parity", ~equals=(a, b) =>
          a == b
        )
        Effect.run(() => {
          let _ = Signal.get(parity)
          None
        }, ~name="log")
        Signal.set(count, 3)
      })
      Assert.equal(log->Array.slice(~start=-3), ["write count", "run parity", "end parity (same)"])
    }),
    Test.make("re-tracking reports dropped dependencies", () => {
      let log = record(() => {
        let flag = Signal.make(true, ~name="flag")
        let a = Signal.make(1, ~name="a")
        let b = Signal.make(2, ~name="b")
        Effect.run(() => {
          let _ = Signal.get(flag) ? Signal.get(a) : Signal.get(b)
          None
        }, ~name="pick")
        Signal.set(flag, false)
      })
      Assert.equal(
        log->Array.slice(~start=-5),
        ["write flag", "run pick", "link b -> pick", "unlink a -> pick", "end pick"],
      )
    }),
    Test.make("batches group the writes and the runs they cause", () => {
      let log = record(() => {
        let a = Signal.make(1, ~name="a")
        let b = Signal.make(2, ~name="b")
        Effect.run(() => {
          let _ = Signal.get(a) + Signal.get(b)
          None
        }, ~name="sum")
        Signal.batch(() => {
          Signal.set(a, 10)
          Signal.batch(() => Signal.set(b, 20))
        })
      })
      Assert.equal(
        log->Array.slice(~start=-6),
        ["batch {", "write a", "write b", "run sum", "end sum", "}"],
      )
    }),
    Test.make("disposal is reported for effects and computeds", () => {
      let log = record(() => {
        let count = Signal.make(1, ~name="count")
        let doubled = Computed.make(() => Signal.get(count) * 2, ~name="doubled")
        let effect = Effect.runWithDisposer(() => {
          let _ = Signal.get(count)
          None
        }, ~name="log")
        effect.dispose()
        effect.dispose()
        Computed.dispose(doubled)
      })
      Assert.equal(log->Array.slice(~start=-2), ["dispose log", "dispose doubled"])
    }),
    Test.make("a throwing run is reported", () => {
      let log = record(() => {
        let count = Signal.make(1, ~name="count")
        try {
          Effect.run(() => {
            if Signal.get(count) > 0 {
              throw(Failure("boom"))
            }
            None
          }, ~name="fails")
        } catch {
        | Failure(_) => ()
        }
      })
      Assert.equal(log->Array.slice(~start=-1), ["end fails (threw)"])
    }),
    Test.make("stacks are captured only when asked for", () => {
      let without = record(() => {
        let _ = Signal.make(0, ~name="plain")
      })
      let with_ = record(~captureStacks=true, () => {
        let _ = Signal.make(0, ~name="traced")
      })
      Assert.combineResults([
        Assert.equal(without, ["create signal plain"]),
        Assert.equal(with_, ["create signal traced +stack"]),
      ])
    }),
    Test.make("nodes created before install are invisible", () => {
      let early = Signal.make(1, ~name="early")
      let log = record(() => {
        Effect.run(() => {
          let _ = Signal.get(early)
          None
        }, ~name="late")
        Signal.set(early, 2)
      })
      Assert.equal(log, ["create effect late", "run late", "end late", "run late", "end late"])
    }),
    Test.make("inspect reads values, levels and edges", () => {
      let ids = []
      Debug.install({
        captureStacks: false,
        emit: event =>
          switch event {
          | Created({id}) => ids->Array.push(id)
          | _ => ()
          },
      })
      let count = Signal.make(2, ~name="count")
      let doubled = Computed.make(() => Signal.get(count) * 2, ~name="doubled")
      let effect = Effect.runWithDisposer(() => {
        let _ = Signal.get(doubled)
        None
      }, ~name="log")
      let (countId, doubledId, effectId) = switch ids {
      | [a, b, c] => (a, b, c)
      | _ => (-1, -1, -1)
      }
      let countNode = Debug.inspect(countId)
      let doubledNode = Debug.inspect(doubledId)
      let effectNode = Debug.inspect(effectId)
      let live = Debug.nodes()
      effect.dispose()
      let afterDispose = Debug.inspect(effectId)
      Debug.uninstall()
      let _ = count
      Assert.combineResults([
        Assert.equal(live, [countId, doubledId, effectId]),
        Assert.equal(countNode->Option.flatMap(n => n.value), Some(Obj.magic(2))),
        Assert.equal(countNode->Option.map(n => n.observers), Some([doubledId])),
        Assert.equal(doubledNode->Option.flatMap(n => n.value), Some(Obj.magic(4))),
        Assert.equal(doubledNode->Option.map(n => n.sources), Some([countId])),
        Assert.equal(doubledNode->Option.map(n => n.observers), Some([effectId])),
        Assert.equal(effectNode->Option.map(n => n.sources), Some([doubledId])),
        Assert.equal(effectNode->Option.map(n => n.value), Some(None)),
        Assert.equal(afterDispose->Option.map(n => n.disposed), Some(true)),
        Assert.equal(afterDispose->Option.map(n => n.sources), Some([])),
        Assert.equal(Debug.inspect(countId), None),
      ])
    }),
    Test.make("idOfSignal finds a signal's id from its record", () => {
      let ids = []
      Debug.install({
        captureStacks: false,
        emit: event =>
          switch event {
          | Created({id}) => ids->Array.push(id)
          | _ => ()
          },
      })
      let count = Signal.make(1, ~name="count")
      let doubled = Computed.make(() => Signal.get(count) * 2, ~name="doubled")
      let found = (Debug.idOfSignal(count), Debug.idOfSignal(doubled))
      Debug.uninstall()
      Assert.equal(found, (ids->Array.get(0), ids->Array.get(1)))
    }),
    Test.make("the library announces itself for devtools to find", () => {
      let found: bool = %raw(`(function () {
        var copies = globalThis[Symbol.for("rescript-signals.debug")]
        return Array.isArray(copies) && copies.length > 0 &&
          typeof copies[0].install === "function" && copies[0].version === 1
      })()`)
      Assert.isTrue(found)
    }),
  ],
)
