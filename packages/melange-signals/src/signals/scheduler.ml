open Core

(* The node currently being tracked (a computed during recompute, or an effect
   during its run). Dependencies read while this is [Some] are recorded. *)
let current_target : node option ref = ref None

(* Dependency-tracking version shared across nested compute/effect runs. *)
let current_tracking_version = ref 0

(* Cursor into the current target's dependency list. During a re-run we walk
   the existing links in order and reuse them instead of allocating, which
   keeps steady-state tracking allocation-free. *)
let current_dep_cursor : link option ref = ref None

(* Pending work, processed in level order on flush. *)
let pending_effects : node list ref = ref []
let pending_computeds : node list ref = ref []
let flushing = ref false

let add_effect_to_pending node =
  if not (is_pending node) then begin
    set_pending node;
    pending_effects := node :: !pending_effects
  end

let add_computed_to_pending node =
  if not (is_pending node) then begin
    set_pending node;
    pending_computeds := node :: !pending_computeds
  end

(* ----- dependency tracking ----- *)

(* Record that [current_target] reads [source]. Reuses an existing link when
   one is already present (marking it with the current tracking version);
   otherwise creates a new link in both intrusive lists. Stale links — those
   not re-marked this run — are pruned after the run by [prune_stale_deps]. *)
let track_dep_into target source =
  match target.first_dep with
  | None ->
    let link = make_link ~source ~target in
    link.last_tracked_version <- !current_tracking_version;
    link_to_deps target link;
    link_to_subs source link;
    current_dep_cursor := Some link
  | Some _ ->
    let version = !current_tracking_version in
    (* Fast path: the next dependency in this run is usually the same one as
       in the previous run, so check the cursor and the link after it. *)
    let fast =
      match !current_dep_cursor with
      | Some cursor when cursor.source == source ->
        cursor.last_tracked_version <- version;
        true
      | Some cursor -> (
        match cursor.next_dep with
        | Some next when next.source == source ->
          next.last_tracked_version <- version;
          current_dep_cursor := Some next;
          true
        | _ -> false)
      | None -> false
    in
    if not fast then begin
      (* Fall back to scanning the dependency list for an existing link. *)
      let rec scan = function
        | Some l when l.source == source ->
          l.last_tracked_version <- version;
          current_dep_cursor := Some l
        | Some l -> scan l.next_dep
        | None ->
          let link = make_link ~source ~target in
          link.last_tracked_version <- version;
          link_to_deps target link;
          link_to_subs source link;
          current_dep_cursor := Some link
      in
      scan target.first_dep
    end

(* Track a read of [source] in whatever context is current. *)
let track_dep source =
  match !current_target with
  | Some target -> track_dep_into target source
  | None -> ()

(* ----- levels ----- *)

(* A node's level is one more than the deepest computed it depends on; plain
   signals sit at level 0. Levels give a glitch-free processing order. *)
let compute_level node =
  let max_level = ref 0 in
  let rec loop = function
    | None -> ()
    | Some l ->
      if is_computed l.source && l.source.level > !max_level then
        max_level := l.source.level;
      loop l.next_dep
  in
  loop node.first_dep;
  !max_level + 1

(* ----- running reactive nodes ----- *)

(* Remove dependency links that were not re-tracked during the latest run. *)
let prune_stale_deps node =
  let version = !current_tracking_version in
  let rec loop = function
    | None -> ()
    | Some l ->
      let next = l.next_dep in
      if l.last_tracked_version <> version then begin
        unlink_from_subs l;
        unlink_from_deps l
      end;
      loop next
  in
  loop node.first_dep

(* Set up tracking context, run [body], prune stale deps, restore context.
   Returns nothing; callers handle propagation/level afterwards. *)
let with_tracking node body =
  let prev_version = !current_tracking_version in
  let prev_target = !current_target in
  let prev_cursor = !current_dep_cursor in
  incr tracking_version;
  current_tracking_version := !tracking_version;
  current_target := Some node;
  current_dep_cursor := node.first_dep;
  let finish () =
    current_target := prev_target;
    current_dep_cursor := prev_cursor;
    current_tracking_version := prev_version
  in
  (try body ()
   with e ->
     finish ();
     raise e);
  prune_stale_deps node;
  finish ()

(* Recompute a computed. Only propagates to subscribers when its value
   actually changed (tracked via [version]). *)
