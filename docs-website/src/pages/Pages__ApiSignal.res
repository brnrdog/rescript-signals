open Xote
open Xote.ReactiveProp
open Basefn

@jsx.component
let make = () => {
  <div>
    <Typography
      text={static("The core reactive primitive for holding mutable state.")}
      variant={Lead}
    />
    <Separator />
    <div class="heading-anchor" id="creating-signals">
      <Typography text={static("Creating Signals")} variant={H2} />
      <a class="anchor-link" href="#creating-signals"> {"#"->Component.text} </a>
    </div>
    <div class="heading-anchor" id="signal-make">
      <Typography text={static("Signal.make(value)")} variant={H3} />
      <a class="anchor-link" href="#signal-make"> {"#"->Component.text} </a>
    </div>
    <Typography text={static("Creates a new signal with an initial value.")} />
    <CodeBlock
      language="rescript"
      code={`let count = Signal.make(0)
let name = Signal.make("Alice")
let items = Signal.make(["a", "b", "c"])`}
    />
    <div class="heading-anchor" id="signal-make-named">
      <Typography text={static("Signal.make(~name, value)")} variant={H3} />
      <a class="anchor-link" href="#signal-make-named"> {"#"->Component.text} </a>
    </div>
    <Typography text={static("Creates a named signal for debugging purposes.")} />
    <CodeBlock language="rescript" code={`let count = Signal.make(~name="counter", 0)`} />
    <Separator />
    <div class="heading-anchor" id="reading-signals">
      <Typography text={static("Reading Signals")} variant={H2} />
      <a class="anchor-link" href="#reading-signals"> {"#"->Component.text} </a>
    </div>
    <div class="heading-anchor" id="signal-get">
      <Typography text={static("Signal.get(signal)")} variant={H3} />
      <a class="anchor-link" href="#signal-get"> {"#"->Component.text} </a>
    </div>
    <Typography
      text={static(
        "Reads the current value and creates a dependency. When called inside a Computed or Effect, the computed/effect will re-run when this signal changes.",
      )}
    />
    <CodeBlock
      language="rescript"
      code={`let count = Signal.make(5)
let value = Signal.get(count) // 5

// Inside a computed — creates a dependency
let doubled = Computed.make(() => Signal.get(count) * 2)`}
    />
    <div class="heading-anchor" id="signal-peek">
      <Typography text={static("Signal.peek(signal)")} variant={H3} />
      <a class="anchor-link" href="#signal-peek"> {"#"->Component.text} </a>
    </div>
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
    <Separator />
    <div class="heading-anchor" id="updating-signals">
      <Typography text={static("Updating Signals")} variant={H2} />
      <a class="anchor-link" href="#updating-signals"> {"#"->Component.text} </a>
    </div>
    <div class="heading-anchor" id="signal-set">
      <Typography text={static("Signal.set(signal, value)")} variant={H3} />
      <a class="anchor-link" href="#signal-set"> {"#"->Component.text} </a>
    </div>
    <Typography text={static("Sets a new value for the signal.")} />
    <CodeBlock language="rescript" code={`Signal.set(count, 10)`} />
    <div class="heading-anchor" id="signal-update">
      <Typography text={static("Signal.update(signal, fn)")} variant={H3} />
      <a class="anchor-link" href="#signal-update"> {"#"->Component.text} </a>
    </div>
    <Typography text={static("Updates the signal value based on the previous value.")} />
    <CodeBlock
      language="rescript"
      code={`Signal.update(count, n => n + 1)
Signal.update(items, arr => Array.concat(arr, ["d"]))`}
    />
    <Separator />
    <div class="heading-anchor" id="batching-updates">
      <Typography text={static("Batching Updates")} variant={H2} />
      <a class="anchor-link" href="#batching-updates"> {"#"->Component.text} </a>
    </div>
    <div class="heading-anchor" id="signal-batch">
      <Typography text={static("Signal.batch(fn)")} variant={H3} />
      <a class="anchor-link" href="#signal-batch"> {"#"->Component.text} </a>
    </div>
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
    <Separator />
    <div class="heading-anchor" id="untracked-reads">
      <Typography text={static("Untracked Reads")} variant={H2} />
      <a class="anchor-link" href="#untracked-reads"> {"#"->Component.text} </a>
    </div>
    <div class="heading-anchor" id="signal-untrack">
      <Typography text={static("Signal.untrack(fn)")} variant={H3} />
      <a class="anchor-link" href="#signal-untrack"> {"#"->Component.text} </a>
    </div>
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
    <EditOnGitHub pageName="Pages__ApiSignal" />
  </div>
}
