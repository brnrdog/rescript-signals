open Xote
open Basefn

let version = "1.3.3"

let isActive = (url: string, pathname: string) => {
  url == pathname
}

// Sidebar section type
type sidebarItem = {
  label: string,
  url: string,
}

type sidebarSection = {
  title: string,
  items: array<sidebarItem>,
}

let sidebarSections: array<sidebarSection> = [
  {
    title: "GETTING STARTED",
    items: [{label: "Installation & Quick Start", url: "/getting-started"}],
  },
  {
    title: "API REFERENCE",
    items: [
      {label: "Signal", url: "/api/signal"},
      {label: "Computed", url: "/api/computed"},
      {label: "Effect", url: "/api/effect"},
    ],
  },
  {
    title: "RESOURCES",
    items: [
      {label: "Examples", url: "/examples"},
      {label: "Release Notes", url: "/release-notes"},
    ],
  },
]

// Mobile sidebar state
let sidebarOpen = Signal.make(false)

let closeSidebar = () => Signal.set(sidebarOpen, false)

module SidebarComponent = {
  @jsx.component
  let make = (~pathname: string) => {
    Component.signalFragment(
      Computed.make(() => {
        let isOpenVal = Signal.get(sidebarOpen)
        let sidebarClass = "sidebar" ++ (isOpenVal ? " open" : "")
        let overlayClass = "sidebar-overlay" ++ (isOpenVal ? " visible" : "")
        [
          <div class={overlayClass} onClick={_ => closeSidebar()} />,
          <nav class={sidebarClass} ariaLabel="Documentation navigation">
            {sidebarSections
            ->Array.map(section => {
              <div key={section.title} class="sidebar-section">
                <div class="sidebar-section-title"> {section.title->Component.text} </div>
                {section.items
                ->Array.map(item => {
                  let active = isActive(item.url, pathname)
                  <div key={item.url} class={"sidebar-item" ++ (active ? " active" : "")}>
                    <Router.Link to={item.url} onClick={_ => closeSidebar()}>
                      {item.label->Component.text}
                    </Router.Link>
                  </div>
                })
                ->Component.fragment}
              </div>
            })
            ->Component.fragment}
          </nav>,
        ]
      }),
    )
  }
}

@jsx.component
let make = () => {
  let location = Router.location()
  let currentPath = Computed.make(() => Signal.get(location).pathname)
  let isHomepage = Computed.make(() => Signal.get(currentPath) == "/")

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

  // Topbar
  let topbar =
    <header class="topbar">
      <div class="topbar-left">
        <button class="hamburger-btn" onClick={_ => Signal.update(sidebarOpen, v => !v)}>
          <Icon name={Menu} size={Sm} />
        </button>
        <Router.Link to="/" class="topbar-logo">
          <span style="display: inline-flex; align-items: center; justify-content: center; width: 24px; height: 24px; background: #22a646; border-radius: 6px; color: white; font-weight: bold; font-size: 14px;">
            {"S"->Component.text}
          </span>
          <span> {"ReScript Signals"->Component.text} </span>
          <span class="version-badge"> {("v" ++ version)->Component.text} </span>
        </Router.Link>
        <nav class="topbar-nav">
          {Component.signalFragment(
            Computed.make(() => {
              let path = Signal.get(currentPath)
              let learnActive =
                path == "/getting-started" ||
                  path->String.startsWith("/api") ||
                  path == "/examples"
              let _ = learnActive
              [
                <Router.Link to="/getting-started">
                  {"Learn"->Component.text}
                </Router.Link>,
                <Router.Link to="/api/signal">
                  {"API Reference"->Component.text}
                </Router.Link>,
                <Router.Link to="/release-notes">
                  {"Blog"->Component.text}
                </Router.Link>,
              ]
            }),
          )}
        </nav>
      </div>
      <div class="topbar-right">
        <Search />
        <a
          class="icon-btn"
          href="https://github.com/brnrdog/rescript-signals"
          target="_blank">
          <Icon name={GitHub} size={Sm} />
        </a>
        <ThemeToggle />
      </div>
    </header>

  // Render layout based on route
  Component.signalFragment(
    Computed.make(() => {
      if Signal.get(isHomepage) {
        [
          <div style="min-height: 100vh; display: flex; flex-direction: column;">
            {topbar}
            <main id="main-content" style="flex: 1;"> {routes} </main>
          </div>,
        ]
      } else {
        let path = Signal.get(currentPath)
        [
          <div style="min-height: 100vh; display: flex; flex-direction: column;">
            {topbar}
            <div class="docs-layout">
              <SidebarComponent pathname={path} />
              <main id="main-content" class="content-area">
                <div class="content-main">
                  <Breadcrumbs />
                  {routes}
                  <PageNavigation />
                  <FeedbackWidget />
                </div>
              </main>
            </div>
          </div>,
        ]
      }
    }),
  )
}
