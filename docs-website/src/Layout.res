open Xote

// ---- External bindings ----
@val @scope("document.documentElement")
external setHtmlAttribute: (string, string) => unit = "setAttribute"
@val @scope("localStorage") external getItem: string => Nullable.t<string> = "getItem"
@val @scope("localStorage") external setItem: (string, string) => unit = "setItem"
@val @scope("window") external addEventListener: (string, 'a) => unit = "addEventListener"
@val @scope("window") external removeEventListener: (string, 'a) => unit = "removeEventListener"

// ---- SSR guard ----
let isBrowser: bool = %raw(`typeof window !== "undefined"`)

// ---- Theme management ----
let initialTheme = {
  if isBrowser {
    switch getItem("rescript-signals-theme")->Nullable.toOption {
    | Some("light") => "light"
    | _ => "dark"
    }
  } else {
    "dark"
  }
}

let _ = if isBrowser {
  setHtmlAttribute("data-theme", initialTheme)
}

let theme = Signal.make(initialTheme)

let toggleTheme = () => {
  Signal.update(theme, current =>
    switch current {
    | "dark" => "light"
    | _ => "dark"
    }
  )
}

let _ = if isBrowser {
  Effect.run(() => {
    let t = Signal.get(theme)
    setHtmlAttribute("data-theme", t)
    setItem("rescript-signals-theme", t)
    None
  })->ignore
}

// ---- Search state ----
let searchOpen = Signal.make(false)

let openSearch = () => Signal.set(searchOpen, true)
let closeSearch = () => Signal.set(searchOpen, false)

// ---- Scroll state ----
let isScrolled = Signal.make(false)

// ---- Search items ----
type searchItem = {
  title: string,
  path: string,
  section: string,
}

let searchItems: array<searchItem> = [
  {title: "Installation", path: "/getting-started", section: "Getting Started"},
  {title: "Signal API", path: "/api/signal", section: "API Reference"},
  {title: "Computed API", path: "/api/computed", section: "API Reference"},
  {title: "Effect API", path: "/api/effect", section: "API Reference"},
  {title: "Examples", path: "/examples", section: "Resources"},
  {title: "Release Notes", path: "/release-notes", section: "Resources"},
]

// ---- Search Modal ----
module SearchModal = {
  type props = {}

  let make = (_props: props) => {
    let query = Signal.make("")
    let selectedIndex = Signal.make(0)

    let filteredItems = Computed.make(() => {
      let q = Signal.get(query)->String.toLowerCase
      if q == "" {
        searchItems
      } else {
        searchItems->Array.filter(item =>
          item.title->String.toLowerCase->String.includes(q) ||
            item.section->String.toLowerCase->String.includes(q)
        )
      }
    })

    let handleInput = (_evt: Dom.event) => {
      let value: string = %raw(`_evt.target.value`)
      Signal.set(query, value)
      Signal.set(selectedIndex, 0)
    }

    let navigateToResult = () => {
      let items = Signal.peek(filteredItems)
      let idx = Signal.peek(selectedIndex)
      switch items->Array.get(idx) {
      | Some(item) =>
        Router.push(item.path, ())
        closeSearch()
        Signal.set(query, "")
      | None => ()
      }
    }

    let handleKeyDown = (_evt: Dom.event) => {
      let key: string = %raw(`_evt.key`)
      switch key {
      | "ArrowDown" => {
          let _ = %raw(`_evt.preventDefault()`)
          let items = Signal.peek(filteredItems)
          Signal.update(selectedIndex, i => i < Array.length(items) - 1 ? i + 1 : i)
        }
      | "ArrowUp" => {
          let _ = %raw(`_evt.preventDefault()`)
          Signal.update(selectedIndex, i => i > 0 ? i - 1 : 0)
        }
      | "Enter" => navigateToResult()
      | "Escape" => {
          closeSearch()
          Signal.set(query, "")
        }
      | _ => ()
      }
    }

    View.signalFragment(
      Computed.make(() => {
        if Signal.get(searchOpen) {
          [
            View.element(
              "div",
              ~attrs=[View.attr("class", "search-overlay")],
              ~events=[
                (
                  "click",
                  _evt => {
                    let className: string = %raw(`_evt.target.className || ""`)
                    if className->String.includes("search-overlay") {
                      closeSearch()
                      Signal.set(query, "")
                    }
                  },
                ),
              ],
              ~children=[
                <div class="search-modal">
                  <div class="search-input-wrapper">
                    {Ui.Icon.make({name: Search, size: Sm})}
                    {View.element(
                      "input",
                      ~attrs=[
                        View.attr("class", "search-input"),
                        View.attr("placeholder", "Search documentation..."),
                        View.attr("autofocus", "true"),
                      ],
                      ~events=[("input", handleInput), ("keydown", handleKeyDown)],
                      (),
                    )}
                    <div class="search-trigger-key"> {View.text("esc")} </div>
                  </div>
                  <div class="search-results">
                    {View.signalFragment(
                      Computed.make(() => {
                        let items = Signal.get(filteredItems)
                        let idx = Signal.get(selectedIndex)
                        if Array.length(items) == 0 {
                          [<div class="search-empty"> {View.text("No results found.")} </div>]
                        } else {
                          let currentSection = ref("")
                          let globalIdx = ref(0)
                          items->Array.flatMap(
                            item => {
                              let nodes = []
                              if currentSection.contents != item.section {
                                currentSection := item.section
                                nodes
                                ->Array.push(
                                  <div class="search-group-label">
                                    {View.text(item.section)}
                                  </div>,
                                )
                                ->ignore
                              }
                              let myIdx = globalIdx.contents
                              let isActive = myIdx == idx
                              let cn = "search-result-item" ++ (isActive ? " active" : "")
                              nodes
                              ->Array.push(
                                View.element(
                                  "div",
                                  ~attrs=[View.attr("class", cn)],
                                  ~events=[
                                    (
                                      "click",
                                      _ => {
                                        Router.push(item.path, ())
                                        closeSearch()
                                        Signal.set(query, "")
                                      },
                                    ),
                                  ],
                                  ~children=[
                                    <div class="search-result-title">
                                      {View.text(item.title)}
                                    </div>,
                                  ],
                                  (),
                                ),
                              )
                              ->ignore
                              globalIdx := myIdx + 1
                              nodes
                            },
                          )
                        }
                      }),
                    )}
                  </div>
                  <div class="search-footer">
                    {View.text("Use arrow keys to navigate, Enter to select, Esc to close")}
                  </div>
                </div>,
              ],
              (),
            ),
          ]
        } else {
          []
        }
      }),
    )
  }
}

// ---- Header ----
module Header = {
  type props = {}

  let make = (_props: props) => {
    // Scroll listener
    let _ = if isBrowser {
      Effect.run(() => {
        let handleScroll = () => {
          let scrollY: float = %raw(`window.scrollY`)
          Signal.set(isScrolled, scrollY > 10.0)
        }
        addEventListener("scroll", handleScroll)
        Some(() => removeEventListener("scroll", handleScroll))
      })->ignore
    }

    View.element(
      "header",
      ~attrs=[
        View.computedAttr("class", () =>
          Signal.get(isScrolled) ? "site-header scrolled" : "site-header"
        ),
      ],
      ~children=[
        <div class="header-inner">
          <div class="header-left">
            {Router.link(
              ~to="/",
              ~attrs=[View.attr("class", "header-logo-link")],
              ~children=[<span> {View.text("rescript-signals")} </span>],
              (),
            )}
            <nav class="header-nav">
              {Router.link(
                ~to="/getting-started",
                ~attrs=[View.attr("class", "header-nav-link")],
                ~children=[View.text("Docs")],
                (),
              )}
              {Router.link(
                ~to="/api/signal",
                ~attrs=[View.attr("class", "header-nav-link")],
                ~children=[View.text("API Reference")],
                (),
              )}
              {Router.link(
                ~to="/examples",
                ~attrs=[View.attr("class", "header-nav-link")],
                ~children=[View.text("Examples")],
                (),
              )}
            </nav>
          </div>
          <div class="header-right">
            {View.element(
              "button",
              ~attrs=[View.attr("class", "search-trigger")],
              ~events=[("click", _ => openSearch())],
              ~children=[
                Ui.Icon.make({name: Search, size: Sm}),
                <span> {View.text("Search docs...")} </span>,
                <div class="search-trigger-keys">
                  <span class="search-trigger-key"> {View.text("\u2318")} </span>
                  <span class="search-trigger-key"> {View.text("K")} </span>
                </div>,
              ],
              (),
            )}
            {View.element(
              "a",
              ~attrs=[
                View.attr("href", "https://github.com/brnrdog/rescript-signals"),
                View.attr("target", "_blank"),
                View.attr("class", "gh-star-btn"),
                View.attr("title", "Star on GitHub"),
              ],
              ~children=[
                Ui.Icon.make({name: Star, size: Sm}),
                View.element(
                  "span",
                  ~attrs=[View.attr("class", "gh-star-label")],
                  ~children=[View.text("Star")],
                  (),
                ),
              ],
              (),
            )}
            {View.element(
              "a",
              ~attrs=[
                View.attr("href", "https://github.com/brnrdog/rescript-signals"),
                View.attr("target", "_blank"),
                View.attr("class", "header-icon-btn"),
                View.attr("title", "GitHub"),
              ],
              ~children=[Ui.Icon.make({name: GitHub, size: Sm})],
              (),
            )}
            {View.element(
              "button",
              ~attrs=[
                View.attr("class", "header-icon-btn"),
                View.attr("title", "Toggle theme"),
              ],
              ~events=[("click", _ => toggleTheme())],
              ~children=[
                View.signalFragment(
                  Computed.make(() =>
                    Signal.get(theme) == "dark"
                      ? [Ui.Icon.make({name: Sun, size: Sm})]
                      : [Ui.Icon.make({name: Moon, size: Sm})]
                  ),
                ),
              ],
              (),
            )}
            {View.element(
              "button",
              ~attrs=[
                View.attr("class", "header-icon-btn mobile-menu-btn"),
                View.attr("title", "Menu"),
              ],
              ~events=[("click", _ => openSearch())],
              ~children=[Ui.Icon.make({name: Menu, size: Sm})],
              (),
            )}
          </div>
        </div>,
      ],
      (),
    )
  }
}

// ---- Footer ----
module Footer = {
  type props = {}

  let make = (_props: props) => {
    let year = Date.now()->Date.fromTime->Date.getFullYear->Int.toString

    <footer class="site-footer">
      <div class="footer-inner">
        <div class="footer-grid">
          <div class="footer-brand">
            <div class="footer-brand-logo">
              <span> {View.text("rescript-signals")} </span>
            </div>
            <p>
              {View.text(
                "A lightweight, high-performance reactive signals library for ReScript with zero runtime dependencies.",
              )}
            </p>
          </div>
          <div class="footer-col">
            <h4> {View.text("Docs")} </h4>
            <ul>
              <li>
                {Router.link(
                  ~to="/getting-started",
                  ~children=[View.text("Getting Started")],
                  (),
                )}
              </li>
              <li>
                {Router.link(~to="/api/signal", ~children=[View.text("API Reference")], ())}
              </li>
              <li> {Router.link(~to="/examples", ~children=[View.text("Examples")], ())} </li>
            </ul>
          </div>
          <div class="footer-col">
            <h4> {View.text("Community")} </h4>
            <ul>
              <li>
                <a href="https://github.com/brnrdog/rescript-signals" target="_blank">
                  {View.text("GitHub")}
                </a>
              </li>
              <li>
                <a href="https://www.npmjs.com/package/rescript-signals" target="_blank">
                  {View.text("npm")}
                </a>
              </li>
            </ul>
          </div>
          <div class="footer-col">
            <h4> {View.text("More")} </h4>
            <ul>
              <li>
                <a href="https://rescript-lang.org/" target="_blank">
                  {View.text("ReScript")}
                </a>
              </li>
              <li>
                <a href="https://github.com/tc39/proposal-signals" target="_blank">
                  {View.text("TC39 Signals")}
                </a>
              </li>
              <li>
                <a href="https://brnrdog.github.io/xote/" target="_blank">
                  {View.text("xote")}
                </a>
              </li>
            </ul>
          </div>
        </div>
        <div class="footer-bottom">
          <div> {View.text(`Copyright \u00A9 ${year} Bernardo Gurgel. MIT License.`)} </div>
          <div class="footer-bottom-right">
            {View.text("Built with ")}
            <a href="https://brnrdog.github.io/xote/" target="_blank"> {View.text("xote")} </a>
          </div>
        </div>
      </div>
    </footer>
  }
}

// ---- Global Cmd+K shortcut ----
let _ = if isBrowser {
  Effect.run(() => {
    let handler = (_evt: Dom.event) => {
      let ctrlOrMeta: bool = %raw(`_evt.ctrlKey || _evt.metaKey`)
      let key: string = %raw(`_evt.key`)
      if ctrlOrMeta && key == "k" {
        let _ = %raw(`_evt.preventDefault()`)
        if Signal.peek(searchOpen) {
          closeSearch()
        } else {
          openSearch()
        }
      }
    }
    addEventListener("keydown", handler)
    Some(() => removeEventListener("keydown", handler))
  })->ignore
}

// ---- Main layout wrapper ----
type props = {children: View.node}

let make = (props: props) => {
  <div>
    <Header />
    <main id="main-content"> {props.children} </main>
    <Footer />
    <SearchModal />
  </div>
}
