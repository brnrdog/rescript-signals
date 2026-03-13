open Xote

// ---- Helper bindings ----
module DomHelpers = {
  type target = {value: string}
  @get external target: Dom.event => target = "target"
  let targetValue = (evt: Dom.event): string => target(evt).value

  @val external setInterval: (unit => unit, int) => int = "setInterval"
  @val external clearInterval: int => unit = "clearInterval"
  @val external setTimeout: (unit => unit, int) => int = "setTimeout"

  type clipboard
  @val @scope("navigator") external clipboard: clipboard = "clipboard"
  @send external writeText: (clipboard, string) => Promise.t<unit> = "writeText"

  let copyToClipboard = (text: string): unit => {
    clipboard->writeText(text)->ignore
  }
}

// ---- Feature data ----
type feature = {
  title: string,
  description: string,
  iconName: Basefn.Icon.name,
  linkText: option<string>,
  linkTo: option<string>,
}

let features = [
  {
    title: "Zero Dependencies",
    description: "Ships with no runtime dependencies. Minimal bundle size for maximum performance in production.",
    iconName: Basefn.Icon.Download,
    linkText: Some("Get Started"),
    linkTo: Some("/getting-started"),
  },
  {
    title: "Fine-Grained Reactivity",
    description: "Automatic dependency tracking ensures only affected computations re-run. No unnecessary re-renders.",
    iconName: Basefn.Icon.Star,
    linkText: Some("Learn about Signals"),
    linkTo: Some("/api/signal"),
  },
  {
    title: "Type Safe",
    description: "Built for ReScript with full type inference. Catch errors at compile time, not at runtime.",
    iconName: Basefn.Icon.Check,
    linkText: Some("View API Reference"),
    linkTo: Some("/api/signal"),
  },
  {
    title: "Glitch-Free Updates",
    description: "Computed values are recalculated in topological order, preventing intermediate inconsistent states.",
    iconName: Basefn.Icon.Heart,
    linkText: None,
    linkTo: None,
  },
  {
    title: "Computed Values",
    description: "Derive reactive state with automatic caching. Values are lazily evaluated and only recompute when dependencies change.",
    iconName: Basefn.Icon.Edit,
    linkText: Some("Computed docs"),
    linkTo: Some("/api/computed"),
  },
  {
    title: "Effect System",
    description: "Run side effects when dependencies change, with automatic cleanup and disposal for resource management.",
    iconName: Basefn.Icon.ExternalLink,
    linkText: Some("Effect docs"),
    linkTo: Some("/api/effect"),
  },
]

// ---- Feature Card ----
module FeatureCard = {
  type props = {feature: feature}

  let make = (props: props) => {
    let {feature: f} = props
    <div class="feature-card">
      <div class="feature-card-icon">
        {Basefn.Icon.make({name: f.iconName, size: Md})}
      </div>
      <h3> {Component.text(f.title)} </h3>
      <p> {Component.text(f.description)} </p>
      {switch (f.linkText, f.linkTo) {
      | (Some(text), Some(to)) =>
        Router.link(
          ~to,
          ~attrs=[Component.attr("class", "feature-card-link")],
          ~children=[
            Component.text(text ++ " "),
            Basefn.Icon.make({name: ChevronRight, size: Sm}),
          ],
          (),
        )
      | _ => Component.fragment([])
      }}
    </div>
  }
}

// ---- Hero ----
module Hero = {
  type props = {}

  let make = (_props: props) => {
    <section class="hero">
      <div class="hero-inner">
        <h1>
          {Component.text("Reactive state with ")}
          <em> {Component.text("fine-grained signals")} </em>
          {Component.text(" for ")}
          <em> {Component.text("ReScript")} </em>
        </h1>
        <p class="hero-subtitle">
          {Component.text(
            "A lightweight, high-performance reactive signals library with zero dependencies, fine-grained reactivity, and full type safety.",
          )}
        </p>
        <div class="hero-buttons">
          {Router.link(
            ~to="/getting-started",
            ~attrs=[Component.attr("class", "btn btn-primary")],
            ~children=[
              Component.text("Get Started "),
              Basefn.Icon.make({name: ChevronRight, size: Sm}),
            ],
            (),
          )}
          <a href="https://github.com/brnrdog/rescript-signals" target="_blank" class="btn btn-ghost">
            {Basefn.Icon.make({name: GitHub, size: Sm})}
            {Component.text(" View on GitHub")}
          </a>
        </div>
      </div>
    </section>
  }
}

// ---- Features Section ----
module Features = {
  type props = {}

  let make = (_props: props) => {
    <section class="features-section">
      <div class="features-inner">
        <div class="features-heading">
          <h2> {Component.text("Everything you need for reactive state")} </h2>
          <p>
            {Component.text(
              "Signals, computed values, and effects \u2014 three powerful primitives for predictable, efficient reactivity.",
            )}
          </p>
        </div>
        <div class="features-grid">
          {Component.fragment(features->Array.map(f => <FeatureCard feature={f} />))}
        </div>
      </div>
    </section>
  }
}

