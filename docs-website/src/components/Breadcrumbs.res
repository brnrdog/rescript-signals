open Xote

type breadcrumb = {
  label: string,
  url: option<string>,
}

// Map paths to their breadcrumb hierarchy
let getBreadcrumbs = (pathname: string): array<breadcrumb> => {
  switch pathname {
  | "/getting-started" => [{label: "Getting Started", url: None}]
  | "/api/signal" => [{label: "API Reference", url: None}, {label: "Signal", url: None}]
  | "/api/computed" => [{label: "API Reference", url: None}, {label: "Computed", url: None}]
  | "/api/effect" => [{label: "API Reference", url: None}, {label: "Effect", url: None}]
  | "/examples" => [{label: "Examples", url: None}]
  | "/release-notes" => [{label: "Release Notes", url: None}]
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
          <nav style="margin-bottom: 1.5rem;">
            <div style="display: flex; align-items: center; gap: 0.5rem; font-size: 0.875rem; color: var(--basefn-text-tertiary);">
              {Component.fragment(
                crumbs->Array.mapWithIndex((crumb, idx) => {
                  let isLast = idx == Array.length(crumbs) - 1
                  let separator = if !isLast {
                    <span style="color: var(--basefn-text-muted);"> {"/"->Component.text} </span>
                  } else {
                    <span />
                  }

                  switch crumb.url {
                  | Some(url) =>
                    <span>
                      <Router.Link to={url} style="color: var(--basefn-text-tertiary); text-decoration: none;">
                        {crumb.label->Component.text}
                      </Router.Link>
                      {separator}
                    </span>
                  | None =>
                    <span style={isLast ? "color: var(--basefn-text-primary);" : ""}>
                      {crumb.label->Component.text}
                      {separator}
                    </span>
                  }
                }),
              )}
            </div>
          </nav>,
        ]
      }
    }),
  )
}
