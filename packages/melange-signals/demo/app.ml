(* Browser demo: a counter wired up entirely through Signals.

   - [count]   a writable Signal
   - [doubled] a Computed derived from it
   - [parity]  a Computed with custom equality, so the "even/odd" label only
     re-renders when the parity actually flips, not on every count change
   - three Effects keep the DOM text in sync with the reactive graph *)

open Signals

(* Minimal DOM bindings via Melange FFI — no extra dependencies. *)
type element

external by_id : string -> element option = "getElementById"
  [@@mel.scope "document"] [@@mel.return nullable]

external set_text : element -> string -> unit = "textContent" [@@mel.set]

external on_click : element -> string -> (unit -> unit) -> unit = "addEventListener"
  [@@mel.send]

let with_el id f = match by_id id with Some el -> f el | None -> ()

let () =
  let count = Signal.make 0 in
  let doubled = Computed.make (fun () -> Signal.get count * 2) in
  let parity = Computed.make ~equals:( = ) (fun () -> Signal.get count mod 2) in

  (* Effects: each reads some reactive values and writes to the DOM. The
     scheduler re-runs an effect only when something it read has changed. *)
  Effect.run (fun () ->
    with_el "count" (fun el -> set_text el (string_of_int (Signal.get count)));
    None);

  Effect.run (fun () ->
    with_el "doubled" (fun el -> set_text el (string_of_int (Signal.get doubled)));
    None);

  Effect.run (fun () ->
    with_el "parity" (fun el ->
      set_text el (if Signal.get parity = 0 then "even" else "odd"));
    None);

  (* Wire up the buttons to mutate the signal. Multiple writes inside one
     handler could be wrapped in [Signal.batch] to coalesce re-renders. *)
  with_el "inc" (fun el ->
    on_click el "click" (fun () -> Signal.update count (fun n -> n + 1)));
  with_el "dec" (fun el ->
    on_click el "click" (fun () -> Signal.update count (fun n -> n - 1)));
  with_el "reset" (fun el ->
    on_click el "click" (fun () -> Signal.set count 0))
