open Xote

type variant = Info | Success | Warning | Error

let variantToClass = (variant: variant) =>
  switch variant {
  | Info => "ui-alert--info"
  | Success => "ui-alert--success"
  | Warning => "ui-alert--warning"
  | Error => "ui-alert--error"
  }

@jsx.component
let make = (~message: Signal.t<string>, ~variant: variant=Info) => {
  <div class={"ui-alert " ++ variantToClass(variant)} role="alert">
    <div class="ui-alert__message"> {View.SignalText(message)} </div>
  </div>
}
