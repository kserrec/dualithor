(* The categorical decision (PLAN 1.5) and the TFL⁺ numerical decision
   (PLAN 1.8), ported from engine/tfl.js: the P/Z inconsistency closure for
   the atomic-categorical fragment (complete there — fuzz-verified in the
   reference against its finite-model oracle), the classic cancellation
   display, numericalDecision with the term-matched condition (iii), and the
   argument checker (port-spec §§11–12). *)

open Ast

(* ── Literals ───────────────────────────────────────────────────────────── *)

type lit = { l_name : string; l_singular : bool; pol : bool }

(* Reduce a term to its literal core: an atom under negations, polarity from
   the negation parity; None outside the atomic fragment. *)
let rec core_lit ?(negations = 0) (t : term) : lit option =
  match t with
  | Neg inner -> core_lit ~negations:(negations + 1) inner
  | Atom { name; singular } ->
      Some { l_name = name; l_singular = singular; pol = negations mod 2 = 0 }
  | _ -> None

let atom_key l = (l.l_name, l.l_singular)
let neg_lit l = { l with pol = not l.pol }

(* Certificates expose literals as canonical notation, but inference identity
   stays structural. Concatenating [name ^ "*"] made the legal general name
   ["A*"] indistinguishable from the singular [A*]. *)
let lit_key l =
  (if l.pol then "+" else "-")
  ^ Notation.print_term (Atom { name = l.l_name; singular = l.l_singular })

let is_atomic_prop (p : prop) =
  core_lit (Infer.canon_term p.subject.term) <> None
  && core_lit (Infer.canon_term p.predicate.term) <> None

let is_atomic_categorical props = List.for_all is_atomic_prop props

(* Term-keyed signed counters: both decision procedures accumulate occurrence
   counts and then ask whether everything cancelled. *)
let add_count counts key delta =
  Hashtbl.replace counts key
    ((match Hashtbl.find_opt counts key with Some v -> v | None -> 0) + delta)

let all_zero counts = Hashtbl.fold (fun _ v acc -> acc && v = 0) counts true

(* ── The P/Z cancellation display ───────────────────────────────────────── *)

type cancellation = { particular : prop; universals : (prop * int) list }

(* Flatten a proposition's two sides through negations with sign
   multiplication: each core term with its algebraic sign. *)
let z_occurrences (p : prop) : (string * int) list =
  let out = ref [] in
  let rec flat t sign =
    match t with
    | Neg inner -> flat inner (-sign)
    | t -> out := (Notation.print_term t, sign) :: !out
  in
  flat p.subject.term (if p.subject.sign = Minus then -1 else 1);
  flat p.predicate.term (if p.predicate.sign = Minus then -1 else 1);
  List.rev !out

(* Best-effort certificate decoration: one particular plus re-used universals
   (each 0–3 times) summing to zero per term key. Wild subjects try both
   readings, + first; over 256 combinations, fall back to the all-+ reading.
   The closure verdict stands whether or not a cancellation exists. *)
exception Budget_exhausted

(* PLAN 1.14(d) — a node budget on the re-use search, the one deliberate
   behavioural deviation from the frozen JS reference (uncapped there, where it
   is dev-only and never exposed). The DFS explores 4^u re-use combinations;
   the 2026-07-30 audit measured exact ×4 growth per universal on a *valid*
   14-line input — 26ms at 7, 105ms at 9, 1.9s at 11, ~days at 20. The closure
   decides the verdict before this runs and the cancellation only decorates the
   certificate, so giving up and reporting none is verdict-safe by
   construction. The budget is shared across the whole call (every wild reading
   and every particular), and leaves the search complete through 9 re-usable
   universals. *)
let cancellation_node_budget = 500_000

