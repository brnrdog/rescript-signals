open Xote

type calloutType = Note | Tip | Warning | Danger

let typeToClass = (t: calloutType) =>
  switch t {
  | Note => "note"
  | Tip => "tip"
  | Warning => "warning"
  | Danger => "danger"
  }

let typeToIcon = (t: calloutType) =>
  switch t {
  | Note => "i"
  | Tip => ">"
  | Warning => "!"
  | Danger => "x"
  }

@jsx.component
let make = (~type_: calloutType=Note, ~children: Component.node) => {
  <div class={"callout " ++ typeToClass(type_)}>
    <span class="callout-icon"> {typeToIcon(type_)->Component.text} </span>
    <div class="callout-content"> {children} </div>
  </div>
}
