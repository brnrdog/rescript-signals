open Xote
open Xote.ReactiveProp
open Basefn

// Simple DOM helpers
let getInputValue: Dom.event => string = %raw(`function(e) { return e.target.value }`)

module CounterExample = {
  @jsx.component
  let make = () => {
    let count = Signal.make(0)
    let countText = Computed.make(() => Signal.get(count)->Int.toString)

    <Card header="Counter">
      <div style="display: flex; align-items: center; gap: 1rem;">
        <Button variant={Secondary} onClick={_ => Signal.update(count, n => n - 1)}>
          {Component.text("-")}
        </Button>
        <div style="font-size: 1.5rem; font-weight: bold; min-width: 3rem; text-align: center;">
          {Component.textSignal(() => Signal.get(countText))}
        </div>
        <Button variant={Secondary} onClick={_ => Signal.update(count, n => n + 1)}>
          {Component.text("+")}
        </Button>
      </div>
    </Card>
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

    <Card header="Todo List">
      <div style="display: flex; gap: 0.5rem; margin-bottom: 1rem;">
        <Input
          value={reactive(inputValue)}
          onInput={evt => Signal.set(inputValue, getInputValue(evt))}
          placeholder="Add a todo..."
        />
        <Button variant={Primary} onClick={addTodo}> {Component.text("Add")} </Button>
      </div>
      <div>
        {Component.list(todos, todo => {
          <div
            style="display: flex; justify-content: space-between; align-items: center; padding: 0.5rem 0; border-bottom: 1px solid var(--basefn-color-border);">
            <Typography text={static(todo)} />
            <Button variant={Ghost} onClick={_ => removeTodo(todo)}>
              {Component.text("Remove")}
            </Button>
          </div>
        })}
      </div>
    </Card>
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

    <Card header="Derived State (Shopping Cart)">
      <Grid columns={Count(3)} gap="0.5rem">
        <div>
          <Label text="Price" />
          <Input
            type_={Number}
            value={reactive(priceStr)}
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
            value={reactive(quantityStr)}
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
      </Grid>
      <Separator />
      <div style="display: flex; flex-direction: column; gap: 0.5rem;">
        <div style="display: flex; justify-content: space-between;">
          <Typography text={static("Subtotal:")} />
          <span>
            {Component.textSignal(() => `$${Signal.get(subtotal)->Float.toFixed(~digits=2)}`)}
          </span>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <Typography text={static("Tax:")} />
          <span>
            {Component.textSignal(() => `$${Signal.get(tax)->Float.toFixed(~digits=2)}`)}
          </span>
        </div>
        <Separator />
        <div style="display: flex; justify-content: space-between;">
          <Typography text={static("Total:")} variant={H4} />
          <span style="font-size: 1.25rem; font-weight: bold;">
            {Component.textSignal(() => `$${Signal.get(total)->Float.toFixed(~digits=2)}`)}
          </span>
        </div>
      </div>
    </Card>
  }
}

@jsx.component
let make = () => {
  <div>
    <div>
    <Typography text={static("Examples")} variant={H1} />
    <Typography
      text={static("Interactive examples demonstrating rescript-signals patterns.")}
      variant={Lead}
    />
    <Separator />
    <Grid columns={Count(1)} gap="1.5rem">
      <CounterExample />
      <TodoExample />
      <DerivedStateExample />
    </Grid>
    <Separator />
    <Typography text={static("Source Code")} variant={H2} />
    <Typography
      text={static(
        "These examples are built with xote and basefn. Check out the source code in the docs-website repository to see the full implementation.",
      )}
    />
    </div>
    <EditOnGitHub pageName="Pages__Examples" />
  </div>
}
