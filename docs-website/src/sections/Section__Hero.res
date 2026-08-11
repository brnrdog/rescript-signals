open Xote

let installCommand = "npm install rescript-signals"

@jsx.component
let make = () =>
  <section id="top" class="hero">
    <h1 class="hero-title"> {View.text("Reactive signals for ReScript")} </h1>
    <p class="hero-lead">
      {View.text(
        "Signals hold state, computeds derive from them, and effects run when what they read changes. Dependencies are tracked as your code reads them, so a write re-runs only what actually depends on it. No runtime dependencies, and the types come from ReScript.",
      )}
    </p>
    <div class="install">
      <code class="install-command"> {View.text(installCommand)} </code>
      <CopyButton text={installCommand} label="Copy install command" />
    </div>
    <p class="hero-links">
      <a href="#getting-started"> {View.text("Getting started")} </a>
      <a href={Generated__Data.repositoryUrl}> {View.text("Source")} </a>
      <a href="https://www.npmjs.com/package/rescript-signals"> {View.text("npm")} </a>
    </p>
  </section>
