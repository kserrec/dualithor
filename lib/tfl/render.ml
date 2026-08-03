(* NL rendering (PLAN 1.9), ported from engine/tfl.js: deterministic English
   readings of terms and propositions, and proof explanation (port-spec §14).
   Lowercasing is ASCII-only per the §16.4 port-language decision.

   **This module is authoritative; the JS reference is not** (Kyle, 2026-08-02).
   The frozen reference stays authoritative on verdicts forever, but over English
   it has none: it is one earlier draft of an English generator and several of
   its readings are wrong. Changes here are verdict-safe by construction — an
   English reading decides nothing — but the strings are still a contract, since
   the back-check (4.4) and the Phase 9 audit surface are built on them, so every
   deviation is deliberate, commented at its branch, exempted by name in the
   rendering differential, and pinned in test/test_readings.ml where a human
   approved it. Three deviations exist so far, all from PLAN 5.0: the compound
   joiner, the quantity word on a relational predicate, and the comma seam. *)

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

(* Does this term's reading end in a relational complex ("head some horse")?
   Such a reading trails off with no closing word, so when it sits in subject
   position in front of a relational predicate there is nothing at all between
   the two — see the comma in read_prop below. Compounds are checked on their
   last element, since that is what ends the string. *)
let rec ends_in_relation (t : term) : bool =
  match t with
  | Rel _ -> true
  | Neg t -> ends_in_relation t
  | Compound elements -> (
      match List.rev elements with
      | e :: _ -> ends_in_relation e.term
      | [] -> false)
  | Atom _ -> false
  (* an inner proposition closes with its quotation mark *)
  | PropTerm (Inner_prop _) -> false
  | PropTerm (Inner_term t) -> ends_in_relation t

let rec read_term (t : term) : string =
  match t with
  | Atom { name; singular } ->
      let nm = base_name name in
      if singular then nm (* proper name: keep case *)
      else if Infer.is_proterm_name name then "that " ^ lowercase nm
      else lowercase nm (* general term: common noun *)
  | Neg t -> "non-" ^ read_term t
  | Compound elements ->
      (* A compound is one term, not a list of them: +Registered+Voter is a
         registered voter, and English writes an intersection by juxtaposition.
         "and" reads as two separate things ("Alice and Bob"), which is the
         wrong relation and the d03 back-check false positive (PLAN 5.0).
         Deviation from the frozen JS renderer, which joins with " and ". *)
      String.concat " "
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
  if Infer.is_fixed_ref s_term then
    (* Singular / proterm subject: a definite individual. A plain-noun
       predicate takes an article; a relation, negation or compound not. *)
    let who = read_term s_term in
    if rel_pred then
      who ^ " " ^ (if q_plus then "" else "does not ") ^ read_term pred
    else
      let plain =
        match pred with Atom { singular; _ } -> not singular | _ -> false
      in
      let reading = read_term pred in
      let art =
        if not plain then ""
        else
          match if reading = "" then None else Some reading.[0] with
          | Some ('a' | 'e' | 'i' | 'o' | 'u' | 'A' | 'E' | 'I' | 'O' | 'U') ->
              "an "
          | _ -> "a "
      in
      who ^ " " ^ (if q_plus then "is " else "is not ") ^ art ^ reading
  else
    let s = read_term s_term in
    (* A relational subject reading trails off without a closing word ("head
       some horse"), and `rel_tail` puts no word in front of an affirmative
       relational predicate — so the two run together and a reader cannot see
       where the subject ends: "every head some horse head some animal". A
       comma marks that seam. It is chosen over inserting "is" because it needs
       no knowledge of English words: "is" reads correctly when the relation is
       noun-like ("head") and wrongly when it is verb-like ("every lov some
       woman is lov some girl"), and the renderer cannot tell the two apart.
       [neg] is the polarity `rel_tail` is about to be called with; when it is
       negative the tail already opens with "does not", which marks the seam by
       itself. Deviation from the frozen JS renderer (PLAN 5.0). *)
    let sep neg =
      if ends_in_relation s_term && rel_pred && not neg then ", " else " "
    in
    if p.subject.sign = Minus then
      if q_plus then "every " ^ s ^ sep false ^ rel_tail pred false
      else if rel_pred then "no " ^ s ^ sep false ^ read_term pred
      else "no " ^ s ^ " is " ^ read_term pred
    else
      (* particular subject (+ or a stray ±). A nonzero level names an
         intermediate quantifier; "few" is the predominant complement, so it
         inverts the predicate polarity in English. *)
      let lvl = p.subject.level in
      (* The quantity word is the whole content of a levelled proposition, and
         it used to be gated on `not rel_pred` — so +Officer^1+(Sign+Contract),
         ^2 and ^3 all read "some officer …", identical to level 0. A reader
         auditing the formula was shown "some" where it says "many" (i06), and
         the back-check was blind there. `rel_tail` already renders a relational
         predicate in both polarities, so the branch needed no other change.
         Deviation from the frozen JS renderer (PLAN 5.0). *)
      if lvl > 0 then
        let word =
          if lvl = 1 then "many" else if lvl = 2 then "most" else "few"
        in
        let affirmative = if lvl = 3 then not q_plus else q_plus in
        word ^ " " ^ s ^ sep (not affirmative) ^ rel_tail pred (not affirmative)
      else if q_plus then "some " ^ s ^ sep false ^ rel_tail pred false
      else "some " ^ s ^ sep true ^ rel_tail pred true

(* ── Explanation of a derivation ────────────────────────────────────────── *)

(* "Because <premises>, <conclusion>." A refutation ends "— which is
   impossible." None for missing/failed proofs. *)
let explain_proof (proof : Derive.proof) : string option =
  (* A found proof always has lines; a record deserialized from JSON (PLAN 3.1)
     might not, and reading its last line would raise. The frozen reference
     TypeErrors here — same accepted call as the side_coeff edge (LOG
     2026-07-30): unreachable input gets the saner answer, not a crash. *)
  if (not proof.found) || proof.lines = [] then None
  else
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
    if closing then
      (* the two clashing lines make the impossibility vivid *)
      let clash =
        List.filter_map
          (fun n -> List.find_opt (fun (l : Derive.line) -> l.n = n) lines)
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
       ^ " \u{2014} which is impossible.")
    else
      match last.l_prop with
      | Some p -> Some ("Because " ^ because ^ ", " ^ read_prop p ^ ".")
      (* unreachable: only the synthetic ⊥ line lacks a prop, and the closing
         branch above already handled it *)
      | None -> Some ("Because " ^ because ^ ", .")
