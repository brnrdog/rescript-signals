import assert from "node:assert/strict"
import { transform } from "./tracked-preprocess.mjs"

let passed = 0
const check = (name, actual, expected) => {
  assert.equal(actual.trim(), expected.trim(), name)
  passed++
}

// Explicit form -> useSignals([dep(...), ...])
check(
  "explicit two args",
  transform(`@tracked(a, b)\n<div />`),
  `SignalsReactAuto.useSignals([SignalsReactAuto.dep(a), SignalsReactAuto.dep(b)])\n<div />`,
)

check(
  "explicit one arg",
  transform(`@tracked(count)\n<div />`),
  `SignalsReactAuto.useSignals([SignalsReactAuto.dep(count)])\n<div />`,
)

// Bare form -> useTracked(() => { ... })
check(
  "bare form wraps block body",
  transform(`let make = () => {\n  @tracked\n  <div />\n}`),
  `let make = () => {\n  SignalsReactAuto.useTracked(() => {\n  <div />\n})}`,
)

// Untouched when no annotation present
check("no annotation is a no-op", transform(`<div />`), `<div />`)

console.log(`tracked-preprocess.test: ${passed} passed`)
