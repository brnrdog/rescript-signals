open Xote

%%raw(`import 'highlight.js/styles/github-dark.min.css'`)

@module("highlight.js") external hljs: 'a = "default"
@send external highlight: ('a, string, {..}) => {"value": string} = "highlight"

// External binding to set innerHTML and query element
@set external setInnerHTML: (Dom.element, string) => unit = "innerHTML"
@val @scope("document") external getElementById: string => Nullable.t<Dom.element> = "getElementById"

// Simple counter for unique IDs
let counter = ref(0)
let makeId = () => {
  counter := counter.contents + 1
  `codeblock-${counter.contents->Int.toString}`
}

@jsx.component
let make = (~code: string, ~language: string="rescript") => {
  let id = makeId()

  let _ = Effect.run(() => {
    switch getElementById(id)->Nullable.toOption {
    | Some(el) =>
      let highlighted = hljs->highlight(code, {"language": language})
      el->setInnerHTML(highlighted["value"])
    | None => ()
    }
    None
  })

  <pre class="code-block" style="background: #0d1117; padding: 1rem; border-radius: 8px; overflow-x: auto;">
    <code
      id
      class={"language-" ++ language}
      style="font-family: monospace; font-size: 14px;"
    />
  </pre>
}
