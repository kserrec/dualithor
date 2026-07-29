(* 1.1 acceptance: the generators produce every constructor shape (coverage
   assertion, deterministic seed), and generated values are well-formed enough
   to build and compare (reflexivity property over 10k cases). *)

open Tfl.Ast

(* ── Coverage: every constructor shape appears in a generated sample ────── *)

type counts = {
  mutable atoms : int;
  mutable negs : int;
  mutable compounds : int;
  mutable rels : int;
  mutable propterm_props : int;
  mutable propterm_terms : int;
  mutable plus : int;
  mutable minus : int;
  mutable wild : int;
  mutable singulars : int;
  mutable nonzero_levels : int;
  mutable primed_names : int;
  mutable quoted_names : int;
}

let is_bare_name (name : string) =
  let bare_char c =
    (c >= 'a' && c <= 'z')
    || (c >= 'A' && c <= 'Z')
    || (c >= '0' && c <= '9')
    || c = '_' || c = '\''
  in
  String.length name > 0
  && (match name.[0] with 'a' .. 'z' | 'A' .. 'Z' -> true | _ -> false)
  && String.for_all bare_char name

let count_prop (c : counts) (p : prop) =
  let sign s =
    match s with
    | Plus -> c.plus <- c.plus + 1
    | Minus -> c.minus <- c.minus + 1
    | Wild -> c.wild <- c.wild + 1
  in
  let rec term t =
    match t with
    | Atom { name; singular } ->
        c.atoms <- c.atoms + 1;
        if singular then c.singulars <- c.singulars + 1;
        if String.length name > 0 && name.[String.length name - 1] = '\'' then
          c.primed_names <- c.primed_names + 1;
        if not (is_bare_name name) then c.quoted_names <- c.quoted_names + 1
    | Neg t ->
        c.negs <- c.negs + 1;
        term t
    | Compound elements ->
        c.compounds <- c.compounds + 1;
        List.iter signed elements
    | Rel { head; objects } ->
        c.rels <- c.rels + 1;
        term head;
        List.iter signed objects
    | PropTerm (Inner_prop p) ->
        c.propterm_props <- c.propterm_props + 1;
        prop p
    | PropTerm (Inner_term t) ->
        c.propterm_terms <- c.propterm_terms + 1;
        term t
  and signed st =
    sign st.sign;
    if st.level > 0 then c.nonzero_levels <- c.nonzero_levels + 1;
    term st.term
  and prop p =
    signed p.subject;
    signed p.predicate
  in
  prop p

let coverage () =
  let c =
    {
      atoms = 0; negs = 0; compounds = 0; rels = 0;
      propterm_props = 0; propterm_terms = 0;
      plus = 0; minus = 0; wild = 0;
      singulars = 0; nonzero_levels = 0; primed_names = 0; quoted_names = 0;
    }
  in
  let rand = Random.State.make [| 0x7f1; 0x5eed |] in
  let sample = QCheck2.Gen.generate ~rand ~n:1000 Gen.prop_gen in
  List.iter (count_prop c) sample;
  let check label n = if n = 0 then failwith ("coverage: no " ^ label) in
  check "Atom" c.atoms;
  check "Neg" c.negs;
  check "Compound" c.compounds;
  check "Rel" c.rels;
  check "PropTerm (prop inner)" c.propterm_props;
  check "PropTerm (bare-term inner)" c.propterm_terms;
  check "Plus sign" c.plus;
  check "Minus sign" c.minus;
  check "Wild sign" c.wild;
  check "singular atom" c.singulars;
  check "nonzero quantity level" c.nonzero_levels;
  check "proterm (primed name)" c.primed_names;
  check "quote-forcing name" c.quoted_names;
  Printf.printf
    "coverage ok: %d atoms, %d negs, %d compounds, %d rels, %d+%d propterms, \
     signs %d/%d/%d, %d singulars, %d leveled, %d primed, %d quoted\n"
    c.atoms c.negs c.compounds c.rels c.propterm_props c.propterm_terms c.plus
    c.minus c.wild c.singulars c.nonzero_levels c.primed_names c.quoted_names

(* ── Properties: generated values build and compare structurally ────────── *)

let reflexivity =
  QCheck2.Test.make ~count:10_000 ~name:"prop_eq is reflexive on generated props"
    Gen.prop_gen
    (fun p -> prop_eq p p)

let term_reflexivity =
  QCheck2.Test.make ~count:10_000 ~name:"term_eq is reflexive on generated terms"
    Gen.term_gen
    (fun t -> term_eq t t)

let () =
  coverage ();
  exit (QCheck_base_runner.run_tests ~verbose:true [ reflexivity; term_reflexivity ])
