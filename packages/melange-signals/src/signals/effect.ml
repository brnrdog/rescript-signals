(* A side effect that re-runs whenever any signal it reads changes. The effect
   body may return a cleanup function, which runs before the next re-run and on
   dispose. *)
type disposer = { dispose : unit -> unit }

let run_with_disposer ?name fn =
  let id = Id.make () in
  let cleanup : (unit -> unit) option ref = ref None in
  (* Run the previous cleanup, then the body, storing its new cleanup. *)
  let run_with_cleanup () =
    (match !cleanup with Some c -> c () | None -> ());
    cleanup := fn ()
  in
  let node = Core.make_effect_node ~id ~name ~run:run_with_cleanup in
  (* Initial run under tracking to establish dependencies. *)
  let prev = !Scheduler.current_target in
  Scheduler.current_target := Some node;
  (try
     run_with_cleanup ();
     Core.clear_dirty node;
     Scheduler.current_target := prev
   with e ->
     Scheduler.current_target := prev;
     raise e);
  node.level <- Scheduler.compute_level node;
  let disposed = ref false in
  let dispose () =
    if not !disposed then begin
      disposed := true;
      (match !cleanup with Some c -> c () | None -> ());
      Core.clear_deps node
    end
  in
  { dispose }

let run ?name fn = ignore (run_with_disposer ?name fn)
