open TestFramework
open Signals

let tests = suite(
  "Signal Tests",
  [
    test("create signal with initial value", () => {
      let signal = Signal.make(42)
      assertEqual(Signal.peek(signal), 42, ~message="Signal should have initial value 42")
    }),
    test("get signal value", () => {
      let signal = Signal.make("hello")
      assertEqual(Signal.get(signal), "hello", ~message="get should return signal value")
    }),
    test("set signal value", () => {
      let signal = Signal.make(10)
      Signal.set(signal, 20)
      assertEqual(Signal.peek(signal), 20, ~message="Signal value should be updated to 20")
    }),
    test("update signal with function", () => {
      let signal = Signal.make(5)
      Signal.update(signal, x => x * 2)
      assertEqual(Signal.peek(signal), 10, ~message="Signal should be updated to 10")
    }),
    test("signal with custom equals function", () => {
      let customEquals = (a, b) => a == b
      let signal = Signal.make(42, ~equals=customEquals)
      Signal.set(signal, 42)
      assertEqual(Signal.peek(signal), 42, ~message="Signal value should remain 42")
    }),
    test("signal with name", () => {
      let signal = Signal.make(100, ~name="counter")
      assertEqual(signal.name, Some("counter"), ~message="Signal should have name 'counter'")
    }),
    test("peek does not track dependencies", () => {
      let signal = Signal.make(1)
      let value = Signal.peek(signal)
      assertEqual(value, 1, ~message="peek should return value without tracking")
    }),
    test("multiple signals independence", () => {
      let signal1 = Signal.make(1)
      let signal2 = Signal.make(2)
      Signal.set(signal1, 10)
      Signal.set(signal2, 20)
      assertTrue(
        Signal.peek(signal1) == 10 && Signal.peek(signal2) == 20,
        ~message="Signals should be independent",
      )
    }),
    test("signal version increments on set", () => {
      let signal = Signal.make(0)
      let initialVersion = signal.version.contents
      Signal.set(signal, 1)
      assertTrue(
        signal.version.contents > initialVersion,
        ~message="Version should increment after set",
      )
    }),
    test("signal with boolean value", () => {
      let signal = Signal.make(true)
      Signal.set(signal, false)
      assertFalse(Signal.peek(signal), ~message="Boolean signal should be false")
    }),
    test("signal with array value", () => {
      let signal = Signal.make([1, 2, 3])
      Signal.update(signal, arr => Array.concat(arr, [4]))
      assertEqual(
        Array.length(Signal.peek(signal)),
        4,
        ~message="Array signal should have 4 elements",
      )
    }),
    test("signal equality prevents unnecessary updates", () => {
      let signal = Signal.make(42)
      let version1 = signal.version.contents
      Signal.set(signal, 42) // Same value
      let version2 = signal.version.contents
      assertEqual(version1, version2, ~message="Version should not change for equal values")
    }),
  ],
)
