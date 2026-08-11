open Xote

/* Copy-to-clipboard, shared by the code blocks and the install command.
   The label changes to "Copied" for two seconds, and the button announces the
   change to assistive technology through aria-live on the label. */

type clipboard
@val @scope("navigator") external clipboard: clipboard = "clipboard"
@send external writeText: (clipboard, string) => Promise.t<unit> = "writeText"
@val external setTimeout: (unit => unit, int) => int = "setTimeout"
@val external clearTimeout: int => unit = "clearTimeout"

@jsx.component
let make = (~text: string, ~label: string="Copy code") => {
  let copied = Signal.make(false)
  let pending = ref(None)

  let handleClick = _ => {
    clipboard->writeText(text)->Promise.done
    Signal.set(copied, true)
    switch pending.contents {
    | Some(id) => clearTimeout(id)
    | None => ()
    }
    pending := Some(setTimeout(() => Signal.set(copied, false), 2000))
  }

  View.element(
    "button",
    ~attrs=[
      View.attr("type", "button"),
      View.attr("class", "copy"),
      View.computedAttr("aria-label", () => Signal.get(copied) ? "Copied" : label),
    ],
    ~events=[("click", handleClick)],
    ~children=[
      View.signalFragment(
        Computed.make(() =>
          Signal.get(copied)
            ? [<Icon name={Check} />, <span class="copy-label"> {View.text("Copied")} </span>]
            : [<Icon name={Copy} />, <span class="copy-label"> {View.text("Copy")} </span>]
        ),
      ),
    ],
    (),
  )
}
