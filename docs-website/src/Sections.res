open Xote

/* The page outline, derived from Api.groups so the navigation cannot list a
   section that does not exist. */

type item = {id: string, label: string, level: int}

let outline: array<item> = Array.flat([
  [{id: "getting-started", label: "Getting started", level: 1}],
  [{id: "api", label: "API", level: 1}],
  Api.groups
  ->Array.map(group =>
    Array.concat(
      [{id: group.id, label: group.name, level: 2}],
      group.entries->Array.map(entry => {id: entry.id, label: entry.label, level: 3}),
    )
  )
  ->Array.flat,
  [{id: "changelog", label: "Changelog", level: 1}],
])

/* The three destinations in the header. */
let primary: array<item> = outline->Array.filter(item => item.level == 1)

/* Which top-level section each heading belongs to, so the header can highlight
   "API" while the reader is somewhere inside it. */
let owners: array<(string, string)> = {
  let current = ref("")
  outline->Array.map(item => {
    if item.level == 1 {
      current := item.id
    }
    (item.id, current.contents)
  })
}

let ownerOf = (id: string): string =>
  switch owners->Array.find(((key, _)) => key == id) {
  | Some((_, owner)) => owner
  | None => ""
  }

let active = Signal.make("")

/* The heading the reader is currently under: the last one whose top has passed
   the header. Measured rather than observed, so a section taller than the
   viewport still reports correctly. */
let findActive: array<string> => string = %raw(`function (ids) {
  var offset = 96
  var current = ""
  for (var i = 0; i < ids.length; i++) {
    var el = document.getElementById(ids[i])
    if (!el) continue
    if (el.getBoundingClientRect().top - offset <= 0) current = ids[i]
  }
  // The final section may be too short to ever cross the line.
  var atBottom = window.innerHeight + window.scrollY >= document.body.scrollHeight - 2
  if (atBottom && ids.length > 0) current = ids[ids.length - 1]
  return current
}`)

@val @scope("window") external addEventListener: (string, unit => unit) => unit = "addEventListener"
@val @scope("window")
external removeEventListener: (string, unit => unit) => unit = "removeEventListener"
@val @scope("window")
external requestAnimationFrame: (unit => unit) => int = "requestAnimationFrame"

let isBrowser: bool = %raw(`typeof window !== "undefined"`)

/* Tracks the current section. Reads are throttled to one per frame, since
   scroll fires far more often than the value can change. */
let track = () =>
  if isBrowser {
    let ids = outline->Array.map(item => item.id)
    let queued = ref(false)

    let measure = () => {
      queued := false
      Signal.set(active, findActive(ids))
    }

    let onScroll = () =>
      if !queued.contents {
        queued := true
        requestAnimationFrame(measure)->ignore
      }

    onScroll()
    addEventListener("scroll", onScroll)
    addEventListener("resize", onScroll)
  }
