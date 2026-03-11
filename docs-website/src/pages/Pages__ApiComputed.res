open Xote

@jsx.component
let make = () => {
  <div>
    <h1 class="page-title"> {"Computed"->Component.text} </h1>
    <p class="lead">
      {"Derived values that automatically update when their dependencies change."->Component.text}
    </p>
    // Creating
    <h2 id="creating-computed-values"> {"Creating Computed Values"->Component.text} </h2>
    <div class="api-signature">
      <div class="api-signature-header"> {"Computed.make(fn)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Creates a computed value from a function. The function is called lazily and cached until a dependency changes."
        ->Component.text}
      </div>
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(5)
let doubled = Computed.make(() => Signal.get(count) * 2)

Signal.get(doubled) // 10
Signal.set(count, 10)
Signal.get(doubled) // 20`}
      />
    </div>
    <div class="api-signature">
      <div class="api-signature-header"> {"Computed.make(~name, fn)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Creates a named computed for debugging."->Component.text}
      </div>
      <CodeBlock
        language="rescript"
        code={`let doubled = Computed.make(~name="doubled", () => {
  Signal.get(count) * 2
})`}
      />
    </div>
    // Reading
    <h2 id="reading-computed-values"> {"Reading Computed Values"->Component.text} </h2>
    <div class="api-signature">
      <div class="api-signature-header"> {"Signal.get(computed)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Reads the computed value and creates a dependency. Can be used inside other computeds or effects."
        ->Component.text}
      </div>
      <CodeBlock
        language="rescript"
        code={`let count = Signal.make(5)
let doubled = Computed.make(() => Signal.get(count) * 2)
let quadrupled = Computed.make(() => Signal.get(doubled) * 2)

Signal.get(quadrupled) // 20`}
      />
    </div>
    <div class="api-signature">
      <div class="api-signature-header"> {"Signal.peek(computed)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Reads the computed value without creating a dependency."->Component.text}
      </div>
      <CodeBlock
        language="rescript"
        code={`let value = Signal.peek(doubled) // No dependency created`}
      />
    </div>
    <Callout type_={Tip}>
      <p>
        {"Computed values return a Signal.t type, so you read them using Signal.get and Signal.peek \u2014 just like regular signals."
        ->Component.text}
      </p>
    </Callout>
    // Disposal
    <h2 id="disposal"> {"Disposal"->Component.text} </h2>
    <div class="api-signature">
      <div class="api-signature-header"> {"Computed.dispose(computed)"->Component.text} </div>
      <div class="api-signature-desc">
        {"Manually disposes a computed, removing all subscriptions. The computed will no longer track dependencies."
        ->Component.text}
      </div>
      <CodeBlock
        language="rescript"
        code={`let computed = Computed.make(() => Signal.get(count) * 2)

// Later, when no longer needed
Computed.dispose(computed)`}
      />
    </div>
    <Callout type_={Warning}>
      <p>
        {"After disposal, reading the computed will return its last cached value but will not update when dependencies change."
        ->Component.text}
      </p>
    </Callout>
    // Key Characteristics
    <h2 id="key-characteristics"> {"Key Characteristics"->Component.text} </h2>
    <div
      style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1rem; margin-top: 1rem;">
      <div class="feature-card">
        <div class="feature-title"> {"Lazy Evaluation"->Component.text} </div>
        <div class="feature-desc">
          {"Computed values are not calculated until they are first read. This avoids unnecessary computation."
          ->Component.text}
        </div>
      </div>
      <div class="feature-card">
        <div class="feature-title"> {"Automatic Caching"->Component.text} </div>
        <div class="feature-desc">
          {"Once calculated, the value is cached until a dependency changes. Multiple reads return the cached value."
          ->Component.text}
        </div>
      </div>
      <div class="feature-card">
        <div class="feature-title"> {"Dependency Tracking"->Component.text} </div>
        <div class="feature-desc">
          {"Dependencies are automatically tracked when Signal.get() is called inside the computation function."
          ->Component.text}
        </div>
      </div>
      <div class="feature-card">
        <div class="feature-title"> {"Glitch-Free"->Component.text} </div>
        <div class="feature-desc">
          {"Updates are batched and computed values are recalculated in topological order to prevent intermediate inconsistent states."
          ->Component.text}
        </div>
      </div>
    </div>
    <EditOnGitHub pageName="Pages__ApiComputed" />
  </div>
}
