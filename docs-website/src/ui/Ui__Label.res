open Xote

@jsx.component
let make = (~text: string) => {
  <label class="ui-label"> {View.text(text)} </label>
}
