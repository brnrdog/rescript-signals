open Xote
open Xote.ReactiveProp
open Basefn

// Fetch latest version from npm registry
@val external fetch: string => promise<'a> = "fetch"
@send external json: 'a => promise<'b> = "json"

let npmVersion = Signal.make("...")

let _ = fetch("https://registry.npmjs.org/rescript-signals/latest")
->Promise.then(response => response->json)
->Promise.then((data: {"version": string}) => {
  Signal.set(npmVersion, data["version"])
  Promise.resolve()
})
->Promise.catch(_ => {
  Signal.set(npmVersion, "1.3.3")
  Promise.resolve()
})

// Helper to check if a URL matches the current path
let isActive = (url: string, pathname: string) => {
  url == pathname
}

@jsx.component
let make = () => {
  let location = Router.location()
  let isHomepage = Computed.make(() => Signal.get(location).pathname == "/")
  let currentPath = Computed.make(() => Signal.get(location).pathname)

  // Create reactive sections that update based on current path
  let makeSections = (pathname: string): array<sidebarNavSection> => [
    {
      title: Some("Getting Started"),
      items: [
        {label: "Installation", icon: None, active: isActive("/getting-started", pathname), url: "/getting-started"},
      ],
    },
    {
      title: Some("API Reference"),
      items: [
        {label: "Signal", icon: None, active: isActive("/api/signal", pathname), url: "/api/signal"},
        {label: "Computed", icon: None, active: isActive("/api/computed", pathname), url: "/api/computed"},
        {label: "Effect", icon: None, active: isActive("/api/effect", pathname), url: "/api/effect"},
      ],
    },
    {
      title: Some("Resources"),
      items: [
        {label: "Examples", icon: None, active: isActive("/examples", pathname), url: "/examples"},
        {label: "Release Notes", icon: None, active: isActive("/release-notes", pathname), url: "/release-notes"},
      ],
    },
  ]

  let sectionsSignal = Computed.make(() => makeSections(Signal.get(currentPath)))

  let logo =
    <Router.Link to="/" style="text-decoration: none; color: inherit;">
      <Typography text={static("rescript-signals")} variant={H4} />
    </Router.Link>

  let topbarLeft =
    <div style="display: flex; align-items: center; gap: 1rem;">
      <Router.Link to="/" style="text-decoration: none; color: inherit; display: flex; align-items: center;">
        <Typography text={static("rescript-signals")} variant={H5} />
      </Router.Link>
      <div class="topbar-nav-links">
        <Router.Link to="/getting-started"> {Component.text("Installation")} </Router.Link>
        <Router.Link to="/api/signal"> {Component.text("API Reference")} </Router.Link>
        <Router.Link to="/examples"> {Component.text("Examples")} </Router.Link>
      </div>
    </div>

  let topbarRight =
    <div style="display: flex; align-items: center; gap: 0.75rem;">
      <div style="width: 200px;">
        <Search />
      </div>
      <Badge label={Computed.make(() => "v" ++ Signal.get(npmVersion))} variant={Secondary} size={Sm} />
      <a
        href="https://github.com/brnrdog/rescript-signals"
        target="_blank"
        style="color: inherit; display: flex; align-items: center;">
        <Icon name={GitHub} size={Md} />
      </a>
      <ThemeToggle />
    </div>

  let topbar = <Topbar leftContent={topbarLeft} rightContent={topbarRight} />

  let routes =
    Router.routes([
      {pattern: "/", render: _ => <Pages.Home />},
      {pattern: "/getting-started", render: _ => <Pages.GettingStarted />},
      {pattern: "/api/signal", render: _ => <Pages.ApiSignal />},
      {pattern: "/api/computed", render: _ => <Pages.ApiComputed />},
      {pattern: "/api/effect", render: _ => <Pages.ApiEffect />},
      {pattern: "/examples", render: _ => <Pages.Examples />},
      {pattern: "/release-notes", render: _ => <Pages.ReleaseNotes />},
    ])

  // Render different layouts based on whether we're on the homepage
  Component.signalFragment(
    Computed.make(() => {
      if Signal.get(isHomepage) {
        [
          <div style="min-height: 100vh; display: flex; flex-direction: column;">
            {topbar}
            <main style="flex: 1;">
              {routes}
            </main>
          </div>,
        ]
      } else {
        let sections = Signal.get(sectionsSignal)
        let sidebar = <Sidebar logo sections />
        [
          <AppLayout sidebar topbar>
            <div class="doc-content">
              <Breadcrumbs />
              {routes}
              <PageNavigation />
            </div>
            <ScrollToTop />
          </AppLayout>,
        ]
      }
    }),
  )
}
