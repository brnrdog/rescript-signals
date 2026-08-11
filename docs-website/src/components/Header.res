open Xote

let navLink = (item: Sections.item) =>
  View.element(
    "a",
    ~attrs=[
      View.attr("href", "#" ++ item.id),
      View.computedAttr("class", () =>
        Sections.ownerOf(Signal.get(Sections.active)) == item.id
          ? "nav-link is-current"
          : "nav-link"
      ),
    ],
    ~children=[View.text(item.label)],
    (),
  )

@jsx.component
let make = () =>
  <header class="site-header">
    <div class="header-inner">
      <a href="#top" class="wordmark">
        {View.text("rescript-signals")}
      </a>
      <nav class="header-nav" ariaLabel="Sections">
        {Sections.primary->Array.map(navLink)->View.fragment}
      </nav>
      <div class="header-actions">
        {/* Both icons are rendered and CSS shows the one for the current theme.
            The server does not know the reader's theme, so branching here would
            make the markup disagree with the client on hydration. */
        View.element(
          "button",
          ~attrs=[
            View.attr("type", "button"),
            View.attr("class", "icon-button theme-toggle"),
            View.attr("aria-label", "Toggle theme"),
          ],
          ~events=[("click", _ => Theme.toggle())],
          ~children=[
            <span class="when-light"> <Icon name={Moon} /> </span>,
            <span class="when-dark"> <Icon name={Sun} /> </span>,
          ],
          (),
        )}
        {View.element(
          "a",
          ~attrs=[
            View.attr("href", Generated__Data.repositoryUrl),
            View.attr("class", "icon-button"),
            View.attr("target", "_blank"),
            View.attr("rel", "noreferrer"),
            View.attr("aria-label", "rescript-signals on GitHub"),
          ],
          ~children=[<Icon name={GitHub} />],
          (),
        )}
      </div>
    </div>
  </header>
