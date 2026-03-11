open Xote

type tocItem = {
  id: string,
  label: string,
}

@jsx.component
let make = (~items: array<tocItem>) => {
  if Array.length(items) == 0 {
    <div />
  } else {
    <aside class="toc-aside">
      <div class="toc-title"> {"On this page"->Component.text} </div>
      <ul class="toc-list">
        {items
        ->Array.map(item => {
          <li key={item.id}>
            <a href={"#" ++ item.id}> {item.label->Component.text} </a>
          </li>
        })
        ->Component.fragment}
      </ul>
    </aside>
  }
}
