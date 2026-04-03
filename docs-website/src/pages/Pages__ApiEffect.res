open Xote
open Xote.ReactiveProp
open Basefn

@jsx.component
let make = () => {
  <div>
    <Typography
      text={static("Side effects that automatically re-run when their dependencies change.")}
      variant={Lead}
    />
    <Separator />
    <div class="heading-anchor" id="creating-effects">
      <Typography text={static("Creating Effects")} variant={H2} />
      <a class="anchor-link" href="#creating-effects"> {"#"->Component.text} </a>
    </div>
    <div class="heading-anchor" id="effect-run">
      <Typography text={static("Effect.run(fn)")} variant={H3} />
      <a class="anchor-link" href="#effect-run"> {"#"->Component.text} </a>
    </div>
    <Typography
      text={static(
        "Creates and immediately runs a fire-and-forget effect. The effect re-runs whenever any signal or computed it reads changes.",
      )}
    />
    <CodeBlock
      language="rescript"
      code={`let count = Signal.make(0)

Effect.run(() => {
  Console.log(\`Count is: \${Signal.get(count)->Int.toString}\`)
  None
})

// Logs: "Count is: 0"
Signal.set(count, 1)
// Logs: "Count is: 1"`}
    />
    <div class="heading-anchor" id="effect-run-with-disposer">
      <Typography text={static("Effect.runWithDisposer(fn)")} variant={H3} />
      <a class="anchor-link" href="#effect-run-with-disposer"> {"#"->Component.text} </a>
    </div>
    <Typography
      text={static(
        "Creates an effect and returns a disposer for manual cleanup. Use this when you need to stop the effect later.",
      )}
    />
    <CodeBlock
      language="rescript"
      code={`let count = Signal.make(0)

let disposer = Effect.runWithDisposer(() => {
  Console.log(\`Count is: \${Signal.get(count)->Int.toString}\`)
  None
})

Signal.set(count, 1)
// Logs: "Count is: 1"

disposer.dispose() // Stop the effect`}
    />
    <div class="heading-anchor" id="effect-run-named">
      <Typography text={static("Effect.run(~name, fn)")} variant={H3} />
      <a class="anchor-link" href="#effect-run-named"> {"#"->Component.text} </a>
    </div>
    <Typography text={static("Creates a named effect for debugging.")} />
    <CodeBlock
      language="rescript"
      code={`Effect.run(~name="logger", () => {
  Console.log(Signal.get(count))
  None
})`}
    />
    <Separator />
    <div class="heading-anchor" id="cleanup">
      <Typography text={static("Cleanup Functions")} variant={H2} />
      <a class="anchor-link" href="#cleanup"> {"#"->Component.text} </a>
    </div>
    <Typography
      text={static(
        "Effects can return a cleanup function that runs before the effect re-runs and when the effect is disposed.",
      )}
    />
    <CodeBlock
      language="rescript"
      code={`let count = Signal.make(0)

Effect.run(() => {
  let value = Signal.get(count)
  Console.log(\`Setting up for: \${value->Int.toString}\`)

  // Cleanup function — runs before next execution
  Some(() => {
    Console.log(\`Cleaning up for: \${value->Int.toString}\`)
  })
})

Signal.set(count, 1)
// Logs: "Cleaning up for: 0"
// Logs: "Setting up for: 1"`}
    />
    <Separator />
    <div class="heading-anchor" id="disposal">
      <Typography text={static("Disposal")} variant={H2} />
      <a class="anchor-link" href="#disposal"> {"#"->Component.text} </a>
    </div>
    <div class="heading-anchor" id="disposer-dispose">
      <Typography text={static("disposer.dispose()")} variant={H3} />
      <a class="anchor-link" href="#disposer-dispose"> {"#"->Component.text} </a>
    </div>
    <Typography
      text={static(
        "Effect.runWithDisposer returns a disposer object. Call dispose() to stop the effect and run any cleanup function.",
      )}
    />
    <CodeBlock
      language="rescript"
      code={`let disposer = Effect.runWithDisposer(() => {
  Console.log(Signal.get(count))
  Some(() => Console.log("Cleanup!"))
})

// Stop tracking and run cleanup
disposer.dispose()
// Logs: "Cleanup!"

// Future changes won't trigger the effect
Signal.set(count, 100) // Nothing logged`}
    />
    <Separator />
    <div class="heading-anchor" id="common-use-cases">
      <Typography text={static("Common Use Cases")} variant={H2} />
      <a class="anchor-link" href="#common-use-cases"> {"#"->Component.text} </a>
    </div>
    <div class="heading-anchor" id="dom-updates">
      <Typography text={static("DOM Updates")} variant={H3} />
      <a class="anchor-link" href="#dom-updates"> {"#"->Component.text} </a>
    </div>
    <CodeBlock
      language="rescript"
      code={`let title = Signal.make("Hello")

Effect.run(() => {
  let el = Document.getElementById("title")
  el->Element.setTextContent(Signal.get(title))
  None
})`}
    />
    <div class="heading-anchor" id="event-listeners">
      <Typography text={static("Event Listeners")} variant={H3} />
      <a class="anchor-link" href="#event-listeners"> {"#"->Component.text} </a>
    </div>
    <CodeBlock
      language="rescript"
      code={`let isActive = Signal.make(false)

Effect.run(() => {
  if Signal.get(isActive) {
    let handler = _ => Console.log("Clicked!")
    Window.addEventListener("click", handler)
    Some(() => Window.removeEventListener("click", handler))
  } else {
    None
  }
})`}
    />
    <div class="heading-anchor" id="timers">
      <Typography text={static("Timers")} variant={H3} />
      <a class="anchor-link" href="#timers"> {"#"->Component.text} </a>
    </div>
    <CodeBlock
      language="rescript"
      code={`let interval = Signal.make(1000)

Effect.run(() => {
  let ms = Signal.get(interval)
  let id = setInterval(() => Console.log("Tick!"), ms)
  Some(() => clearInterval(id))
})`}
    />
    <div class="heading-anchor" id="local-storage">
      <Typography text={static("Local Storage Sync")} variant={H3} />
      <a class="anchor-link" href="#local-storage"> {"#"->Component.text} </a>
    </div>
    <CodeBlock
      language="rescript"
      code={`let theme = Signal.make("light")

Effect.run(() => {
  let current = Signal.get(theme)
  LocalStorage.setItem("theme", current)
  None
})`}
    />
    <EditOnGitHub pageName="Pages__ApiEffect" />
  </div>
}
