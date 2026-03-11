open Xote
open Basefn

type searchResult = {
  title: string,
  description: string,
  url: string,
  category: string,
}

let searchIndex: array<searchResult> = [
  {
    title: "Installation",
    description: "Learn how to install rescript-signals using npm, yarn, or pnpm",
    url: "/getting-started",
    category: "Getting Started",
  },
  {
    title: "Signal.make",
    description: "Create a new signal with an initial value",
    url: "/api/signal",
    category: "API Reference",
  },
  {
    title: "Signal.get",
    description: "Read the current value and create a dependency",
    url: "/api/signal",
    category: "API Reference",
  },
  {
    title: "Signal.set",
    description: "Set a new value for the signal",
    url: "/api/signal",
    category: "API Reference",
  },
  {
    title: "Signal.update",
    description: "Update the signal value based on the previous value",
    url: "/api/signal",
    category: "API Reference",
  },
  {
    title: "Signal.batch",
    description: "Batch multiple signal updates into a single notification cycle",
    url: "/api/signal",
    category: "API Reference",
  },
  {
    title: "Signal.peek",
    description: "Read the current value without creating a dependency",
    url: "/api/signal",
    category: "API Reference",
  },
  {
    title: "Signal.untrack",
    description: "Read signals without creating dependencies",
    url: "/api/signal",
    category: "API Reference",
  },
  {
    title: "Computed.make",
    description: "Create a computed value from a function with automatic caching",
    url: "/api/computed",
    category: "API Reference",
  },
  {
    title: "Computed.get",
    description: "Read the computed value and create a dependency",
    url: "/api/computed",
    category: "API Reference",
  },
  {
    title: "Computed.dispose",
    description: "Manually dispose a computed and remove subscriptions",
    url: "/api/computed",
    category: "API Reference",
  },
  {
    title: "Effect.run",
    description: "Create and run a side effect that tracks dependencies",
    url: "/api/effect",
    category: "API Reference",
  },
  {
    title: "Effect Cleanup",
    description: "Return a cleanup function from effects for resource management",
    url: "/api/effect",
    category: "API Reference",
  },
  {
    title: "Counter Example",
    description: "Simple counter demonstrating signals and reactivity",
    url: "/examples",
    category: "Examples",
  },
  {
    title: "Todo List Example",
    description: "Todo list with add and remove functionality",
    url: "/examples",
    category: "Examples",
  },
  {
    title: "Shopping Cart Example",
    description: "Derived state example with computed values for totals",
    url: "/examples",
    category: "Examples",
  },
  {
    title: "Release Notes",
    description: "View the changelog and release history",
    url: "/release-notes",
    category: "Resources",
  },
]

let search = (query: string): array<searchResult> => {
  if query->String.trim == "" {
    []
  } else {
    let lowerQuery = query->String.toLowerCase
    searchIndex->Array.filter(item => {
      item.title->String.toLowerCase->String.includes(lowerQuery) ||
        item.description->String.toLowerCase->String.includes(lowerQuery) ||
        item.category->String.toLowerCase->String.includes(lowerQuery)
    })
  }
}

let groupByCategory = (results: array<searchResult>): array<(string, array<searchResult>)> => {
  let groups: ref<array<(string, array<searchResult>)>> = ref([])
  results->Array.forEach(item => {
    let found = ref(false)
    groups :=
      groups.contents->Array.map(((cat, items)) => {
        if cat == item.category {
          found := true
          (cat, Array.concat(items, [item]))
        } else {
          (cat, items)
        }
      })
    if !found.contents {
      groups := Array.concat(groups.contents, [(item.category, [item])])
    }
  })
  groups.contents
}

let getInputValue: Dom.event => string = %raw(`function(e) { return e.target.value }`)
let getKeyboardKey: Dom.event => string = %raw(`function(e) { return e.key }`)
let preventDefault: Dom.event => unit = %raw(`function(e) { e.preventDefault() }`)
let stopPropagation: Dom.event => unit = %raw(`function(e) { e.stopPropagation() }`)

let addKeydownListener: (Dom.event => unit) => unit => unit = %raw(`function(callback) {
  document.addEventListener('keydown', callback);
  return function() { document.removeEventListener('keydown', callback) };
}`)

@val external setTimeout: (unit => unit, int) => unit = "setTimeout"

