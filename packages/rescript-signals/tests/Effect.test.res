@@warning("-44")
open Zekr
open Types
open Signals

let tests = Suite.make(
  "Effect Tests",
  [
    Test.make("effect runs initially", () => {
      let runCount = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        runCount := runCount.contents + 1
        None
      })
      disposer.dispose()
      Assert.equal(runCount.contents, 1, ~message="Effect should run once initially")
    }),
    Test.make("effect runs when dependency changes", () => {
      let count = Signal.make(0)
      let runCount = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        let _ = Signal.get(count)
        runCount := runCount.contents + 1
        None
      })
      Signal.set(count, 1)
      disposer.dispose()
      Assert.equal(runCount.contents, 2, ~message="Effect should run again when signal changes")
    }),
    Test.make("effect with multiple dependencies", () => {
      let a = Signal.make(1)
      let b = Signal.make(2)
      let sum = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        sum := Signal.get(a) + Signal.get(b)
        None
      })
      let result1 = Assert.equal(sum.contents, 3, ~message="Initial sum should be 3")
      Signal.set(a, 5)
      let result2 = Assert.equal(sum.contents, 7, ~message="Sum should update to 7")
      disposer.dispose()
      Assert.combineResults([result1, result2])
    }),
    Test.make("effect cleanup runs on re-execution", () => {
      let count = Signal.make(0)
      let cleanupCount = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        let _ = Signal.get(count)
        Some(() => cleanupCount := cleanupCount.contents + 1)
      })
      Signal.set(count, 1)
      Signal.set(count, 2)
      disposer.dispose()
      Assert.isTrue(cleanupCount.contents >= 2, ~message="Cleanup should run on re-execution")
    }),
    Test.make("effect cleanup runs on disposal", () => {
      let cleaned = ref(false)
      let disposer = Effect.runWithDisposer(() => Some(() => cleaned := true))
      disposer.dispose()
      Assert.isTrue(cleaned.contents, ~message="Cleanup should run on disposal")
    }),
    Test.make("effect with conditional dependency", () => {
      let toggle = Signal.make(true)
      let a = Signal.make(1)
      let b = Signal.make(2)
      let result = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        result := if Signal.get(toggle) {
          Signal.get(a)
        } else {
          Signal.get(b)
        }
        None
      })
      let result1 = Assert.equal(result.contents, 1, ~message="Should read from signal a")
      Signal.set(toggle, false)
      let result2 = Assert.equal(result.contents, 2, ~message="Should read from signal b")
      disposer.dispose()
      Assert.combineResults([result1, result2])
    }),
    Test.make("nested effects", () => {
      let outer = Signal.make(0)
      let outerRuns = ref(0)
      let innerRuns = ref(0)
      let disposer1 = Effect.runWithDisposer(() => {
        let _ = Signal.get(outer)
        outerRuns := outerRuns.contents + 1
        None
      })
      let disposer2 = Effect.runWithDisposer(() => {
        let _ = Signal.get(outer)
        innerRuns := innerRuns.contents + 1
        None
      })
      Signal.set(outer, 1)
      disposer1.dispose()
      disposer2.dispose()
      Assert.isTrue(
        outerRuns.contents >= 1 && innerRuns.contents >= 1,
        ~message="Both effects should run",
      )
    }),
    Test.make("effect with computed dependency", () => {
      let base = Signal.make(2)
      let doubled = Computed.make(() => Signal.get(base) * 2)
      let result = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        result := Signal.get(doubled)
        None
      })
      let result1 = Assert.equal(result.contents, 4, ~message="Initial result should be 4")
      Signal.set(base, 3)
      let result2 = Assert.equal(result.contents, 6, ~message="Result should update to 6")
      disposer.dispose()
      Assert.combineResults([result1, result2])
    }),
    Test.make("effect disposal stops tracking", () => {
      let count = Signal.make(0)
      let runCount = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        let _ = Signal.get(count)
        runCount := runCount.contents + 1
        None
      })
      let runsBeforeDispose = runCount.contents
      disposer.dispose()
      Signal.set(count, 1)
      Signal.set(count, 2)
      Assert.equal(
        runCount.contents,
        runsBeforeDispose,
        ~message="Effect should not run after disposal",
      )
    }),
    Test.make("effect with array mutation tracking", () => {
      let items = Signal.make([1, 2, 3])
      let length = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        length := Array.length(Signal.get(items))
        None
      })
      let result1 = Assert.equal(length.contents, 3, ~message="Initial length should be 3")
      Signal.set(items, [1, 2, 3, 4])
      let result2 = Assert.equal(length.contents, 4, ~message="Length should update to 4")
      disposer.dispose()
      Assert.combineResults([result1, result2])
    }),
    Test.make("effect does not run for untracked signals", () => {
      let tracked = Signal.make(1)
      let untracked = Signal.make(10)
      let runCount = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        let _ = Signal.get(tracked)
        let _ = Signal.peek(untracked)
        runCount := runCount.contents + 1
        None
      })
      let initialRuns = runCount.contents
      Signal.set(untracked, 20)
      let result = Assert.equal(
        runCount.contents,
        initialRuns,
        ~message="Effect should not run for peeked signals",
      )
      disposer.dispose()
      result
    }),
    Test.make("flush drains effects enqueued by running effects", () => {
      let trigger = Signal.make(0)
      let derived = Signal.make(0)
      let derivedRuns = ref(0)

      let derivedDisposer = Effect.runWithDisposer(() => {
        ignore(Signal.get(derived))
        derivedRuns := derivedRuns.contents + 1
        None
      })

      let triggerDisposer = Effect.runWithDisposer(() => {
        let value = Signal.get(trigger)
        if value > 0 {
          Signal.set(derived, value)
        }
        None
      })

      Signal.set(trigger, 1)

      let result = Assert.equal(
        derivedRuns.contents,
        2,
        ~message="Derived effect should run in same flush when enqueued by another effect",
      )

      triggerDisposer.dispose()
      derivedDisposer.dispose()
      result
    }),
    Test.make("nested effect creation preserves outer effect dependency", () => {
      let trigger = Signal.make(0)
      let source = Signal.make(0)
      let outerRuns = ref(0)
      let innerDisposer: ref<option<Effect.disposer>> = ref(None)

      let outerDisposer = Effect.runWithDisposer(() => {
        let t = Signal.get(trigger)
        if t == 1 && innerDisposer.contents === None {
          let created = Effect.runWithDisposer(() => {
            ignore(Signal.get(source))
            None
          })
          innerDisposer := Some(created)
        }
        ignore(Signal.get(source))
        outerRuns := outerRuns.contents + 1
        None
      })

      Signal.set(trigger, 1)
      Signal.set(source, 1)

      let result = Assert.equal(
        outerRuns.contents,
        3,
        ~message="Outer effect should still rerun when source changes after nested effect creation",
      )

      switch innerDisposer.contents {
      | Some(disposer) => disposer.dispose()
      | None => ()
      }
      outerDisposer.dispose()
      result
    }),
    Test.make("nested computed creation preserves outer computed dependency", () => {
      let trigger = Signal.make(0)
      let source = Signal.make(0)

      let outerComputed = Computed.make(() => {
        ignore(Signal.get(trigger))
        let _nested = Computed.make(() => Signal.get(source) + 1)
        Signal.get(source)
      })

      let outerRuns = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        ignore(Signal.get(outerComputed))
        outerRuns := outerRuns.contents + 1
        None
      })

      Signal.set(trigger, 1)
      Signal.set(source, 1)

      let result = Assert.equal(
        outerRuns.contents,
        3,
        ~message="Outer computed should stay subscribed to source after nested computed creation",
      )

      disposer.dispose()
      result
    }),
    Test.make("multiple disposals are safe", () => {
      let disposer = Effect.runWithDisposer(() => None)
      disposer.dispose()
      disposer.dispose()
      Pass
    }),
  ],
)
