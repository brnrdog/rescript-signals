@@warning("-44")
open Zekr
open Signals

exception Broken(int)

// Calls `read` and reports what it threw, or its value.
let attempt = (read: unit => int): string =>
  switch read() {
  | value => Int.toString(value)
  | exception Broken(n) => `broken ${Int.toString(n)}`
  }

// A JavaScript error, thrown as itself rather than as a ReScript exception.
let jsError: unit => Obj.t = %raw(`function () { return new Error("from js") }`)
let throwRaw: Obj.t => 'a = %raw(`function (value) { throw value }`)
let caughtRaw: (unit => 'a) => Obj.t = %raw(`function (fn) {
  try { fn() } catch (value) { return value }
  return undefined
}`)

let tests = Suite.make(
  "Failure Tests",
  [
    Test.make("a computed holds a failure until a dependency changes", () => {
      let source = Signal.make(1)
      let runs = ref(0)
      let checked = Computed.make(() => {
        runs := runs.contents + 1
        let value = Signal.get(source)
        if value < 0 {
          throw(Broken(value))
        }
        value
      })
      Signal.set(source, -1)
      let first = attempt(() => Signal.peek(checked))
      let again = attempt(() => Signal.peek(checked))
      let runsWhileFailed = runs.contents
      Signal.set(source, 2)
      Assert.combineResults([
        Assert.equal(first, "broken -1"),
        Assert.equal(again, "broken -1"),
        Assert.equal(runsWhileFailed, 2, ~message="the failure is held, not recomputed per read"),
        Assert.equal(attempt(() => Signal.peek(checked)), "2"),
      ])
    }),
    Test.make("Computed.make does not throw when its first run fails; a read does", () => {
      let source = Signal.make(-1)
      let checked = Computed.make(() => {
        let value = Signal.get(source)
        value < 0 ? throw(Broken(value)) : value
      })
      let failed = attempt(() => Signal.peek(checked))
      Signal.set(source, 3)
      Assert.combineResults([
        Assert.equal(failed, "broken -1"),
        Assert.equal(attempt(() => Signal.peek(checked)), "3"),
      ])
    }),
    Test.make("an effect reading a failed computed runs again when it recovers", () => {
      let source = Signal.make(1)
      let checked = Computed.make(() => {
        let value = Signal.get(source)
        value < 0 ? throw(Broken(value)) : value * 10
      })
      let seen = []
      Effect.run(() => {
        seen->Array.push(attempt(() => Signal.get(checked)))->ignore
        None
      })
      Signal.set(source, -2)
      Signal.set(source, 3)
      Signal.set(source, 4)
      Assert.equal(seen, ["10", "broken -2", "30", "40"])
    }),
    Test.make("an effect that throws a computed's failure runs again when it recovers", () => {
      let source = Signal.make(1)
      let checked = Computed.make(() => {
        let value = Signal.get(source)
        value < 0 ? throw(Broken(value)) : value
      })
      let seen = []
      Effect.run(() => {
        seen->Array.push(Signal.get(checked))->ignore
        None
      })
      let escaped = try {
        Signal.set(source, -1)
        false
      } catch {
      | Broken(_) => true
      }
      Signal.set(source, 5)
      // An effect that threw out of a flush stays queued (a separate, older
      // behaviour), so it may run more than once here; what matters is that
      // it runs again at all, and sees the recovery.
      Assert.combineResults([
        Assert.isTrue(escaped),
        Assert.equal(seen->Array.get(0), Some(1)),
        Assert.equal(seen->Array.at(-1), Some(5)),
      ])
    }),
    Test.make("a failure reaches what is computed from it, and so does the recovery", () => {
      let source = Signal.make(1)
      let checked = Computed.make(() => {
        let value = Signal.get(source)
        value < 0 ? throw(Broken(value)) : value
      })
      let doubled = Computed.make(() => Signal.get(checked) * 2)
      let seen = []
      Effect.run(() => {
        seen->Array.push(attempt(() => Signal.get(doubled)))->ignore
        None
      })
      Signal.set(source, -1)
      Signal.set(source, 4)
      Assert.equal(seen, ["2", "broken -1", "8"])
    }),
    Test.make("a computed with equals that recovers to its old value still notifies", () => {
      let source = Signal.make(1)
      let checked = Computed.make(() => {
        let value = Signal.get(source)
        value < 0 ? throw(Broken(value)) : value
      }, ~equals=(a, b) => a == b)
      let seen = []
      Effect.run(() => {
        seen->Array.push(attempt(() => Signal.get(checked)))->ignore
        None
      })
      Signal.set(source, -1)
      Signal.set(source, 1)
      Assert.equal(seen, ["1", "broken -1", "1"])
    }),
    Test.make("a JavaScript error is thrown again as itself", () => {
      let error = jsError()
      let source = Signal.make(true)
      let failing = Computed.make(() => Signal.get(source) ? throwRaw(error) : 1)
      let first = caughtRaw(() => Signal.peek(failing))
      let second = caughtRaw(() => Signal.peek(failing))
      Assert.combineResults([Assert.isTrue(first === error), Assert.isTrue(second === error)])
    }),
    Test.make("a cold computed holds its failure too", () => {
      let source = Signal.make(-1)
      let runs = ref(0)
      let checked = Computed.make(() => {
        runs := runs.contents + 1
        let value = Signal.get(source)
        value < 0 ? throw(Broken(value)) : value
      })
      let other = Signal.make(0)
      Signal.set(other, 1)
      let read = attempt(() => Signal.peek(checked))
      Assert.combineResults([Assert.equal(read, "broken -1"), Assert.equal(runs.contents, 1)])
    }),
  ],
)
