open Xote

type variant = H1 | H2 | H3 | H4 | P | Lead | Small | Muted | Code

let variantToClass = (variant: variant) =>
  switch variant {
  | H1 => "ui-typography--h1"
  | H2 => "ui-typography--h2"
  | H3 => "ui-typography--h3"
  | H4 => "ui-typography--h4"
  | P => "ui-typography--p"
  | Lead => "ui-typography--lead"
  | Small => "ui-typography--small"
  | Muted => "ui-typography--muted"
  | Code => "ui-typography--code"
  }

let renderText = (text: MaybeSignal.t<string>) =>
  switch text {
  | Reactive(signal) => View.SignalText(signal)
  | Static(value) => View.text(value)
  }

@jsx.component
let make = (~text: MaybeSignal.t<string>, ~variant: variant=P, ~class: string="", ~style=?) => {
  let class = {
    let base = "ui-typography " ++ variantToClass(variant)
    class === "" ? base : base ++ " " ++ class
  }

  switch variant {
  | H1 => <h1 class ?style> {renderText(text)} </h1>
  | H2 => <h2 class ?style> {renderText(text)} </h2>
  | H3 => <h3 class ?style> {renderText(text)} </h3>
  | H4 => <h4 class ?style> {renderText(text)} </h4>
  | P | Lead | Muted => <p class ?style> {renderText(text)} </p>
  | Small => <small class ?style> {renderText(text)} </small>
  | Code => <code class ?style> {renderText(text)} </code>
  }
}
