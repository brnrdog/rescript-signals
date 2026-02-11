open Xote
open Xote.ReactiveProp
open Basefn

let version = "1.3.3"

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
    <a href="/" style="text-decoration: none; color: inherit;">
      <Typography text={static("ReScript Signals")} variant={H4} />
    </a>

  let topbarLeft =
    <a href="/" style="text-decoration: none; color: inherit; display: flex; align-items: center; gap: 0.75rem;">
      <Typography text={static("ReScript Signals")} variant={H5} />
      <Badge label={Signal.make("v" ++ version)} variant={Secondary} />
    </a>

  let topbarRight =
    <div style="display: flex; align-items: center; gap: 1rem;">
      <div style="width: 200px;">
        <Search />
      </div>
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
            <main style="flex: 1; padding: 2rem; max-width: 1200px; margin: 0 auto; width: 100%;">
              {routes}
            </main>
          </div>,
        ]
      } else {
        let sections = Signal.get(sectionsSignal)
        let sidebar = <Sidebar logo sections />
        [
          <AppLayout sidebar topbar>
            <div style="padding: 2rem; max-width: 900px;">
              <Breadcrumbs />
              {routes}
              <PageNavigation />
            </div>
          </AppLayout>,
        ]
      }
    }),
  )
}
