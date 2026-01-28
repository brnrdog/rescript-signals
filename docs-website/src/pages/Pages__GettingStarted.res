
open Xote.ReactiveProp
open Basefn

@jsx.component
let make = () => {
  <div>
    <Typography text={static("Getting Started")} variant={H1} />
    <Typography
      text={static("Learn how to install and use rescript-signals in your project.")}
      variant={Lead}
    />
    <Separator />
    <Typography text={static("Installation")} variant={H2} />
    <Typography
      text={static("Install rescript-signals using your preferred package manager:")}
    />
    <Tabs
      tabs=[
        {
          value: "npm",
          label: "npm",
          content: <CodeBlock language="bash" code="npm install rescript-signals" />,
        },
        {
          value: "yarn",
          label: "yarn",
          content: <CodeBlock language="bash" code="yarn add rescript-signals" />,
        },
        {
          value: "pnpm",
          label: "pnpm",
          content: <CodeBlock language="bash" code="pnpm add rescript-signals" />,
        },
      ]
    />
    <Separator />
    <Typography text={static("Configuration")} variant={H2} />
    <Typography text={static("Add rescript-signals to your rescript.json dependencies:")} />
    <Card>
      <CodeBlock
        language="json"
        code={`{
  "dependencies": [
    "rescript-signals"
  ]
}`}
      />
    </Card>
    <Separator />
    <Typography text={static("Core Concepts")} variant={H2} />
    <Typography
      text={static(
        "rescript-signals provides three main primitives for building reactive applications:",
      )}
    />
    <Grid columns={Count(1)} gap="1rem">
      <Card header="Signal">
        <Typography
          text={static(
            "A reactive container that holds a value. When the value changes, all subscribers are automatically notified.",
          )}
        />
        <CodeBlock
          language="rescript"
          code={`let name = Signal.make("World")
let greeting = Signal.get(name) // "World"
Signal.set(name, "ReScript")`}
        />
      </Card>
      <Card header="Computed">
        <Typography
          text={static(
            "A derived value that automatically recalculates when its dependencies change. Values are lazily evaluated and cached.",
          )}
        />
        <CodeBlock
          language="rescript"
          code={`let count = Signal.make(5)
let doubled = Computed.make(() => Signal.get(count) * 2)
Computed.get(doubled) // 10`}
        />
      </Card>
      <Card header="Effect">
        <Typography
          text={static(
            "A side effect that runs when its dependencies change. Perfect for DOM updates, logging, or API calls.",
          )}
        />
        <CodeBlock
          language="rescript"
          code={`let count = Signal.make(0)
Effect.run(() => {
  Console.log(\`Count changed to: \${Signal.get(count)->Int.toString}\`)
})`}
        />
      </Card>
    </Grid>
  </div>
}
