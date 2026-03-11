open Xote

%%raw(`import 'highlight.js/styles/github-dark.min.css'`)

@module("highlight.js") external hljs: 'a = "default"
@send external highlight: ('a, string, {..}) => {"value": string} = "highlight"

@set external setInnerHTML: (Dom.element, string) => unit = "innerHTML"
@val @scope("document")
external getElementById: string => Nullable.t<Dom.element> = "getElementById"
@val external setTimeout: (unit => unit, int) => unit = "setTimeout"

let copyToClipboard: string => unit = %raw(`function(text) {
  navigator.clipboard.writeText(text)
}`)

let counter = ref(0)
let makeId = () => {
  counter := counter.contents + 1
  `codeblock-${counter.contents->Int.toString}`
}

@jsx.component
let make = (~code: string, ~language: string="rescript", ~filename: string="") => {
  let id = makeId()
  let copied = Signal.make(false)

  let _ = Effect.run(() => {
    setTimeout(
      () => {
        switch getElementById(id)->Nullable.toOption {
        | Some(el) =>
          let highlighted = hljs->highlight(code, {"language": language})
          el->setInnerHTML(highlighted["value"])
        | None => ()
        }
      },
      0,
    )
    None
  })

  let handleCopy = _ => {
    copyToClipboard(code)
    Signal.set(copied, true)
    setTimeout(() => Signal.set(copied, false), 2000)
  }

  <div class="code-block-wrapper">
    <div class="code-block-header">
      <span> {(filename != "" ? filename : language)->Component.text} </span>
      {Component.signalFragment(
        Computed.make(() => {
          let isCopied = Signal.get(copied)
          [
            <button class={"code-copy-btn" ++ (isCopied ? " copied" : "")} onClick={handleCopy}>
              <span> {(isCopied ? "Copied!" : "Copy")->Component.text} </span>
            </button>,
          ]
        }),
      )}
    </div>
    <div class="code-block">
      <pre>
        <code id class={"language-" ++ language}> {Component.text(code)} </code>
      </pre>
    </div>
  </div>
}

module Tabbed = {
  type tab = {
    label: string,
    code: string,
    language: string,
  }

  @jsx.component
  let make = (~tabs: array<tab>) => {
    let activeTab = Signal.make(0)

    <div class="code-block-wrapper">
      <div class="code-block-header" style="padding: 0; gap: 0;">
        <div class="code-block-tabs">
          {tabs
          ->Array.mapWithIndex((tab, idx) => {
            <button key={tab.label} class="code-block-tab" onClick={_ => Signal.set(activeTab, idx)}>
              {tab.label->Component.text}
            </button>
          })
          ->Component.fragment}
        </div>
      </div>
      {Component.signalFragment(
        Computed.make(() => {
          let idx = Signal.get(activeTab)
          switch tabs->Array.get(idx) {
          | Some(tab) => {
              let blockId = makeId()

              let _ = Effect.run(() => {
                setTimeout(
                  () => {
                    switch getElementById(blockId)->Nullable.toOption {
                    | Some(el) =>
                      let highlighted = hljs->highlight(tab.code, {"language": tab.language})
                      el->setInnerHTML(highlighted["value"])
                    | None => ()
                    }
                  },
                  0,
                )
                None
              })

              [
                <div class="code-block">
                  <pre>
                    <code id={blockId} class={"language-" ++ tab.language}>
                      {Component.text(tab.code)}
                    </code>
                  </pre>
                </div>,
              ]
            }
          | None => []
          }
        }),
      )}
    </div>
  }
}
