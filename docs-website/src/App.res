open Xote
open Xote.ReactiveProp
open Basefn

@jsx.component
let make = () => {
  let sections: array<sidebarNavSection> = [
    {
      title: Some("Getting Started"),
      items: [
        {label: "Home", icon: None, active: false, url: "/"},
        {label: "Installation", icon: None, active: false, url: "/getting-started"},
      ],
    },
    {
      title: Some("API Reference"),
      items: [
        {label: "Signal", icon: None, active: false, url: "/api/signal"},
        {label: "Computed", icon: None, active: false, url: "/api/computed"},
        {label: "Effect", icon: None, active: false, url: "/api/effect"},
      ],
    },
    {
      title: Some("Resources"),
      items: [{label: "Examples", icon: None, active: false, url: "/examples"}],
    },
  ]

  let logo = <Typography text={static("ReScript Signals")} variant={H4} />

  let footer =
    <a href="https://github.com/brnrdog/rescript-signals" target="_blank">
      <Typography text={static("GitHub")} variant={Small} />
    </a>

  let sidebar = <Sidebar logo sections footer />

  let topbar =
    <Topbar
      leftContent={<Typography text={static("Documentation")} variant={H5} />}
      rightContent={<ThemeToggle />}
    />

  <AppLayout sidebar topbar>
    <div style="padding: 2rem; max-width: 900px;">
      {Router.routes([
        {pattern: "/", render: _ => <Pages.Home />},
        {pattern: "/getting-started", render: _ => <Pages.GettingStarted />},
        {pattern: "/api/signal", render: _ => <Pages.ApiSignal />},
        {pattern: "/api/computed", render: _ => <Pages.ApiComputed />},
        {pattern: "/api/effect", render: _ => <Pages.ApiEffect />},
        {pattern: "/examples", render: _ => <Pages.Examples />},
      ])}
    </div>
  </AppLayout>
}
