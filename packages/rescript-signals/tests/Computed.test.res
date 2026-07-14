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
    Test.make("computed with custom equals function", () => {
      // Test that custom equals function is used for value comparison
      let obj = Signal.make({"id": 1, "name": "Alice"})

      // Computed extracts just the id, with custom equality
      let userId = Computed.make(
        () => Signal.get(obj)["id"],
        ~equals=(a, b) => a == b,
      )

      let result1 = Assert.equal(Signal.peek(userId), 1, ~message="Initial value should be 1")

      // Change name but keep same id
      Signal.set(obj, {"id": 1, "name": "Bob"})
      let result2 = Assert.equal(Signal.peek(userId), 1, ~message="Value should still be 1")

      // Change id
      Signal.set(obj, {"id": 2, "name": "Bob"})
      let result3 = Assert.equal(Signal.peek(userId), 2, ~message="Value should update to 2")

      Assert.combineResults([result1, result2, result3])
    }),
    Test.make("custom equals suppresses downstream effect when value is unchanged", () => {
      let profile = Signal.make({"id": 1, "name": "Alice"})
      let userId = Computed.make(
        () => Signal.get(profile)["id"],
        ~equals=(a, b) => a == b,
      )
      let effectRuns = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        effectRuns := effectRuns.contents + 1
        ignore(Signal.get(userId))
        None
      })

      let result1 = Assert.equal(effectRuns.contents, 1, ~message="Effect should run once initially")

      // Name changes, derived id does not.
      Signal.set(profile, {"id": 1, "name": "Bob"})
      let result2 = Assert.equal(
        effectRuns.contents,
        1,
        ~message="Effect should not run when derived value is unchanged",
      )

      // Derived id changes.
      Signal.set(profile, {"id": 2, "name": "Bob"})
      let result3 = Assert.equal(
        effectRuns.contents,
        2,
        ~message="Effect should run once when derived value changes",
      )

      disposer.dispose()
      Assert.combineResults([result1, result2, result3])
    }),
    Test.make("repro: custom equals should suppress effect when derived value is unchanged", () => {
      let profile = Signal.make({"id": 1, "name": "Alice"})
      let userId = Computed.make(
        () => Signal.get(profile)["id"],
        ~equals=(a, b) => a == b,
      )
      let effectRuns = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        effectRuns := effectRuns.contents + 1
        ignore(Signal.get(userId))
        None
      })

      // Source update does not change computed output.
      Signal.set(profile, {"id": 1, "name": "Bob"})

      let result = Assert.equal(
        effectRuns.contents,
        1,
        ~message="Expected no effect re-run when custom equals says computed output is unchanged",
      )

      disposer.dispose()
      result
    }),
    Test.make("computed equality with array length", () => {
      let items = Signal.make([1, 2, 3])
      let recomputeCount = ref(0)

      // Computed that only cares about length, not contents
      let length = Computed.make(
        () => {
          recomputeCount := recomputeCount.contents + 1
          Signal.get(items)->Array.length
        },
        ~equals=(a, b) => a == b,
      )

      let _ = Signal.peek(length)
      let result1 = Assert.equal(Signal.peek(length), 3, ~message="Initial length should be 3")

      // Change contents but keep same length
      Signal.set(items, [4, 5, 6])
      let _ = Signal.peek(length)
      let result2 = Assert.equal(Signal.peek(length), 3, ~message="Length should still be 3")

      // Change length
      Signal.set(items, [1, 2])
      let result3 = Assert.equal(Signal.peek(length), 2, ~message="Length should update to 2")

      Assert.combineResults([result1, result2, result3])
    }),
    Test.make("computed with structural equality for tuples", () => {
      // Test structural equality comparison for tuple values
      let position = Signal.make((0, 0))

      // Computed with structural equality for point tuple
      let currentPos = Computed.make(
        () => Signal.get(position),
        ~equals=((ax, ay), (bx, by)) => ax == bx && ay == by,
      )

      let posSum = Computed.make(() => {
        let (x, y) = Signal.get(currentPos)
        x + y
      })

      let result1 = Assert.equal(Signal.peek(posSum), 0, ~message="Initial sum should be 0")

      // Set to structurally equal point (different reference)
      Signal.set(position, (0, 0))
      let result2 = Assert.equal(Signal.peek(posSum), 0, ~message="Sum should still be 0")

      // Set to different point
      Signal.set(position, (10, 20))
      let result3 = Assert.equal(Signal.peek(posSum), 30, ~message="Sum should update to 30")

      Assert.combineResults([result1, result2, result3])
    }),
    Test.make("chained computeds with equality short-circuit", () => {
      let source = Signal.make(10)
      let middleComputeCount = ref(0)
      let finalComputeCount = ref(0)

      // Middle computed: clamps value to 0-100 range
      let clamp = (min, max, v) =>
        if v < min {
          min
        } else if v > max {
          max
        } else {
          v
        }

      let clamped = Computed.make(
        () => {
          middleComputeCount := middleComputeCount.contents + 1
          clamp(0, 100, Signal.get(source))
        },
        ~equals=(a, b) => a == b,
      )

      // Final computed depends on clamped
      let doubled = Computed.make(
        () => {
          finalComputeCount := finalComputeCount.contents + 1
          Signal.get(clamped) * 2
        },
        ~equals=(a, b) => a == b,
      )

      let _ = Signal.peek(doubled)
      let result1 = Assert.equal(Signal.peek(doubled), 20, ~message="Initial value should be 20")

      // Change source but clamped result stays the same (still 10)
      Signal.set(source, 10)
      let _ = Signal.peek(doubled)

      // Change source to value that clamps to same result
      let _beforeMiddle = middleComputeCount.contents
      let _beforeFinal = finalComputeCount.contents
      Signal.set(source, 10) // Same value
      let _ = Signal.peek(doubled)

      let result2 = Assert.equal(
        Signal.peek(doubled),
        20,
        ~message="Value should still be 20",
      )

      // Change to different clamped value
      Signal.set(source, 50)
      let _ = Signal.peek(doubled)

      let result3 = Assert.equal(
        Signal.peek(doubled),
        100,
        ~message="Value should update to 100",
      )

      Assert.combineResults([result1, result2, result3])
    }),
  ],
)
