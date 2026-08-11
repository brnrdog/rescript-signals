# Docs website redesign — single page

**Date:** 2026-08-11
**Scope:** `docs-website/`
**Status:** approved design, ready for implementation planning

## Goal

Replace the current seven-route documentation site with a single page: hero, getting
started, API, changelog. Clean, neutral, direct. No marketing language, no claim on the
page that isn't verifiable from the source.

## Why now

Three problems beyond the visual one, all found while reading the current site:

1. **The changelog is broken.** `Pages__ReleaseNotes` fetches
   `https://raw.githubusercontent.com/brnrdog/rescript-signals/main/CHANGELOG.md`. There
   is no `CHANGELOG.md` at the repo root — it lives in `packages/rescript-signals/`. The
   request returns 404 with a plain-text body, `.then(text)` resolves successfully, the
   `.catch` never fires, and the page renders GitHub's `404: Not Found` string through
   `innerHTML` as if it were the changelog.
2. **Syntax highlighting is broken.** `CodeBlock` calls
   `hljs.highlight(code, {language: "rescript"})`. highlight.js has no `rescript`
   language, so it throws — inside a `setTimeout`, so the throw is invisible and every
   ReScript block silently stays plain text. The dependency ships for nothing.
3. **The API reference documents functions that do not exist** (see "Corrections" below).

## Decisions

| Question | Decision |
| --- | --- |
| Live demo | One demo, showing Signal + Computed + Effect together. No fake browser chrome, no tabs. |
| Old URLs (`/getting-started`, `/api/*`, `/examples`, `/release-notes`) | Dropped. Only `/` is built. Old paths hit the GitHub Pages 404. |
| Palette | Neutral grayscale, single accent (ReScript red). Light default, dark via system preference, toggle persists an override. |
| Search (⌘K modal) | Removed. On a single page, ⌘F is the search. |
| React adapter | Four lines at the end of Getting Started, linking to `rescript-signals-react`. |
| Version number in hero | Omitted. See "Version" below. |

## Page structure

One document, seven bands:

```
sticky header    rescript-signals    Start  API  Changelog      ☾  GitHub
─────────────────────────────────────────────────────────────────────────
hero             Reactive signals for ReScript.
                 one paragraph · npm install rescript-signals [copy]
─────────────────────────────────────────────────────────────────────────
demo             source │ running
─────────────────────────────────────────────────────────────────────────
getting started  install · rescript.json · first example · React adapter
─────────────────────────────────────────────────────────────────────────
API              Signal · Computed · Effect
─────────────────────────────────────────────────────────────────────────
changelog        last 5 releases, built in · link to full history
─────────────────────────────────────────────────────────────────────────
footer           MIT · Bernardo Gurgel · built with xote
```

Content column is max ~72ch, centred. On viewports ≥1100px a hairline table of contents
sits in the right margin listing every section and every API entry, with the current
entry marked; below 1100px it is not rendered at all. The header is sticky, one row tall,
with a hairline bottom rule that appears only once the page is scrolled.

**Removed from the current site:** the six-card feature grid, the "Get started today"
band, the four-column footer, the ⌘K search modal, the Examples page, the fake browser
chrome around the demo, and the tabbed multi-demo switcher.

### Anchors

`#getting-started`, `#signal`, `#computed`, `#effect`, `#changelog`, plus one per API
entry (`#signal-make`, `#signal-get`, …). Anchor ids are the single source for the TOC —
the TOC is derived from the API data, never hand-maintained in parallel.

## The demo

```
let count   = Signal.make(0)              │      3
let doubled = Computed.make(              │   [−]   [+]
  () => Signal.get(count) * 2 )           │
                                          │   doubled  6
Effect.run(() => {                        │
  log(`count → ${Signal.get(count)}`)     │   count → 3
  None                                    │   count → 2
})                                        │   count → 1
```

Source on the left, running instance on the right; they stack on narrow viewports. The
effect appends a line to the log, which is the only way to make an effect visible on a
page. It appends exactly once per change, so the log is also the evidence for the
batching claim made in the API section.

The log signal is capped (keep the most recent 8 entries) so the section cannot grow
unbounded. Both the signal and the effect are created inside the component so the demo
holds no module-level mutable state.

The source shown beside it must be the real code the demo runs, not an approximation.

## Visual system

Two font families: **DM Sans** (text) and **Geist Mono** (code). Instrument Serif is
dropped.

