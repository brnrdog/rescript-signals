@@warning("-44")
open TestFramework
open Signals

let tests = suite(
  "Effect Tests",
  [
    test("effect runs initially", () => {
      let runCount = ref(0)
      let disposer = Effect.run(() => {
        runCount := runCount.contents + 1
        None
      })
      disposer.dispose()
      assertEqual(runCount.contents, 1, ~message="Effect should run once initially")
    }),
    test("effect runs when dependency changes", () => {
      let count = Signal.make(0)
      let runCount = ref(0)
      let disposer = Effect.run(() => {
        let _ = Signal.get(count)
        runCount := runCount.contents + 1
        None
      })
      Signal.set(count, 1)
      disposer.dispose()
      assertEqual(runCount.contents, 2, ~message="Effect should run again when signal changes")
    }),
    test("effect with multiple dependencies", () => {
      let a = Signal.make(1)
      let b = Signal.make(2)
      let sum = ref(0)
      let disposer = Effect.run(() => {
        sum := Signal.get(a) + Signal.get(b)
        None
      })
      let result1 = assertEqual(sum.contents, 3, ~message="Initial sum should be 3")
      Signal.set(a, 5)
      let result2 = assertEqual(sum.contents, 7, ~message="Sum should update to 7")
      disposer.dispose()
      combineResults([result1, result2])
    }),
    test("effect cleanup runs on re-execution", () => {
      let count = Signal.make(0)
      let cleanupCount = ref(0)
      let disposer = Effect.run(() => {
        let _ = Signal.get(count)
        Some(() => cleanupCount := cleanupCount.contents + 1)
      })
      Signal.set(count, 1)
      Signal.set(count, 2)
      disposer.dispose()
      assertTrue(cleanupCount.contents >= 2, ~message="Cleanup should run on re-execution")
    }),
    test("effect cleanup runs on disposal", () => {
      let cleaned = ref(false)
      let disposer = Effect.run(() => Some(() => cleaned := true))
      disposer.dispose()
      assertTrue(cleaned.contents, ~message="Cleanup should run on disposal")
    }),
    test("effect with conditional dependency", () => {
      let toggle = Signal.make(true)
      let a = Signal.make(1)
      let b = Signal.make(2)
      let result = ref(0)
      let disposer = Effect.run(() => {
        result := if Signal.get(toggle) {
          Signal.get(a)
        } else {
          Signal.get(b)
        }
        None
      })
      let result1 = assertEqual(result.contents, 1, ~message="Should read from signal a")
      Signal.set(toggle, false)
      let result2 = assertEqual(result.contents, 2, ~message="Should read from signal b")
      disposer.dispose()
      combineResults([result1, result2])
    }),
    test("nested effects", () => {
      let outer = Signal.make(0)
      let outerRuns = ref(0)
      let innerRuns = ref(0)
      let disposer1 = Effect.run(() => {
        let _ = Signal.get(outer)
        outerRuns := outerRuns.contents + 1
        None
      })
      let disposer2 = Effect.run(() => {
        let _ = Signal.get(outer)
        innerRuns := innerRuns.contents + 1
        None
      })
      Signal.set(outer, 1)
      disposer1.dispose()
      disposer2.dispose()
      assertTrue(
        outerRuns.contents >= 1 && innerRuns.contents >= 1,
        ~message="Both effects should run",
      )
    }),
    test("effect with computed dependency", () => {
      let base = Signal.make(2)
      let doubled = Computed.make(() => Signal.get(base) * 2)
      let result = ref(0)
      let disposer = Effect.run(() => {
        result := Signal.get(doubled)
        None
      })
      let result1 = assertEqual(result.contents, 4, ~message="Initial result should be 4")
      Signal.set(base, 3)
      let result2 = assertEqual(result.contents, 6, ~message="Result should update to 6")
      disposer.dispose()
      combineResults([result1, result2])
    }),
    test("effect disposal stops tracking", () => {
      let count = Signal.make(0)
      let runCount = ref(0)
      let disposer = Effect.run(() => {
        let _ = Signal.get(count)
        runCount := runCount.contents + 1
        None
      })
      let runsBeforeDispose = runCount.contents
      disposer.dispose()
      Signal.set(count, 1)
      Signal.set(count, 2)
      assertEqual(
        runCount.contents,
        runsBeforeDispose,
        ~message="Effect should not run after disposal",
      )
    }),
    test("effect with array mutation tracking", () => {
      let items = Signal.make([1, 2, 3])
      let length = ref(0)
      let disposer = Effect.run(() => {
        length := Array.length(Signal.get(items))
        None
      })
      let result1 = assertEqual(length.contents, 3, ~message="Initial length should be 3")
      Signal.set(items, [1, 2, 3, 4])
      let result2 = assertEqual(length.contents, 4, ~message="Length should update to 4")
      disposer.dispose()
      combineResults([result1, result2])
    }),
    test("effect does not run for untracked signals", () => {
      let tracked = Signal.make(1)
      let untracked = Signal.make(10)
      let runCount = ref(0)
      let disposer = Effect.run(() => {
        let _ = Signal.get(tracked)
        let _ = Signal.peek(untracked)
        runCount := runCount.contents + 1
        None
      })
      let initialRuns = runCount.contents
      Signal.set(untracked, 20)
      let result = assertEqual(
        runCount.contents,
        initialRuns,
        ~message="Effect should not run for peeked signals",
      )
      disposer.dispose()
      result
    }),
    test("multiple disposals are safe", () => {
      let disposer = Effect.run(() => None)
      disposer.dispose()
      disposer.dispose()
      Pass
    }),
  ],
)
