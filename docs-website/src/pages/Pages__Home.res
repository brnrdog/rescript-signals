open Xote
open Xote.ReactiveProp
open Basefn

@jsx.component
let make = () => {
  <div>
    // Hero Section
    <div class="hero-section">
      <Typography text={static("ReScript Signals")} variant={H1} class="hero-title" />
      <Typography
        text={static(
          "A lightweight, high-performance reactive signals library for ReScript. Zero dependencies, fine-grained reactivity, full type safety.",
        )}
        variant={Lead}
        class="hero-subtitle"
      />
      <div class="hero-buttons">
        <Button variant={Primary} onClick={_ => Router.push("/getting-started", ())}>
          {Component.text("Get Started")}
        </Button>
        <Button variant={Secondary} onClick={_ => Router.push("/api/signal", ())}>
          {Component.text("API Reference")}
        </Button>
      </div>
      <div style="display: inline-flex; align-items: center; gap: 0.5rem;">
        <Badge label={Signal.make("v1.3.3")} variant={Secondary} size={Sm} />
        <Typography
          text={static("MIT Licensed")}
          variant={Muted}
        />
      </div>
    </div>
    <Separator />
    // Features Section
    <div class="feature-section">
      <Typography text={static("Why ReScript Signals?")} variant={H2} class="feature-section-title" />
      <Grid columns={Count(3)} gap="1.5rem">
        <Card variant={Outlined} className="feature-card">
          <div class="feature-icon">
            <Icon name={Star} size={Md} />
          </div>
          <Typography text={static("Zero Dependencies")} variant={H4} />
          <Typography
            text={static(
              "Ships with no runtime dependencies. Minimal bundle size for maximum performance in production.",
            )}
            variant={Muted}
          />
        </Card>
        <Card variant={Outlined} className="feature-card">
          <div class="feature-icon">
            <Icon name={Settings} size={Md} />
          </div>
          <Typography text={static("Fine-Grained Reactivity")} variant={H4} />
          <Typography
            text={static(
              "Automatic dependency tracking ensures only affected computations re-run. No unnecessary re-renders.",
            )}
            variant={Muted}
          />
        </Card>
        <Card variant={Outlined} className="feature-card">
          <div class="feature-icon">
            <Icon name={Check} size={Md} />
          </div>
          <Typography text={static("Type Safe")} variant={H4} />
          <Typography
            text={static(
              "Built for ReScript with full type inference. Catch errors at compile time, not at runtime.",
            )}
            variant={Muted}
          />
        </Card>
      </Grid>
    </div>
    <Separator />
    // Code Showcase: Signals
    <div class="code-showcase">
      <Typography text={static("Create reactive state with Signals")} variant={H2} align={Center} />
      <Typography
        text={static(
          "Signals are reactive containers that hold a value. When the value changes, all subscribers are automatically notified.",
        )}
        variant={Muted}
        align={Center}
        style="margin-bottom: 1.5rem;"
      />
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(0)

// Read the current value
let value = Signal.get(count) // 0

// Update the value
Signal.set(count, 5)

// Update based on previous value
Signal.update(count, n => n + 1) // 6`}
      />
    </div>
    <Separator />
    // Code Showcase: Computed
    <div class="code-showcase">
      <Typography text={static("Derive values with Computed")} variant={H2} align={Center} />
      <Typography
        text={static(
          "Computed values automatically recalculate when their dependencies change. Values are lazily evaluated and cached.",
        )}
        variant={Muted}
        align={Center}
        style="margin-bottom: 1.5rem;"
      />
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(5)
let doubled = Computed.make(() => Signal.get(count) * 2)

Computed.get(doubled) // 10

Signal.set(count, 10)
Computed.get(doubled) // 20 — automatically updated`}
      />
    </div>
    <Separator />
    // Code Showcase: Effects
    <div class="code-showcase">
      <Typography text={static("React to changes with Effects")} variant={H2} align={Center} />
      <Typography
        text={static(
          "Effects run side effects whenever their dependencies change. Perfect for DOM updates, logging, or API calls.",
        )}
        variant={Muted}
        align={Center}
        style="margin-bottom: 1.5rem;"
      />
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(0)

Effect.run(() => {
  Console.log(\`Count is: \${Signal.get(count)->Int.toString}\`)
})
// Logs: "Count is: 0"

Signal.set(count, 1)
// Logs: "Count is: 1" — effect re-runs automatically`}
      />
    </div>
    <Separator />
    // Bottom CTA
    <div class="bottom-cta">
      <Typography text={static("Ready to get started?")} variant={H2} />
      <Typography
        text={static(
          "Install rescript-signals and start building reactive applications in minutes.",
        )}
        variant={Muted}
        style="margin-bottom: 2rem;"
      />
      <div style="display: flex; gap: 1rem; justify-content: center;">
        <Button variant={Primary} onClick={_ => Router.push("/getting-started", ())}>
          {Component.text("Read the Docs")}
        </Button>
        <Button variant={Ghost} onClick={_ => Router.push("/examples", ())}>
          {Component.text("See Examples")}
        </Button>
      </div>
    </div>
  </div>
}
