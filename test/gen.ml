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

(* ── Differential-gate generators ───────────────────────────────────────────
   Fragment-shaped inputs for the engine-level comparisons (PLAN 1.5–1.9):
   small shared name pools so terms actually interact, ± only on fixed
   references, and fragment-valid propositions only — invalid-input agreement
   is the validateProp gate's job. *)

(* Random concatenations of notation tokens: mostly ill-formed, some valid,
   exercising every tokenizer/parser error path on both engines at once. *)
let token_pool =
  [
    "+"; "-"; "−"; "±"; "+-"; "("; ")"; "["; "]"; "*"; "^"; "\""; "'"; "′";
    "″"; " "; "\n"; "S"; "P"; "Dog"; "Boy'"; "p"; "q"; "x1"; "_"; "2"; "²";
    "⁰"; "₁"; "7"; "head of a horse";
  ]

let token_string_gen : string G.t =
  let open G in
  let* n = int_bound 25 in
  let* parts = list_size (return n) (oneof_list token_pool) in
  return (String.concat "" parts)

(* Atomic-categorical arguments: sides are atoms under 0–2 negations, the
   fragment the P/Z closure decides completely. *)
let atomic_argument_gen : (prop list * prop) G.t =
  let open G in
  let general =
    map (fun n -> Atom { name = n; singular = false })
      (oneof_list [ "A"; "B"; "C"; "D" ])
  in
  let fixed =
    oneof_list
      [
        Atom { name = "s"; singular = true };
        Atom { name = "t"; singular = true };
        Atom { name = "x'"; singular = false };
      ]
  in
  let rec wrap n t = if n = 0 then t else wrap (n - 1) (Neg t) in
  let side =
    let* atom = oneof_weighted [ (3, general); (1, fixed) ] in
    let* negs = int_bound 2 in
    return (wrap negs atom)
  in
  let signed_side =
    let* sign = oneof_list [ Plus; Minus ] in
    let* term = side in
    return { sign; term; level = 0 }
  in
  let subject =
    oneof_weighted
      [
        (3, signed_side);
        (1, map (fun t -> { sign = Wild; term = t; level = 0 }) fixed);
      ]
  in
  let prop =
    let* subject = subject in
    let* predicate = signed_side in
    return { subject; predicate }
  in
  let* n = int_range 1 4 in
  let* premises = list_size (return n) prop in
  let* conclusion = prop in
  return (premises, conclusion)

(* Relational propositions: predicate usually a relational complex (heads
   occasionally carrying pairing subscripts, objects occasionally nested),
   sometimes a plain atom to hit the no-passive paths. *)
let relational_prop_gen : prop G.t =
  let open G in
  let general =
    map (fun n -> Atom { name = n; singular = false })
      (oneof_list [ "A"; "B"; "C" ])
  in
  let fixed =
    oneof_list
      [ Atom { name = "s"; singular = true }; Atom { name = "x'"; singular = false } ]
  in
  let signed_atom =
    oneof_weighted
      [
        ( 4,
          let* sign = oneof_list [ Plus; Minus ] in
          let* term = oneof_weighted [ (3, general); (1, fixed) ] in
          return { sign; term; level = 0 } );
        (1, map (fun t -> { sign = Wild; term = t; level = 0 }) fixed);
      ]
  in
  let head = oneof_list [ "R"; "Lov"; "R₂₁"; "Lov₂₁₃" ] in
  let rel_term =
    let* h = head in
    let* n_objs = int_range 1 2 in
    let* objects = list_size (return n_objs) signed_atom in
    let* nest = oneof_weighted [ (4, return false); (1, return true) ] in
    let base = Rel { head = Atom { name = h; singular = false }; objects } in
    if nest then
      let* outer_sign = oneof_list [ Plus; Minus ] in
      return
        (Rel
           {
             head = Atom { name = "R"; singular = false };
             objects = [ { sign = outer_sign; term = base; level = 0 } ];
           })
    else return base
  in
  let* subject = signed_atom in
  let* predicate =
    let* sign = oneof_list [ Plus; Minus ] in
    let* term =
      oneof_weighted
        [ (4, rel_term); (1, oneof_weighted [ (3, general); (1, fixed) ]) ]
    in
    return { sign; term; level = 0 }
  in
  return { subject; predicate }

let relational_argument_gen : (prop list * prop) G.t =
  let open G in
  let* n = int_range 1 2 in
  let* premises = list_size (return n) relational_prop_gen in
  let* conclusion = relational_prop_gen in
  return (premises, conclusion)

(* Leveled atomic-categorical arguments (TFL⁺): levels 0–3 ride only +
   subjects; level-0 draws re-cover the P/Z route. *)
let leveled_argument_gen : (prop list * prop) G.t =
  let open G in
  let atom =
    let* name = oneof_list [ "A"; "B"; "C"; "g"; "s" ] in
    let* singular = oneof_weighted [ (5, return false); (1, return true) ] in
    return (Atom { name; singular })
  in
  let side =
    let* a = atom in
    let* negs = int_bound 2 in
    let rec wrap n t = if n = 0 then t else wrap (n - 1) (Neg t) in
    return (wrap negs a)
  in
  let prop =
    let* s_sign = oneof_list [ Plus; Minus ] in
    let* s_term = side in
    let* level =
      if s_sign = Plus then
        oneof_weighted [ (2, return 0); (3, int_range 1 3) ]
      else return 0
    in
    let* q_sign = oneof_list [ Plus; Minus ] in
    let* q_term = side in
    return
      {
        subject = { sign = s_sign; term = s_term; level };
        predicate = { sign = q_sign; term = q_term; level = 0 };
      }
  in
  let* n = int_range 1 3 in
  let* premises = list_size (return n) prop in
  let* conclusion = prop in
  return (premises, conclusion)

(* Statement propositions (lowercase atoms, negs/compounds) for the DNF
   equivalence path. *)
let statement_prop_gen : prop G.t =
  let open G in
  let atom =
    map (fun n -> Atom { name = n; singular = false }) (oneof_list [ "p"; "q"; "r" ])
  in
  let rec term_sized n =
    if n = 0 then atom
    else
      oneof_weighted
        [
          (3, atom);
          (1, map (fun t -> Neg t) (term_sized (n - 1)));
          ( 1,
            let* s1 = oneof_list [ Plus; Minus ] in
            let* t1 = term_sized (n - 1) in
            let* s2 = oneof_list [ Plus; Minus ] in
            let* t2 = term_sized (n - 1) in
            return
              (Compound
                 [
                   { sign = s1; term = t1; level = 0 };
                   { sign = s2; term = t2; level = 0 };
                 ]) );
        ]
  in
  let* s_sign = oneof_list [ Plus; Minus ] in
  let* s_term = term_sized 2 in
  let* q_sign = oneof_list [ Plus; Minus ] in
  let* q_term = term_sized 2 in
  return
    {
      subject = { sign = s_sign; term = s_term; level = 0 };
      predicate = { sign = q_sign; term = q_term; level = 0 };
    }

let equivalence_pair_gen : (prop * prop) G.t =
  let open G in
  let side = oneof_weighted [ (1, statement_prop_gen); (1, relational_prop_gen) ] in
  let* a = side in
  let* b =
    (* half the time, derive b from a so genuine equivalences appear *)
    oneof_weighted
      [
        (1, side);
        (1, return (Tfl.Infer.obverse a));
        ( 1,
          return
            (match Tfl.Infer.contrapositive a with Some c -> c | None -> a) );
      ]
  in
  return (a, b)

let query_term_gen : (prop list * term) G.t =
  let open G in
  let* premises, conclusion = atomic_argument_gen in
  let* term =
    oneof_list
      [
        Atom { name = "A"; singular = false };
        Atom { name = "B"; singular = false };
        Atom { name = "s"; singular = true };
        Atom { name = "x'"; singular = false };
      ]
  in
  return (premises @ [ conclusion ], term)

(* Random program sources: printed props, comment tails, garbage lines. *)
let program_src_gen : string G.t =
  let open G in
  let prop_line =
    map Tfl.Notation.print_proposition (oneof [ relational_prop_gen; prop_gen ])
  in
  let line =
    oneof_weighted
      [
        (5, prop_line);
        (2, map (fun p -> p ^ " -- a comment") prop_line);
        (1, token_string_gen);
        (1, return "");
        (1, return "-- whole-line comment");
      ]
  in
  let* n = int_range 1 4 in
  let* lines = list_size (return n) line in
  return (String.concat "\n" lines)

(* ── Oracle-semantics generators (PLAN 1.10) ────────────────────────────────
   Mirrors engine/oracle.js's own random formulas: three general atoms plus one
   singular and one proterm, so the vocabulary of an argument stays small
   enough for both engines to enumerate every model exhaustively (the sampling
   path is not comparable across engines — see Semantics). *)

let sem_fixed : term G.t =
  G.oneof_list
    [ Atom { name = "s"; singular = true }; Atom { name = "t'"; singular = false } ]

let sem_wild : signed_term G.t =
  G.map (fun t -> { sign = Wild; term = t; level = 0 }) sem_fixed

let rec wrap_negs n t = if n = 0 then t else wrap_negs (n - 1) (Neg t)

(* An atom under 0–2 negations, fixed reference occasionally. *)
let sem_atomic_term (atoms : string list) : term G.t =
  let open G in
  let* base =
    oneof_weighted
      [
        (1, sem_fixed);
        ( 5,
          map (fun n -> Atom { name = n; singular = false }) (oneof_list atoms) );
      ]
  in
  let* negs = oneof_weighted [ (3, return 0); (1, int_range 1 2) ] in
  return (wrap_negs negs base)

let sem_signed (gen : term G.t) : signed_term G.t =
  let open G in
  let* sign = oneof_list [ Plus; Minus ] in
  let* term = gen in
  return { sign; term; level = 0 }

let sem_categorical_prop (atoms : string list) : prop G.t =
  let open G in
  let* subject =
    oneof_weighted [ (1, sem_wild); (3, sem_signed (sem_atomic_term atoms)) ]
  in
  let* predicate = sem_signed (sem_atomic_term atoms) in
  return { subject; predicate }

(* Relational propositions over a single relation: objects are plain atoms or
   fixed references, complexes nest one level deep, and either side may carry
   the complex — the shapes suites 2, 3 and 5 of the oracle fuzz. *)
let sem_relational_prop (atoms : string list) (rel_name : string) : prop G.t =
  let open G in
  let plain =
    map (fun n -> Atom { name = n; singular = false }) (oneof_list atoms)
  in
  let obj = oneof_weighted [ (1, sem_wild); (2, sem_signed plain) ] in
  let rec complex depth =
    let* o =
      if depth <= 0 then obj
      else
        oneof_weighted
          [ (5, obj); (1, sem_signed (complex (depth - 1))) ]
    in
    return (Rel { head = Atom { name = rel_name; singular = false }; objects = [ o ] })
  in
  let side allow_rel =
    if allow_rel then
      oneof_weighted [ (1, sem_signed (complex 1)); (1, sem_signed plain) ]
    else sem_signed plain
  in
  let* subject =
    oneof_weighted
      [
        (1, sem_wild);
        (1, side true);
        (2, side false);
      ]
  in
  let* predicate = side true in
  return { subject; predicate }

(* Compound-bearing categoricals, so Simp's conjunct-drops and Add's compound
   intros face the semantics too (oracle suite 2). *)
let sem_compound_prop (atoms : string list) : prop G.t =
  let open G in
  let compound =
    let* k = int_range 2 3 in
    let* elements =
      list_size (return k)
        (let* sign = oneof_weighted [ (2, return Plus); (1, return Minus) ] in
         let* term = sem_atomic_term atoms in
         return { sign; term; level = 0 })
    in
    return (Compound elements)
  in
  let side = G.oneof [ sem_signed compound; sem_signed (sem_atomic_term atoms) ] in
  let* subject = side in
  let* predicate = side in
  return { subject; predicate }

(* A plain subject and a relational predicate with 1–2 objects: the passive
   transformation's own input shape, arity 3 included so the n-ary crossing
   guard is exercised (oracle suite 4). *)
let sem_passive_prop (atoms : string list) (rel_name : string) : prop G.t =
  let open G in
  let plain =
    map (fun n -> Atom { name = n; singular = false }) (oneof_list atoms)
  in
  let slot = oneof_weighted [ (1, sem_wild); (2, sem_signed plain) ] in
  let* k = int_range 1 2 in
  let* objects = list_size (return k) slot in
  let* subject = slot in
  return
    {
      subject;
      predicate =
        {
          sign = Plus;
          term = Rel { head = Atom { name = rel_name; singular = false }; objects };
          level = 0;
        };
    }

let sem_argument (prop : prop G.t) ~(max_premises : int) :
    (prop list * prop) G.t =
  let open G in
  let* n = int_range 1 max_premises in
  let* premises = list_size (return n) prop in
  let* conclusion = prop in
  return (premises, conclusion)

let sem_categorical_argument = sem_argument (sem_categorical_prop [ "A"; "B"; "C" ]) ~max_premises:3
let sem_relational_argument = sem_argument (sem_relational_prop [ "A"; "B" ] "R") ~max_premises:2

let print_argument (premises, conclusion) =
  String.concat "; " (List.map Tfl.Notation.print_proposition premises)
  ^ " ⊢ "
  ^ Tfl.Notation.print_proposition conclusion
