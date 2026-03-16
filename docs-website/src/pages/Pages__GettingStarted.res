open Xote.ReactiveProp
open Basefn

@jsx.component
let make = () => {
  <div>
    <Typography
      text={static("Learn how to install and use rescript-signals in your project.")}
      variant={Lead}
    />
    <Separator />
    <div class="heading-anchor" id="installation">
      <Typography text={static("Installation")} variant={H2} />
      <a class="anchor-link" href="#installation"> {"#"->Xote.Component.text} </a>
    </div>
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
    <div class="heading-anchor" id="configuration">
      <Typography text={static("Configuration")} variant={H2} />
      <a class="anchor-link" href="#configuration"> {"#"->Xote.Component.text} </a>
    </div>
    <Typography text={static("Add rescript-signals to your rescript.json dependencies:")} />
    <CodeBlock
      language="json"
      code={`{
  "dependencies": [
    "rescript-signals"
  ]
}`}
    />
    <Separator />
    <div class="heading-anchor" id="core-concepts">
      <Typography text={static("Core Concepts")} variant={H2} />
      <a class="anchor-link" href="#core-concepts"> {"#"->Xote.Component.text} </a>
    </div>
    <Typography
      text={static(
        "rescript-signals provides three main primitives for building reactive applications:",
      )}
    />
    <div class="heading-anchor" id="signal">
      <Typography text={static("Signal")} variant={H3} />
      <a class="anchor-link" href="#signal"> {"#"->Xote.Component.text} </a>
    </div>
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
    <div class="heading-anchor" id="computed">
      <Typography text={static("Computed")} variant={H3} />
      <a class="anchor-link" href="#computed"> {"#"->Xote.Component.text} </a>
    </div>
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
    <div class="heading-anchor" id="effect">
      <Typography text={static("Effect")} variant={H3} />
      <a class="anchor-link" href="#effect"> {"#"->Xote.Component.text} </a>
    </div>
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
    <EditOnGitHub pageName="Pages__GettingStarted" />
  </div>
}
