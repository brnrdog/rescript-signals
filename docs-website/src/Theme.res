open Xote

/* Theme state.
 *
 * The value on `<html data-theme>` is established by an inline script in
 * index.html before first paint — this module adopts whatever that script
 * decided rather than deciding again, so there is no flash and no disagreement
 * between the two. */

@val @scope("document.documentElement")
external setHtmlAttribute: (string, string) => unit = "setAttribute"

@val @scope("document.documentElement")
external getHtmlAttribute: string => Nullable.t<string> = "getAttribute"

@val @scope("localStorage") external setItem: (string, string) => unit = "setItem"

let storageKey = "rescript-signals-theme"

let isBrowser: bool = %raw(`typeof document !== "undefined"`)

type t = Light | Dark

let toString = (theme: t) =>
  switch theme {
  | Light => "light"
  | Dark => "dark"
  }

let ofString = (value: string) =>
  switch value {
  | "dark" => Dark
  | _ => Light
  }

let initial = if isBrowser {
  switch getHtmlAttribute("data-theme")->Nullable.toOption {
  | Some(value) => ofString(value)
  | None => Light
  }
} else {
  Light
}

let current = Signal.make(initial)

let toggle = () =>
  Signal.update(current, theme =>
    switch theme {
    | Light => Dark
    | Dark => Light
    }
  )

/* Writes the choice back out. Skipped on the server, and skipped for the very
   first run in the browser since the inline script already set the attribute. */
let start = () =>
  if isBrowser {
    let first = ref(true)
    Effect.run(() => {
      let theme = Signal.get(current)->toString
      if first.contents {
        first := false
      } else {
        setHtmlAttribute("data-theme", theme)
        setItem(storageKey, theme)
      }
      None
    })
  }
