
open Xote.ReactiveProp
open Basefn

@jsx.component
let make = () => {
  <div>
    <Typography text={static("Effect")} variant={H1} />
    <Typography
      text={static("Side effects that automatically re-run when their dependencies change.")}
      variant={Lead}
    />
    <Separator />
    <Typography text={static("Creating Effects")} variant={H2} />
    <Card header="Effect.run(fn)">
      <Typography
        text={static(
          "Creates and immediately runs an effect. The effect re-runs whenever any signal or computed it reads changes.",
        )}
      />
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
    </Card>
    <Card header="Effect.run(~name, fn)">
      <Typography text={static("Creates a named effect for debugging.")} />
      <CodeBlock
        language="rescript"
        code={`Effect.run(~name="logger", () => {
  Console.log(Signal.get(count))
})`}
      />
    </Card>
    <Separator />
    <Typography text={static("Cleanup Functions")} variant={H2} />
    <Card header="Returning a Cleanup Function">
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

  // Cleanup function - runs before next execution
  Some(() => {
    Console.log(\`Cleaning up for: \${value->Int.toString}\`)
  })
})

Signal.set(count, 1)
// Logs: "Cleaning up for: 0"
// Logs: "Setting up for: 1"`}
      />
    </Card>
    <Separator />
    <Typography text={static("Disposal")} variant={H2} />
    <Card header="disposer.dispose()">
      <Typography
        text={static(
          "Effect.run returns a disposer object. Call dispose() to stop the effect and run any cleanup function.",
        )}
      />
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
    </Card>
    <Separator />
    <Typography text={static("Common Use Cases")} variant={H2} />
    <Grid columns={Count(1)} gap="1rem">
      <Card header="DOM Updates">
        <CodeBlock
          language="rescript"
          code={`let title = Signal.make("Hello")

Effect.run(() => {
  let el = Document.getElementById("title")
  el->Element.setTextContent(Signal.get(title))
  None
})`}
        />
      </Card>
      <Card header="Event Listeners">
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
      </Card>
      <Card header="Timers">
        <CodeBlock
          language="rescript"
          code={`let interval = Signal.make(1000)

Effect.run(() => {
  let ms = Signal.get(interval)
  let id = setInterval(() => Console.log("Tick!"), ms)
  Some(() => clearInterval(id))
})`}
        />
      </Card>
      <Card header="Local Storage Sync">
        <CodeBlock
          language="rescript"
          code={`let theme = Signal.make("light")

Effect.run(() => {
  let current = Signal.get(theme)
  LocalStorage.setItem("theme", current)
  None
})`}
        />
      </Card>
    </Grid>
  </div>
}
