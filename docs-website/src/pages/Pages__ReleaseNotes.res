open Xote
open Xote.ReactiveProp
open Basefn

// External bindings for fetch
@val external fetch: string => promise<'a> = "fetch"
@send external text: 'a => promise<string> = "text"

// Simple markdown renderer for changelog
let renderMarkdown = (markdown: string): string => {
  markdown
  // Headers
  ->String.replaceRegExp(%re("/^### (.+)$/gm"), "<h3>$1</h3>")
  ->String.replaceRegExp(%re("/^## (.+)$/gm"), "<h2 style=\"margin-top: 2rem; padding-top: 1rem; border-top: 1px solid var(--basefn-color-border);\">$1</h2>")
  ->String.replaceRegExp(%re("/^# (.+)$/gm"), "<h1>$1</h1>")
  // Bold
  ->String.replaceRegExp(%re("/\*\*(.+?)\*\*/g"), "<strong>$1</strong>")
  // Italic
  ->String.replaceRegExp(%re("/\*(.+?)\*/g"), "<em>$1</em>")
  // Code blocks
  ->String.replaceRegExp(%re("/```(\w+)?\n([\s\S]*?)```/g"), "<pre style=\"background: #0d1117; padding: 1rem; border-radius: 8px; overflow-x: auto; margin: 0.5rem 0;\"><code>$2</code></pre>")
  // Inline code
  ->String.replaceRegExp(%re("/`([^`]+)`/g"), "<code style=\"background: var(--basefn-color-muted); padding: 0.2em 0.4em; border-radius: 4px; font-size: 0.9em;\">$1</code>")
  // Links
  ->String.replaceRegExp(%re("/\[([^\]]+)\]\(([^)]+)\)/g"), "<a href=\"$2\" target=\"_blank\" style=\"color: var(--basefn-color-primary);\">$1</a>")
  // List items
  ->String.replaceRegExp(%re("/^- (.+)$/gm"), "<li style=\"margin-left: 1.5rem;\">$1</li>")
  ->String.replaceRegExp(%re("/^\* (.+)$/gm"), "<li style=\"margin-left: 1.5rem;\">$1</li>")
  // Paragraphs (double newlines)
  ->String.replaceRegExp(%re("/\n\n/g"), "</p><p style=\"margin: 1rem 0;\">")
  // Single newlines in list context
  ->String.replaceRegExp(%re("/\n(?=<li)/g"), "")
}

@set external setInnerHTML: (Dom.element, string) => unit = "innerHTML"
@val @scope("document") external getElementById: string => Nullable.t<Dom.element> = "getElementById"
@val external setTimeout: (unit => unit, int) => unit = "setTimeout"

type loadState = Loading | Loaded(string) | Error(string)

@jsx.component
let make = () => {
  let state = Signal.make(Loading)

  let _ = Effect.run(() => {
    let _ = fetch("https://raw.githubusercontent.com/brnrdog/rescript-signals/main/CHANGELOG.md")
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

  // Render the markdown content after state changes
  let _ = Effect.run(() => {
    switch Signal.get(state) {
    | Loaded(content) =>
      setTimeout(() => {
        switch getElementById("changelog-content")->Nullable.toOption {
        | Some(el) => el->setInnerHTML(renderMarkdown(content))
        | None => ()
        }
      }, 0)
    | _ => ()
    }
    None
  })

  <div>
    <div>
    <Typography text={static("Release Notes")} variant={H1} />
    <Typography
      text={static("View the changelog and release history for rescript-signals.")}
      variant={Lead}
    />
    <Separator />
    {Component.signalFragment(
      Computed.make(() => {
        switch Signal.get(state) {
        | Loading => [<Spinner />]
        | Error(msg) =>
          [
            <Alert variant={Error} message={Signal.make(msg)} />,
          ]
        | Loaded(_) =>
          [
            <div
              id="changelog-content"
              style="line-height: 1.6;"
            />,
          ]
        }
      }),
    )}
    </div>
    <EditOnGitHub pageName="Pages__ReleaseNotes" />
  </div>
}
