open Xote

type variant = Primary | Secondary | Ghost

let variantToClass = (variant: variant) =>
  switch variant {
  | Primary => "ui-button--primary"
  | Secondary => "ui-button--secondary"
  | Ghost => "ui-button--ghost"
  }

@jsx.component
let make = (
  ~children=XoteJSX.null(),
  ~variant: variant=Primary,
  ~disabled: bool=false,
  ~onClick: option<Dom.event => unit>=?,
) => {
  let class = "ui-button " ++ variantToClass(variant)

  <button class disabled ?onClick> {children} </button>
}
