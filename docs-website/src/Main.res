open Xote

%%raw(`import './styles.css'`)

// Import modules to ensure they are included in the bundle
module Website = Website

Router.init(~basePath="/rescript-signals", ())
Component.mountById(<Website.App />, "app")
