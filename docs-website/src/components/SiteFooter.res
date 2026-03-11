open Xote

@jsx.component
let make = () => {
  <footer class="site-footer">
    <div class="footer-inner">
      <div class="footer-brand">
        <div class="footer-brand-name"> {"ReScript Signals"->Component.text} </div>
        <div class="footer-brand-desc">
          {"A lightweight, high-performance reactive signals library for ReScript with zero runtime dependencies."
          ->Component.text}
        </div>
      </div>
      <div class="footer-col">
        <div class="footer-col-title"> {"Docs"->Component.text} </div>
        <Router.Link to="/getting-started"> {"Getting Started"->Component.text} </Router.Link>
        <Router.Link to="/api/signal"> {"API Reference"->Component.text} </Router.Link>
        <Router.Link to="/examples"> {"Examples"->Component.text} </Router.Link>
      </div>
      <div class="footer-col">
        <div class="footer-col-title"> {"Community"->Component.text} </div>
        <a href="https://github.com/brnrdog/rescript-signals" target="_blank">
          {"GitHub"->Component.text}
        </a>
        <a href="https://github.com/brnrdog/rescript-signals/issues" target="_blank">
          {"Issues"->Component.text}
        </a>
        <a href="https://github.com/brnrdog/rescript-signals/discussions" target="_blank">
          {"Discussions"->Component.text}
        </a>
      </div>
      <div class="footer-col">
        <div class="footer-col-title"> {"More"->Component.text} </div>
        <Router.Link to="/release-notes"> {"Release Notes"->Component.text} </Router.Link>
        <a href="https://www.npmjs.com/package/rescript-signals" target="_blank">
          {"npm"->Component.text}
        </a>
        <a href="https://github.com/brnrdog/rescript-signals/blob/main/LICENSE" target="_blank">
          {"License"->Component.text}
        </a>
      </div>
    </div>
    <div class="footer-bottom">
      <span> {"Copyright 2024 ReScript Signals contributors."->Component.text} </span>
    </div>
  </footer>
}
