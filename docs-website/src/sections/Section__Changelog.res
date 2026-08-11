open Xote

/* Built in at compile time by scripts/gen-data.mjs, so it is present in the
   prerendered HTML and cannot fail to load. */

let renderBlock = (block: Generated__Data.block) =>
  switch block {
  | Paragraph(text) => <p class="release-note"> {View.text(text)} </p>
  | Code(code) => <CodeBlock code copyable={false} />
  }

let renderChange = (change: Generated__Data.change) =>
  <li class="change">
    <span class={change.breaking ? "change-kind is-breaking" : "change-kind"}>
      {View.text(change.kind)}
    </span>
    <span class="change-summary"> {View.text(change.summary)} </span>
  </li>

let renderRelease = (release: Generated__Data.release) =>
  <article class="release">
    <div class="release-head">
      <h3 class="release-version">
        <a href={release.url}> {View.text(release.version)} </a>
      </h3>
      {View.element(
        "time",
        ~attrs=[View.attr("class", "release-date"), View.attr("datetime", release.date)],
        ~children=[View.text(release.date)],
        (),
      )}
      {release.breaking
        ? <span class="release-flag"> {View.text("breaking")} </span>
        : View.fragment([])}
    </div>
    <div class="release-body">
      <ul class="changes"> {release.changes->Array.map(renderChange)->View.fragment} </ul>
      {release.notes->Array.map(renderBlock)->View.fragment}
    </div>
  </article>

@jsx.component
let make = () =>
  <section id="changelog" class="section">
    <p class="section-label"> {View.text("History")} </p>
    <h2 class="section-title"> {View.text("Changelog")} </h2>
    <p class="section-lead">
      {View.text("The five most recent releases. This page documents ")}
      <code> {View.text(Generated__Data.version)} </code>
      {View.text(", the version it was built against.")}
    </p>
    <div class="releases"> {Generated__Data.releases->Array.map(renderRelease)->View.fragment} </div>
    <p class="section-more">
      <a href={Generated__Data.repositoryUrl ++ "/releases"}>
        {View.text("Full release history on GitHub")}
      </a>
    </p>
  </section>
