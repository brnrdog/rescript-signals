(* Core types for the reactive system.

   The reactive graph is a doubly linked structure. Every reactive thing —
   a plain signal, a computed, or an effect — is represented by a single
   [node]. A [link] is an edge between a [source] node (the value being read)
   and a [target] node (the observer doing the reading). Each link lives in
   two intrusive lists simultaneously:

   - the source's subscriber list  (next_sub / prev_sub)
   - the target's dependency list  (next_dep / prev_dep)

   A plain signal is a node with neither [compute] nor [run].
   A computed is a node with [compute = Some _]; it is both a source (it has
   subscribers) and a target (it has dependencies).
   An effect is a node with [run = Some _]; it is only a target.

   The original ReScript implementation packed the computed's observer and
   subscriber records into one object and reinterpreted pointers with
   [Obj.magic], relying on JS objects being keyed by field name. The unified
   [node] here encodes the same graph without any unsafe casts, so the code
   compiles unchanged for both native OCaml and Melange. *)

(* Bitwise flags for node state (avoids per-node boolean fields). *)
let flag_dirty = 1
let flag_pending = 2
let flag_running = 4

(* Global tracking version: bumped once per compute/effect run so that
   dependencies tracked during the current run can be told apart from stale
   ones left over from a previous run. *)
let tracking_version = ref 0

(* Global mutation version: bumped on every real signal write. Lets a computed
   skip recomputation when nothing it could depend on has changed. *)
let global_version = ref 0

type kind =
  | Signal
  | Computed
  | Effect

type node = {
  id : int;
  kind : kind;
  name : string option;
  (* --- observer side: what this node reads --- *)
  mutable first_dep : link option;
  mutable last_dep : link option;
  (* --- source side: who reads this node --- *)
  mutable first_sub : link option;
  mutable last_sub : link option;
  (* number of subscribers that are themselves computeds; lets plain signals
     take a fast notification path when all subscribers are effects *)
  mutable computed_subscriber_count : int;
  (* bumped whenever this node's value actually changes *)
  mutable version : int;
  mutable flags : int;
  mutable level : int;
  mutable last_global_version : int;
  (* Some for computeds: recompute the value, bumping [version] on change *)
  mutable compute : (unit -> unit) option;
  (* Some for effects: the side-effecting body to run *)
  mutable run : (unit -> unit) option;
  (* computeds with a custom equality defer downstream effects until the
     computed has recomputed, so an unchanged result can short-circuit them *)
  mutable defer_effects_until_recompute : bool;
}

and link = {
  mutable source : node;
  mutable target : node;
  mutable next_dep : link option;
  mutable prev_dep : link option;
  mutable next_sub : link option;
  mutable prev_sub : link option;
  mutable last_tracked_version : int;
}

(* ----- node construction ----- *)

let make_signal_node ~id ~name =
  {
    id;
    kind = Signal;
    name;
    first_dep = None;
    last_dep = None;
    first_sub = None;
    last_sub = None;
    computed_subscriber_count = 0;
    version = 0;
    flags = 0;
    level = 0;
    last_global_version = 0;
    compute = None;
    run = None;
    defer_effects_until_recompute = false;
  }

let make_computed_node ~id ~name ~defer_effects_until_recompute =
  {
    id;
    kind = Computed;
    name;
    first_dep = None;
    last_dep = None;
    first_sub = None;
    last_sub = None;
    computed_subscriber_count = 0;
    version = 0;
    flags = flag_dirty (* computeds start dirty *);
    level = 0;
    last_global_version = 0;
    compute = None (* installed by Computed once the closure exists *);
    run = None;
    defer_effects_until_recompute;
  }

let make_effect_node ~id ~name ~run =
  {
    id;
    kind = Effect;
    name;
    first_dep = None;
    last_dep = None;
    first_sub = None;
    last_sub = None;
    computed_subscriber_count = 0;
    version = 0;
    flags = flag_dirty (* effects start dirty *);
    level = 0;
    last_global_version = 0;
    compute = None;
    run = Some run;
    defer_effects_until_recompute = false;
  }

(* ----- predicates ----- *)

let is_computed n = match n.compute with Some _ -> true | None -> false
let is_effect n = match n.run with Some _ -> true | None -> false

(* ----- flag operations ----- *)

let is_dirty n = n.flags land flag_dirty <> 0
let set_dirty n = n.flags <- n.flags lor flag_dirty
let clear_dirty n = n.flags <- n.flags land lnot flag_dirty
let is_pending n = n.flags land flag_pending <> 0
let set_pending n = n.flags <- n.flags lor flag_pending
let clear_pending n = n.flags <- n.flags land lnot flag_pending

(* ----- link construction ----- *)

let make_link ~source ~target =
  {
    source;
    target;
    next_dep = None;
    prev_dep = None;
    next_sub = None;
    prev_sub = None;
    last_tracked_version = 0;
  }

(* Append [link] to [source]'s subscriber list. *)
let link_to_subs source link =
  link.prev_sub <- source.last_sub;
  link.next_sub <- None;
  (match source.last_sub with
   | Some last -> last.next_sub <- Some link
   | None -> source.first_sub <- Some link);
  source.last_sub <- Some link;
  if is_computed link.target then
    source.computed_subscriber_count <- source.computed_subscriber_count + 1

(* Append [link] to [target]'s dependency list. *)
let link_to_deps target link =
  link.prev_dep <- target.last_dep;
  link.next_dep <- None;
  (match target.last_dep with
   | Some last -> last.next_dep <- Some link
   | None -> target.first_dep <- Some link);
  target.last_dep <- Some link

(* Remove [link] from its source's subscriber list. *)
let unlink_from_subs link =
  let source = link.source in
  (match link.prev_sub with
   | Some prev -> prev.next_sub <- link.next_sub
   | None -> source.first_sub <- link.next_sub);
  (match link.next_sub with
   | Some next -> next.prev_sub <- link.prev_sub
   | None -> source.last_sub <- link.prev_sub);
  link.prev_sub <- None;
  link.next_sub <- None;
  if is_computed link.target && source.computed_subscriber_count > 0 then
    source.computed_subscriber_count <- source.computed_subscriber_count - 1

(* Remove [link] from its target's dependency list. *)
let unlink_from_deps link =
  let target = link.target in
  (match link.prev_dep with
   | Some prev -> prev.next_dep <- link.next_dep
   | None -> target.first_dep <- link.next_dep);
  (match link.next_dep with
   | Some next -> next.prev_dep <- link.prev_dep
   | None -> target.last_dep <- link.prev_dep);
  link.prev_dep <- None;
  link.next_dep <- None

(* Unlink all dependencies of [node] (used on dispose). *)
let clear_deps node =
  let rec loop = function
    | None -> ()
    | Some l ->
      let next = l.next_dep in
      unlink_from_subs l;
      loop next
  in
  loop node.first_dep;
  node.first_dep <- None;
  node.last_dep <- None
