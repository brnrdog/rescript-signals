open Xote

type breadcrumb = {
  label: string,
  url: option<string>,
}

let getBreadcrumbs = (pathname: string): array<breadcrumb> => {
  let home = {label: "Home", url: Some("/")}

  switch pathname {
  | "/getting-started" => [home, {label: "Learn", url: None}, {label: "Getting Started", url: None}]
  | "/api/signal" => [
      home,
      {label: "API Reference", url: None},
      {label: "Signal", url: None},
    ]
  | "/api/computed" => [
      home,
      {label: "API Reference", url: None},
      {label: "Computed", url: None},
    ]
  | "/api/effect" => [
      home,
      {label: "API Reference", url: None},
      {label: "Effect", url: None},
    ]
  | "/examples" => [home, {label: "Learn", url: None}, {label: "Examples", url: None}]
  | "/release-notes" => [home, {label: "Release Notes", url: None}]
  | _ => []
  }
}

@jsx.component
let make = () => {
  let location = Router.location()
  let breadcrumbs = Computed.make(() => getBreadcrumbs(Signal.get(location).pathname))

  Component.signalFragment(
    Computed.make(() => {
      let crumbs = Signal.get(breadcrumbs)
      if Array.length(crumbs) == 0 {
        []
      } else {
        [
          <nav class="breadcrumbs" ariaLabel="Breadcrumb">
            {Component.fragment(
              crumbs->Array.mapWithIndex((crumb, idx) => {
                let isLast = idx == Array.length(crumbs) - 1
                let separator = if !isLast {
                  <span class="separator"> {"/"->Component.text} </span>
                } else {
                  <span />
                }

                switch crumb.url {
                | Some(url) =>
                  <span key={idx->Int.toString}>
                    <Router.Link to={url}> {crumb.label->Component.text} </Router.Link>
                    {separator}
                  </span>
                | None =>
                  <span key={idx->Int.toString} class={isLast ? "current" : ""}>
                    {crumb.label->Component.text}
                    {separator}
                  </span>
                }
              }),
            )}
          </nav>,
        ]
      }
    }),
  )
}
