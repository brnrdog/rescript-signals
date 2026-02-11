open Xote
open Xote.ReactiveProp
open Basefn

type pageInfo = {
  label: string,
  url: string,
}

// Define the order of pages in the documentation
let pageOrder: array<pageInfo> = [
  {label: "Getting Started", url: "/getting-started"},
  {label: "Signal API", url: "/api/signal"},
  {label: "Computed API", url: "/api/computed"},
  {label: "Effect API", url: "/api/effect"},
  {label: "Examples", url: "/examples"},
  {label: "Release Notes", url: "/release-notes"},
]

let findCurrentIndex = (pathname: string): option<int> => {
  pageOrder->Array.findIndex(page => page.url == pathname)->Some->Option.flatMap(idx =>
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

  <div style="margin-top: 3rem; padding-top: 1.5rem; border-top: 1px solid var(--basefn-color-border); display: flex; justify-content: space-between;">
    {Component.signalFragment(
      Computed.make(() => {
        switch Signal.get(prevPage) {
        | Some(page) => [
            <Router.Link
              to={page.url}
              style="display: flex; flex-direction: column; text-decoration: none; color: inherit;">
              <Typography text={static("Previous")} variant={Small} />
              <Typography text={static(page.label)} variant={H5} />
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
            <Router.Link
              to={page.url}
              style="display: flex; flex-direction: column; align-items: flex-end; text-decoration: none; color: inherit; margin-left: auto;">
              <Typography text={static("Next")} variant={Small} />
              <Typography text={static(page.label)} variant={H5} />
            </Router.Link>,
          ]
        | None => [<div />]
        }
      }),
    )}
  </div>
}
