open Xote
open Xote.ReactiveProp
open Basefn

@jsx.component
let make = () => {
  <div>
    <Typography text={static("ReScript Signals")} variant={H1} />
    <Typography
      text={static(
        "A lightweight, high-performance reactive signals library for ReScript with zero runtime dependencies.",
      )}
      variant={Lead}
    />
    <Separator />
    <Grid columns={Count(3)} gap="1.5rem">
      <Card header="Zero Dependencies">
        <Typography
          text={static("Ships with no runtime dependencies for minimal bundle size.")}
        />
      </Card>
      <Card header="Fine-Grained Reactivity">
        <Typography
          text={static(
            "Automatic dependency tracking ensures only affected computations re-run.",
          )}
        />
      </Card>
      <Card header="Type Safe">
        <Typography
          text={static("Full ReScript type safety with inferred types throughout.")}
        />
      </Card>
    </Grid>
    <Separator />
    <Typography text={static("Quick Example")} variant={H2} />
    <Card>
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(0)

// Read the value (creates a dependency)
let value = Signal.get(count)

// Update the value
Signal.set(count, 5)

// Update based on previous value
Signal.update(count, n => n + 1)

// Derived values update automatically
let doubled = Computed.make(() => Signal.get(count) * 2)

// Side effects run when dependencies change
Effect.run(() => {
  Console.log(\`Count is: \${Signal.get(count)->Int.toString}\`)
})`}
      />
    </Card>
    <Separator />
    <div style="display: flex; gap: 1rem;">
      <Button variant={Primary} onClick={_ => Router.push("/getting-started", ())}>
        {Component.text("Get Started")}
      </Button>
      <Button variant={Secondary} onClick={_ => Router.push("/api/signal", ())}>
        {Component.text("API Reference")}
      </Button>
    </div>
  </div>
}
