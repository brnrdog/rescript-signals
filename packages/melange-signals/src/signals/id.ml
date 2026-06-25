let next = ref 0

let make () =
  incr next;
  !next
