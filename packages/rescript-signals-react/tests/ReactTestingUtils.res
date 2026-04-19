%%raw(`
import { JSDOM } from 'jsdom';
const dom = new JSDOM('<!doctype html><html><body></body></html>');
globalThis.window = dom.window;
globalThis.document = dom.window.document;
globalThis.HTMLElement = dom.window.HTMLElement;
Object.defineProperty(globalThis, 'navigator', {
  value: dom.window.navigator,
  writable: true,
  configurable: true,
});
globalThis.IS_REACT_ACT_ENVIRONMENT = true;
`)

type rendered = {
  container: Dom.element,
  root: ReactDOM.Client.Root.t,
}

@module("react") external act: (unit => unit) => unit = "act"

@val external document: Dom.document = "document"
@send external createElement: (Dom.document, string) => Dom.element = "createElement"
@send external appendChild: (Dom.element, Dom.element) => Dom.element = "appendChild"
@send external removeChild: (Dom.element, Dom.element) => Dom.element = "removeChild"
@get external body: Dom.document => Dom.element = "body"
@get external textContent: Dom.element => string = "textContent"
@get external innerHTML: Dom.element => string = "innerHTML"

let renderComponent = (element: React.element): rendered => {
  let container = document->createElement("div")
  let _ = document->body->appendChild(container)
  let root = ref(None)
  act(() => {
    let r = ReactDOM.Client.createRoot(container)
    root := Some(r)
    r->ReactDOM.Client.Root.render(element)
  })
  {
    container,
    root: Option.getExn(root.contents),
  }
}

let cleanup = (rendered: rendered) => {
  act(() => {
    rendered.root->ReactDOM.Client.Root.unmount()
  })
  let _ = document->body->removeChild(rendered.container)
}
