open Xote
open Xote.ReactiveProp
open Basefn

// Search index - contains searchable content for each page
type searchResult = {
  title: string,
  description: string,
  url: string,
  category: string,
}

let searchIndex: array<searchResult> = [
  // Getting Started
  {
    title: "Installation",
    description: "Learn how to install rescript-signals using npm, yarn, or pnpm",
    url: "/getting-started",
    category: "Getting Started",
  },
  // API - Signal
  {
    title: "Signal.make",
    description: "Create a new signal with an initial value",
    url: "/api/signal",
    category: "API",
  },
  {
    title: "Signal.get",
    description: "Read the current value and create a dependency",
    url: "/api/signal",
    category: "API",
  },
  {
    title: "Signal.set",
    description: "Set a new value for the signal",
    url: "/api/signal",
    category: "API",
  },
  {
    title: "Signal.update",
    description: "Update the signal value based on the previous value",
    url: "/api/signal",
    category: "API",
  },
  {
    title: "Signal.batch",
    description: "Batch multiple signal updates into a single notification cycle",
    url: "/api/signal",
    category: "API",
  },
  {
    title: "Signal.peek",
    description: "Read the current value without creating a dependency",
    url: "/api/signal",
    category: "API",
  },
  {
    title: "Signal.untrack",
    description: "Read signals without creating dependencies",
    url: "/api/signal",
    category: "API",
  },
  // API - Computed
  {
    title: "Computed.make",
    description: "Create a computed value from a function with automatic caching",
    url: "/api/computed",
    category: "API",
  },
  {
    title: "Computed.get",
    description: "Read the computed value and create a dependency",
    url: "/api/computed",
    category: "API",
  },
  {
    title: "Computed.dispose",
    description: "Manually dispose a computed and remove subscriptions",
    url: "/api/computed",
    category: "API",
  },
  // API - Effect
  {
    title: "Effect.run",
    description: "Create and run a side effect that tracks dependencies",
    url: "/api/effect",
    category: "API",
  },
  {
    title: "Effect Cleanup",
    description: "Return a cleanup function from effects for resource management",
    url: "/api/effect",
    category: "API",
  },
  {
    title: "Effect Disposal",
    description: "Stop an effect and run cleanup with disposer.dispose()",
    url: "/api/effect",
    category: "API",
  },
  // Examples
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
  // Release Notes
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

// DOM helper
let getInputValue: Dom.event => string = %raw(`function(e) { return e.target.value }`)

@jsx.component
let make = () => {
  let query = Signal.make("")
  let isOpen = Signal.make(false)
  let results = Computed.make(() => search(Signal.get(query)))

  let handleInput = evt => {
    let value = getInputValue(evt)
    Signal.set(query, value)
    Signal.set(isOpen, value->String.trim != "")
  }

  let handleResultClick = (url: string) => {
    Signal.set(isOpen, false)
    Signal.set(query, "")
    Router.push(url, ())
  }

  <div style="position: relative;">
    <Input
      value={reactive(query)}
      onInput={handleInput}
      placeholder="Search docs..."
    />
    {Component.signalFragment(
      Computed.make(() => {
        if Signal.get(isOpen) {
          let items = Signal.get(results)
          [
            <div
              style="position: absolute; top: 100%; left: 0; right: 0; background: var(--basefn-color-background); border: 1px solid var(--basefn-color-border); border-radius: 8px; margin-top: 4px; max-height: 400px; overflow-y: auto; z-index: 1000; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);">
              {if items->Array.length == 0 {
                <div style="padding: 1rem; color: var(--basefn-color-muted);">
                  {Component.text("No results found")}
                </div>
              } else {
                <div>
                  {items
                  ->Array.map(item => {
                    <div
                      key={item.title ++ item.url}
                      onClick={_ => handleResultClick(item.url)}
                      style="padding: 0.75rem 1rem; cursor: pointer; border-bottom: 1px solid var(--basefn-color-border);"
                      class="search-result">
                      <div style="display: flex; justify-content: space-between; align-items: center;">
                        <Typography text={static(item.title)} variant={H5} />
                        <Badge label={Signal.make(item.category)} variant={Secondary} size={Sm} />
                      </div>
                      <Typography text={static(item.description)} variant={Small} />
                    </div>
                  })
                  ->Component.fragment}
                </div>
              }}
            </div>,
          ]
        } else {
          []
        }
      }),
    )}
  </div>
}
