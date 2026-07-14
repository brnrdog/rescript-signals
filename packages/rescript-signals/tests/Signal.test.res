@@warning("-44")
open Zekr
open Signals

let tests = Suite.make(
  "Signal Tests",
  [
    Test.make("create signal with initial value", () => {
      let signal = Signal.make(42)
      Assert.equal(Signal.peek(signal), 42, ~message="Signal should have initial value 42")
    }),
    Test.make("get signal value", () => {
      let signal = Signal.make("hello")
      Assert.equal(Signal.get(signal), "hello", ~message="get should return signal value")
    }),
    Test.make("set signal value", () => {
      let signal = Signal.make(10)
      Signal.set(signal, 20)
      Assert.equal(Signal.peek(signal), 20, ~message="Signal value should be updated to 20")
    }),
    Test.make("update signal with function", () => {
      let signal = Signal.make(5)
      Signal.update(signal, x => x * 2)
      Assert.equal(Signal.peek(signal), 10, ~message="Signal should be updated to 10")
    }),
    Test.make("signal with custom equals function", () => {
      let customEquals = (a, b) => a == b
      let signal = Signal.make(42, ~equals=customEquals)
      Signal.set(signal, 42)
      Assert.equal(Signal.peek(signal), 42, ~message="Signal value should remain 42")
    }),
    Test.make("signal with name", () => {
      let signal = Signal.make(100, ~name="counter")
      Assert.equal(signal.name, Some("counter"), ~message="Signal should have name 'counter'")
    }),
    Test.make("peek does not track dependencies", () => {
      let signal = Signal.make(1)
      let value = Signal.peek(signal)
      Assert.equal(value, 1, ~message="peek should return value without tracking")
    }),
    Test.make("multiple signals independence", () => {
      let signal1 = Signal.make(1)
      let signal2 = Signal.make(2)
      Signal.set(signal1, 10)
      Signal.set(signal2, 20)
      Assert.isTrue(
        Signal.peek(signal1) == 10 && Signal.peek(signal2) == 20,
        ~message="Signals should be independent",
      )
    }),
    Test.make("signal version increments on set", () => {
      let signal = Signal.make(0)
      let initialVersion = signal.subs.version
      Signal.set(signal, 1)
      Assert.isTrue(
        signal.subs.version > initialVersion,
        ~message="Version should increment after set",
      )
    }),
    Test.make("signal with boolean value", () => {
      let signal = Signal.make(true)
      Signal.set(signal, false)
      Assert.isFalse(Signal.peek(signal), ~message="Boolean signal should be false")
    }),
    Test.make("signal with array value", () => {
      let signal = Signal.make([1, 2, 3])
      Signal.update(signal, arr => Array.concat(arr, [4]))
      Assert.equal(
        Array.length(Signal.peek(signal)),
        4,
        ~message="Array signal should have 4 elements",
      )
    }),
    Test.make("signal equality prevents unnecessary updates", () => {
      let signal = Signal.make(42)
      let version1 = signal.subs.version
      Signal.set(signal, 42) // Same value
      let version2 = signal.subs.version
      Assert.equal(version1, version2, ~message="Version should not change for equal values")
    }),
    Test.make("batch prevents redundant effect runs", () => {
      let a = Signal.make(0)
      let b = Signal.make(0)
      let c = Signal.make(0)
      let runCount = ref(0)

      let disposer = Effect.runWithDisposer(() => {
        let _ = Signal.get(a) + Signal.get(b) + Signal.get(c)
        runCount := runCount.contents + 1
        None
      })

      let afterInitial = runCount.contents

      Signal.batch(() => {
        Signal.set(a, 1)
        Signal.set(b, 2)
        Signal.set(c, 3)
      })

      let result1 = Assert.equal(
        runCount.contents,
        afterInitial + 1,
        ~message="Effect should run only once with batch",
      )

      let result2 = Assert.equal(
        (a.value, b.value, c.value),
        (1, 2, 3),
        ~message="Batched signal updates should run",
      )

      let result = Assert.combineResults([result1, result2])

      disposer.dispose()
      result
    }),
    Test.make("batch works with nested batches", () => {
      let signal = Signal.make(0)
      let runCount = ref(0)

      let disposer = Effect.runWithDisposer(() => {
        let _ = Signal.get(signal)
        runCount := runCount.contents + 1
        None
      })

      let afterInitial = runCount.contents

      Signal.batch(() => {
        Signal.set(signal, 1)
        Signal.batch(
          () => {
            Signal.set(signal, 2)
            Signal.set(signal, 3)
          },
        )
        Signal.set(signal, 4)
      })

      let result = Assert.equal(
        runCount.contents,
        afterInitial + 1,
        ~message="Nested batch should still run effect only once",
      )

      disposer.dispose()
      result
    }),
    Test.make("batch returns the function result", () => {
      let result = Signal.batch(() => {
        let x = 1 + 2
        let y = x * 2
        y + 10
      })

      Assert.equal(result, 16, ~message="Batch should return function result")
    }),
    Test.make("untrack prevents dependency tracking", () => {
      let tracked = Signal.make(1)
      let untracked = Signal.make(10)
      let runCount = ref(0)

      let disposer = Effect.runWithDisposer(() => {
        let _ = Signal.get(tracked)
        let _ = Signal.untrack(() => Signal.get(untracked))
        runCount := runCount.contents + 1
        None
      })

      let afterInitial = runCount.contents

      // Changing untracked signal should not trigger effect
      Signal.set(untracked, 20)

      let result1 = Assert.equal(
        runCount.contents,
        afterInitial,
        ~message="Effect should not run when untracked signal changes",
      )

      // Changing tracked signal should trigger effect
      Signal.set(tracked, 2)

      let result2 = Assert.equal(
        runCount.contents,
        afterInitial + 1,
        ~message="Effect should run when tracked signal changes",
      )

      disposer.dispose()
      Assert.combineResults([result1, result2])
    }),
    Test.make("untrack can be nested", () => {
      let a = Signal.make(1)
      let b = Signal.make(2)
      let c = Signal.make(3)
      let runCount = ref(0)

      let disposer = Effect.runWithDisposer(() => {
        let _ = Signal.get(a)
        let _ = Signal.untrack(
          () => {
            let _ = Signal.get(b)
            Signal.untrack(() => Signal.get(c))
          },
        )
        runCount := runCount.contents + 1
        None
      })

      let afterInitial = runCount.contents

      Signal.set(b, 20)
      Signal.set(c, 30)

      let result1 = Assert.equal(
        runCount.contents,
        afterInitial,
        ~message="Nested untrack should prevent tracking",
      )

      Signal.set(a, 10)

      let result2 = Assert.equal(
        runCount.contents,
        afterInitial + 1,
        ~message="Only tracked signal should trigger effect",
      )

      disposer.dispose()
      Assert.combineResults([result1, result2])
    }),
    Test.make("untrack returns the function result", () => {
      let signal = Signal.make(42)
      let result = Signal.untrack(() => {
        let value = Signal.get(signal)
        value * 2
      })

      Assert.equal(result, 84, ~message="Untrack should return function result")
    }),
  ],
)
