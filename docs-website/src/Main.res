open Xote

%%raw(`import './styles.css'`)

Basefn.Theme.init()
Router.init(~basePath="/rescript-signals", ())
Component.mountById(<App />, "app")
