open Xote

type inputType = Text | Number

let inputTypeToString = (type_: inputType) =>
  switch type_ {
  | Text => "text"
  | Number => "number"
  }

@jsx.component
let make = (
  ~value: MaybeSignal.t<string>,
  ~type_: inputType=Text,
  ~placeholder: string="",
  ~onInput: option<Dom.event => unit>=?,
) => {
  <input class="ui-input" type_={inputTypeToString(type_)} placeholder value ?onInput />
}
