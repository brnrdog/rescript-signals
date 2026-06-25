(* Public entrypoint: reactive Signals for OCaml + Melange.

   {[
     let count = Signal.make 0 in
     let doubled = Computed.make (fun () -> Signal.get count * 2) in
     Effect.run (fun () ->
       Printf.printf "doubled = %d\n" (Signal.get doubled);
       None);
     Signal.set count 5  (* prints "doubled = 10" *)
   ]} *)

module Signal = Signal
module Computed = Computed
module Effect = Effect
