open Xote
open Basefn

let getScrollY: unit => float = %raw(`function() { return window.scrollY || 0 }`)
let scrollToTop: unit => unit = %raw(`function() { window.scrollTo({ top: 0, behavior: 'smooth' }) }`)
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

  Component.signalFragment(
    Computed.make(() => {
      if Signal.get(isVisible) {
        [
          <div style="position: fixed; bottom: 2rem; right: 2rem; z-index: 100;">
            <Button variant={Secondary} onClick={_ => scrollToTop()}>
              <Icon name={ChevronUp} size={Sm} />
            </Button>
          </div>,
        ]
      } else {
        []
      }
    }),
  )
}
