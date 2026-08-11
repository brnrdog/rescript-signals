# Upgrading the docs site to xote 7.1.0-beta.7

This documents the upgrade of `docs-website` from **xote 4.16.1** to **xote 7.1.0-beta.7**
(the `beta` dist-tag). The goal was the bare minimum needed to build and run — no
adoption of new xote features beyond what was required to compile.

## Summary of dependency changes

| Package           | Before      | After            | Why                                                                 |
| ----------------- | ----------- | ---------------- | ------------------------------------------------------------------- |
| `xote`            | `^4.16.1`   | `7.1.0-beta.7`   | The upgrade itself. Pinned exactly — it is a prerelease.              |
| `rescript-signals`| `^1.3.3`    | `^3.1.2`         | Forced: xote 7 depends on `rescript-signals ^3.1.0`.                  |
| `basefn`          | `^1.9.1`    | *(removed)*      | No release is compatible with xote 7. Replaced by a local UI kit.     |
| `highlight.js`    | *(implicit)*| `^11.11.2`       | `CodeBlock.res` imports it directly; it used to arrive via `basefn`.  |

## 1. xote 4 → 7: module reorganisation

xote 7 dropped the hand-written `Xote.res` umbrella module in favour of
`"namespace": true` in its `rescript.json`, with each public module exposed by its own
name. Modules are reachable as `Xote.<Module>`, and `open Xote` still brings them into
scope unqualified — so the existing `open Xote` lines were left untouched.

The modules themselves were renamed:

| xote 4                    | xote 7            |
| ------------------------- | ----------------- |
| `Xote.Component`          | `Xote.View`       |
| `Xote.ReactiveProp`       | `Xote.MaybeSignal`|
| `Xote__JSX` (JSX module)  | `Xote.XoteJSX`    |

`Router`, `SSR`, `Hydration`, `Signal`, `Computed` and `Effect` kept their names, and
the parts of their APIs this site uses (`Router.init` / `initSSR` / `routes` / `link` /
`push`, `SSR.renderToString`, `Hydration.hydrateById`) are unchanged.

### `rescript.json`

```diff
   "jsx": {
     "version": 4,
-    "module": "Xote__JSX"
+    "module": "Xote.XoteJSX"
   }
```

The JSX module must be spelled with the namespace prefix now that xote is namespaced.

### Call-site renames

Applied mechanically across `src/`:

- `Component.*` → `View.*`
- `Xote.ReactiveProp` → `Xote.MaybeSignal` (including `open Xote.ReactiveProp`;
  `static` / `reactive` keep their names, so the call sites did not change)

Two functions were renamed inside the module, and two element shorthands were removed:

| xote 4                 | xote 7                             |
| ---------------------- | ---------------------------------- |
| `Component.textSignal` | `View.signalText`                  |
| `Component.list`       | `View.each`                        |
| `Component.input(...)` | `View.element("input", ...)`       |

xote 7's `View` no longer ships per-tag helpers (`div`, `span`, `input`, …); the generic
`View.element` covers them. Only `Component.input` was in use here, at two call sites
(`HomePage.res`, `Layout.res`).

Note: `Xote.Prop` exists in xote 7 as a deprecated alias of `MaybeSignal` with the same
constructors. Using it would have been a smaller edit, but it emits deprecation warnings,
and the rename cost is identical — so `MaybeSignal` was used directly.

## 2. `rescript-signals` had to move too

xote 7 declares `rescript-signals ^3.1.0`. The site was still on `^1.3.3`, and ReScript
resolves one version of a package per build graph, so xote's own sources failed to
compile against it:

```
The value runWithDisposer can't be found in Effect
```

Bumping the site to `rescript-signals@^3.1.2` fixed it. None of the site's own uses of
`Signal` / `Computed` / `Effect` needed changes across that major bump.

## 3. Removing `basefn`

`basefn` is the UI kit the site used for `Typography`, `Button`, `Card`, `Grid`, `Input`,
`Select`, `Tabs`, `Label`, `Alert`, `Spinner`, `Separator` and `Icon`.

No published version works with xote 7:

- `basefn@1.9.1` (what the site pinned) targets xote 4 — its `rescript.json` still points
  JSX at `Xote__JSX`.
- `basefn@1.11.0` (latest) peer-depends on `xote@^6.0.0` and references `Xote.Node`,
  which xote 7 renamed to `View`. Compiling it against xote 7 produced 42 errors across
  its component sources.

Since ReScript compiles dependency sources, this blocked the build outright and could not
be worked around from the consumer side. `basefn` was therefore dropped and the pieces the
site actually used were reimplemented locally in **`src/ui/`**:

