# rescript-tracked-ppx

A native ReScript PPX that expands the `@tracked` annotation into the
`rescript-signals-react` auto-tracking hooks at compile time.

```rescript
@react.component
let make = (~a, ~b, ~c) => {
  @tracked([a, b])
  <div> {React.string(Int.toString(Signal.get(a) + Signal.get(b)))} {React.string(c)} </div>
}
```

expands to:

```rescript
@react.component
let make = (~a, ~b, ~c) => {
  SignalsReactAuto.useSignals([SignalsReactAuto.dep(a), SignalsReactAuto.dep(b)])
  <div> {React.string(Int.toString(Signal.get(a) + Signal.get(b)))} {React.string(c)} </div>
}
```

## Supported syntax

- `@tracked([a, b, ...])` — explicit dependency list. Expands to
  `SignalsReactAuto.useSignals([dep(a), dep(b)])`.
- `@tracked()` (or bare `@tracked`) — automatic discovery. Expands to
  `SignalsReactAuto.useTracked(() => <body>)`; any `Signal.get` read inside the
  body subscribes the component automatically.

The generated thunk is emitted as `Function$(fun () => ...)` with a `res.arity`
attribute, the encoding ReScript uses for uncurried functions in the ppx AST
(see `ast_mapper_from0.ml`); a bare `Pexp_fun` would be imported as curried and
rejected by uncurried-by-default mode.

## How it works

ReScript 12 hands an external ppx an OCaml **4.06** parsetree (marshal magic
`Caml1999M022`). `ppx.ml` vendors those exact 4.06 AST types (copied from
`ocaml/ocaml@4.06`) so `Marshal` round-trips faithfully, implements the
`ppx <infile> <outfile>` protocol, and rewrites expressions carrying the
`tracked` attribute. The only build dependency is `ocamlopt` — no opam/dune.

## Build

```bash
sh build.sh   # produces ./ppx
```

Wire it into a project's `rescript.json`:

```json
{ "ppx-flags": ["rescript-tracked-ppx/ppx"] }
```
