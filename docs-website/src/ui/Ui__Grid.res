open Xote

type columns = Count(int)

@jsx.component
let make = (~children: XoteJSX.element, ~columns: columns=Count(1), ~gap: string="1rem") => {
  let Count(count) = columns
  let style = `grid-template-columns: repeat(${count->Int.toString}, minmax(0, 1fr)); gap: ${gap};`

  <div class="ui-grid" style> {children} </div>
}
