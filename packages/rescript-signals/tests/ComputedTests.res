@@warning("-44")
open Zekr
open Types
open Signals

let tests = Suite.make(
  "Computed Tests",
  [
    Test.make("computed from single signal", () => {
      let count = Signal.make(5)
      let doubled = Computed.make(() => Signal.get(count) * 2)
      Assert.equal(Signal.peek(doubled), 10, ~message="Computed should be 10 (5 * 2)")
    }),
    Test.make("computed updates when dependency changes", () => {
      let count = Signal.make(3)
      let doubled = Computed.make(() => Signal.get(count) * 2)
      Signal.set(count, 4)
      Assert.equal(Signal.peek(doubled), 8, ~message="Computed should update to 8 (4 * 2)")
    }),
    Test.make("computed from multiple signals", () => {
      let a = Signal.make(10)
      let b = Signal.make(5)
      let sum = Computed.make(() => Signal.get(a) + Signal.get(b))
      Assert.equal(Signal.peek(sum), 15, ~message="Computed sum should be 15")
    }),
    Test.make("computed updates when any dependency changes", () => {
      let a = Signal.make(10)
      let b = Signal.make(5)
      let sum = Computed.make(() => Signal.get(a) + Signal.get(b))
      Signal.set(a, 20)
      let result1 = Assert.equal(Signal.peek(sum), 25, ~message="Computed should update to 25")
      Signal.set(b, 10)
      let result2 = Assert.equal(Signal.peek(sum), 30, ~message="Computed should update to 30")
      Assert.combineResults([result1, result2])
    }),
    Test.make("chained computed signals", () => {
      let base = Signal.make(2)
      let doubled = Computed.make(() => Signal.get(base) * 2)
      let quadrupled = Computed.make(() => Signal.get(doubled) * 2)
      Assert.equal(Signal.peek(quadrupled), 8, ~message="Chained computed should be 8")
    }),
    Test.make("chained computed updates propagate", () => {
      let base = Signal.make(2)
      let doubled = Computed.make(() => Signal.get(base) * 2)
      let quadrupled = Computed.make(() => Signal.get(doubled) * 2)
      Signal.set(base, 3)
      Assert.equal(Signal.peek(quadrupled), 12, ~message="Chained computed should update to 12")
    }),
    Test.make("computed with conditional logic", () => {
      let value = Signal.make(5)
      let description = Computed.make(() =>
        if Signal.get(value) > 10 {
          "large"
        } else {
          "small"
        }
      )
      let result1 = Assert.equal(Signal.peek(description), "small", ~message="Should be 'small'")
      Signal.set(value, 15)
      let result2 = Assert.equal(
        Signal.peek(description),
        "large",
        ~message="Should update to 'large'",
      )
      Assert.combineResults([result1, result2])
    }),
    Test.make("computed with string concatenation", () => {
      let firstName = Signal.make("John")
      let lastName = Signal.make("Doe")
      let fullName = Computed.make(() => Signal.get(firstName) ++ " " ++ Signal.get(lastName))
      Assert.equal(Signal.peek(fullName), "John Doe", ~message="Full name should be 'John Doe'")
    }),
    Test.make("computed disposal", () => {
      let count = Signal.make(1)
      let doubled = Computed.make(() => Signal.get(count) * 2)
      Computed.dispose(doubled)
      Pass
    }),
    Test.make("computed with array operations", () => {
      let numbers = Signal.make([1, 2, 3])
      let sum = Computed.make(() => Signal.get(numbers)->Array.reduce(0, (acc, n) => acc + n))
      Assert.equal(Signal.peek(sum), 6, ~message="Sum should be 6")
    }),
    Test.make("computed recalculates lazily when read", () => {
      let count = Signal.make(0)
      let computeCount = ref(0)
      let computed = Computed.make(() => {
        computeCount := computeCount.contents + 1
        Signal.get(count) * 2
      })
      // First read triggers initial computation
      let _ = Signal.peek(computed)
      let afterFirstRead = computeCount.contents

      // Changes to signal should mark computed dirty but NOT recompute yet (lazy)
      Signal.set(count, 1)
      Signal.set(count, 2)
      Signal.set(count, 3)

      // Should still be the same (lazy - didn't recompute)
      let result1 = Assert.equal(
        computeCount.contents,
        afterFirstRead,
        ~message="Computed should not eagerly recalculate (lazy evaluation)",
      )

      Signal.set(count, 4)
      Signal.set(count, 5)

      // Should still be the same (lazy - didn't recompute)
      let result2 = Assert.equal(
        computeCount.contents,
        afterFirstRead,
        ~message="Computed should not eagerly recalculate (lazy evaluation)",
      )

      // Reading again should trigger recomputation
      let _ = Signal.peek(computed)
      let result3 = Assert.isTrue(
        computeCount.contents > afterFirstRead,
        ~message="Computed should recalculate when read after changes",
      )

      Assert.combineResults([result1, result2, result3])
    }),
    Test.make("computed with nested object access", () => {
      let obj = Signal.make({"value": 42})
      let extracted = Computed.make(() => Signal.get(obj)["value"])
      Assert.equal(Signal.peek(extracted), 42, ~message="Should extract nested value")
    }),
    Test.make("conditional reads return fresh data (auto-disposal fix)", () => {
      let count = Signal.make(0)
      let doubled = Computed.make(() => Signal.get(count) * 2)
      let show = Signal.make(true)
      let result = ref(0)

      let disposer = Effect.runWithDisposer(() => {
        if Signal.get(show) {
          result := Signal.get(doubled)
        }
        None
      })

      let result1 = Assert.equal(result.contents, 0, ~message="Initial result should be 0")

      Signal.set(show, false)
      Signal.set(count, 5)
      Signal.set(show, true)

      let result2 = Assert.equal(
        result.contents,
        10,
        ~message="Should get fresh computed value after conditional re-read",
      )

      disposer.dispose()
      Assert.combineResults([result1, result2])
    }),
  ],
)
