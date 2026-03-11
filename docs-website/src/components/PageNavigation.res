open Xote

type pageInfo = {
  label: string,
  url: string,
}

let pageOrder: array<pageInfo> = [
  {label: "Getting Started", url: "/getting-started"},
  {label: "Signal API", url: "/api/signal"},
  {label: "Computed API", url: "/api/computed"},
  {label: "Effect API", url: "/api/effect"},
  {label: "Examples", url: "/examples"},
  {label: "Release Notes", url: "/release-notes"},
]

let findCurrentIndex = (pathname: string): option<int> => {
  pageOrder
  ->Array.findIndex(page => page.url == pathname)
  ->Some
  ->Option.flatMap(idx =>
    if idx >= 0 {
      Some(idx)
    } else {
      None
    }
  )
}

let getPreviousPage = (pathname: string): option<pageInfo> => {
  switch findCurrentIndex(pathname) {
  | Some(idx) if idx > 0 => pageOrder->Array.get(idx - 1)
  | _ => None
  }
}

let getNextPage = (pathname: string): option<pageInfo> => {
  switch findCurrentIndex(pathname) {
  | Some(idx) if idx < Array.length(pageOrder) - 1 => pageOrder->Array.get(idx + 1)
  | _ => None
  }
}

@jsx.component
let make = () => {
  let location = Router.location()
  let pathname = Computed.make(() => Signal.get(location).pathname)
  let prevPage = Computed.make(() => getPreviousPage(Signal.get(pathname)))
  let nextPage = Computed.make(() => getNextPage(Signal.get(pathname)))

  <div class="page-nav">
    {Component.signalFragment(
      Computed.make(() => {
        switch Signal.get(prevPage) {
        | Some(page) => [
            <Router.Link to={page.url} class="page-nav-link">
              <span class="page-nav-label">
                {"\u2190 Previous"->Component.text}
              </span>
              <span class="page-nav-title"> {page.label->Component.text} </span>
            </Router.Link>,
          ]
        | None => [<div />]
        }
      }),
    )}
    {Component.signalFragment(
      Computed.make(() => {
        switch Signal.get(nextPage) {
        | Some(page) => [
            <Router.Link to={page.url} class="page-nav-link next">
              <span class="page-nav-label">
                {"Next \u2192"->Component.text}
              </span>
              <span class="page-nav-title"> {page.label->Component.text} </span>
            </Router.Link>,
          ]
        | None => [<div />]
        }
      }),
    )}
  </div>
}
