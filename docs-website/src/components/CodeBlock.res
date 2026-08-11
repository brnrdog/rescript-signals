open Xote

/* A code block. Highlighting happens through Highlight, which is pure, so the
   markup is produced during SSR and hydrates unchanged — no innerHTML, no
   post-render patching. */

@jsx.component
let make = (~code: string, ~language: string="rescript", ~copyable: bool=true) =>
  <div class="code">
    <pre class="code-pre">
      <code class={"code-body lang-" ++ language}> {Highlight.render(code, ~language)} </code>
    </pre>
    {copyable ? <CopyButton text={code} /> : View.fragment([])}
  </div>
