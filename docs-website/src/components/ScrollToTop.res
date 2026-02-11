open Xote
open Basefn

// Get scroll position
let getScrollY: unit => float = %raw(`function() { return window.scrollY || 0 }`)

// Scroll to top
let scrollToTop: unit => unit = %raw(`function() { window.scrollTo({ top: 0, behavior: 'smooth' }) }`)

// Add scroll listener
let addScrollListener: (unit => unit) => unit => unit = %raw(`function(callback) {
  window.addEventListener('scroll', callback)
  return function() { window.removeEventListener('scroll', callback) }
}`)

@jsx.component
let make = () => {
  let isVisible = Signal.make(false)

  let _ = Effect.run(() => {
    let cleanup = addScrollListener(() => {
      let scrollY = getScrollY()
      Signal.set(isVisible, scrollY > 300.0)
    })
    Some(cleanup)
  })

  let handleClick = _ => {
    scrollToTop()
  }

  Component.signalFragment(
    Computed.make(() => {
      if Signal.get(isVisible) {
        [
          <div style="position: fixed; bottom: 2rem; right: 2rem; z-index: 1000;">
            <Button variant={Secondary} onClick={handleClick}>
              <Icon name={ChevronUp} size={Md} />
            </Button>
          </div>,
        ]
      } else {
        []
      }
    }),
  )
}
