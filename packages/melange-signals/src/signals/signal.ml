(* A writable reactive value. The [node] carries this signal's place in the
   dependency graph; [value] holds the current value and [equals] decides
   whether a write is a real change. Computeds reuse this same record (see
   [Computed]) with a node that has a [compute] function attached. *)
type 'a t = {
  mutable value : 'a;
  equals : 'a -> 'a -> bool;
  name : string option;
  node : Core.node;
}

let default_equals a b = a == b
let never_equals _ _ = false

let make ?name ?equals initial_value =
  let id = Id.make () in
  let equals = match equals with Some eq -> eq | None -> default_equals in
  { value = initial_value; equals; name; node = Core.make_signal_node ~id ~name }

(* Read the current value, tracking it as a dependency of the running
   computed/effect (if any), and refreshing it first if it is a computed. *)
let get signal =
  Scheduler.ensure_computed_fresh signal.node;
  Scheduler.track_dep signal.node;
  signal.value

(* Read without tracking a dependency (still refreshes a stale computed). *)
let peek signal =
  Scheduler.ensure_computed_fresh signal.node;
  signal.value

let set signal new_value =
  let should_update =
    try not (signal.equals signal.value new_value) with _ -> true
  in
  if should_update then begin
    signal.value <- new_value;
    signal.node.version <- signal.node.version + 1;
    incr Core.global_version;
    Scheduler.notify_subs signal.node
  end

let update signal fn = set signal (fn signal.value)

let name signal = signal.name
let batch = Scheduler.batch
let untrack = Scheduler.untrack
