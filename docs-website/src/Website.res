open Xote

// Import page content modules
module Pages__GettingStarted = Pages__GettingStarted
module Pages__ApiSignal = Pages__ApiSignal
module Pages__ApiComputed = Pages__ApiComputed
module Pages__ApiEffect = Pages__ApiEffect
module Pages__Examples = Pages__Examples
module Pages__ReleaseNotes = Pages__ReleaseNotes

// 404 Page component
module NotFoundPage = {
  type props = {}

  let make = (_props: props) => {
    <Layout
      children={
        <div class="not-found">
          <h1> {Component.text("404")} </h1>
          <p> {Component.text("The page you're looking for doesn't exist.")} </p>
          {Router.link(
            ~to="/",
            ~attrs=[Component.attr("class", "btn btn-primary")],
            ~children=[Component.text("Go Home")],
            (),
          )}
        </div>
      }
    />
  }
}

// Main app
module App = {
  type props = {}

  let make = (_props: props) => {
    Router.routes(
      [
        {
          pattern: "/",
          render: _params => <HomePage />,
        },
        {
          pattern: "/getting-started",
          render: _params =>
            <DocsPage
              currentPath="/getting-started"
              pageTitle="Installation"
              pageLead="Learn how to install rescript-signals and start building reactive applications."
              content={<Pages__GettingStarted />}
            />,
        },
        {
          pattern: "/api/signal",
          render: _params =>
            <DocsPage
              currentPath="/api/signal"
              pageTitle="Signal"
              pageLead="Reactive state containers that form the foundation of the reactivity model."
              content={<Pages__ApiSignal />}
              tocItems=[
                {text: "Signal.make", id: "signal-make", level: 2},
                {text: "Signal.get", id: "signal-get", level: 2},
                {text: "Signal.peek", id: "signal-peek", level: 2},
                {text: "Signal.set", id: "signal-set", level: 2},
                {text: "Signal.update", id: "signal-update", level: 2},
                {text: "Signal.batch", id: "signal-batch", level: 2},
                {text: "Signal.untrack", id: "signal-untrack", level: 2},
              ]
            />,
        },
        {
          pattern: "/api/computed",
          render: _params =>
            <DocsPage
              currentPath="/api/computed"
              pageTitle="Computed"
              pageLead="Derived signals that automatically recompute when their dependencies change."
              content={<Pages__ApiComputed />}
              tocItems=[
                {text: "Computed.make", id: "computed-make", level: 2},
                {text: "Computed.get", id: "computed-get", level: 2},
                {text: "Computed.dispose", id: "computed-dispose", level: 2},
              ]
            />,
        },
        {
          pattern: "/api/effect",
          render: _params =>
            <DocsPage
              currentPath="/api/effect"
              pageTitle="Effect"
              pageLead="Side effects that run when their dependencies change, with automatic cleanup."
              content={<Pages__ApiEffect />}
              tocItems=[
                {text: "Effect.run", id: "effect-run", level: 2},
                {text: "Cleanup", id: "cleanup", level: 2},
                {text: "Disposal", id: "disposal", level: 2},
              ]
            />,
        },
        {
          pattern: "/examples",
          render: _params =>
            <DocsPage
              currentPath="/examples"
              pageTitle="Examples"
              pageLead="Interactive code examples demonstrating signals, computed values, and effects."
              content={<Pages__Examples />}
            />,
        },
        {
          pattern: "/release-notes",
          render: _params =>
            <DocsPage
              currentPath="/release-notes"
              pageTitle="Release Notes"
              pageLead="Changelog and release history for rescript-signals."
              content={<Pages__ReleaseNotes />}
            />,
        },
        {
          pattern: "*",
          render: _params => <NotFoundPage />,
        },
      ],
    )
  }
}