// ---- Interactive Code Demo ----
module CodeDemo = {
  type props = {}

  module CounterApp = {
    type props = {}
    let make = (_props: props) => {
      let count = Signal.make(0)
      let increment = (_evt: Dom.event) => Signal.update(count, n => n + 1)
      let decrement = (_evt: Dom.event) => Signal.update(count, n => n - 1)
      let reset = (_evt: Dom.event) => Signal.set(count, 0)

      <div class="counter-app">
        <div class="counter-display">
          {Component.textSignal(() => Signal.get(count)->Int.toString)}
        </div>
        <div class="counter-buttons">
          <button onClick={decrement} class="counter-btn"> {Component.text("-")} </button>
          <button onClick={reset} class="counter-btn counter-btn-reset">
            {Component.text("Reset")}
          </button>
          <button onClick={increment} class="counter-btn"> {Component.text("+")} </button>
        </div>
      </div>
    }
  }

  module TemperatureApp = {
    type props = {}
    let make = (_props: props) => {
      let celsius = Signal.make(0.0)
      let fahrenheit = Computed.make(() => Signal.get(celsius) *. 9.0 /. 5.0 +. 32.0)
      let kelvin = Computed.make(() => Signal.get(celsius) +. 273.15)

      let handleInput = (evt: Dom.event) => {
        let value = DomHelpers.targetValue(evt)
        switch value->Float.fromString {
        | Some(num) => Signal.set(celsius, num)
        | None => ()
        }
      }

      <div class="temp-app">
        <div class="temp-input-group">
          <label class="temp-label"> {Component.text("Celsius")} </label>
          {Component.input(
            ~attrs=[
              Component.attr("type", "number"),
              Component.attr("class", "temp-input"),
              Component.attr("placeholder", "0"),
            ],
            ~events=[("input", handleInput)],
            (),
          )}
        </div>
        <div class="temp-results">
          <div class="temp-result">
            <span class="temp-result-label"> {Component.text("Fahrenheit")} </span>
            <span class="temp-result-value">
              {Component.textSignal(() => Signal.get(fahrenheit)->Float.toFixed(~digits=1))}
            </span>
          </div>
          <div class="temp-result">
            <span class="temp-result-label"> {Component.text("Kelvin")} </span>
            <span class="temp-result-value">
              {Component.textSignal(() => Signal.get(kelvin)->Float.toFixed(~digits=1))}
            </span>
          </div>
        </div>
      </div>
    }
  }

  module TimerApp = {
    type props = {}
    let make = (_props: props) => {
      let isRunning = Signal.make(false)
      let seconds = Signal.make(0)

      let _ = Effect.run(() => {
        if Signal.get(isRunning) {
          let id = DomHelpers.setInterval(() => Signal.update(seconds, s => s + 1), 1000)
          Some(() => DomHelpers.clearInterval(id))
        } else {
          None
        }
      })->ignore

      let toggleTimer = (_evt: Dom.event) => Signal.update(isRunning, r => !r)
      let resetTimer = (_evt: Dom.event) => {
        Signal.set(isRunning, false)
        Signal.set(seconds, 0)
      }

      <div class="timer-app">
        <div class="timer-display">
          {Component.textSignal(() => {
            let s = Signal.get(seconds)
            let mins = s / 60
            let secs = mod(s, 60)
            `${mins->Int.toString->String.padStart(2, "0")}:${secs->Int.toString->String.padStart(2, "0")}`
          })}
        </div>
        <div class="timer-buttons">
          <button onClick={toggleTimer} class="timer-btn timer-btn-primary">
            {Component.textSignal(() => Signal.get(isRunning) ? "Pause" : "Start")}
          </button>
          <button onClick={resetTimer} class="timer-btn"> {Component.text("Reset")} </button>
        </div>
      </div>
    }
  }

  let counterCode = `open RescriptSignals

let count = Signal.make(0)

let increment = (_evt) =>
  Signal.update(count, n => n + 1)

let decrement = (_evt) =>
  Signal.update(count, n => n - 1)

// Read the current value
let value = Signal.get(count)

// Update based on previous value
Signal.update(count, n => n + 1)`

  let tempCode = `open RescriptSignals

let celsius = Signal.make(0.0)

// Computed values auto-update
let fahrenheit = Computed.make(() =>
  Signal.get(celsius) *. 9.0 /. 5.0 +. 32.0
)

let kelvin = Computed.make(() =>
  Signal.get(celsius) +. 273.15
)

// When celsius changes, both
// fahrenheit and kelvin update
// automatically`

  let timerCode = `open RescriptSignals

let isRunning = Signal.make(false)
let seconds = Signal.make(0)

// Effect with cleanup callback
let _ = Effect.run(() => {
  if Signal.get(isRunning) {
    let id = setInterval(
      () => Signal.update(seconds, s => s + 1),
      1000
    )
    // Cleanup: clear interval
    Some(() => clearInterval(id))
  } else {
    None
  }
})`

