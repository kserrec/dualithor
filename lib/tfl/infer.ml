(* Inference core A (PLAN 1.4), ported from engine/tfl.js: engine-fragment
   validation, canonical form (equality up to Com, Assoc, DN and wild
   quantity), identity keys, node counts, the immediate inferences
   (EN / IN / Contrap / It), and net-sign occurrences (port-spec §§5–8).

   Canonical form is level-less: the JS engine rebuilds every signed term
   with level 0 (ST's default) — quantity levels live only on raw
   propositions and are consumed by the numerical decision (1.8). *)

open Ast

exception Engine_error of string
(* The input parsed but lies outside the inference fragment — distinct from
   Notation.Parse_error. Message texts mirror the JS EngineError exactly. *)

let engine_error msg = raise (Engine_error msg)

(* ── Fixed reference ────────────────────────────────────────────────────── *)

(* A proterm: an atom whose name ends in a prime. Its reference is fixed by an
   antecedent, so it earns the same wild-quantity treatment as a singular —
   the all/some distinction collapses on fixed reference. *)
let is_proterm_name name =
  String.length name > 0 && name.[String.length name - 1] = '\''

let is_fixed_ref = function
  | Atom { name; singular } -> singular || is_proterm_name name
  | _ -> false

(* ── Engine-fragment validation (spec §5) ───────────────────────────────── *)

let rec validate_term (t : term) : unit =
  match t with
  | Atom _ -> ()
  | Neg t -> validate_term t
  | Compound elements ->
      List.iter
        (fun el ->
          if el.sign = Wild then
            engine_error
              "± cannot sign a compound element (it marks quantity, not \
               quality)";
          if el.level <> 0 then
            engine_error
              "a quantity level attaches only to a categorical subject, not a \
               compound element";
          validate_term el.term)
        elements
  | Rel { head; objects } ->
      validate_term head;
      List.iter
        (fun o ->
          if o.level <> 0 then
            engine_error
              "a quantity level attaches only to a categorical subject, not a \
               relational object";
          if o.sign = Wild && not (is_fixed_ref o.term) then
            engine_error "wild quantity (±) requires a singular term or proterm";
          validate_term o.term)
        objects
  | PropTerm (Inner_prop p) -> validate_prop p
  | PropTerm (Inner_term _) -> ()

and validate_prop (p : prop) : unit =
  (* Levels 0–3 mark the intermediate quantifiers (0 some/every, 1 many,
     2 most, 3 few); a level rides only on a particular (+) subject. *)
  if p.predicate.level <> 0 then
    engine_error
      "a quantity level attaches only to the subject, not the predicate";
  if p.subject.level < 0 || p.subject.level > 3 then
    engine_error
      "quantity level must be 0 (some/every), 1 (many), 2 (most) or 3 (few)";
  if p.subject.level > 0 && p.subject.sign <> Plus then
    engine_error
      "a nonzero quantity level marks an intermediate quantifier and needs a \
       particular (+) subject";
  validate_term p.subject.term;
  validate_term p.predicate.term;
  if p.subject.sign = Wild && not (is_fixed_ref p.subject.term) then
    engine_error "wild quantity (±) requires a singular or proterm subject";
  if p.predicate.sign = Wild then
    engine_error
      "± cannot sign a predicate (quality is + or −; write the quantity wild \
       on the subject)"

(* ── Pairing subscripts on relation heads (spec §9) ─────────────────────── *)

(* A trailing run of subscript digits of length exactly [arity] that is a
   permutation of 1..arity splits off as roles; otherwise the run is part of
   the name and roles default to the identity. The base keeps at least one
   character (the JS regex's lazy nonempty prefix). *)
let head_roles (name : string) (arity : int) : string * int list =
  let cps = Notation.decode name in
  let n = Array.length cps in
  let s = ref n in
  while !s > 0 && Notation.is_subscript_digit cps.(!s - 1) do
    decr s
  done;
  let s = max !s 1 in
  let identity = List.init arity (fun i -> i + 1) in
  if arity > 0 && n - s = arity then
    let roles = List.init arity (fun i -> cps.(s + i) - 0x2080) in
    if List.sort compare roles = identity then (
      let b = Buffer.create n in
      for k = 0 to s - 1 do
        Buffer.add_utf_8_uchar b (Uchar.of_int cps.(k))
      done;
      (Buffer.contents b, roles))
    else (name, identity)
  else (name, identity)

let make_head_name (base : string) (roles : int list) : string =
  if List.mapi (fun i _ -> i + 1) roles = roles then base
  else
    let b = Buffer.create (String.length base + 8) in
    Buffer.add_string b base;
    List.iter
      (fun r -> Buffer.add_utf_8_uchar b (Uchar.of_int (0x2080 + r)))
      roles;
    Buffer.contents b

(* ── Canonical form (spec §6) ───────────────────────────────────────────── *)

let st sign term = { sign; term; level = 0 }

let rec canon_term (t : term) : term =
  match t with
  | Atom _ -> t
  | Neg inner -> (
      match canon_term inner with Neg t' -> t' (* DN *) | c -> Neg c)
  | Compound elements -> (
      (* Assoc: a +-signed element that is itself a compound splices in. *)
      let els =
        List.concat_map
          (fun el ->
            match (el.sign, canon_term el.term) with
            | Plus, Compound inner -> inner
            | sign, c -> [ st sign c ])
          elements
      in
      match els with
      | [ { sign = Minus; term; _ } ] -> canon_term (Neg term)
      | [ { term; _ } ] -> term
      | els ->
          Compound
            (List.sort
               (fun a b ->
                 compare
                   (Notation.print_signed_term a)
                   (Notation.print_signed_term b))
               els))
  | Rel { head; objects } ->
      let objects =
        List.map
          (fun o ->
            let c = canon_term o.term in
            st (if is_fixed_ref c then Wild else o.sign) c)
          objects
      in
      let head = canon_term head in
      let head =
        match head with
        | Atom { name; singular } ->
            (* Identity pairing subscripts say nothing — the bare head is the
               canonical spelling. *)
            let base, roles = head_roles name (List.length objects + 1) in
            let name' = make_head_name base roles in
            if name' <> name then Atom { name = name'; singular } else head
        | _ -> head
      in
      Rel { head; objects }
  | PropTerm (Inner_prop p) -> PropTerm (Inner_prop (canon_prop p))
  | PropTerm (Inner_term _) -> t

and canon_prop (p : prop) : prop =
  let s_term = canon_term p.subject.term in
  let q_term = canon_term p.predicate.term in
  let s_sign = if is_fixed_ref s_term then Wild else p.subject.sign in
  let q_sign = p.predicate.sign in
  (* Conversion (Com): I-forms (+,+) and E-forms (−,−) commute; a wild
     fixed-reference subject joins in via whichever reading matches. *)
  let i_like = (s_sign = Plus || s_sign = Wild) && q_sign = Plus in
  let e_like = (s_sign = Minus || s_sign = Wild) && q_sign = Minus in
  if i_like || e_like then
    let base = if i_like then Plus else Minus in
    if Notation.print_term q_term < Notation.print_term s_term then
      {
        subject = st (if is_fixed_ref q_term then Wild else base) q_term;
        predicate = st base s_term;
      }
    else
      {
        subject = st (if is_fixed_ref s_term then Wild else base) s_term;
        predicate = st q_sign q_term;
      }
  else { subject = st s_sign s_term; predicate = st q_sign q_term }

let prop_key p = Notation.print_proposition (canon_prop p)
let term_key t = Notation.print_term (canon_term t)
let prop_eq_up_to a b = prop_key a = prop_key b

(* Size measures for search fuel (spec §6): propNodes counts only the two
   term trees, not the ST wrappers. *)
let rec node_count = function
  | Atom _ -> 1
  | Neg t -> 1 + node_count t
  | Compound els -> 1 + List.fold_left (fun n e -> n + node_count e.term) 0 els
  | Rel { head; objects } ->
      1 + node_count head
      + List.fold_left (fun n o -> n + node_count o.term) 0 objects
  | PropTerm (Inner_prop p) -> 2 + prop_nodes p
  | PropTerm (Inner_term t) -> 2 + node_count t

and prop_nodes p = node_count p.subject.term + node_count p.predicate.term

(* ── EN, IN, Contrap, It (spec §7) ──────────────────────────────────────── *)

let flip_sign = function Plus -> Minus | Minus -> Plus | Wild -> Wild

(* EN — the contradictory: flip quantity and quality (± stays wild). Used for
   counterclaims; not itself an entailment. *)
let contradictory (p : prop) : prop =
  canon_prop
    {
      subject = st (flip_sign p.subject.sign) p.subject.term;
      predicate = st (flip_sign p.predicate.sign) p.predicate.term;
    }

(* IN — obversion: flip the quality and negate the predicate term. *)
let obverse (p : prop) : prop =
  canon_prop
    {
      p with
      predicate = st (flip_sign p.predicate.sign) (Neg p.predicate.term);
    }

(* Contrap — contraposition of A (−S+P → −(−P)+(−S)) and O (+S−P → +(−P)−(−S));
   None otherwise. A wild subject uses its universal reading for A,
   particular for O. *)
let contrapositive (p : prop) : prop option =
  let s_sign = p.subject.sign and q_sign = p.predicate.sign in
  let a_form = (s_sign = Minus || s_sign = Wild) && q_sign = Plus in
  let o_form = (s_sign = Plus || s_sign = Wild) && q_sign = Minus in
  if (not a_form) && not o_form then None
  else
    Some
      (canon_prop
         {
           subject = st (if a_form then Minus else Plus) (Neg p.predicate.term);
           predicate = st (if a_form then Plus else Minus) (Neg p.subject.term);
         })

(* It — the tautology move: −T+T for any term ("every T is T"; safe with no
   existential import, unlike +T+T). *)
let tautology (t : term) : prop =
  canon_prop { subject = st Minus t; predicate = st Plus t }

(* ── Net-sign occurrences (spec §8) ─────────────────────────────────────── *)

(* An occurrence is a term position together with the product of the signs
   governing it; a ± on the occurrence's own slot makes the net sign
   resolvable. Relation heads and the inside of propositional terms are
   opaque — the rules never substitute there. *)

type side = On_subject | On_predicate
type occ_step = Occ_neg | Occ_at of int

type occurrence = {
  occ_term : term;
  side : side;
  steps : occ_step list;
  occ_sign : int; (* net sign: +1 / -1 *)
  own_wild : bool;
}

let occurrences (p : prop) : occurrence list =
  let out = ref [] in
  let rec walk t side steps sign own_wild =
    out := { occ_term = t; side; steps; occ_sign = sign; own_wild } :: !out;
    match t with
    | Neg inner -> walk inner side (steps @ [ Occ_neg ]) (-sign) false
    | Compound els ->
        List.iteri
          (fun i el ->
            walk el.term side (steps @ [ Occ_at i ])
              (if el.sign = Minus then -sign else sign)
              false)
          els
    | Rel { objects; _ } ->
        List.iteri
          (fun i o ->
            walk o.term side (steps @ [ Occ_at i ])
              (if o.sign = Minus then -sign else sign)
              (o.sign = Wild))
          objects
    | Atom _ | PropTerm _ -> ()
  in
  walk p.subject.term On_subject []
    (if p.subject.sign = Minus then -1 else 1)
    (p.subject.sign = Wild);
  walk p.predicate.term On_predicate []
    (if p.predicate.sign = Minus then -1 else 1)
    false;
  List.rev !out

let can_be_plus occ = occ.own_wild || occ.occ_sign = 1
