open Xote

%%raw(`import './styles.css'`)

// Import modules to ensure they are included in the bundle
module Website = Website

Router.init(~basePath="/rescript-signals", ())
Hydration.hydrateById(() => <Website.App />, "app")
