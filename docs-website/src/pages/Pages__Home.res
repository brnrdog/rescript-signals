open Xote
open Basefn

@jsx.component
let make = () => {
  // Tab state
  let demoTab = Signal.make(0)

  // --- Tab 0: Signals & Computed ---
  let demoCount = Signal.make(0)
  let demoCountText = Computed.make(() => Signal.get(demoCount)->Int.toString)
  let demoDoubled = Computed.make(() => Signal.get(demoCount) * 2)
  let demoDoubledText = Computed.make(() => Signal.get(demoDoubled)->Int.toString)

  // --- Tab 1: Batching ---
  let firstName = Signal.make("John")
  let lastName = Signal.make("Doe")
  let fullName = Computed.make(() => Signal.get(firstName) ++ " " ++ Signal.get(lastName))
  let batchLog: Signal.t<array<string>> = Signal.make([])
  let renderCount = Signal.make(0)
  let _ = Effect.run(() => {
    let _fn = Signal.get(fullName)
    Signal.update(renderCount, n => n + 1)
    None
  })

  // --- Tab 2: Untracked Reads ---
  let trackedVal = Signal.make(1)
  let untrackedVal = Signal.make(10)
  let trackedResult = Computed.make(() => {
    let a = Signal.get(trackedVal)
    let b = Signal.untrack(() => Signal.get(untrackedVal))
    a + b
  })
  let untrackedLog: Signal.t<array<string>> = Signal.make([])

  let demoCode0 = `let count = Signal.make(0)

// Derived value \u2014 auto-updates
let doubled = Computed.make(() =>
  Signal.get(count) * 2
)

// Side effect \u2014 runs on change
Effect.run(() => {
  let v = Signal.get(count)
  Console.log(\`Count: \${v->Int.toString}\`)
})`

  let demoCode1 = `let firstName = Signal.make("John")
let lastName = Signal.make("Doe")
let fullName = Computed.make(() =>
  Signal.get(firstName) ++ " " ++
  Signal.get(lastName)
)

// Without batching: 2 re-computations
Signal.set(firstName, "Jane")
Signal.set(lastName, "Smith")

// With batching: only 1 re-computation
Signal.batch(() => {
  Signal.set(firstName, "Jane")
  Signal.set(lastName, "Smith")
})`

  let demoCode2 = `let tracked = Signal.make(1)
let untracked = Signal.make(10)

// Only re-runs when 'tracked' changes
let result = Computed.make(() => {
  let a = Signal.get(tracked)
  let b = Signal.untrack(() =>
    Signal.get(untracked)
  )
  a + b
})

Signal.set(tracked, 2)    // result updates
Signal.set(untracked, 20) // result unchanged`

  <div>
    // Hero Section
    <section class="hero">
      <div class="hero-bg" />
      <div class="hero-content">
        <h1 class="hero-title">
          {"Fine-grained reactivity"->Component.text}
          <br />
          {"for "->Component.text}
          <span style="color: var(--text-accent);"> {"ReScript"->Component.text} </span>
        </h1>
        <p class="hero-subtitle">
          {"A lightweight, high-performance reactive signals library with zero runtime dependencies. Automatic dependency tracking, batched updates, and full type safety."
          ->Component.text}
        </p>
        <div class="hero-actions">
          <Router.Link to="/getting-started" class="btn btn-primary">
            {"Get Started \u2192"->Component.text}
          </Router.Link>
          <a
            class="btn btn-ghost"
            href="https://github.com/brnrdog/rescript-signals"
            target="_blank">
            {"View on GitHub"->Component.text}
          </a>
        </div>
      </div>
    </section>
    // Features Grid
    <section class="features-grid" style="margin-top: 1rem;">
      <div class="feature-card reveal">
        <div class="feature-icon">
          <Icon name={Download} size={Sm} />
        </div>
        <div class="feature-title"> {"Zero Dependencies"->Component.text} </div>
        <div class="feature-desc">
          {"Ships with no runtime dependencies for minimal bundle size. Pure ReScript implementation with no external overhead."
          ->Component.text}
        </div>
      </div>
      <div class="feature-card reveal">
        <div class="feature-icon">
          <Icon name={Star} size={Sm} />
        </div>
        <div class="feature-title"> {"Fine-Grained Updates"->Component.text} </div>
        <div class="feature-desc">
          {"Automatic dependency tracking ensures only affected computations re-run. No unnecessary renders or wasted cycles."
          ->Component.text}
        </div>
      </div>
      <div class="feature-card reveal">
        <div class="feature-icon">
          <Icon name={Check} size={Sm} />
        </div>
        <div class="feature-title"> {"Type Safe"->Component.text} </div>
        <div class="feature-desc">
          {"Full ReScript type safety with inferred types throughout. Catch errors at compile time, not runtime."
          ->Component.text}
        </div>
      </div>
      <div class="feature-card reveal">
        <div class="feature-icon">
          <Icon name={AlertCircle} size={Sm} />
        </div>
        <div class="feature-title"> {"Glitch-Free"->Component.text} </div>
        <div class="feature-desc">
          {"Derived values never see inconsistent states. Updates are batched and computed in topological order."
          ->Component.text}
        </div>
      </div>
      <div class="feature-card reveal">
        <div class="feature-icon">
          <Icon name={Loader} size={Sm} />
        </div>
        <div class="feature-title"> {"Lazy Evaluation"->Component.text} </div>
        <div class="feature-desc">
          {"Computed values are only calculated when first read. Cached results are reused until dependencies change."
          ->Component.text}
        </div>
      </div>
      <div class="feature-card reveal">
        <div class="feature-icon">
          <Icon name={Settings} size={Sm} />
        </div>
        <div class="feature-title"> {"Batched Updates"->Component.text} </div>
        <div class="feature-desc">
          {"Group multiple signal updates into a single notification cycle for optimal performance."
          ->Component.text}
        </div>
      </div>
    </section>
    // Interactive Code Demo
    <section class="code-demo">
      <div class="section-header">
        <h2 class="section-title"> {"See it in action"->Component.text} </h2>
        <p class="section-desc">
          {"Three primitives. Infinite composability. Signals, Computed, and Effects are all you need."
          ->Component.text}
        </p>
      </div>
      <div class="code-demo-container">
        <div class="code-demo-tabs">
          {Component.signalFragment(
            Computed.make(() => {
              let active = Signal.get(demoTab)
              let tabs = ["Signals & Computed", "Batching", "Untracked Reads"]
              tabs
              ->Array.mapWithIndex((label, idx) => {
                [
                  <button
                    key={label}
                    class={"code-demo-tab" ++ (idx == active ? " active" : "")}
                    onClick={_ => Signal.set(demoTab, idx)}>
                    {label->Component.text}
                  </button>,
                ]
              })
              ->Array.flat
            }),
          )}
        </div>
        <div class="code-demo-body">
          <div class="code-demo-source">
            {Component.signalFragment(
              Computed.make(() => {
                let active = Signal.get(demoTab)
                let code = switch active {
                | 0 => demoCode0
                | 1 => demoCode1
                | _ => demoCode2
                }
                [<CodeBlock code language="rescript" />]
              }),
            )}
          </div>
          <div class="code-demo-output">
            <div class="code-demo-output-label"> {"Live Output"->Component.text} </div>
            {Component.signalFragment(
              Computed.make(() => {
                let tab = Signal.get(demoTab)
                switch tab {
                // Tab 0: Signals & Computed
                | 0 => [
                    <div style="display: flex; flex-direction: column; gap: 1.5rem;">
                      <div>
                        <div
                          style="font-size: 0.8125rem; color: var(--text-muted); margin-bottom: 0.5rem;">
                          {"count"->Component.text}
                        </div>
                        <div
                          style="font-size: 2.5rem; font-weight: 700; font-family: 'JetBrains Mono', monospace; color: var(--text-primary);">
                          {Component.textSignal(() => Signal.get(demoCountText))}
                        </div>
                      </div>
                      <div>
                        <div
                          style="font-size: 0.8125rem; color: var(--text-muted); margin-bottom: 0.5rem;">
                          {"doubled (computed)"->Component.text}
                        </div>
                        <div
                          style="font-size: 2.5rem; font-weight: 700; font-family: 'JetBrains Mono', monospace; color: var(--text-accent);">
                          {Component.textSignal(() => Signal.get(demoDoubledText))}
                        </div>
                      </div>
                      <div style="display: flex; gap: 0.75rem;">
                        <button
                          class="btn btn-ghost"
                          style="padding: 0.5rem 1rem; font-size: 0.875rem;"
                          onClick={_ => Signal.update(demoCount, n => n - 1)}>
                          {"- Decrement"->Component.text}
                        </button>
                        <button
                          class="btn btn-primary"
                          style="padding: 0.5rem 1rem; font-size: 0.875rem;"
                          onClick={_ => Signal.update(demoCount, n => n + 1)}>
                          {"+ Increment"->Component.text}
                        </button>
                      </div>
                    </div>,
                  ]
                // Tab 1: Batching
                | 1 => [
                    <div style="display: flex; flex-direction: column; gap: 1.25rem;">
                      <div>
                        <div
                          style="font-size: 0.8125rem; color: var(--text-muted); margin-bottom: 0.375rem;">
                          {"fullName (computed)"->Component.text}
                        </div>
                        <div
                          style="font-size: 1.75rem; font-weight: 700; font-family: 'JetBrains Mono', monospace; color: var(--text-accent);">
                          {Component.textSignal(() => Signal.get(fullName))}
                        </div>
                      </div>
                      <div>
                        <div
                          style="font-size: 0.8125rem; color: var(--text-muted); margin-bottom: 0.375rem;">
                          {"Re-computations"->Component.text}
                        </div>
                        <div
                          style="font-size: 1.75rem; font-weight: 700; font-family: 'JetBrains Mono', monospace; color: var(--text-primary);">
                          {Component.textSignal(() => Signal.get(renderCount)->Int.toString)}
                        </div>
                      </div>
                      <div
                        style="display: flex; flex-direction: column; gap: 0.5rem; padding-top: 0.5rem; border-top: 1px solid var(--border-default);">
                        <div
                          style="font-size: 0.8125rem; color: var(--text-muted); margin-bottom: 0.25rem;">
                          {"Update without batching (2 re-computations):"->Component.text}
                        </div>
                        <button
                          class="btn btn-ghost"
                          style="padding: 0.5rem 1rem; font-size: 0.8125rem;"
                          onClick={_ => {
                            Signal.set(firstName, "Jane")
                            Signal.set(lastName, "Smith")
                            Signal.update(
                              batchLog,
                              arr =>
                                Array.concat(arr, ["Set firstName, then lastName (2 updates)"]),
                            )
                          }}>
                          {"Set Jane Smith (unbatched)"->Component.text}
                        </button>
                        <div
                          style="font-size: 0.8125rem; color: var(--text-muted); margin-bottom: 0.25rem;">
                          {"Update with batching (1 re-computation):"->Component.text}
                        </div>
                        <button
                          class="btn btn-primary"
                          style="padding: 0.5rem 1rem; font-size: 0.8125rem;"
                          onClick={_ => {
                            Signal.batch(() => {
                              Signal.set(firstName, "John")
                              Signal.set(lastName, "Doe")
                            })
                            Signal.update(
                              batchLog,
                              arr => Array.concat(arr, ["Batched set John Doe (1 update)"]),
                            )
                          }}>
                          {"Set John Doe (batched)"->Component.text}
                        </button>
                      </div>
                    </div>,
                  ]
                // Tab 2: Untracked Reads
                | _ => [
                    <div style="display: flex; flex-direction: column; gap: 1.25rem;">
                      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                        <div>
                          <div
                            style="font-size: 0.8125rem; color: var(--text-muted); margin-bottom: 0.375rem;">
                            {"tracked"->Component.text}
                          </div>
                          <div
                            style="font-size: 1.75rem; font-weight: 700; font-family: 'JetBrains Mono', monospace; color: var(--text-primary);">
                            {Component.textSignal(() => Signal.get(trackedVal)->Int.toString)}
                          </div>
                        </div>
                        <div>
                          <div
                            style="font-size: 0.8125rem; color: var(--text-muted); margin-bottom: 0.375rem;">
                            {"untracked"->Component.text}
                          </div>
                          <div
                            style="font-size: 1.75rem; font-weight: 700; font-family: 'JetBrains Mono', monospace; color: var(--text-primary);">
                            {Component.textSignal(() => Signal.get(untrackedVal)->Int.toString)}
                          </div>
                        </div>
                      </div>
                      <div>
                        <div
                          style="font-size: 0.8125rem; color: var(--text-muted); margin-bottom: 0.375rem;">
                          {"result (tracked + untracked)"->Component.text}
                        </div>
                        <div
                          style="font-size: 2rem; font-weight: 700; font-family: 'JetBrains Mono', monospace; color: var(--text-accent);">
                          {Component.textSignal(() => Signal.get(trackedResult)->Int.toString)}
                        </div>
                      </div>
                      <div
                        style="display: flex; flex-direction: column; gap: 0.5rem; padding-top: 0.5rem; border-top: 1px solid var(--border-default);">
                        <div style="display: flex; gap: 0.75rem;">
                          <button
                            class="btn btn-primary"
                            style="padding: 0.5rem 1rem; font-size: 0.8125rem;"
                            onClick={_ => {
                              Signal.update(trackedVal, n => n + 1)
                              Signal.update(
                                untrackedLog,
                                arr =>
                                  Array.concat(arr, ["tracked++ -> result updates"]),
                              )
                            }}>
                            {"tracked + 1"->Component.text}
                          </button>
                          <button
                            class="btn btn-ghost"
                            style="padding: 0.5rem 1rem; font-size: 0.8125rem;"
                            onClick={_ => {
                              Signal.update(untrackedVal, n => n + 10)
                              Signal.update(
                                untrackedLog,
                                arr =>
                                  Array.concat(
                                    arr,
                                    ["untracked+10 -> result unchanged!"],
                                  ),
                              )
                            }}>
                            {"untracked + 10"->Component.text}
                          </button>
                        </div>
                        <div
                          style="font-size: 0.75rem; color: var(--text-muted); line-height: 1.5; margin-top: 0.25rem;">
                          {"Try it: changing 'tracked' updates the result, but changing 'untracked' does not \u2014 because it was read inside Signal.untrack()."
                          ->Component.text}
                        </div>
                      </div>
                    </div>,
                  ]
                }
              }),
            )}
          </div>
        </div>
      </div>
    </section>
    // Comparison Section
    <section class="comparison-section">
      <div class="section-header">
        <h2 class="section-title"> {"Why ReScript Signals?"->Component.text} </h2>
        <p class="section-desc">
          {"Purpose-built for ReScript with zero compromises."->Component.text}
        </p>
      </div>
      <table class="comparison-table">
        <thead>
          <tr>
            <th> {"Feature"->Component.text} </th>
            <th> {"ReScript Signals"->Component.text} </th>
            <th> {"Preact Signals"->Component.text} </th>
            <th> {"SolidJS"->Component.text} </th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td> {"Zero dependencies"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="cross"> {"\u2717"->Component.text} </td>
            <td class="cross"> {"\u2717"->Component.text} </td>
          </tr>
          <tr>
            <td> {"ReScript-native types"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="cross"> {"\u2717"->Component.text} </td>
            <td class="cross"> {"\u2717"->Component.text} </td>
          </tr>
          <tr>
            <td> {"Fine-grained reactivity"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
          </tr>
          <tr>
            <td> {"Automatic dependency tracking"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
          </tr>
          <tr>
            <td> {"Glitch-free evaluation"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
          </tr>
          <tr>
            <td> {"Batched updates"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="partial"> {"~"->Component.text} </td>
          </tr>
          <tr>
            <td> {"Lazy computed evaluation"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="cross"> {"\u2717"->Component.text} </td>
          </tr>
          <tr>
            <td> {"Compile-time type safety"->Component.text} </td>
            <td class="check"> {"\u2713"->Component.text} </td>
            <td class="partial"> {"~"->Component.text} </td>
            <td class="partial"> {"~"->Component.text} </td>
          </tr>
        </tbody>
      </table>
    </section>
    // Community Section
    <section class="community-section">
      <div class="section-header">
        <h2 class="section-title"> {"Community"->Component.text} </h2>
        <p class="section-desc">
          {"Join the growing community of developers using ReScript Signals."->Component.text}
        </p>
      </div>
      <div class="community-links" style="justify-content: center;">
        <a
          class="btn btn-ghost"
          href="https://github.com/brnrdog/rescript-signals"
          target="_blank">
          <Icon name={GitHub} size={Sm} />
          {"GitHub"->Component.text}
        </a>
        <a
          class="btn btn-ghost"
          href="https://www.npmjs.com/package/rescript-signals"
          target="_blank">
          <Icon name={ExternalLink} size={Sm} />
          {"npm"->Component.text}
        </a>
        <a
          class="btn btn-ghost"
          href="https://github.com/brnrdog/rescript-signals/discussions"
          target="_blank">
          <Icon name={ExternalLink} size={Sm} />
          {"Discussions"->Component.text}
        </a>
      </div>
    </section>
    // Footer
    <SiteFooter />
  </div>
}
