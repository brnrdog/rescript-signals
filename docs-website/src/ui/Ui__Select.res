open Xote

type selectOption = {
  value: string,
  label: string,
}

@jsx.component
let make = (
  ~value: Signal.t<string>,
  ~options: Signal.t<array<selectOption>>,
  ~onChange: option<Dom.event => unit>=?,
) => {
  // Keep the bound signal in sync before notifying the caller, so handlers can
  // read the new selection straight off `value`.
  let handleChange = (event: Dom.event) => {
    Signal.set(value, Obj.magic(event)["target"]["value"])

    switch onChange {
    | Some(onChange) => onChange(event)
    | None => ()
    }
  }

  <select class="ui-select" value onChange={handleChange}>
    {View.each(options, option =>
      <option value={option.value}> {View.text(option.label)} </option>
    )}
  </select>
}
