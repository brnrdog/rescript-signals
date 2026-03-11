open Xote
open Basefn

let getInputValue: Dom.event => string = %raw(`function(e) { return e.target.value }`)

module CounterExample = {
  @jsx.component
  let make = () => {
    let count = Signal.make(0)
    let countText = Computed.make(() => Signal.get(count)->Int.toString)

    <div class="api-signature">
      <div class="api-signature-header"> {"Counter"->Component.text} </div>
      <div style="display: flex; align-items: center; gap: 1rem; margin-top: 0.75rem;">
        <button
          class="btn btn-ghost"
          style="padding: 0.5rem 1rem;"
          onClick={_ => Signal.update(count, n => n - 1)}>
          {"-"->Component.text}
        </button>
        <div
          style="font-size: 2rem; font-weight: 700; min-width: 3rem; text-align: center; font-family: 'JetBrains Mono', monospace; color: var(--text-primary);">
          {Component.textSignal(() => Signal.get(countText))}
        </div>
        <button
          class="btn btn-ghost"
          style="padding: 0.5rem 1rem;"
          onClick={_ => Signal.update(count, n => n + 1)}>
          {"+"->Component.text}
        </button>
      </div>
      <div style="margin-top: 1rem;">
        <CodeBlock
          language="rescript"
          code={`let count = Signal.make(0)
let countText = Computed.make(() =>
  Signal.get(count)->Int.toString
)`}
        />
      </div>
    </div>
  }
}

module TodoExample = {
  @jsx.component
  let make = () => {
    let todos: Signal.t<array<string>> = Signal.make([])
    let inputValue = Signal.make("")

    let addTodo = _ => {
      let text = Signal.get(inputValue)
      if text->String.trim != "" {
        Signal.update(todos, arr => Array.concat(arr, [text]))
        Signal.set(inputValue, "")
      }
    }

    let removeTodo = (todoText: string) => {
      Signal.update(todos, arr => arr->Array.filter(t => t != todoText))
    }

    <div class="api-signature">
      <div class="api-signature-header"> {"Todo List"->Component.text} </div>
      <div style="margin-top: 0.75rem;">
        <div style="display: flex; gap: 0.5rem; margin-bottom: 1rem;">
          <Input
            value={Xote.ReactiveProp.reactive(inputValue)}
            onInput={evt => Signal.set(inputValue, getInputValue(evt))}
            placeholder="Add a todo..."
          />
          <button class="btn btn-primary" style="padding: 0.5rem 1rem;" onClick={addTodo}>
            {"Add"->Component.text}
          </button>
        </div>
        <div>
          {Component.list(todos, todo => {
            <div
              style="display: flex; justify-content: space-between; align-items: center; padding: 0.625rem 0; border-bottom: 1px solid var(--border-default);">
              <span> {todo->Component.text} </span>
              <button
                class="icon-btn"
                style="width: 28px; height: 28px; font-size: 0.875rem;"
                onClick={_ => removeTodo(todo)}>
                {"\u2715"->Component.text}
              </button>
            </div>
          })}
        </div>
      </div>
    </div>
  }
}

