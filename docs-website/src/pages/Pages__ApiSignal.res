
open Xote.ReactiveProp
open Basefn

@jsx.component
let make = () => {
  <div>
    <div>
    <Typography text={static("Signal")} variant={H1} />
    <Typography
      text={static("The core reactive primitive for holding mutable state.")}
      variant={Lead}
    />
    <Separator />
    <Typography text={static("Creating Signals")} variant={H2} />
    <Card header="Signal.make(value)">
      <Typography text={static("Creates a new signal with an initial value.")} />
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(0)
let name = Signal.make("Alice")
let items = Signal.make(["a", "b", "c"])`}
      />
    </Card>
    <Card header="Signal.make(~name, value)">
      <Typography text={static("Creates a named signal for debugging purposes.")} />
      <CodeBlock language="rescript" code={`let count = Signal.make(~name="counter", 0)`} />
    </Card>
    <Separator />
    <Typography text={static("Reading Signals")} variant={H2} />
    <Card header="Signal.get(signal)">
      <Typography
        text={static(
          "Reads the current value and creates a dependency. When called inside a Computed or Effect, the computed/effect will re-run when this signal changes.",
        )}
      />
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(5)
let value = Signal.get(count) // 5

// Inside a computed - creates a dependency
let doubled = Computed.make(() => Signal.get(count) * 2)`}
      />
    </Card>
    <Card header="Signal.peek(signal)">
      <Typography
        text={static(
          "Reads the current value without creating a dependency. Useful when you need to read a value but don't want to trigger re-computation.",
        )}
      />
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(5)

// Won't create a dependency
let value = Signal.peek(count)`}
      />
    </Card>
    <Separator />
    <Typography text={static("Updating Signals")} variant={H2} />
    <Card header="Signal.set(signal, value)">
      <Typography text={static("Sets a new value for the signal.")} />
      <CodeBlock language="rescript" code={`Signal.set(count, 10)`} />
    </Card>
    <Card header="Signal.update(signal, fn)">
      <Typography text={static("Updates the signal value based on the previous value.")} />
      <CodeBlock
        language="rescript"
        code={`Signal.update(count, n => n + 1)
Signal.update(items, arr => Array.concat(arr, ["d"]))`}
      />
    </Card>
    <Separator />
    <Typography text={static("Batching Updates")} variant={H2} />
    <Card header="Signal.batch(fn)">
      <Typography
        text={static(
          "Batches multiple signal updates into a single notification cycle. Improves performance when updating many signals at once.",
        )}
      />
      <CodeBlock
        language="rescript"
        code={`let firstName = Signal.make("John")
let lastName = Signal.make("Doe")

// Both updates trigger a single re-computation
Signal.batch(() => {
  Signal.set(firstName, "Jane")
  Signal.set(lastName, "Smith")
})`}
      />
    </Card>
    <Separator />
    <Typography text={static("Untracked Reads")} variant={H2} />
    <Card header="Signal.untrack(fn)">
      <Typography
        text={static(
          "Reads signals without creating dependencies. Similar to peek but works for a block of code.",
        )}
      />
      <CodeBlock
        language="rescript"
        code={`let a = Signal.make(1)
let b = Signal.make(2)

// Only depends on 'a', not 'b'
let computed = Computed.make(() => {
  let aVal = Signal.get(a)
  let bVal = Signal.untrack(() => Signal.get(b))
  aVal + bVal
})`}
      />
    </Card>
    </div>
    <EditOnGitHub pageName="Pages__ApiSignal" />
  </div>
}
