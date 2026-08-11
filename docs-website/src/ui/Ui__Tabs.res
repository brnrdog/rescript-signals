open Xote

type tab = {
  value: string,
  label: string,
  content: View.node,
}

@jsx.component
let make = (~tabs: array<tab>, ~defaultValue: option<string>=?) => {
  let active = Signal.make(
    switch defaultValue {
    | Some(value) => value
    | None => tabs->Array.get(0)->Option.mapOr("", tab => tab.value)
    },
  )

  <div class="ui-tabs">
    <div class="ui-tabs__list">
      {tabs
      ->Array.map(tab => {
        let class = Computed.make(() =>
          Signal.get(active) === tab.value
            ? "ui-tabs__trigger ui-tabs__trigger--active"
            : "ui-tabs__trigger"
        )

        <button class onClick={_ => Signal.set(active, tab.value)}>
          {View.text(tab.label)}
        </button>
      })
      ->View.fragment}
    </div>
    <div class="ui-tabs__content">
      {View.signalFragment(
        Computed.make(() => {
          let activeValue = Signal.get(active)
          tabs->Array.find(tab => tab.value === activeValue)->Option.mapOr([], tab => [tab.content])
        }),
      )}
    </div>
  </div>
}
