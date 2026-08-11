open Xote

@jsx.component
let make = () =>
  <footer class="site-footer">
    <div class="footer-inner">
      <span>
        {View.text("MIT licensed. Built by ")}
        <a href="https://github.com/brnrdog"> {View.text("Bernardo Gurgel")} </a>
        {View.text(".")}
      </span>
      <span>
        {View.text("This page is a ")}
        <a href="https://brnrdog.github.io/xote/"> {View.text("xote")} </a>
        {View.text(" app, so its own reactivity runs on rescript-signals.")}
      </span>
    </div>
  </footer>
