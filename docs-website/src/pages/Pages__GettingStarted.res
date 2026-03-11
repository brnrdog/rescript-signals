open Xote

@jsx.component
let make = () => {
  <div>
    <h1 class="page-title"> {"Getting Started"->Component.text} </h1>
    <p class="lead">
      {"Learn how to install and use rescript-signals in your project."->Component.text}
    </p>
    // Installation
    <h2 id="installation"> {"Installation"->Component.text} </h2>
    <p>
      {"Install rescript-signals using your preferred package manager:"->Component.text}
    </p>
    <CodeBlock.Tabbed
      tabs=[
        {label: "npm", code: "npm install rescript-signals", language: "bash"},
        {label: "yarn", code: "yarn add rescript-signals", language: "bash"},
        {label: "pnpm", code: "pnpm add rescript-signals", language: "bash"},
      ]
    />
    // Configuration
    <h2 id="configuration"> {"Configuration"->Component.text} </h2>
    <p>
      {"Add rescript-signals to your rescript.json dependencies:"->Component.text}
    </p>
    <CodeBlock
      language="json"
      filename="rescript.json"
      code={`{
  "dependencies": [
    "rescript-signals"
  ]
}`}
    />
    <Callout type_={Tip}>
      <p>
        {"Make sure you have ReScript 11+ installed. rescript-signals uses the latest ReScript features for optimal type inference."
        ->Component.text}
      </p>
    </Callout>
    // Core Concepts
    <h2 id="core-concepts"> {"Core Concepts"->Component.text} </h2>
    <p>
      {"rescript-signals provides three main primitives for building reactive applications:"
      ->Component.text}
    </p>
    // Signal
    <h3 id="signals"> {"Signal"->Component.text} </h3>
    <p>
      {"A reactive container that holds a value. When the value changes, all subscribers are automatically notified."
      ->Component.text}
    </p>
    <CodeBlock
      language="rescript"
      code={`let name = Signal.make("World")
let greeting = Signal.get(name) // "World"
Signal.set(name, "ReScript")`}
    />
    // Computed
    <h3 id="computed"> {"Computed"->Component.text} </h3>
    <p>
      {"A derived value that automatically recalculates when its dependencies change. Values are lazily evaluated and cached."
      ->Component.text}
    </p>
    <CodeBlock
      language="rescript"
      code={`let count = Signal.make(5)
let doubled = Computed.make(() => Signal.get(count) * 2)
Signal.get(doubled) // 10`}
    />
    // Effect
    <h3 id="effects"> {"Effect"->Component.text} </h3>
    <p>
      {"A side effect that runs when its dependencies change. Perfect for DOM updates, logging, or API calls."
      ->Component.text}
    </p>
    <CodeBlock
      language="rescript"
      code={`let count = Signal.make(0)
Effect.run(() => {
  Console.log(\`Count changed to: \${Signal.get(count)->Int.toString}\`)
})`}
    />
    <Callout type_={Note}>
      <p>
        {"Effects run immediately when created, and then re-run whenever any of their dependencies change."
        ->Component.text}
      </p>
    </Callout>
    // Next Steps
    <h2 id="next-steps"> {"Next Steps"->Component.text} </h2>
    <p>
      {"Now that you understand the basics, explore the API reference for each primitive:"
      ->Component.text}
    </p>
    <ul style="line-height: 2; padding-left: 1.5rem;">
      <li>
        <Router.Link to="/api/signal"> {"Signal API"->Component.text} </Router.Link>
        {" \u2014 Creating, reading, and updating reactive state"->Component.text}
      </li>
      <li>
        <Router.Link to="/api/computed"> {"Computed API"->Component.text} </Router.Link>
        {" \u2014 Derived values with automatic caching"->Component.text}
      </li>
      <li>
        <Router.Link to="/api/effect"> {"Effect API"->Component.text} </Router.Link>
        {" \u2014 Side effects with automatic cleanup"->Component.text}
      </li>
    </ul>
    <EditOnGitHub pageName="Pages__GettingStarted" />
  </div>
}
