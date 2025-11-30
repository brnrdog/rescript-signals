type kind = [#Effect | #Computed(int)] // int = backing signal ID

type t = {
  id: int,
  kind: kind,
  run: unit => unit,
  mutable deps: Set.t<int>,
  mutable level: int,
}

let make = (id: int, kind: kind, run: unit => unit): t => {
  id,
  kind,
  run,
  deps: Set.make(),
  level: 0,
}
