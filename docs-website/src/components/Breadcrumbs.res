open Xote

type breadcrumb = {
  label: string,
  url: option<string>,
}

// Map paths to their breadcrumb hierarchy
let getBreadcrumbs = (pathname: string): array<breadcrumb> => {
  let home = {label: "Home", url: Some("/")}

  switch pathname {
  | "/getting-started" => [home, {label: "Getting Started", url: None}]
  | "/api/signal" => [home, {label: "API Reference", url: None}, {label: "Signal", url: None}]
  | "/api/computed" => [home, {label: "API Reference", url: None}, {label: "Computed", url: None}]
  | "/api/effect" => [home, {label: "API Reference", url: None}, {label: "Effect", url: None}]
  | "/examples" => [home, {label: "Examples", url: None}]
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
          <nav style="margin-bottom: 1rem;">
            <div style="display: flex; align-items: center; gap: 0.5rem; font-size: 0.875rem; color: var(--basefn-color-muted);">
              {Component.fragment(
                crumbs->Array.mapWithIndex((crumb, idx) => {
                  let isLast = idx == Array.length(crumbs) - 1
                  let separator = if !isLast {
                    <span style="color: var(--basefn-color-muted);"> {"/"->Component.text} </span>
                  } else {
                    <span />
                  }

                  switch crumb.url {
                  | Some(url) =>
                    <span>
                      <a href={url} style="color: var(--basefn-color-muted); text-decoration: none;">
                        {crumb.label->Component.text}
                      </a>
                      {separator}
                    </span>
                  | None =>
                    <span style={isLast ? "color: var(--basefn-color-foreground);" : ""}>
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
