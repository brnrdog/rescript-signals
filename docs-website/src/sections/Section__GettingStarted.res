open Xote

let configuration = `{
  "dependencies": ["rescript-signals"]
}`

let firstExample = `open Signals

let query = Signal.make("")
let results = Computed.make(() => search(Signal.get(query)))

Effect.run(() => {
  render(Signal.get(results))
  None
})

// Re-runs the search and the render, once
Signal.set(query, "Jorge Ben")`

let reactExample = `open Signals
open SignalsReact

let count = Signal.make(0)

@react.component
let make = () => {
  let value = useSignalValue(count)
  <span> {React.string(Int.toString(value))} </span>
}`

/* Numbered because installation genuinely is a sequence — each step depends on
   the one before it. */
let step = (~number: string, ~title: string, ~body: View.node) =>
  <li class="step">
    <span class="step-number"> {View.text(number)} </span>
    <div class="step-body">
      <h3 class="step-title"> {View.text(title)} </h3>
      body
    </div>
  </li>

@jsx.component
let make = () =>
  <section id="getting-started" class="section">
    <p class="section-label"> {View.text("Setup")} </p>
    <h2 class="section-title"> {View.text("Getting started")} </h2>
    <p class="section-lead">
      {View.text("Three steps, and nothing to wire up by hand afterwards.")}
    </p>
    <ol class="steps">
      {step(
        ~number="1",
        ~title="Install the package",
        ~body=<CodeBlock code={Section__Hero.installCommand} language="bash" />,
      )}
      {step(
        ~number="2",
        ~title="Declare it in rescript.json",
        ~body=View.fragment([
          <p> {View.text("The ReScript compiler resolves dependencies from this file.")} </p>,
          <CodeBlock code={configuration} language="json" />,
        ]),
      )}
      {step(
        ~number="3",
        ~title="Open Signals and build something",
        ~body=View.fragment([
          <p>
            {View.text("The package is namespaced, so ")}
            <code> {View.text("open Signals")} </code>
            {View.text(" brings ")}
            <code> {View.text("Signal")} </code>
            {View.text(", ")}
            <code> {View.text("Computed")} </code>
            {View.text(" and ")}
            <code> {View.text("Effect")} </code>
            {View.text(" into scope.")}
          </p>,
          <CodeBlock code={firstExample} />,
          <p class="step-note">
            {View.text(
              "Nothing subscribes by hand. The computed depends on the signal because it read it, the effect depends on the computed for the same reason, and writing to the signal is what re-runs them.",
            )}
          </p>,
        ]),
      )}
    </ol>
    <div class="aside">
      <h3 id="react" class="aside-title"> {View.text("Using React?")} </h3>
      <p>
        <a href="https://www.npmjs.com/package/rescript-signals-react">
          {View.text("rescript-signals-react")}
        </a>
        {View.text(
          " adapts signals to components through useSyncExternalStore: useSignalValue to subscribe to a signal, useSignal for component-local state, useComputed for derived values.",
        )}
      </p>
      <CodeBlock code={reactExample} />
    </div>
  </section>
