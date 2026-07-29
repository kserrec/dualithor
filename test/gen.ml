(* QCheck generators for random terms and propositions. These feed every later
   property test (round-trip, differential fuzz), so they generate only
   parser-producible shapes: compounds have 2+ elements, relational complexes
   1+ objects, propositional-term bare inners are atoms.

   Per the port-language decisions (LOG.md 2026-07-29): bare names use ASCII
   letters only, and all generated text stays ASCII, inside the range where the
   JS reference and the OCaml engine agree on string ordering. *)

open Tfl.Ast
module G = QCheck2.Gen

let sign_gen : sign G.t = G.oneof_list [ Plus; Minus; Wild ]

(* An ASCII bare name: letter, then letters/digits/underscore, then optional
   proterm primes. *)
let bare_name : string G.t =
  let open G in
  let letter = oneof [ char_range 'a' 'z'; char_range 'A' 'Z' ] in
  let rest = oneof [ char_range 'a' 'z'; char_range 'A' 'Z'; char_range '0' '9'; return '_' ] in
  let* c = letter in
  let* tail = string_size ~gen:rest (int_bound 5) in
  let* primes = int_bound 2 in
  return (Printf.sprintf "%c%s%s" c tail (String.make primes '\''))

(* A name that forces the printer to quote it (contains a space or hyphen). *)
let quoted_name : string G.t =
  let open G in
  let word = string_size ~gen:(char_range 'a' 'z') (int_range 1 6) in
  let* a = word in
  let* sep = oneof_list [ " "; "-" ] in
  let* b = word in
  return (a ^ sep ^ b)

let atom_gen : term G.t =
  let open G in
  let* name = oneof_weighted [ (8, bare_name); (2, quoted_name) ] in
  let* singular = oneof_weighted [ (3, return false); (1, return true) ] in
  return (Atom { name; singular })

(* Levels: mostly 0 (classical); occasionally 1-3 (TFL+ intermediate
   quantifiers). *)
let level_gen : int G.t = G.oneof_weighted [ (8, G.return 0); (2, G.int_range 1 3) ]

let rec term_sized (n : int) : term G.t =
  if n <= 0 then atom_gen
  else
    G.oneof_weighted
      [
        (3, atom_gen);
        (2, G.map (fun t -> Neg t) (term_sized (n / 2)));
        (2, compound_sized n);
        (2, rel_sized n);
        (1, propterm_sized n);
      ]

and signed_sized (n : int) : signed_term G.t =
  let open G in
  let* sign = sign_gen in
  let* term = term_sized n in
  let* level = level_gen in
  return { sign; term; level }

and compound_sized (n : int) : term G.t =
  let open G in
  let* k = int_range 2 3 in
  let* elements = list_size (return k) (signed_sized (n / 2)) in
  return (Compound elements)

and rel_sized (n : int) : term G.t =
  let open G in
  let* head = oneof_weighted [ (4, atom_gen); (1, term_sized (n / 2)) ] in
  let* k = int_range 1 3 in
  let* objects = list_size (return k) (signed_sized (n / 2)) in
  return (Rel { head; objects })

and propterm_sized (n : int) : term G.t =
  let open G in
  let* inner =
    oneof_weighted
      [
        (1, map (fun t -> Inner_term t) atom_gen);
        (1, map (fun p -> Inner_prop p) (prop_sized (n / 2)));
      ]
  in
  return (PropTerm inner)

and prop_sized (n : int) : prop G.t =
  let open G in
  let* subject = signed_sized n in
  let* predicate = signed_sized n in
  return { subject; predicate }

let term_gen : term G.t = G.sized (fun n -> term_sized (min n 8))
let prop_gen : prop G.t = G.sized (fun n -> prop_sized (min n 8))
