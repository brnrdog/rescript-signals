open Xote

type variant = Default | Outlined

let variantToClass = (variant: variant) =>
  switch variant {
  | Default => "ui-card--default"
  | Outlined => "ui-card--outlined"
  }

@jsx.component
let make = (~children: XoteJSX.element, ~variant: variant=Default, ~header: option<string>=?) => {
  <div class={"ui-card " ++ variantToClass(variant)}>
    {switch header {
    | Some(text) => <div class="ui-card__header"> {View.text(text)} </div>
    | None => XoteJSX.null()
    }}
    <div class="ui-card__body"> {children} </div>
  </div>
}
