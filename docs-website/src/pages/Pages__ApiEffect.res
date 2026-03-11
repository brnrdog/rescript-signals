open Xote

@jsx.component
let make = () => {
  <div>
    <h1 class="page-title"> {"Effect"->Component.text} </h1>
    <p class="lead">
      {"Side effects that automatically re-run when their dependencies change."->Component.text}
    </p>
    // Creating Effects
    <h2 id="creating-effects"> {"Creating Effects"->Component.text} </h2>
    <div class="api-signature">
      <div class="api-signature-header"> {"Effect.run(fn)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Creates and immediately runs an effect. The effect re-runs whenever any signal or computed it reads changes."
        ->Component.text}
      </div>
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(0)

let disposer = Effect.run(() => {
  Console.log(\`Count is: \${Signal.get(count)->Int.toString}\`)
})

// Logs: "Count is: 0"
Signal.set(count, 1)
// Logs: "Count is: 1"`}
      />
    </div>
    <div class="api-signature">
      <div class="api-signature-header"> {"Effect.run(~name, fn)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Creates a named effect for debugging."->Component.text}
      </div>
      <CodeBlock
        language="rescript"
        code={`Effect.run(~name="logger", () => {
  Console.log(Signal.get(count))
})`}
      />
    </div>
    // Cleanup
    <h2 id="cleanup-functions"> {"Cleanup Functions"->Component.text} </h2>
    <p>
      {"Effects can return a cleanup function that runs before the effect re-runs and when the effect is disposed."
      ->Component.text}
    </p>
    <CodeBlock
      language="rescript"
      code={`let count = Signal.make(0)

Effect.run(() => {
  let value = Signal.get(count)
  Console.log(\`Setting up for: \${value->Int.toString}\`)

  // Cleanup function - runs before next execution
  Some(() => {
    Console.log(\`Cleaning up for: \${value->Int.toString}\`)
  })
})

Signal.set(count, 1)
// Logs: "Cleaning up for: 0"
// Logs: "Setting up for: 1"`}
    />
    <Callout type_={Tip}>
      <p>
        {"Return Some(cleanupFn) to register cleanup, or None if no cleanup is needed. Cleanup runs both before re-execution and on disposal."
        ->Component.text}
      </p>
    </Callout>
    // Disposal
    <h2 id="disposal"> {"Disposal"->Component.text} </h2>
    <div class="api-signature">
      <div class="api-signature-header"> {"disposer.dispose()"->Component.text} </div>
      <div class="api-signature-desc">
        {"Effect.run returns a disposer object. Call dispose() to stop the effect and run any cleanup function."
        ->Component.text}
      </div>
      <CodeBlock
        language="rescript"
        code={`let disposer = Effect.run(() => {
  Console.log(Signal.get(count))
  Some(() => Console.log("Cleanup!"))
})

// Stop tracking and run cleanup
disposer.dispose()
// Logs: "Cleanup!"

// Future changes won't trigger the effect
Signal.set(count, 100) // Nothing logged`}
      />
    </div>
    <Callout type_={Warning}>
      <p>
        {"Always dispose of effects when they are no longer needed to prevent memory leaks and unintended side effects."
        ->Component.text}
      </p>
    </Callout>
    // Common Use Cases
    <h2 id="common-use-cases"> {"Common Use Cases"->Component.text} </h2>
    <h3 id="dom-updates"> {"DOM Updates"->Component.text} </h3>
    <CodeBlock
      language="rescript"
      code={`let title = Signal.make("Hello")

Effect.run(() => {
  let el = Document.getElementById("title")
  el->Element.setTextContent(Signal.get(title))
  None
})`}
    />
    <h3 id="event-listeners"> {"Event Listeners"->Component.text} </h3>
    <p>
      {"Use cleanup functions to properly remove event listeners when the effect re-runs or is disposed."
      ->Component.text}
    </p>
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
    <h3 id="timers"> {"Timers"->Component.text} </h3>
    <CodeBlock
      language="rescript"
      code={`let interval = Signal.make(1000)

Effect.run(() => {
  let ms = Signal.get(interval)
  let id = setInterval(() => Console.log("Tick!"), ms)
  Some(() => clearInterval(id))
})`}
    />
    <h3 id="local-storage"> {"Local Storage Sync"->Component.text} </h3>
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
