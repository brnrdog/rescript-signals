(* Behavioural tests for the reactive core. This file is plain OCaml (no
   Melange/JS APIs) so the same suite runs natively under dune and validates
   Signal / Computed / Effect / Scheduler semantics. *)

open Signals

let failures = ref 0
let total = ref 0

let check name cond =
  incr total;
  if cond then Printf.printf "  ok   %s\n" name
  else begin
    incr failures;
    Printf.printf "  FAIL %s\n" name
  end

let check_eq name a b =
  check (Printf.sprintf "%s (got %d, want %d)" name a b) (a = b)

(* ----- Signal ----- *)

let test_signal () =
  print_endline "Signal";
  let s = Signal.make 42 in
  check_eq "initial value" (Signal.peek s) 42;
  Signal.set s 20;
  check_eq "set value" (Signal.peek s) 20;
  Signal.update s (fun x -> x * 2);
  check_eq "update value" (Signal.peek s) 40;
  let named = Signal.make ~name:"counter" 0 in
  check "name preserved" (Signal.name named = Some "counter");
  (* custom equality prevents a no-op write from notifying *)
  let eqs = Signal.make ~equals:( = ) 1 in
  let runs = ref 0 in
  let d = Effect.run_with_disposer (fun () -> ignore (Signal.get eqs); incr runs; None) in
  let after_initial = !runs in
  Signal.set eqs 1;
  check_eq "equal write does not re-run effect" !runs after_initial;
  Signal.set eqs 2;
  check_eq "changed write re-runs effect" !runs (after_initial + 1);
  d.dispose ()

(* ----- Effect ----- *)

let test_effect () =
  print_endline "Effect";
  let s = Signal.make 0 in
  let seen = ref (-1) in
  let runs = ref 0 in
  let d = Effect.run_with_disposer (fun () -> seen := Signal.get s; incr runs; None) in
  check_eq "effect runs once on create" !runs 1;
  check_eq "effect sees initial value" !seen 0;
  Signal.set s 7;
  check_eq "effect re-runs on change" !runs 2;
  check_eq "effect sees new value" !seen 7;
  d.dispose ();
  Signal.set s 99;
  check_eq "disposed effect does not run" !runs 2;
  (* cleanup runs before re-run and on dispose *)
  let cleanups = ref 0 in
  let s2 = Signal.make 0 in
  let d2 =
    Effect.run_with_disposer (fun () ->
      ignore (Signal.get s2);
      Some (fun () -> incr cleanups))
  in
  Signal.set s2 1;
  check_eq "cleanup ran before re-run" !cleanups 1;
  d2.dispose ();
  check_eq "cleanup ran on dispose" !cleanups 2

(* ----- batch / untrack ----- *)

let test_batch_untrack () =
  print_endline "batch / untrack";
  let a = Signal.make 0 and b = Signal.make 0 and c = Signal.make 0 in
  let runs = ref 0 in
  let d =
    Effect.run_with_disposer (fun () ->
      ignore (Signal.get a + Signal.get b + Signal.get c);
      incr runs;
      None)
  in
  let after_initial = !runs in
  Signal.batch (fun () ->
    Signal.set a 1;
    Signal.set b 2;
    Signal.set c 3);
  check_eq "batch coalesces to one re-run" !runs (after_initial + 1);
  check "batched writes applied" (a.value = 1 && b.value = 2 && c.value = 3);
  d.dispose ();
  let r = Signal.batch (fun () -> 1 + 2 + 3) in
  check_eq "batch returns result" r 6;
  (* untrack *)
  let tracked = Signal.make 1 and untracked = Signal.make 10 in
  let runs2 = ref 0 in
  let d2 =
    Effect.run_with_disposer (fun () ->
      ignore (Signal.get tracked);
      ignore (Signal.untrack (fun () -> Signal.get untracked));
      incr runs2;
      None)
  in
  let base = !runs2 in
  Signal.set untracked 20;
  check_eq "untracked change does not re-run" !runs2 base;
  Signal.set tracked 2;
  check_eq "tracked change re-runs" !runs2 (base + 1);
  d2.dispose ()

(* ----- Computed ----- *)

let test_computed () =
  print_endline "Computed";
  let s = Signal.make 10 in
  let doubled = Computed.make (fun () -> Signal.get s * 2) in
  check_eq "computed initial" (Signal.peek doubled) 20;
  Signal.set s 15;
  check_eq "computed lazily refreshes on read" (Signal.peek doubled) 30;
  (* chained computeds *)
  let plus_one = Computed.make (fun () -> Signal.get doubled + 1) in
  check_eq "chained computed initial" (Signal.peek plus_one) 31;
  Signal.set s 100;
  check_eq "chained computed updates" (Signal.peek plus_one) 201;
  (* computeds only recompute when read (laziness) *)
  let computes = ref 0 in
  let s2 = Signal.make 1 in
  let lazy_c = Computed.make (fun () -> incr computes; Signal.get s2 + 1) in
  let after_create = !computes in
  Signal.set s2 2;
  Signal.set s2 3;
  check_eq "no recompute without a read" !computes after_create;
  check_eq "value correct after reads" (Signal.peek lazy_c) 4;
  check_eq "recompute happened once on read" !computes (after_create + 1);
  (* effect depending on computed *)
  let seen = ref 0 and runs = ref 0 in
  let s3 = Signal.make 1 in
  let c3 = Computed.make (fun () -> Signal.get s3 * 10) in
  let d = Effect.run_with_disposer (fun () -> seen := Signal.get c3; incr runs; None) in
  check_eq "effect sees computed" !seen 10;
  Signal.set s3 5;
  check_eq "effect re-runs via computed" !seen 50;
  check_eq "effect ran twice total" !runs 2;
  d.dispose ()

(* ----- diamond / glitch-freedom ----- *)

let test_diamond () =
  print_endline "Diamond (glitch-freedom)";
  let a = Signal.make 1 in
  let b = Computed.make (fun () -> Signal.get a + 1) in
  let c = Computed.make (fun () -> Signal.get a + 10) in
  let runs = ref 0 and last = ref 0 in
  let d =
    Effect.run_with_disposer (fun () ->
      last := Signal.get b + Signal.get c;
      incr runs;
      None)
  in
  check_eq "diamond initial sum" !last 13;
  let base = !runs in
  Signal.set a 2;
  check_eq "diamond effect runs once per change" !runs (base + 1);
  check_eq "diamond sum recomputed" !last 15;
  d.dispose ()

(* ----- custom-equality computed short-circuits effects ----- *)

let test_computed_equals () =
  print_endline "Computed with custom equality";
  let s = Signal.make 2 in
  let parity = Computed.make ~equals:( = ) (fun () -> Signal.get s mod 2) in
  let runs = ref 0 in
  let d = Effect.run_with_disposer (fun () -> ignore (Signal.get parity); incr runs; None) in
  let base = !runs in
  Signal.set s 4;
  (* 4 mod 2 = 0, same as 2 mod 2 = 0 -> effect should not re-run *)
  check_eq "unchanged computed cancels effect" !runs base;
  Signal.set s 5;
  (* 5 mod 2 = 1 -> changed -> effect runs *)
  check_eq "changed computed re-runs effect" !runs (base + 1);
  d.dispose ()

let () =
  test_signal ();
  test_effect ();
  test_batch_untrack ();
  test_computed ();
  test_diamond ();
  test_computed_equals ();
  Printf.printf "\n%d/%d checks passed\n" (!total - !failures) !total;
  if !failures > 0 then exit 1
