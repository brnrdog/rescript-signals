open Xote

%%raw(`import 'highlight.js/styles/github-dark.min.css'`)

@module("highlight.js") external hljs: 'a = "default"
@send external highlight: ('a, string, {..}) => {"value": string} = "highlight"

// External binding to set innerHTML and query element
@set external setInnerHTML: (Dom.element, string) => unit = "innerHTML"
@val @scope("document") external getElementById: string => Nullable.t<Dom.element> = "getElementById"
@val external setTimeout: (unit => unit, int) => unit = "setTimeout"

// Simple counter for unique IDs
let counter = ref(0)
let makeId = () => {
  counter := counter.contents + 1
  `codeblock-${counter.contents->Int.toString}`
}

@jsx.component
let make = (~code: string, ~language: string="rescript") => {
  let id = makeId()

  // Use setTimeout to ensure the DOM element exists before we try to manipulate it
  let _ = Effect.run(() => {
    setTimeout(() => {
      switch getElementById(id)->Nullable.toOption {
      | Some(el) =>
        let highlighted = hljs->highlight(code, {"language": language})
        el->setInnerHTML(highlighted["value"])
      | None => ()
      }
    }, 0)
    None
  })

  <pre class="code-block" style="background: #0d1117; padding: 1rem; border-radius: 8px; overflow-x: auto; margin: 0.5rem 0;">
    <code
      id
      class={"language-" ++ language}
      style="font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, monospace; font-size: 14px; line-height: 1.5;">
      {Component.text(code)}
    </code>
  </pre>
}
