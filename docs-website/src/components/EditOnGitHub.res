open Xote.ReactiveProp
open Basefn

let baseUrl = "https://github.com/brnrdog/rescript-signals/edit/main/docs-website/src/pages/"

@jsx.component
let make = (~pageName: string) => {
  let url = baseUrl ++ pageName ++ ".res"

  <div style="margin-top: 3rem; padding-top: 1.5rem; border-top: 1px solid var(--basefn-color-border);">
    <a
      href={url}
      target="_blank"
      style="display: inline-flex; align-items: center; gap: 0.5rem; color: var(--basefn-color-muted); text-decoration: none; font-size: 0.875rem;">
      <Icon name={GitHub} size={Sm} />
      <Typography text={static("Edit this page on GitHub")} variant={Small} />
    </a>
  </div>
}
