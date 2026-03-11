open Xote
open Basefn

let baseUrl = "https://github.com/brnrdog/rescript-signals/edit/main/docs-website/src/pages/"

@jsx.component
let make = (~pageName: string) => {
  let url = baseUrl ++ pageName ++ ".res"

  <div class="edit-on-github">
    <a href={url} target="_blank" style="display: inline-flex; align-items: center; gap: 0.5rem;">
      <Icon name={GitHub} size={Sm} />
      {"Edit this page on GitHub"->Component.text}
    </a>
  </div>
}