module DerivedStateExample = {
  @jsx.component
  let make = () => {
    let price = Signal.make(100.0)
    let quantity = Signal.make(1)
    let taxRate = Signal.make(0.1)

    let subtotal = Computed.make(() => {
      Signal.get(price) *. Int.toFloat(Signal.get(quantity))
    })

    let tax = Computed.make(() => {
      Signal.get(subtotal) *. Signal.get(taxRate)
    })

    let total = Computed.make(() => {
      Signal.get(subtotal) +. Signal.get(tax)
    })

    let priceStr = Computed.make(() => Signal.get(price)->Float.toString)
    let quantityStr = Computed.make(() => Signal.get(quantity)->Int.toString)

    let taxRateOptions: Signal.t<array<Basefn__Select.selectOption>> = Signal.make([
      {Basefn__Select.value: "0.05", label: "5%"},
      {value: "0.1", label: "10%"},
      {value: "0.2", label: "20%"},
    ])

    let taxRateStrSignal = Signal.make("0.1")

    <div class="api-signature">
      <div class="api-signature-header"> {"Derived State (Shopping Cart)"->Component.text} </div>
      <div style="margin-top: 0.75rem;">
        <div
          style="display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 0.75rem;">
          <div>
            <Label text="Price" />
            <Input
              type_={Number}
              value={Xote.ReactiveProp.reactive(priceStr)}
              onInput={evt => {
                switch Float.fromString(getInputValue(evt)) {
                | Some(v) => Signal.set(price, v)
                | None => ()
                }
              }}
            />
          </div>
          <div>
            <Label text="Quantity" />
            <Input
              type_={Number}
              value={Xote.ReactiveProp.reactive(quantityStr)}
              onInput={evt => {
                switch Int.fromString(getInputValue(evt)) {
                | Some(v) => Signal.set(quantity, v)
                | None => ()
                }
              }}
            />
          </div>
          <div>
            <Label text="Tax Rate" />
            <Select
              value={taxRateStrSignal}
              onChange={_ => {
                switch Float.fromString(Signal.get(taxRateStrSignal)) {
                | Some(v) => Signal.set(taxRate, v)
                | None => ()
                }
              }}
              options={taxRateOptions}
            />
          </div>
        </div>
        <div
          style="margin-top: 1.5rem; padding-top: 1rem; border-top: 1px solid var(--border-default);">
          <div
            style="display: flex; flex-direction: column; gap: 0.5rem; font-size: 0.9375rem;">
            <div style="display: flex; justify-content: space-between;">
              <span style="color: var(--text-secondary);"> {"Subtotal:"->Component.text} </span>
              <span style="font-family: 'JetBrains Mono', monospace;">
                {Component.textSignal(
                  () => `$${Signal.get(subtotal)->Float.toFixed(~digits=2)}`,
                )}
              </span>
            </div>
            <div style="display: flex; justify-content: space-between;">
              <span style="color: var(--text-secondary);"> {"Tax:"->Component.text} </span>
              <span style="font-family: 'JetBrains Mono', monospace;">
                {Component.textSignal(() => `$${Signal.get(tax)->Float.toFixed(~digits=2)}`)}
              </span>
            </div>
            <div
              style="display: flex; justify-content: space-between; padding-top: 0.75rem; border-top: 1px solid var(--border-default); font-weight: 600; font-size: 1.125rem;">
              <span> {"Total:"->Component.text} </span>
              <span style="font-family: 'JetBrains Mono', monospace; color: var(--text-accent);">
                {Component.textSignal(
                  () => `$${Signal.get(total)->Float.toFixed(~digits=2)}`,
                )}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  }
}

@jsx.component
let make = () => {
  <div>
    <h1 class="page-title"> {"Examples"->Component.text} </h1>
    <p class="lead">
      {"Interactive examples demonstrating rescript-signals patterns."->Component.text}
    </p>
    <Callout type_={Tip}>
      <p>
        {"These examples are live \u2014 interact with them to see reactivity in action. All state is managed with signals, computed values, and effects."
        ->Component.text}
      </p>
    </Callout>
    <h2 id="counter"> {"Counter"->Component.text} </h2>
    <p>
      {"A simple counter demonstrating signals and computed values."->Component.text}
    </p>
    <CounterExample />
    <h2 id="todo-list"> {"Todo List"->Component.text} </h2>
    <p>
      {"A todo list with add and remove functionality using signal arrays."->Component.text}
    </p>
    <TodoExample />
    <h2 id="derived-state"> {"Derived State"->Component.text} </h2>
    <p>
      {"A shopping cart demonstrating how computed values compose to derive complex state from simple signals."
      ->Component.text}
    </p>
    <DerivedStateExample />
    <h2 id="source-code"> {"Source Code"->Component.text} </h2>
    <p style="color: var(--text-secondary);">
      {"These examples are built with xote and basefn. Check out the source code in the docs-website repository to see the full implementation."
      ->Component.text}
    </p>
    <EditOnGitHub pageName="Pages__Examples" />
  </div>
}
