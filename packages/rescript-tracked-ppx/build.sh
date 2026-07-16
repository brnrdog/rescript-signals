#!/bin/sh
# Compiles the @tracked ppx to a native binary using the system OCaml compiler.
# ReScript 12 hands ppx an OCaml 4.06 parsetree; ppx.ml vendors those exact
# types, so the only build dependency is ocamlopt (any recent OCaml works).
set -e
cd "$(dirname "$0")"
ocamlopt -w -a-31 ppx.ml -o ppx
rm -f ppx.cmi ppx.cmx ppx.o
echo "built $(pwd)/ppx"
