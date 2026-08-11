open Xote

%%raw(`import './styles.css'`)

@val @scope("document")
external getElementById: string => Nullable.t<Dom.element> = "getElementById"

@get external firstElementChild: Dom.element => Nullable.t<Dom.element> = "firstElementChild"

/* The production build pre-renders the page into #app, so there is markup to
 * hydrate. `vite dev` serves index.html with the SSR outlet still empty, and
 * hydration only attaches reactivity to nodes that already exist — it never
 * creates any — so an empty container has to be client-rendered instead.
 * This also covers the client-only fallback prerender.mjs writes when SSR
 * fails for a route. */
switch getElementById("app")->Nullable.toOption {
| Some(container) =>
  switch firstElementChild(container)->Nullable.toOption {
  | Some(_) => Hydration.hydrate(() => <Page />, container)
  | None => View.mount(<Page />, container)
  }
| None => Console.error("Container element not found: app")
}

// Browser-only behaviour, started after mount so the markup it reads exists.
Theme.start()
Sections.track()