let run_computed_cycle node ~should_clear_pending =
  let previous_version = node.version in
  if should_clear_pending then clear_pending node;
  with_tracking node (fun () ->
    match node.compute with Some f -> f () | None -> ());
  clear_dirty node;
  node.last_global_version <- !global_version;
  if node.first_sub <> None && node.version <> previous_version then begin
    let rec loop = function
      | None -> ()
      | Some (l : link) ->
        let sub = l.target in
        if is_computed sub then
          (* lazily mark downstream computeds dirty *)
          set_dirty sub
        else
          (* queue subscribing effects, unless it is the effect currently
             running (avoids self-retriggering) *)
          (match !current_target with
           | Some cur when cur == sub -> ()
           | _ -> add_effect_to_pending sub);
        loop l.next_sub
    in
    loop node.first_sub
  end

let retrack_computed node =
  let old_level = node.level in
  run_computed_cycle node ~should_clear_pending:true;
  if old_level = 0 then node.level <- compute_level node

let retrack_effect node =
  let old_level = node.level in
  clear_pending node;
  with_tracking node (fun () ->
    match node.run with Some f -> f () | None -> ());
  clear_dirty node;
  if old_level = 0 then node.level <- compute_level node

(* ----- flush ----- *)

let by_level a b = compare a.level b.level

let flush () =
  flushing := true;
  (try
     while !pending_computeds <> [] || !pending_effects <> [] do
       (* Computeds first: recomputing them may queue further effects. *)
       if !pending_computeds <> [] then begin
         let batch = List.sort by_level !pending_computeds in
         pending_computeds := [];
         List.iter retrack_computed batch
       end;
       if !pending_effects <> [] then begin
         let batch = List.sort by_level !pending_effects in
         pending_effects := [];
         List.iter retrack_effect batch
       end
     done;
     flushing := false
   with e ->
     flushing := false;
     raise e)

(* ----- notification ----- *)

(* Propagate a write from [source]. Computeds are marked dirty transitively
   (and lazily — they recompute only when read or when feeding an effect).
   Effects are queued. Effects reached through a deferring computed are held
   until that computed recomputes, so an unchanged computed can cancel them. *)
let notify_subs source =
  (match source.first_sub with
   | None -> ()
   | Some _ when (not (is_computed source)) && source.computed_subscriber_count = 0 ->
     (* Fast path: plain signal whose subscribers are all effects. *)
     let rec loop = function
       | None -> ()
       | Some (l : link) ->
         add_effect_to_pending l.target;
         loop l.next_sub
     in
     loop source.first_sub
   | Some _ ->
     let queue = Queue.create () in
     Queue.push source queue;
     while not (Queue.is_empty queue) do
       let s = Queue.pop queue in
       let rec loop = function
         | None -> ()
         | Some (l : link) ->
           let target = l.target in
           if is_computed target then begin
             if not (is_dirty target) then begin
               set_dirty target;
               Queue.push target queue
             end
           end
           else if is_computed s then begin
             if s.defer_effects_until_recompute then add_computed_to_pending s
             else add_effect_to_pending target
           end
           else add_effect_to_pending target;
           loop l.next_sub
       in
       loop s.first_sub
     done);
  if (!pending_effects <> [] || !pending_computeds <> []) && not !flushing then
    flush ()

(* Ensure a computed is up to date before its value is read. *)
let ensure_computed_fresh node =
  if is_computed node && is_dirty node then begin
    if node.last_global_version = !global_version then
      (* dirty flag is stale: nothing it depends on has been written *)
      clear_dirty node
    else begin
      let old_level = node.level in
      run_computed_cycle node ~should_clear_pending:false;
      if old_level = 0 then node.level <- compute_level node
    end
  end

(* ----- public scheduling helpers ----- *)

let batch fn =
  let was_flushing = !flushing in
  flushing := true;
  match fn () with
  | result ->
    if not was_flushing then begin
      flushing := false;
      if !pending_effects <> [] || !pending_computeds <> [] then flush ()
    end;
    result
  | exception e ->
    if not was_flushing then flushing := false;
    raise e

let untrack fn =
  let prev_target = !current_target in
  let prev_cursor = !current_dep_cursor in
  current_target := None;
  current_dep_cursor := None;
  let restore () =
    current_target := prev_target;
    current_dep_cursor := prev_cursor
  in
  match fn () with
  | result ->
    restore ();
    result
  | exception e ->
    restore ();
    raise e
