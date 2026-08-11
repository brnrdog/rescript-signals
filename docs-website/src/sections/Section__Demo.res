open Xote

/* The one live demo: all three primitives in one graph.
 *
 * `count` is written by the buttons, `doubled` derives from it, and the effect
 * writes a line into the log. The log is the point — an effect is otherwise
 * invisible, and because it appends exactly one line per change, the log is
 * also the evidence that a write re-runs its dependents once. */

/* Kept to short lines so the pane never needs to scroll sideways. */
let source = `open Signals

let count = Signal.make(0)

let doubled = Computed.make(() =>
  Signal.get(count) * 2
)

Effect.run(() => {
  log(Signal.get(count))
  None
})`

let historyLimit = 8

@jsx.component
let make = () => {
  let count = Signal.make(0)
  let doubled = Computed.make(() => Signal.get(count) * 2)
  let history = Signal.make([])

  /* Bumped by every interaction, so the propagation trace can restart its
     animation. Alternating between two class names is what re-triggers it. */
  let pulse = Signal.make(0)

  Effect.run(() => {
    let value = Signal.get(count)
    Signal.update(history, entries =>
      Array.concat(["count is " ++ Int.toString(value)], entries)->Array.slice(
        ~start=0,
        ~end=historyLimit,
      )
    )
    None
  })

  let act = (change: int => int) => (_evt: Dom.event) => {
    Signal.update(count, change)
    Signal.update(pulse, n => n + 1)
  }

  let node = (id: string, label: string) =>
    <span class={"trace-node trace-" ++ id}> {View.text(label)} </span>

  <section id="demo" class="demo">
    <div class="demo-grid">
      <div class="demo-source">
        <div class="pane-label"> {View.text("Source")} </div>
        <CodeBlock code={source} />
      </div>
      <div class="demo-live">
        <div class="pane-label"> {View.text("Running")} </div>
        {View.element(
          "div",
          ~attrs=[
            View.attr("aria-hidden", "true"),
            View.computedAttr("class", () =>
              mod(Signal.get(pulse), 2) == 0 ? "trace phase-a" : "trace phase-b"
            ),
          ],
          ~children=[
            node("count", "count"),
            <span class="trace-edge"> {View.text("→")} </span>,
            node("computed", "doubled"),
            <span class="trace-edge"> {View.text("→")} </span>,
            node("effect", "effect"),
          ],
          (),
        )}
        <div class="readouts">
          <div class="readout">
            <span class="readout-label"> {View.text("count")} </span>
            <span class="readout-value">
              {View.signalText(() => Signal.get(count)->Int.toString)}
            </span>
          </div>
          <div class="readout">
            <span class="readout-label"> {View.text("doubled")} </span>
            <span class="readout-value">
              {View.signalText(() => Signal.get(doubled)->Int.toString)}
            </span>
          </div>
        </div>
        <div class="demo-controls">
          {View.element(
            "button",
            ~attrs=[
              View.attr("type", "button"),
              View.attr("class", "control"),
              View.attr("aria-label", "Decrement count"),
            ],
            ~events=[("click", act(n => n - 1))],
            ~children=[View.text("−")],
            (),
          )}
          {View.element(
            "button",
            ~attrs=[View.attr("type", "button"), View.attr("class", "control")],
            ~events=[("click", act(_ => 0))],
            ~children=[View.text("Reset")],
            (),
          )}
          {View.element(
            "button",
            ~attrs=[
              View.attr("type", "button"),
              View.attr("class", "control"),
              View.attr("aria-label", "Increment count"),
            ],
            ~events=[("click", act(n => n + 1))],
            ~children=[View.text("+")],
            (),
          )}
        </div>
        <div class="log">
          <div class="log-label"> {View.text("Effect output")} </div>
          <ol class="log-lines">
            {View.each(history, line => <li class="log-line"> {View.text(line)} </li>)}
          </ol>
        </div>
      </div>
    </div>
    <p class="demo-caption">
      {View.text(
        "One line per change, never two — the effect runs once after each write, not once per signal it reads.",
      )}
    </p>
  </section>
}