let find_cancellation (canon_props : prop list) : cancellation option =
  let budget = ref cancellation_node_budget in
  let try_resolved (resolved : prop list) : cancellation option =
    let particulars = List.filter (fun p -> p.subject.sign = Plus) resolved in
    let universals = List.filter (fun p -> p.subject.sign = Minus) resolved in
    let u_occs = Array.of_list (List.map z_occurrences universals) in
    let n_u = Array.length u_occs in
    let rec try_particular = function
      | [] -> None
      | particular :: rest -> (
          let total : (string, int) Hashtbl.t = Hashtbl.create 16 in
          let bump occs k =
            List.iter (fun (key, sign) -> add_count total key (sign * k)) occs
          in
          bump (z_occurrences particular) 1;
          let used = Array.make n_u 0 in
          let rec dfs i =
            decr budget;
            if !budget <= 0 then raise Budget_exhausted;
            if i = n_u then all_zero total
            else
              let found = ref false in
              (try
                 for k = 0 to 3 do
                   if k > 0 then bump u_occs.(i) 1;
                   used.(i) <- k;
                   if dfs (i + 1) then (
                     found := true;
                     raise Exit)
                 done
               with Exit -> ());
              if !found then true
              else (
                bump u_occs.(i) (-3);
                used.(i) <- 0;
                false)
          in
          match dfs 0 with
          | true ->
              Some
                {
                  particular;
                  universals =
                    List.mapi (fun i u -> (u, used.(i))) universals
                    |> List.filter (fun (_, times) -> times > 0);
                }
          | false -> try_particular rest)
    in
    try_particular particulars
  in
  let readings =
    List.map
      (fun p ->
        if p.subject.sign = Wild then
          [
            { p with subject = Infer.st Plus p.subject.term };
            { p with subject = Infer.st Minus p.subject.term };
          ]
        else [ p ])
      canon_props
  in
  let combos = List.fold_left (fun n r -> n * List.length r) 1 readings in
  try
    if combos > 256 then try_resolved (List.map List.hd readings)
    else
      let rec walk rs acc =
        match rs with
        | [] -> try_resolved (List.rev acc)
        | r :: rest ->
            List.fold_left
              (fun found reading ->
                match found with
                | Some _ -> found
                | None -> walk rest (reading :: acc))
              None r
      in
      walk readings []
  with Budget_exhausted -> None

(* ── The inconsistency closure ──────────────────────────────────────────── *)

type certificate = {
  point : string list;
  clash : (string * string) option;
  cancellation : cancellation option;
}

(* An individual with known literals; insertion order is preserved because
   the certificate reports the point as the JS Set would iterate it. *)
type pt = { mutable lits : lit list }

let pt_mem pt k = List.mem k pt.lits
let pt_add pt k = if not (pt_mem pt k) then pt.lits <- pt.lits @ [ k ]

(* Is [units] satisfiable under [implications]? Unit propagation plus genuine
   case splits — completeness needs the splits: closure alone misses forced
   literals like B in {B→¬B, ¬B→¬A, ¬A→B}. Boolean result only, so propagation
   order is free. *)
