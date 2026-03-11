open Xote

@val external fetch: string => promise<'a> = "fetch"
@send external text: 'a => promise<string> = "text"

let renderMarkdown = (markdown: string): string => {
  markdown
  ->String.replaceRegExp(%re("/^### (.+)$/gm"), "<h3>$1</h3>")
  ->String.replaceRegExp(
    %re("/^## (.+)$/gm"),
    "<h2 style=\"margin-top: 2.5rem; padding-top: 1.5rem; border-top: 1px solid var(--border-default); font-size: 1.5rem;\">$1</h2>",
  )
  ->String.replaceRegExp(
    %re("/^# (.+)$/gm"),
    "<h1 style=\"font-family: 'Instrument Serif', Georgia, serif; font-size: 2rem;\">$1</h1>",
  )
  ->String.replaceRegExp(%re("/\*\*(.+?)\*\*/g"), "<strong>$1</strong>")
  ->String.replaceRegExp(%re("/\*(.+?)\*/g"), "<em>$1</em>")
  ->String.replaceRegExp(
    %re("/```(\w+)?\n([\s\S]*?)```/g"),
    "<pre style=\"background: var(--code-bg); padding: 1rem; border-radius: 10px; overflow-x: auto; margin: 0.75rem 0; border: 1px solid var(--code-border);\"><code style=\"font-family: 'JetBrains Mono', monospace; font-size: 0.8125rem; line-height: 1.65;\">$2</code></pre>",
  )
  ->String.replaceRegExp(
    %re("/`([^`]+)`/g"),
    "<code style=\"background: var(--code-bg); padding: 0.15em 0.4em; border-radius: 4px; font-size: 0.875em; font-family: 'JetBrains Mono', monospace; border: 1px solid var(--code-border);\">$1</code>",
  )
  ->String.replaceRegExp(
    %re("/\[([^\]]+)\]\(([^)]+)\)/g"),
    "<a href=\"$2\" target=\"_blank\" style=\"color: var(--text-accent);\">$1</a>",
  )
  ->String.replaceRegExp(
    %re("/^- (.+)$/gm"),
    "<li style=\"margin-left: 1.5rem; margin-bottom: 0.25rem;\">$1</li>",
  )
  ->String.replaceRegExp(
    %re("/^\* (.+)$/gm"),
    "<li style=\"margin-left: 1.5rem; margin-bottom: 0.25rem;\">$1</li>",
  )
  ->String.replaceRegExp(
    %re("/\n\n/g"),
    "</p><p style=\"margin: 0.75rem 0; line-height: 1.65; color: var(--text-secondary);\">",
  )
  ->String.replaceRegExp(%re("/\n(?=<li)/g"), "")
}

@set external setInnerHTML: (Dom.element, string) => unit = "innerHTML"
@val @scope("document")
external getElementById: string => Nullable.t<Dom.element> = "getElementById"
@val external setTimeout: (unit => unit, int) => unit = "setTimeout"

type loadState = Loading | Loaded(string) | Error(string)

@jsx.component
let make = () => {
  let state = Signal.make(Loading)

  let _ = Effect.run(() => {
    let _ =
      fetch("https://raw.githubusercontent.com/brnrdog/rescript-signals/main/CHANGELOG.md")
      ->Promise.then(response => response->text)
      ->Promise.then(content => {
        Signal.set(state, Loaded(content))
        Promise.resolve()
      })
      ->Promise.catch(_ => {
        Signal.set(state, Error("Failed to load changelog"))
        Promise.resolve()
      })
    None
  })

  let _ = Effect.run(() => {
    switch Signal.get(state) {
    | Loaded(content) =>
      setTimeout(
        () => {
          switch getElementById("changelog-content")->Nullable.toOption {
          | Some(el) => el->setInnerHTML(renderMarkdown(content))
          | None => ()
          }
        },
        0,
      )
    | _ => ()
    }
    None
  })

  <div>
    <h1 class="page-title"> {"Release Notes"->Component.text} </h1>
    <p class="lead">
      {"View the changelog and release history for rescript-signals."->Component.text}
    </p>
    {Component.signalFragment(
      Computed.make(() => {
        switch Signal.get(state) {
        | Loading => [
            <div
              style="padding: 3rem; text-align: center; color: var(--text-muted); font-size: 0.875rem;">
              {"Loading changelog..."->Component.text}
            </div>,
          ]
        | Error(msg) => [
            <Callout type_={Danger}>
              <p> {msg->Component.text} </p>
            </Callout>,
          ]
        | Loaded(_) => [<div id="changelog-content" style="line-height: 1.65;" />]
        }
      }),
    )}
    <EditOnGitHub pageName="Pages__ReleaseNotes" />
  </div>
}