  let make = (_props: props) => {
    let activeTab = Signal.make("counter")
    let copied = Signal.make(false)

    let setTab = (tab: string) => (_evt: Dom.event) => Signal.set(activeTab, tab)

    let handleCopy = (_evt: Dom.event) => {
      let snippet = switch Signal.peek(activeTab) {
      | "counter" => counterCode
      | "temperature" => tempCode
      | _ => timerCode
      }
      DomHelpers.copyToClipboard(snippet)
      Signal.set(copied, true)
      let _ = DomHelpers.setTimeout(() => Signal.set(copied, false), 2000)
    }

    <section class="code-demo-section">
      <div class="code-demo-inner">
        <div class="code-demo-heading">
          <h2> {Component.text("Signals, Computeds, and Effects")} </h2>
          <p>
            {Component.text(
              "Three powerful building blocks for seamless reactivity. Your mental model stays simple and predictable.",
            )}
          </p>
        </div>
        <div class="code-demo-container">
          <div class="code-editor-pane">
            <div class="code-editor-tabs">
              {Component.element(
                "div",
                ~attrs=[
                  Component.computedAttr("class", () =>
                    "code-editor-tab" ++ (Signal.get(activeTab) == "counter" ? " active" : "")
                  ),
                ],
                ~events=[("click", setTab("counter"))],
                ~children=[Component.text("Counter.res")],
                (),
              )}
              {Component.element(
                "div",
                ~attrs=[
                  Component.computedAttr("class", () =>
                    "code-editor-tab" ++ (Signal.get(activeTab) == "temperature" ? " active" : "")
                  ),
                ],
                ~events=[("click", setTab("temperature"))],
                ~children=[Component.text("Temperature.res")],
                (),
              )}
              {Component.element(
                "div",
                ~attrs=[
                  Component.computedAttr("class", () =>
                    "code-editor-tab" ++ (Signal.get(activeTab) == "timer" ? " active" : "")
                  ),
                ],
                ~events=[("click", setTab("timer"))],
                ~children=[Component.text("Timer.res")],
                (),
              )}
            </div>
            <div class="code-editor-body">
              {Component.element(
                "button",
                ~attrs=[
                  Component.computedAttr("class", () =>
                    "code-copy-btn" ++ (Signal.get(copied) ? " copied" : "")
                  ),
                ],
                ~events=[("click", handleCopy)],
                ~children=[
                  Component.signalFragment(
                    Computed.make(() =>
                      Signal.get(copied)
                        ? [Basefn.Icon.make({name: Check, size: Sm}), Component.text(" Copied")]
                        : [Basefn.Icon.make({name: Copy, size: Sm}), Component.text(" Copy")]
                    ),
                  ),
                ],
                (),
              )}
              <pre class="code-editor-pre">
                <code>
                  {Component.signalFragment(
                    Computed.make(() => {
                      let code = switch Signal.get(activeTab) {
                      | "counter" => counterCode
                      | "temperature" => tempCode
                      | _ => timerCode
                      }
                      [SyntaxHighlight.highlight(code)]
                    }),
                  )}
                </code>
              </pre>
            </div>
          </div>
          <div class="code-preview-pane">
            <div class="code-preview-header">
              <div class="browser-dots">
                <span class="browser-dot browser-dot-red" />
                <span class="browser-dot browser-dot-yellow" />
                <span class="browser-dot browser-dot-green" />
              </div>
              <div class="browser-url"> {Component.text("localhost:5173")} </div>
            </div>
            <div class="code-preview-body">
              {Component.signalFragment(
                Computed.make(() =>
                  switch Signal.get(activeTab) {
                  | "counter" => [<CounterApp />]
                  | "temperature" => [<TemperatureApp />]
                  | _ => [<TimerApp />]
                  }
                ),
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  }
}

// ---- Community Section ----
module Community = {
  type props = {}

  let make = (_props: props) => {
    <section class="community-section">
      <div class="community-inner">
        <h2> {Component.text("Get started today")} </h2>
        <p>
          {Component.text(
            "rescript-signals is open source, zero-dependency, and built for developers who value simplicity, type safety, and fine-grained reactivity.",
          )}
        </p>
        <div class="community-links">
          <a href="https://github.com/brnrdog/rescript-signals" target="_blank" class="btn btn-ghost">
            {Basefn.Icon.make({name: GitHub, size: Sm})}
            {Component.text(" GitHub")}
          </a>
          <a href="https://www.npmjs.com/package/rescript-signals" target="_blank" class="btn btn-ghost">
            {Basefn.Icon.make({name: Download, size: Sm})}
            {Component.text(" npm")}
          </a>
          {Router.link(
            ~to="/examples",
            ~attrs=[Component.attr("class", "btn btn-ghost")],
            ~children=[
              Basefn.Icon.make({name: Star, size: Sm}),
              Component.text(" Examples"),
            ],
            (),
          )}
        </div>
      </div>
    </section>
  }
}

// ---- Main page component ----
type props = {}

let make = (_props: props) => {
  <Layout children={Component.fragment([<Hero />, <Features />, <CodeDemo />, <Community />])} />
}
