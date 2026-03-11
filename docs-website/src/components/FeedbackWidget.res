open Xote

@jsx.component
let make = () => {
  let selected = Signal.make("")

  let handleClick = (value: string) => {
    Signal.set(selected, value)
  }

  <div class="feedback-widget">
    <span> {"Was this page helpful?"->Component.text} </span>
    {Component.signalFragment(
      Computed.make(() => {
        let sel = Signal.get(selected)
        if sel != "" {
          [<span style="color: var(--green-400); font-weight: 500;"> {"Thanks for your feedback!"->Component.text} </span>]
        } else {
          [
            <button
              class="feedback-btn"
              onClick={_ => handleClick("yes")}>
              {"Yes"->Component.text}
            </button>,
            <button
              class="feedback-btn"
              onClick={_ => handleClick("no")}>
              {"No"->Component.text}
            </button>,
          ]
        }
      }),
    )}
  </div>
}