let rec sat (implications : (lit * lit) list) (units : lit list) : bool =
  let assign : (string * bool, bool) Hashtbl.t = Hashtbl.create 16 in
  let stack = ref units in
  let ok = ref true in
  while !ok && !stack <> [] do
    match !stack with
    | [] -> ()
    | k :: rest -> (
        stack := rest;
        let v = atom_key k and pol = k.pol in
        match Hashtbl.find_opt assign v with
        | Some p -> if p <> pol then ok := false
        | None ->
            Hashtbl.add assign v pol;
            List.iter
              (fun (from_, to_) ->
                if from_ = k then stack := to_ :: !stack;
                if to_ = neg_lit k then stack := neg_lit from_ :: !stack)
              implications)
  done;
  if not !ok then false
  else
    match
      List.find_opt
        (fun (from_, _) -> not (Hashtbl.mem assign (atom_key from_)))
        implications
    with
    | None -> true
    | Some (from_, _) ->
        let units' =
          Hashtbl.fold
            (fun (name, singular) pol acc ->
              { l_name = name; l_singular = singular; pol } :: acc)
            assign []
        in
        sat implications (from_ :: units')
        || sat implications (neg_lit from_ :: units')

let check_inconsistent (props : prop list) : certificate option =
  List.iter Infer.validate_prop props;
  if not (is_atomic_categorical props) then
    Infer.engine_error
      "the inconsistency check requires an atomic-categorical set";
  let canon = List.map Infer.canon_prop props in

  let implications =
    ref []
    (* (from, to) over literal keys, in push order *)
  in
  let points =
    ref []
    (* in push order *)
  in
  let singulars =
    { lits = [] }
    (* insertion-ordered set of literal keys *)
  in
  List.iter
    (fun p ->
      let s =
        match core_lit (Infer.canon_term p.subject.term) with
        | Some l -> l
        | None -> assert false (* atomic by the check above *)
      in
      let q =
        match core_lit (Infer.canon_term p.predicate.term) with
        | Some l ->
            if p.predicate.sign = Minus then { l with pol = not l.pol } else l
        | None -> assert false
      in
      let s_k = s and q_k = q in
      let wild = p.subject.sign = Wild in
      if p.subject.sign = Minus || wild then
        implications :=
          !implications @ [ (s_k, q_k); (neg_lit q_k, neg_lit s_k) ];
      if p.subject.sign = Plus || wild then (
        let point = { lits = [] } in
        pt_add point s_k;
        pt_add point q_k;
        points := !points @ [ point ]);
      List.iter
        (fun (occ : Infer.occurrence) ->
          match occ.occ_term with
          | Atom { name; singular } when Infer.is_fixed_ref occ.occ_term ->
              pt_add singulars
                { l_name = name; l_singular = singular; pol = true }
          | _ -> ())
        (Infer.occurrences p))
    canon;
  List.iter
    (fun key -> points := !points @ [ { lits = [ key ] } ])
    singulars.lits;
  let implications = !implications in

  (* Fixpoint: a point forced (2-SAT backbone) to carry a positive
     fixed-reference literal gains it explicitly; points sharing one merge
     (that named individual is one individual). *)
  let is_fixed_key k =
    k.pol && (k.l_singular || Infer.is_proterm_name k.l_name)
  in
  let merge_pass () =
    let arr = Array.of_list !points in
    let n = Array.length arr in
    let merged = ref false in
    (try
       for i = 0 to n - 1 do
         for j = i + 1 to n - 1 do
           if
             List.exists
               (fun k -> is_fixed_key k && pt_mem arr.(j) k)
               arr.(i).lits
           then (
             List.iter (pt_add arr.(i)) arr.(j).lits;
             points := List.filteri (fun idx _ -> idx <> j) !points;
             merged := true;
             raise Exit)
         done
       done
     with Exit -> ());
    !merged
  in
  let changed = ref true in
  while !changed do
    changed := false;
    List.iter
      (fun point ->
        List.iter
          (fun l ->
            if
              (not (pt_mem point l))
              && not (sat implications (point.lits @ [ neg_lit l ]))
            then (
              pt_add point l;
              changed := true))
          singulars.lits)
      !points;
    if merge_pass () then changed := true
  done;

  let rec first_unsat = function
    | [] -> None
    | point :: rest ->
        if not (sat implications point.lits) then Some point
        else first_unsat rest
  in
  match first_unsat !points with
  | None -> None
  | Some point ->
      let clash =
        List.find_opt (fun k -> pt_mem point (neg_lit k)) point.lits
        |> Option.map (fun k -> (lit_key k, lit_key (neg_lit k)))
      in
      Some
        {
          point = List.map lit_key point.lits;
          clash;
          cancellation = find_cancellation canon;
        }

(* ── The numerical decision (TFL⁺, PLAN 1.8) ────────────────────────────── *)

let rec term_has_level = function
  | Atom _ -> false
  | Neg t -> term_has_level t
  | Compound elements -> List.exists signed_term_has_level elements
  | Rel { head; objects } ->
      term_has_level head || List.exists signed_term_has_level objects
  | PropTerm (Inner_prop p) -> has_level p
  | PropTerm (Inner_term t) -> term_has_level t

and signed_term_has_level (st : signed_term) =
  st.level <> 0 || term_has_level st.term

and has_level (p : prop) =
  signed_term_has_level p.subject || signed_term_has_level p.predicate

type numerical_decision = {
  n_valid : bool;
  sum : bool; (* condition (i): premises sum algebraically to the conclusion *)
  n_particular : bool; (* condition (ii): particular counts match *)
  level_ok : bool; (* condition (iii): term-matched level licensing *)
  carried_level : int;
  conclusion_level : int;
  particular_premises : int;
  particular_conclusions : int;
}

(* A categorical side's algebraic coefficient: the occurrence sign times the
   term's own negation parity (so +(−P) counts as −P). Atomic by contract. *)
let side_coeff (st : signed_term) : (string * bool) * int =
  match core_lit st.term with
  | Some lit ->
      let occ = if st.sign = Minus then -1 else 1 in
      (atom_key lit, occ * if lit.pol then 1 else -1)
  | None -> Infer.engine_error "numerical sides must be atomic"

(* Castro-Manzano et al. 2018 §5, with the term-matched condition (iii): a
   conclusion's nonzero level must be licensed by a premise whose own subject
   IS the conclusion's subject term — an intermediate quantity is carried by
   the term it quantifies, so a level riding the middle term licenses
   nothing (port-spec §12; verified against the paper's Tables 9–13). *)
let numerical_decision (premises : prop list) (conclusion : prop) :
    numerical_decision =
  let all = premises @ [ conclusion ] in
  List.iter Infer.validate_prop all;
  if not (is_atomic_categorical all) then
    Infer.engine_error
      "quantity levels are supported only in categorical (atomic) syllogisms";
  List.iter
    (fun p ->
      if p.subject.sign = Wild then
        Infer.engine_error
          "a wild ± subject has no quantity-level reading; use + (particular) \
           or − (universal)")
    all;
  (* (i) the algebraic sum of the premises equals the conclusion. *)
  let coeff : (string * bool, int) Hashtbl.t = Hashtbl.create 16 in
  let bump st factor =
    let key, c = side_coeff st in
    add_count coeff key (factor * c)
  in
  List.iter
    (fun p ->
      bump p.subject 1;
      bump p.predicate 1)
    premises;
  bump conclusion.subject (-1);
  bump conclusion.predicate (-1);
  let sum = all_zero coeff in
  (* (ii) the particular counts match. *)
  let particular_premises =
    List.length (List.filter (fun p -> p.subject.sign = Plus) premises)
  in
  let particular_conclusions =
    if conclusion.subject.sign = Plus then 1 else 0
  in
  let n_particular = particular_premises = particular_conclusions in
  (* (iii) the term-matched level condition. *)
  let c_sub_key = Infer.term_key conclusion.subject.term in
  let carried_level =
    List.fold_left
      (fun acc p ->
        if p.subject.sign = Plus && Infer.term_key p.subject.term = c_sub_key
        then max acc p.subject.level
        else acc)
      0 premises
  in
  let conclusion_level = conclusion.subject.level in
  let level_ok = conclusion_level <= carried_level in
  {
    n_valid = sum && n_particular && level_ok;
    sum;
    n_particular;
    level_ok;
    carried_level;
    conclusion_level;
    particular_premises;
    particular_conclusions;
  }

(* ── The argument checker ───────────────────────────────────────────────── *)

type verdict = Valid | Invalid | Contradicted | Unknown
type meth = PZ | Derivation | Indirect | Numerical

type result = {
  verdict : verdict;
  meth : meth;
  certificate : certificate option;
  proof : Derive.proof option;
  decision : numerical_decision option;
}

let check_argument ?max_lines ?(max_work = Derive.default_max_work) ?slack
    (premises : prop list) (conclusion : prop) : result =
  List.iter Infer.validate_prop premises;
  Infer.validate_prop conclusion;
  if List.exists has_level (premises @ [ conclusion ]) then
    (* Numerical fragment: any nonzero level routes to the decision method. *)
    let d = numerical_decision premises conclusion in
    (* PLAN 5.3, Kyle's decision 2026-08-02: a failed numerical decision is
       `Unknown`, never `Invalid`.

       The three conditions are a *sound but incomplete* rule set, and
       Pratt-Hartmann (2009, 2013) proves no finite syllogistic rule set can be
       complete for the numerically definite syllogistic — so inferences this
       cannot derive necessarily exist. Asserting `Invalid` for them is a wrong
       verdict, not a missing one. Witness: `+S^2+P ; +S^2+Q ⊢ +P+Q` — two
       strict majorities of one set must intersect, so it is valid, and
       condition (ii) rejects it for having two particular premises against one
       particular conclusion.

       This is the same boundary the rest of the engine already respects, and
       `Unknown ≠ Invalid` is documented in the 3.1 interface for exactly this
       reason. The cost is real and deliberate: **this layer can now certify
       validity and can never assert invalidity**, so genuinely invalid
       leveled arguments (most does not convert; many does not license most)
       come back `Unknown` too. Recovering that needs an actual decision
       procedure — `Sat(Syl+Num)` is NP-complete, so integer reasoning would
       give real verdicts — rather than more rules, which provably cannot
       suffice. Documented deviation from the frozen JS reference, normalized
       in the differential harness. *)
    {
      verdict = (if d.n_valid then Valid else Unknown);
      meth = Numerical;
      certificate = None;
      proof = None;
      decision = Some d;
    }
  else
    let counterclaim = premises @ [ Infer.contradictory conclusion ] in
    if is_atomic_categorical counterclaim then
      match check_inconsistent counterclaim with
      | Some certificate ->
          {
            verdict = Valid;
            meth = PZ;
            certificate = Some certificate;
            proof = None;
            decision = None;
          }
      | None ->
          {
            verdict = Invalid;
            meth = PZ;
            certificate = None;
            proof = None;
            decision = None;
          }
    else
      let work_budget = Derive.create_work_budget ~limit:max_work () in
      let proof =
        Derive.derive ?max_lines ~work_budget ?slack premises conclusion
      in
      if proof.found then
        {
          verdict = Valid;
          meth = Derivation;
          certificate = None;
          proof = Some proof;
          decision = None;
        }
      else
        let indirect =
          Derive.indirect_proof ?max_lines ~work_budget ?slack premises
            conclusion
        in
        if indirect.found then
          {
            verdict = Valid;
            meth = Indirect;
            certificate = None;
            proof = Some indirect;
            decision = None;
          }
        else
          let refutation =
            Derive.derive ?max_lines ~work_budget ?slack premises
              (Infer.contradictory conclusion)
          in
          if refutation.found then
            {
              verdict = Contradicted;
              meth = Derivation;
              certificate = None;
              proof = Some refutation;
              decision = None;
            }
          else
            let indirect_ref =
              Derive.indirect_proof ?max_lines ~work_budget ?slack premises
                (Infer.contradictory conclusion)
            in
            if indirect_ref.found then
              {
                verdict = Contradicted;
                meth = Indirect;
                certificate = None;
                proof = Some indirect_ref;
                decision = None;
              }
            else
              {
                verdict = Unknown;
                meth = Derivation;
                certificate = None;
                proof = None;
                decision = None;
              }