@jsx.component
let make = () => {
  let query = Signal.make("")
  let isOpen = Signal.make(false)
  let highlightedIndex = Signal.make(0)
  let results = Computed.make(() => search(Signal.get(query)))
  let grouped = Computed.make(() => groupByCategory(Signal.get(results)))

  let _ = Effect.run(() => {
    let cleanup = addKeydownListener(evt => {
      let key = getKeyboardKey(evt)
      let hasMeta: Dom.event => bool = %raw(`function(e) { return e.metaKey || e.ctrlKey }`)
      if key == "k" && hasMeta(evt) {
        preventDefault(evt)
        Signal.set(isOpen, !Signal.get(isOpen))
      }
      if key == "Escape" && Signal.get(isOpen) {
        Signal.set(isOpen, false)
        Signal.set(query, "")
      }
    })
    Some(cleanup)
  })

  let handleInput = evt => {
    let value = getInputValue(evt)
    Signal.set(query, value)
    Signal.set(highlightedIndex, 0)
  }

  let handleResultClick = (url: string) => {
    Signal.set(isOpen, false)
    Signal.set(query, "")
    Router.push(url, ())
  }

  let openSearch = _ => {
    Signal.set(isOpen, true)
    Signal.set(query, "")
    Signal.set(highlightedIndex, 0)
    setTimeout(
      () => {
        let _: unit = %raw(`(function() {
          var el = document.getElementById('search-input');
          if (el) el.focus();
        })()`)
      },
      50,
    )
  }

  let handleModalKeydown = (evt: Dom.event) => {
    let key = getKeyboardKey(evt)
    let allResults = Signal.get(results)
    let count = Array.length(allResults)

    switch key {
    | "ArrowDown" => {
        preventDefault(evt)
        let m = if count > 1 { count } else { 1 }
        Signal.update(highlightedIndex, n => mod(n + 1, m))
      }
    | "ArrowUp" => {
        preventDefault(evt)
        let m = if count > 1 { count } else { 1 }
        Signal.update(highlightedIndex, n => mod(n - 1 + m, m))
      }
    | "Enter" => {
        let idx = Signal.get(highlightedIndex)
        switch allResults->Array.get(idx) {
        | Some(item) => handleResultClick(item.url)
        | None => ()
        }
      }
    | _ => ()
    }
  }

  let trigger =
    <button class="search-trigger" onClick={openSearch}>
      <Icon name={Search} size={Sm} />
      <span> {"Search docs..."->Component.text} </span>
      <kbd> {"\u2318K"->Component.text} </kbd>
    </button>

  let modal = Component.signalFragment(
    Computed.make(() => {
      if Signal.get(isOpen) {
        let groups = Signal.get(grouped)
        let allResults = Signal.get(results)
        let hiIdx = Signal.get(highlightedIndex)

        [
          <div
            class="search-modal-overlay"
            onClick={_ => {
              Signal.set(isOpen, false)
              Signal.set(query, "")
            }}>
            <div class="search-modal" onClick={stopPropagation} onKeyDown={handleModalKeydown}>
              <div class="search-input-wrapper">
                <Icon name={Search} size={Sm} />
                <input
                  id="search-input"
                  class="search-input"
                  placeholder="Search documentation..."
                  value={Signal.get(query)}
                  onInput={handleInput}
                />
                <kbd
                  style="font-size: 0.6875rem; padding: 0.125rem 0.5rem; border: 1px solid var(--border-default); border-radius: 4px; background: var(--bg-elevated); color: var(--text-muted);">
                  {"esc"->Component.text}
                </kbd>
              </div>
              <div class="search-results">
                {if Signal.get(query)->String.trim == "" {
                  <div class="search-empty">
                    {"Type to search the documentation..."->Component.text}
                  </div>
                } else if Array.length(allResults) == 0 {
                  <div class="search-empty"> {"No results found"->Component.text} </div>
                } else {
                  let globalIdx = ref(0)
                  <div>
                    {groups
                    ->Array.map(((category, items)) => {
                      <div key={category}>
                        <div class="search-group-title"> {category->Component.text} </div>
                        {items
                        ->Array.map(item => {
                          let idx = globalIdx.contents
                          globalIdx := globalIdx.contents + 1
                          let isHighlighted = idx == hiIdx
                          <div
                            key={item.title ++ item.url ++ idx->Int.toString}
                            class={"search-result-item" ++ (
                              isHighlighted ? " highlighted" : ""
                            )}
                            onClick={_ => handleResultClick(item.url)}>
                            <div class="search-result-title">
                              {item.title->Component.text}
                            </div>
                            <div class="search-result-desc">
                              {item.description->Component.text}
                            </div>
                          </div>
                        })
                        ->Component.fragment}
                      </div>
                    })
                    ->Component.fragment}
                  </div>
                }}
              </div>
              <div class="search-footer">
                <span>
                  <kbd> {"\u2191"->Component.text} </kbd>
                  <kbd> {"\u2193"->Component.text} </kbd>
                  {" to navigate"->Component.text}
                </span>
                <span>
                  <kbd> {"\u23CE"->Component.text} </kbd>
                  {" to select"->Component.text}
                </span>
                <span>
                  <kbd> {"esc"->Component.text} </kbd>
                  {" to close"->Component.text}
                </span>
              </div>
            </div>
          </div>,
        ]
      } else {
        []
      }
    }),
  )

  <div> {trigger} {modal} </div>
}
