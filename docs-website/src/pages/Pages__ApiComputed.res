open Xote
open Xote.ReactiveProp
open Basefn

@jsx.component
let make = () => {
  <div>
    <Typography
      text={static("Derived values that automatically update when their dependencies change.")}
      variant={Lead}
    />
    <Separator />
    <div class="heading-anchor" id="creating-computed">
      <Typography text={static("Creating Computed Values")} variant={H2} />
      <a class="anchor-link" href="#creating-computed"> {"#"->Component.text} </a>
    </div>
    <div class="heading-anchor" id="computed-make">
      <Typography text={static("Computed.make(fn)")} variant={H3} />
      <a class="anchor-link" href="#computed-make"> {"#"->Component.text} </a>
    </div>
    <Typography
      text={static(
        "Creates a computed value from a function. The function is called lazily and cached until a dependency changes.",
      )}
    />
    <CodeBlock
      language="rescript"
      code={`let count = Signal.make(5)
let doubled = Computed.make(() => Signal.get(count) * 2)

Computed.get(doubled) // 10
Signal.set(count, 10)
Computed.get(doubled) // 20`}
    />
    <div class="heading-anchor" id="computed-make-named">
      <Typography text={static("Computed.make(~name, fn)")} variant={H3} />
      <a class="anchor-link" href="#computed-make-named"> {"#"->Component.text} </a>
    </div>
    <Typography text={static("Creates a named computed for debugging.")} />
    <CodeBlock
      language="rescript"
      code={`let doubled = Computed.make(~name="doubled", () => {
  Signal.get(count) * 2
})`}
    />
    <Separator />
    <div class="heading-anchor" id="reading-computed">
      <Typography text={static("Reading Computed Values")} variant={H2} />
      <a class="anchor-link" href="#reading-computed"> {"#"->Component.text} </a>
    </div>
    <div class="heading-anchor" id="computed-get">
      <Typography text={static("Computed.get(computed)")} variant={H3} />
      <a class="anchor-link" href="#computed-get"> {"#"->Component.text} </a>
    </div>
    <Typography
      text={static(
        "Reads the computed value and creates a dependency. Can be used inside other computeds or effects.",
      )}
    />
    <CodeBlock
      language="rescript"
      code={`let count = Signal.make(5)
let doubled = Computed.make(() => Signal.get(count) * 2)
let quadrupled = Computed.make(() => Computed.get(doubled) * 2)

Computed.get(quadrupled) // 20`}
    />
    <div class="heading-anchor" id="computed-peek">
      <Typography text={static("Computed.peek(computed)")} variant={H3} />
      <a class="anchor-link" href="#computed-peek"> {"#"->Component.text} </a>
    </div>
    <Typography text={static("Reads the computed value without creating a dependency.")} />
    <CodeBlock
      language="rescript"
      code={`let value = Computed.peek(doubled) // No dependency created`}
    />
    <Separator />
    <div class="heading-anchor" id="disposal">
      <Typography text={static("Disposal")} variant={H2} />
      <a class="anchor-link" href="#disposal"> {"#"->Component.text} </a>
    </div>
    <div class="heading-anchor" id="computed-dispose">
      <Typography text={static("Computed.dispose(computed)")} variant={H3} />
      <a class="anchor-link" href="#computed-dispose"> {"#"->Component.text} </a>
    </div>
    <Typography
      text={static(
        "Manually disposes a computed, removing all subscriptions. The computed will no longer track dependencies.",
      )}
    />
    <CodeBlock
      language="rescript"
      code={`let computed = Computed.make(() => Signal.get(count) * 2)

// Later, when no longer needed
Computed.dispose(computed)`}
    />
    <Separator />
    <div class="heading-anchor" id="key-characteristics">
      <Typography text={static("Key Characteristics")} variant={H2} />
      <a class="anchor-link" href="#key-characteristics"> {"#"->Component.text} </a>
    </div>
    <ul style="line-height: 1.8; color: var(--basefn-text-secondary);">
      <li> <strong> {"Lazy Evaluation"->Component.text} </strong> {" — Computed values are not calculated until they are first read. This avoids unnecessary computation."->Component.text} </li>
      <li> <strong> {"Automatic Caching"->Component.text} </strong> {" — Once calculated, the value is cached until a dependency changes. Multiple reads return the cached value."->Component.text} </li>
      <li> <strong> {"Dependency Tracking"->Component.text} </strong> {" — Dependencies are automatically tracked when Signal.get() or Computed.get() is called inside the computation function."->Component.text} </li>
      <li> <strong> {"Glitch-Free"->Component.text} </strong> {" — Updates are batched and computed values are recalculated in topological order to prevent intermediate inconsistent states."->Component.text} </li>
    </ul>
    <EditOnGitHub pageName="Pages__ApiComputed" />
  </div>
}
