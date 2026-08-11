open Xote

// Render function called by the prerender script.
let render = (_url: string) => SSR.renderToString(() => <Page />)