Tokens, defined on `:root` for light and overridden under
`[data-theme="dark"]` plus `@media (prefers-color-scheme: dark)` when no explicit
override is set:

| Token | Light | Dark |
| --- | --- | --- |
| `--bg` | `#ffffff` | `#0e0e10` |
| `--surface` | `#f6f6f7` | `#17171a` |
| `--text` | `#16161a` | `#ececee` |
| `--muted` | `#6b6b73` | `#97979f` |
| `--rule` | `#e4e4e7` | `#27272b` |
| `--accent` | `#e6484f` | `#ff6b70` |

The accent appears only on links, focus rings, and the active TOC row. Nothing else on
the page is chromatic. Emphasis comes from weight, size, and hairline rules.

Theme is applied by a small inline script in `index.html` that runs before first paint,
reading `localStorage` then `prefers-color-scheme`. This fixes the flash of dark the
current site has, where the theme is only set once `Layout.res` evaluates after
hydration.

## Code blocks

highlight.js is removed entirely. In its place, a small ReScript tokenizer
(`src/Highlight.res`, ~100 lines) that returns `View.node` values.

- Three tones only: comments muted, strings slightly warm, everything else plain body
  text. No rainbow.
- Recognises comments (`//`), string and template literals, and enough structure to not
  mangle punctuation. It does not need to be a parser — it needs to never produce
  *wrong* output. When in doubt a token is plain text.
- Pure and deterministic, so it runs during SSR and hydrates to identical markup. Blocks
  are highlighted in the prerendered HTML rather than patched in after a `setTimeout`.
- No `innerHTML`, no `getElementById`, no id counter.

`CodeBlock` keeps its copy button, rewritten to render through the tokenizer and to drop
the `setTimeout`/`innerHTML` path. `SyntaxHighlight.res` (the second, naive highlighter
used only by the old home page) is deleted.

## Build-time data

A Node script, `scripts/gen-data.mjs`, reads
`node_modules/rescript-signals/` and emits one generated ReScript module,
`src/Generated__Data.res`, containing:

- `version: string` — from the installed package's `package.json`.
- `releases: array<release>` — parsed from the installed package's `CHANGELOG.md`.

Reading from `node_modules` rather than the repo is deliberate: the in-repo
`packages/rescript-signals/CHANGELOG.md` is stale (its newest entry is 2.1.0 while the
released version is 3.1.2), whereas the installed copy matches the version the docs
actually describe.

The parser must handle both heading formats present in that file:

```
## 2.1.0 (2026-04-07)
## [rescript-signals-v3.1.2](https://github.com/…/compare/…) (2026-08-10)
```

and must skip the stray `# Changelog` heading that sits partway down the file, since new
entries are prepended above the original header. Version and date are extracted; the
body is parsed into `### Bug Fixes` / `### Features` groups of bullet lines, with commit
hash links preserved as `(text, url)` pairs. Anything it cannot parse is skipped rather
than rendered raw — a changelog entry that fails to parse must not be able to inject
markup.

Wiring: `predev` and `prebuild` npm scripts run the generator.
`src/Generated__Data.res` is gitignored. The generator fails loudly (non-zero exit) if
the changelog or `package.json` is missing, rather than emitting an empty module.

The changelog section renders the **5 most recent releases** as typed data, followed by
a link to the full history on GitHub.

### Version

The hero shows no version number. The repo's own
`packages/rescript-signals/package.json` says `2.1.0` while the published version is
`3.1.2`, so any number derived from the repo would be wrong. `version` is still
generated (it is accurate, coming from the installed package) and is used in the
changelog section heading only.

Fixing the repo's stale changelog and package version is a separate concern and is **out
of scope** for this work.

## Corrections to documented API

The new API section is written against the installed source
(`node_modules/rescript-signals/src/signals/*.res`), not carried over from the existing
pages. Verified surface:

```
Signal.make(initialValue, ~name=?, ~equals=?) : Signal.t<'a>
Signal.get(signal)                            : 'a
Signal.peek(signal)                           : 'a
Signal.set(signal, value)                     : unit
Signal.update(signal, fn)                     : unit
Signal.batch(fn)
Signal.untrack(fn)                            : 'a

Computed.make(compute, ~name=?, ~equals=?)    : Signal.t<'a>
Computed.dispose(signal)                      : unit

Effect.run(fn, ~name=?)                       : unit
Effect.runWithDisposer(fn, ~name=?)           : disposer
type disposer = {dispose: unit => unit}
```

