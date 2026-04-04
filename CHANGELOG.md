# Changelog

All notable changes to this project will be documented in this file. See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2.0.0 (2026-04-04)

* feat!: make Effect.run fire-and-forget ([831f353](https://github.com/brnrdog/rescript-signals/commit/831f353))


### BREAKING CHANGE

* Effect.run now returns unit instead of
disposer. If you need to manually dispose an effect, use
Effect.runWithDisposer instead.

Migration guide:

Before:
```rescript
let disposer = Effect.run(() => {
  Console.log(Signal.get(count))
  None
})
disposer.dispose()
```

After:
```rescript
let disposer = Effect.runWithDisposer(() => {
  Console.log(Signal.get(count))
  None
})
disposer.dispose()
```

If you don't need the disposer, no changes are required:
```rescript
Effect.run(() => {
  Console.log(Signal.get(count))
  None
})
```

## <small>1.3.4 (2026-03-29)</small>

* fix: strip dev sources from rescript.json during npm pack (#20) ([be26da0](https://github.com/brnrdog/rescript-signals/commit/be26da0)), closes [#20](https://github.com/brnrdog/rescript-signals/issues/20)
* docs: add active page highlighting in sidebar ([8240b6d](https://github.com/brnrdog/rescript-signals/commit/8240b6d))
* docs: add breadcrumbs navigation ([ef06eef](https://github.com/brnrdog/rescript-signals/commit/ef06eef))
* docs: add copy-to-clipboard button to code blocks ([ff33fc4](https://github.com/brnrdog/rescript-signals/commit/ff33fc4))
* docs: add docs-website for GitHub Pages ([158a932](https://github.com/brnrdog/rescript-signals/commit/158a932))
* docs: add Edit on GitHub links to all pages ([cfa5933](https://github.com/brnrdog/rescript-signals/commit/cfa5933))
* docs: add Previous/Next page navigation ([62a0784](https://github.com/brnrdog/rescript-signals/commit/62a0784))
* docs: add scroll to top button ([63e3ed5](https://github.com/brnrdog/rescript-signals/commit/63e3ed5))
* docs: add search functionality to docs website ([20fa316](https://github.com/brnrdog/rescript-signals/commit/20fa316))
* docs: enable SSR prerendering for docs website (#15) ([975185c](https://github.com/brnrdog/rescript-signals/commit/975185c)), closes [#15](https://github.com/brnrdog/rescript-signals/issues/15)
* docs: fix duplicate headers on docs pages (#19) ([0d8b2d6](https://github.com/brnrdog/rescript-signals/commit/0d8b2d6)), closes [#19](https://github.com/brnrdog/rescript-signals/issues/19)
* docs: fix routing for GitHub Pages by setting router basePath ([7b7f4ae](https://github.com/brnrdog/rescript-signals/commit/7b7f4ae))
* docs: fix SSR and add GitHub Pages SPA routing support (#17) ([e2f039c](https://github.com/brnrdog/rescript-signals/commit/e2f039c)), closes [#17](https://github.com/brnrdog/rescript-signals/issues/17)
* docs: fix SSR compatibility by guarding browser APIs (#16) ([962c09f](https://github.com/brnrdog/rescript-signals/commit/962c09f)), closes [#16](https://github.com/brnrdog/rescript-signals/issues/16)
* docs: fix vite config ([bcd6b9a](https://github.com/brnrdog/rescript-signals/commit/bcd6b9a))
* docs: footer adjustments ([2b8a42f](https://github.com/brnrdog/rescript-signals/commit/2b8a42f))
* docs: improve docs-website with conditional sidebar and release notes ([44fba46](https://github.com/brnrdog/rescript-signals/commit/44fba46))
* docs: redesign homepage and improve documentation styling (#13) ([90161c3](https://github.com/brnrdog/rescript-signals/commit/90161c3)), closes [#13](https://github.com/brnrdog/rescript-signals/issues/13) [#0d1117](https://github.com/brnrdog/rescript-signals/issues/0d1117)
* docs: redesign website with xote-style layout and purple theme (#14) ([cb20cfc](https://github.com/brnrdog/rescript-signals/commit/cb20cfc)), closes [#14](https://github.com/brnrdog/rescript-signals/issues/14)
* docs: switch from mountById to hydrateById for SSR ([7712e01](https://github.com/brnrdog/rescript-signals/commit/7712e01)), closes [#app](https://github.com/brnrdog/rescript-signals/issues/app)
* docs: update README.md ([73063e7](https://github.com/brnrdog/rescript-signals/commit/73063e7))
* docs: update README.md ([4356082](https://github.com/brnrdog/rescript-signals/commit/4356082))
* docs: update xote and basefn ([013caa0](https://github.com/brnrdog/rescript-signals/commit/013caa0))
* chore: add homepage link ([b15fc5c](https://github.com/brnrdog/rescript-signals/commit/b15fc5c))
* chore: save benchmarks results in json files ([88221c7](https://github.com/brnrdog/rescript-signals/commit/88221c7))
* chore: update zekr ([e187e69](https://github.com/brnrdog/rescript-signals/commit/e187e69))
* ci: add GitHub Pages deployment workflow ([6d5aec8](https://github.com/brnrdog/rescript-signals/commit/6d5aec8))
* test: replace TestFramework with Zekr ([34d339c](https://github.com/brnrdog/rescript-signals/commit/34d339c))

## <small>1.3.3 (2026-01-21)</small>

* perf: unify computed observer and subs into single structure ([f5d0ad1](https://github.com/brnrdog/rescript-signals/commit/f5d0ad1))

## <small>1.3.2 (2026-01-21)</small>

* chore: add benchmark script ([cfc2a7c](https://github.com/brnrdog/rescript-signals/commit/cfc2a7c))
* perf: a few performance updates ([41b2f27](https://github.com/brnrdog/rescript-signals/commit/41b2f27))
* perf: eliminate Map lookups and level recompute ([2bb0a5a](https://github.com/brnrdog/rescript-signals/commit/2bb0a5a))
* perf: eliminate map lookups on signal read ([b3ad10f](https://github.com/brnrdog/rescript-signals/commit/b3ad10f))
* perf: optimize computed creation path ([3d84e36](https://github.com/brnrdog/rescript-signals/commit/3d84e36))
* perf: replace observer tracking with linked lists ([bc80675](https://github.com/brnrdog/rescript-signals/commit/bc80675))
* perf: skip sorting when observers at same level ([1a406d3](https://github.com/brnrdog/rescript-signals/commit/1a406d3))
* fix: remove @rescript/core as dep ([008e5fe](https://github.com/brnrdog/rescript-signals/commit/008e5fe))

## <small>1.3.1 (2026-01-16)</small>

* fix: avoid stack overflow on deep computed chains ([9132ee0](https://github.com/brnrdog/rescript-signals/commit/9132ee0))
* docs: update readme ([1a06e3e](https://github.com/brnrdog/rescript-signals/commit/1a06e3e))
* chore: fix typo in package keywords ([a780672](https://github.com/brnrdog/rescript-signals/commit/a780672))
* chore: update package keywords ([364306d](https://github.com/brnrdog/rescript-signals/commit/364306d))

## 1.3.0 (2025-12-13)

* feat: add optional name argument for debugging ([9699a83](https://github.com/brnrdog/rescript-signals/commit/9699a83))
* test: supress shadowing warning in test files ([ec74f3d](https://github.com/brnrdog/rescript-signals/commit/ec74f3d))

## 1.2.0 (2025-12-05)

* feat: introduce Signal.batch and Signal.untrack ([a8716ae](https://github.com/brnrdog/rescript-signals/commit/a8716ae))

## 1.1.0 (2025-12-04)

* refactor(scheduler): extract utility modules ([080367f](https://github.com/brnrdog/rescript-signals/commit/080367f))
* test: test framework improvements ([9bc7fe3](https://github.com/brnrdog/rescript-signals/commit/9bc7fe3))
* fix: prevent infinite loops on recompute ([4835c6c](https://github.com/brnrdog/rescript-signals/commit/4835c6c))
* feat: lazy computed evaluation ([a894edc](https://github.com/brnrdog/rescript-signals/commit/a894edc))
* docs: update CONTRIBUTING ([d4a80b0](https://github.com/brnrdog/rescript-signals/commit/d4a80b0))

## <small>1.0.2 (2025-12-02)</small>

* fix(scheduler): effect level inflation ([ece7af5](https://github.com/brnrdog/rescript-signals/commit/ece7af5))
* fix(scheduler): fix computed auto-disposal ([a9b9711](https://github.com/brnrdog/rescript-signals/commit/a9b9711))
* fix(scheduler): flush ([d9c8744](https://github.com/brnrdog/rescript-signals/commit/d9c8744))
* fix(scheduler): prevents crashing on exceptions ([6ce0476](https://github.com/brnrdog/rescript-signals/commit/6ce0476))
* fix(signal): strict equal for equality by default ([6e30e39](https://github.com/brnrdog/rescript-signals/commit/6e30e39))
* perf(scheduler): prevent extra recomputes ([591c134](https://github.com/brnrdog/rescript-signals/commit/591c134))
* chore: revisit commits that trigger releases ([55e8148](https://github.com/brnrdog/rescript-signals/commit/55e8148))
* docs: update README ([6d373ed](https://github.com/brnrdog/rescript-signals/commit/6d373ed))

## <small>1.0.1 (2025-12-02)</small>

* docs: update README ([c9b2461](https://github.com/brnrdog/rescript-signals/commit/c9b2461))

## 1.0.0 (2025-12-02)

* chore: add .npmrc ([00a730a](https://github.com/brnrdog/rescript-signals/commit/00a730a))
* chore: add github workflows for ci and release ([cc8d1b1](https://github.com/brnrdog/rescript-signals/commit/cc8d1b1))
* chore: attempt to fix npm publish ([7a42294](https://github.com/brnrdog/rescript-signals/commit/7a42294))
* chore: exit process on test failure ([334e2e7](https://github.com/brnrdog/rescript-signals/commit/334e2e7))
* chore: remove commit lint from ci ([6c06ba9](https://github.com/brnrdog/rescript-signals/commit/6c06ba9))
* chore: remove npm token reference ([a4954a8](https://github.com/brnrdog/rescript-signals/commit/a4954a8))
* chore: setup semantic release ([1adea29](https://github.com/brnrdog/rescript-signals/commit/1adea29))
* chore: update license ([cab35af](https://github.com/brnrdog/rescript-signals/commit/cab35af))
* chore: update package configurations ([48bf9de](https://github.com/brnrdog/rescript-signals/commit/48bf9de))
* docs: add CONTRIBUTING ([3c1529c](https://github.com/brnrdog/rescript-signals/commit/3c1529c))
* docs: add README ([5bd2e17](https://github.com/brnrdog/rescript-signals/commit/5bd2e17))
* docs: update README ([49f7399](https://github.com/brnrdog/rescript-signals/commit/49f7399))
* test: add script to run tests ([ab54a02](https://github.com/brnrdog/rescript-signals/commit/ab54a02))
* test: add tests to Computed module ([0b6b27b](https://github.com/brnrdog/rescript-signals/commit/0b6b27b))
* test: add tests to Effect module ([6be24df](https://github.com/brnrdog/rescript-signals/commit/6be24df))
* test: add tests to Signal module ([9846ac5](https://github.com/brnrdog/rescript-signals/commit/9846ac5))
* test: add tests to Signal module ([2027a86](https://github.com/brnrdog/rescript-signals/commit/2027a86))
* test: setup simple test framework ([01e0e97](https://github.com/brnrdog/rescript-signals/commit/01e0e97))
* feat: add core signal modules ([b8dbfc6](https://github.com/brnrdog/rescript-signals/commit/b8dbfc6))
* Initial commit ([318ac52](https://github.com/brnrdog/rescript-signals/commit/318ac52))
