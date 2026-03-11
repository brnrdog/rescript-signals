open Xote

@jsx.component
let make = () => {
  <div>
    <h1 class="page-title"> {"Signal"->Component.text} </h1>
    <p class="lead">
      {"The core reactive primitive for holding mutable state."->Component.text}
    </p>
    // Creating Signals
    <h2 id="creating-signals"> {"Creating Signals"->Component.text} </h2>
    <div class="api-signature">
      <div class="api-signature-header"> {"Signal.make(value)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Creates a new signal with an initial value."->Component.text}
      </div>
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(0)
let name = Signal.make("Alice")
let items = Signal.make(["a", "b", "c"])`}
      />
    </div>
    <div class="api-signature">
      <div class="api-signature-header"> {"Signal.make(~name, value)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Creates a named signal for debugging purposes."->Component.text}
      </div>
      <CodeBlock language="rescript" code={`let count = Signal.make(~name="counter", 0)`} />
    </div>
    // Reading Signals
    <h2 id="reading-signals"> {"Reading Signals"->Component.text} </h2>
    <div class="api-signature">
      <div class="api-signature-header"> {"Signal.get(signal)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Reads the current value and creates a dependency. When called inside a Computed or Effect, the computed/effect will re-run when this signal changes."
        ->Component.text}
      </div>
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(5)
let value = Signal.get(count) // 5

// Inside a computed - creates a dependency
let doubled = Computed.make(() => Signal.get(count) * 2)`}
      />
    </div>
    <div class="api-signature">
      <div class="api-signature-header"> {"Signal.peek(signal)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Reads the current value without creating a dependency. Useful when you need to read a value but don't want to trigger re-computation."
        ->Component.text}
      </div>
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(5)

// Won't create a dependency
let value = Signal.peek(count)`}
      />
    </div>
    <Callout type_={Tip}>
      <p>
        {"Use peek when you need to read a value in an effect without subscribing to future changes. This prevents unnecessary re-runs."
        ->Component.text}
      </p>
    </Callout>
    // Updating Signals
    <h2 id="updating-signals"> {"Updating Signals"->Component.text} </h2>
    <div class="api-signature">
      <div class="api-signature-header"> {"Signal.set(signal, value)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Sets a new value for the signal."->Component.text}
      </div>
      <CodeBlock language="rescript" code={`Signal.set(count, 10)`} />
    </div>
    <div class="api-signature">
      <div class="api-signature-header"> {"Signal.update(signal, fn)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Updates the signal value based on the previous value."->Component.text}
      </div>
      <CodeBlock
        language="rescript"
        code={`Signal.update(count, n => n + 1)
Signal.update(items, arr => Array.concat(arr, ["d"]))`}
      />
    </div>
    // Batching
    <h2 id="batching-updates"> {"Batching Updates"->Component.text} </h2>
    <div class="api-signature">
      <div class="api-signature-header"> {"Signal.batch(fn)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Batches multiple signal updates into a single notification cycle. Improves performance when updating many signals at once."
        ->Component.text}
      </div>
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
    </div>
    <Callout type_={Note}>
      <p>
        {"Batching is especially useful when updating multiple related signals simultaneously. Without batching, each set call would trigger dependent computations individually."
        ->Component.text}
      </p>
    </Callout>
    // Untracked
    <h2 id="untracked-reads"> {"Untracked Reads"->Component.text} </h2>
    <div class="api-signature">
      <div class="api-signature-header"> {"Signal.untrack(fn)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Reads signals without creating dependencies. Similar to peek but works for a block of code."
        ->Component.text}
      </div>
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
    </div>
    <Callout type_={Warning}>
      <p>
        {"Be careful with untrack \u2014 the computed will not re-run when untracked signals change, which can lead to stale values if not used intentionally."
        ->Component.text}
      </p>
    </Callout>
    <EditOnGitHub pageName="Pages__ApiSignal" />
  </div>
}
