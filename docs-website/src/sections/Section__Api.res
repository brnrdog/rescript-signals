open Xote

/* Rendered from Api.groups, so the members listed at the top of each module and
   the entries below it are two views of one list. */

let anchor = (id: string) =>
  <a class="anchor" href={"#" ++ id} ariaLabel="Link to this section">
    {View.text("#")}
  </a>

/* With no table of contents, each module carries its own index. */
let member = (entry: Api.entry) =>
  <a class="member" href={"#" ++ entry.id}> {View.text(entry.label)} </a>

let renderEntry = (entry: Api.entry) =>
  <article class="entry">
    <h4 id={entry.id} class="entry-signature">
      <code> {View.text(entry.signature)} </code>
      {anchor(entry.id)}
    </h4>
    <p class="entry-summary"> {View.text(entry.summary)} </p>
    <CodeBlock code={entry.code} />
    {entry.notes
    ->Array.map(note => <p class="entry-note"> {View.text(note)} </p>)
    ->View.fragment}
  </article>

let renderClosing = ((term, description): (string, string)) =>
  <div class="trait">
    <dt class="trait-term"> {View.text(term)} </dt>
    <dd class="trait-description"> {View.text(description)} </dd>
  </div>

let renderGroup = (group: Api.group) =>
  <section class="module">
    <div class="module-head">
      <h3 id={group.id} class="module-name">
        {View.text(group.name)}
        {anchor(group.id)}
      </h3>
      <p class="module-lead"> {View.text(group.lead)} </p>
      <div class="members"> {group.entries->Array.map(member)->View.fragment} </div>
    </div>
    <div class="module-body"> {group.entries->Array.map(renderEntry)->View.fragment} </div>
    {Array.length(group.closing) == 0
      ? View.fragment([])
      : <dl class="traits"> {group.closing->Array.map(renderClosing)->View.fragment} </dl>}
  </section>

@jsx.component
let make = () =>
  <section id="api" class="section">
    <p class="section-label"> {View.text("Reference")} </p>
    <h2 class="section-title"> {View.text("API")} </h2>
    <p class="section-lead">
      {View.text(
        "Three modules, and that is the whole surface. Every signature below was read off the installed source.",
      )}
    </p>
    {Api.groups->Array.map(renderGroup)->View.fragment}
  </section>