Errors in the current site that must not be carried forward:

1. **`Computed.get` and `Computed.peek` do not exist.** `Computed.make` returns a
   `Signal.t<'a>`, so a computed is read with `Signal.get` / `Signal.peek`. Both
   `Pages__ApiComputed` and `Pages__GettingStarted` document the non-existent functions.
2. **`~equals` is undocumented** on both `Signal.make` and `Computed.make`. The new page
   documents it.
3. **`open RescriptSignals`** appears in the current home-page demo snippets. The
   package's `rescript.json` sets `"namespace": "Signals"`, so consumers write
   `open Signals`. Every snippet on the new page uses `open Signals`.

Prose worth preserving from the current pages, because it is correct and hard-won:

- Computeds attach to their sources only while they have a subscriber and detach on
  their own once the last one goes away; dropping a computed you never subscribed to
  needs no cleanup. `Computed.dispose` is only for detaching one that is still
  subscribed, and it stays usable — the next read rebuilds its dependencies.
- Updates are glitch-free: computeds recalculate in topological order, so no intermediate
  inconsistent state is observable.
- Effects may return a cleanup function, which runs before each re-run and on dispose.

Every code snippet on the page must compile against the real API. Snippets are checked
by reading the source, not by memory of the old pages.

## Module structure

```
src/
  Main.res                  hydrate the page
  EntryServer.res           SSR render entry
  Page.res                  composes header, sections, footer
  Theme.res                 theme signal, toggle, persistence
  Highlight.res             ReScript tokenizer → View.node
  Generated__Data.res       generated, gitignored
  Api.res                   API entries as data (id, signature, summary, code)
  components/
    Header.res
    Footer.res
    CodeBlock.res           kept, rewritten
    Toc.res                 derived from Api entries
    Icon.res                trimmed: GitHub, Sun, Moon, Copy, Check only
  sections/
    Section__Hero.res
    Section__Demo.res
    Section__GettingStarted.res
    Section__Api.res
    Section__Changelog.res
  styles.css                rewritten from scratch
```

`Api.res` holds the API reference as an array of records rather than as markup, so the
section body and the TOC are two renderings of one list and cannot drift apart. Each
entry: `{id, signature, summary, code, notes}`.

**Deleted:** `Website.res`, `HomePage.res`, `DocsPage.res`, `Layout.res`,
`SyntaxHighlight.res`, `pages/` (all six), `ui/` (all of it, including `ui.css`),
`components/EditOnGitHub.res`.

The router goes away: `Main.res` mounts `<Page />` directly with no `Router.init`, and
`prerender.mjs` renders `/` only. `public/404.html` stays as-is.

`index.html` changes: drop Instrument Serif from the font request, add the
before-paint theme script, update the meta description, and set `theme-color` for both
colour schemes.

## Non-goals

- Benchmarks. The README has a benchmark table; it is not one of the four sections and
  does not go on the page.
- The Examples page content (todo list, form, etc.). The one demo plus the API snippets
  carry that weight.
- Fixing the root `README.md`'s `Effect.runWithDispose` typo, or the stale in-repo
  changelog and package version. Real problems, separate work.
- Self-hosting the two webfonts.

## Acceptance criteria

1. `npm run build` in `docs-website/` succeeds and produces `build/client/index.html`
   containing the full page content — hero, demo, getting started, all API entries, and
   the changelog — as server-rendered HTML, with no `<!--ssr-outlet-->` left and no
   client-only fallback warning from `prerender.mjs`.
2. The prerendered HTML contains highlighted code markup for ReScript blocks (not bare
   text nodes), and hydration produces no mismatch.
3. No network request is made for changelog content at runtime; the changelog is present
   in the prerendered HTML.
4. The demo increments, the computed tracks it, and the effect log gains exactly one
   line per change.
5. First paint is in the correct theme with no flash, both with and without a stored
   override.
6. Every code snippet on the page uses `open Signals` and only functions that exist in
   the installed source. No `Computed.get`, no `Computed.peek`, no
   `open RescriptSignals`.
7. highlight.js is gone from `package.json` and from the client bundle.
8. `styles.css` is under 10KB (current: 38KB) and `ui/` is gone.
9. Keyboard: every interactive element is reachable and shows a visible accent focus
   ring; the theme toggle and copy buttons have accessible labels.
10. No horizontal scroll at 320px width; code blocks scroll within their own container.
