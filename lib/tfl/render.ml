(* NL rendering (PLAN 1.9), ported from engine/tfl.js: deterministic English
   readings of terms and propositions, and proof explanation (port-spec §14).
   The strings are a byte-exact contract — the pipeline's back-translation
   check depends on them — so every branch mirrors the JS renderer exactly.
   Lowercasing is ASCII-only per the §16.4 port-language decision. *)

open Ast

let lowercase = String.lowercase_ascii

(* Strip trailing proterm primes for display. *)
let base_name (name : string) : string =
  let n = String.length name in
  let e = ref n in
  while !e > 0 && name.[!e - 1] = '\'' do
    decr e
  done;
  String.sub name 0 !e

let rec read_term (t : term) : string =
  match t with
  | Atom { name; singular } ->
      let nm = base_name name in
      if singular then nm (* proper name: keep case *)
      else if Infer.is_proterm_name name then "that " ^ lowercase nm
      else lowercase nm (* general term: common noun *)
  | Neg t -> "non-" ^ read_term t
  | Compound elements ->
      String.concat " and "
        (List.map
           (fun e ->
             if e.sign = Minus then "non-" ^ read_term e.term
             else read_term e.term)
           elements)
  | Rel { head; objects } ->
      let objs =
        List.map
          (fun o ->
            let q =
              match o.sign with
              | Minus -> "every "
              | Wild -> ""
              | Plus -> "some "
            in
            q ^ read_term o.term)
          objects
      in
      String.trim (lowercase (read_term head) ^ " " ^ String.concat " " objs)
  | PropTerm (Inner_prop p) -> "\u{201C}" ^ read_prop p ^ "\u{201D}"
  | PropTerm (Inner_term t) -> read_term t

(* Predicate tail for general-subject readings ("… loves some girl" /
   "… is a mortal" / "… is not a mortal"). *)
and rel_tail (pred : term) (neg : bool) : string =
  match pred with
  | Rel _ -> (if neg then "does not " else "") ^ read_term pred
  | _ -> (if neg then "is not" else "is") ^ " " ^ read_term pred

(* Read a proposition as an English sentence. First re-orient so a fixed
   individual is the subject — canonical form converts ±Socrates*+Man to
   +Man+Socrates*, but "Socrates is a man" is the reading. *)
and read_prop (raw : prop) : string =
  let p =
    match
      List.find_opt
        (fun o -> Infer.is_fixed_ref o.subject.term)
        (Relational.orientations raw)
    with
    | Some o -> o
    | None -> raw
  in
  let s_term = p.subject.term in
  let q_plus = p.predicate.sign = Plus in
  let pred = p.predicate.term in
  let rel_pred = match pred with Rel _ -> true | _ -> false in
  if Infer.is_fixed_ref s_term then (
    (* Singular / proterm subject: a definite individual. A plain-noun
       predicate takes an article; a relation, negation or compound not. *)
    let who = read_term s_term in
    if rel_pred then who ^ " " ^ (if q_plus then "" else "does not ") ^ read_term pred
    else (
      let plain =
        match pred with Atom { singular; _ } -> not singular | _ -> false
      in
      let reading = read_term pred in
      let art =
        if not plain then ""
        else (
          match if reading = "" then None else Some reading.[0] with
          | Some ('a' | 'e' | 'i' | 'o' | 'u' | 'A' | 'E' | 'I' | 'O' | 'U') ->
              "an "
          | _ -> "a ")
      in
      who ^ " " ^ (if q_plus then "is " else "is not ") ^ art ^ reading))
  else (
    let s = read_term s_term in
    if p.subject.sign = Minus then
      if q_plus then "every " ^ s ^ " " ^ rel_tail pred false
      else if rel_pred then "no " ^ s ^ " " ^ read_term pred
      else "no " ^ s ^ " is " ^ read_term pred
    else (
      (* particular subject (+ or a stray ±). A nonzero level names an
         intermediate quantifier; "few" is the predominant complement, so it
         inverts the predicate polarity in English. *)
      let lvl = p.subject.level in
      if lvl > 0 && not rel_pred then (
        let word = if lvl = 1 then "many" else if lvl = 2 then "most" else "few" in
        let affirmative = if lvl = 3 then not q_plus else q_plus in
        word ^ " " ^ s ^ " " ^ rel_tail pred (not affirmative))
      else if q_plus then "some " ^ s ^ " " ^ rel_tail pred false
      else "some " ^ s ^ " " ^ rel_tail pred true))

(* ── Explanation of a derivation ────────────────────────────────────────── *)

(* "Because <premises>, <conclusion>." A refutation ends "— which is
   impossible." None for missing/failed proofs. *)
let explain_proof (proof : Derive.proof) : string option =
  (* A found proof always has lines; a record deserialized from JSON (PLAN 3.1)
     might not, and reading its last line would raise. The frozen reference
     TypeErrors here — same accepted call as the side_coeff edge (LOG
     2026-07-30): unreachable input gets the saner answer, not a crash. *)
  if (not proof.found) || proof.lines = [] then None
  else (
    let lines = proof.lines in
    let is_given r = r = "premise" || r = "fact" || r = "counterclaim" in
    let givens =
      List.filter
        (fun (l : Derive.line) -> is_given l.rule && l.l_prop <> None)
        lines
    in
    let last = List.nth lines (List.length lines - 1) in
    let closing = last.text = "\u{22A5}" in
    let because =
      String.concat ", and "
        (List.map
           (fun (l : Derive.line) ->
             match l.l_prop with Some p -> read_prop p | None -> "")
           givens)
    in
    if closing then (
      (* the two clashing lines make the impossibility vivid *)
      let clash =
        List.filter_map
          (fun n ->
            List.find_opt (fun (l : Derive.line) -> l.n = n) lines)
          last.parents
      in
      let pair =
        String.concat ", yet "
          (List.filter_map
             (fun (l : Derive.line) -> Option.map read_prop l.l_prop)
             clash)
      in
      Some
        ("Because " ^ because ^ ", it would follow that " ^ pair
       ^ " \u{2014} which is impossible."))
    else
      match last.l_prop with
      | Some p -> Some ("Because " ^ because ^ ", " ^ read_prop p ^ ".")
      (* unreachable: only the synthetic ⊥ line lacks a prop, and the closing
         branch above already handled it *)
      | None -> Some ("Because " ^ because ^ ", ."))