```
src/ui/Ui.res              — barrel module (replaces `open Basefn` → `open Ui`)
src/ui/ui.css              — styles, ported from the basefn CSS for these components
src/ui/Ui__Alert.res       — variant + message only
src/ui/Ui__Button.res      — Primary | Secondary | Ghost
src/ui/Ui__Card.res        — Default | Outlined, optional header
src/ui/Ui__Grid.res        — `Count(n)` columns + gap
src/ui/Ui__Icon.res        — the 13 icons the site references
src/ui/Ui__Input.res       — Text | Number
src/ui/Ui__Label.res
src/ui/Ui__Select.res      — signal-bound value + options
src/ui/Ui__Separator.res
src/ui/Ui__Spinner.res
src/ui/Ui__Tabs.res
src/ui/Ui__Typography.res  — H1–H4, P, Lead, Small, Muted, Code
```

These are deliberately minimal: only the props and variants the pages pass are
implemented, so the JSX at every call site is unchanged apart from the module name.

Source-level changes this required:

- `open Basefn` → `open Ui` (8 files)
- `Basefn.Icon.*` → `Ui.Icon.*`, `Basefn__Select.*` → `Ui__Select.*`
- `basefn` removed from `rescript.json` `dependencies` and from `vite.config.js`
  `ssr.noExternal`

### Icons

`basefn`'s `Icon` pulled paths from the `lucide` package and injected them as an HTML
string through `setTimeout`, so icons did not server-render. The local `Ui__Icon` inlines
the same Lucide path data (ISC licensed) as real SVG JSX. This drops the `lucide`
dependency and the icons now appear in the pre-rendered HTML.

### Theme

`Basefn.Theme.applyTheme` was called from `Layout.res` alongside the site's own
`setHtmlAttribute("data-theme", …)`. It set the identical attribute on
`document.documentElement`, plus a `no-transitions` class that has no CSS rule anywhere in
this project. The call was redundant, so it was removed rather than reimplemented.

### CSS

The site's `styles.css` already defines its own `--basefn-*` theme tokens (it overrode
basefn's palette), and never styled any `.basefn-*` class — so removing basefn only left
three tokens undefined, now declared in `styles.css`:

```css
--basefn-color-border: var(--border-default);
--basefn-color-muted: var(--text-muted);
--basefn-radius-lg: 0.5rem;
```

The `--basefn-*` token *names* were kept as-is. They are referenced from inline styles
throughout the pages, and renaming them is a large, purely cosmetic diff — see
"Follow-ups" below.

The new components use `ui-*` class names and `src/ui/ui.css` carries the styles, ported
from the corresponding basefn CSS and trimmed to the variants in use.

## 4. `highlight.js` is now a direct dependency

`src/components/CodeBlock.res` imports `highlight.js` and two of its stylesheets, but the
site never declared it — it resolved through `basefn`'s dependency tree. With basefn gone,
the client bundle failed:

```
[vite]: Rollup failed to resolve import "highlight.js/styles/github.min.css"
```

Adding `highlight.js@^11.11.2` to `dependencies` fixed it.

## Verification

```bash
cd docs-website
rm -rf node_modules package-lock.json && npm install   # clean install, 0 vulnerabilities
npm run build                                          # rescript + client + SSR + prerender
```

All 7 routes pre-render. The built site was then driven in Chromium to confirm hydration
and reactivity survived the upgrade:

- home page renders 22 server-rendered icons
- counter hydrates and increments
- theme toggle flips `data-theme` and swaps its icon reactively
- client-side router navigates between pages
- tabs switch on click
- todo input + button appends items
- computed cart totals recalculate on input, and on select change

## Known issues and follow-ups

- **Pre-existing, not caused by this upgrade:** `CodeBlock` defaults to
  `language="rescript"`, but highlight.js has no `rescript` grammar (only `reasonml`), so
  every code block logs `Unknown language: "rescript"` and renders unhighlighted. This was
  already true before the upgrade and was left alone.
- `xote` is pinned to the exact beta. Revisit when 7.1.0 is released.
- The `--basefn-*` CSS custom property names outlived the dependency. Renaming them to a
  neutral prefix is a mechanical follow-up across `styles.css` and the inline styles.
- The xote 7 README describes a `@xote.component` PPX that allows inline signal reads in
  JSX without thunks or value primitives. This upgrade deliberately did not adopt it; the
  site still uses `@jsx.component` with explicit `View.signalText` / `View.signalFragment`.
