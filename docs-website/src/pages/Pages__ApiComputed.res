
open Xote.ReactiveProp
open Basefn

@jsx.component
let make = () => {
  <div>
    <div>
    <Typography text={static("Computed")} variant={H1} />
    <Typography
      text={static("Derived values that automatically update when their dependencies change.")}
      variant={Lead}
    />
    <Separator />
    <Typography text={static("Creating Computed Values")} variant={H2} />
    <Card header="Computed.make(fn)">
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
    </Card>
    <Card header="Computed.make(~name, fn)">
      <Typography text={static("Creates a named computed for debugging.")} />
      <CodeBlock
        language="rescript"
        code={`let doubled = Computed.make(~name="doubled", () => {
  Signal.get(count) * 2
})`}
      />
    </Card>
    <Separator />
    <Typography text={static("Reading Computed Values")} variant={H2} />
    <Card header="Computed.get(computed)">
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
    </Card>
    <Card header="Computed.peek(computed)">
      <Typography text={static("Reads the computed value without creating a dependency.")} />
      <CodeBlock
        language="rescript"
        code={`let value = Computed.peek(doubled) // No dependency created`}
      />
    </Card>
    <Separator />
    <Typography text={static("Disposal")} variant={H2} />
    <Card header="Computed.dispose(computed)">
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
    </Card>
    <Separator />
    <Typography text={static("Key Characteristics")} variant={H2} />
    <Grid columns={Count(2)} gap="1rem">
      <Card header="Lazy Evaluation">
        <Typography
          text={static(
            "Computed values are not calculated until they are first read. This avoids unnecessary computation.",
          )}
        />
      </Card>
      <Card header="Automatic Caching">
        <Typography
          text={static(
            "Once calculated, the value is cached until a dependency changes. Multiple reads return the cached value.",
          )}
        />
      </Card>
      <Card header="Dependency Tracking">
        <Typography
          text={static(
            "Dependencies are automatically tracked when Signal.get() or Computed.get() is called inside the computation function.",
          )}
        />
      </Card>
      <Card header="Glitch-Free">
        <Typography
          text={static(
            "Updates are batched and computed values are recalculated in topological order to prevent intermediate inconsistent states.",
          )}
        />
      </Card>
    </Grid>
    </div>
    <EditOnGitHub pageName="Pages__ApiComputed" />
  </div>
}
