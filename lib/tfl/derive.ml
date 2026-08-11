(* Proof search (PLAN 1.5), ported from engine/tfl.js: the fuel-bounded
   forward-chaining core (saturate), tautology seeding, direct derivation,
   and ancestry extraction (port-spec §10). Line order is fully deterministic
   and must mirror the JS engine exactly — the differential harness compares
   whole proofs. *)

open Ast

(* A line on the saturation board. *)
type sat_line = {
  s_prop : prop;
  key : string;
  rule : string;
  parents : int list;
}

(* A line of an extracted proof; [l_prop] is None only for the synthetic ⊥
   closing line of a refutation (PLAN 1.6). *)
type line = {
  n : int; (* 1-based *)
  l_prop : prop option;
  text : string;
  rule : string;
  parents : int list; (* renumbered, 1-based *)
}

type proof = { found : bool; lines : line list }

(* A deterministic estimate of inference work, measured in term-node visits.
   The line bound caps retained results, but it does not cap the work needed to
   construct and reject candidates between those lines. One shared budget can
   span the direct, indirect, and contradictory searches for one argument. *)
type work_budget = { limit : int; mutable remaining : int }

exception Work_limit_exceeded of int

let default_max_work = 8_000_000

(* [prop_nodes] is the retained-tree size. Candidate construction costs more
   for a wide compound: Simp copies the remaining conjuncts once per dropped
   element, so a width-[n] compound performs quadratic term-node work. Charge
   that shape here while ordinary atomic and relational terms retain their
   linear weight. *)
let rec term_work = function
  | Atom _ -> 1
  | Neg term -> 1 + term_work term
  | Compound elements ->
      let width = List.length elements in
      1 + (width * width)
      + List.fold_left
          (fun total element -> total + term_work element.term)
          0 elements
  | Rel { head; objects } ->
      1 + term_work head
      + List.fold_left
          (fun total object_ -> total + term_work object_.term)
          0 objects
  | PropTerm (Inner_prop proposition) -> 2 + prop_work proposition
  | PropTerm (Inner_term term) -> 2 + term_work term

and prop_work proposition =
  term_work proposition.subject.term + term_work proposition.predicate.term

let create_work_budget ?(limit = default_max_work) () =
  if limit < 1 then invalid_arg "inference work limit must be positive";
  { limit; remaining = limit }

let work_limit_message limit =
  Printf.sprintf
    "Inference search exceeded the %d-term-node work limit" limit

let consume_work budget amount =
  let amount = max 1 amount in
  if amount > budget.remaining then (
    budget.remaining <- 0;
    raise (Work_limit_exceeded budget.limit))
  else budget.remaining <- budget.remaining - amount

(* ── saturate ───────────────────────────────────────────────────────────── *)

(* Shared forward-chaining core. [setup] seeds the board through the push
   function it is handed (push returns the line's index — an existing line's
   index when the key is already known, None when over the size cap);
   [on_new_line] inspects each genuinely new line (setup lines included) and
   returns a non-None hit to stop. Everything pushed must already be
   canonical; the dedup key is the printed proposition.

   Rules applied: IN, Contrap, Simp, Pass — guarded passives — (unary);
   DON both directions, Add (binary). [rules], when given, restricts to
   those rule names. *)
let saturate ?(max_lines = 400) ?(max_work = default_max_work) ?work_budget
    ?rules ~size_cap
    (setup : (prop -> string -> int list -> int option) -> unit)
    (on_new_line : int -> sat_line -> (string -> int option) -> 'hit option) :
    sat_line array * 'hit option =
  let allow r = match rules with None -> true | Some rs -> List.mem r rs in
  let work =
    match work_budget with
    | Some budget -> budget
    | None -> create_work_budget ~limit:max_work ()
  in
  let lines = ref (Array.make 64 None) in
  let count = ref 0 in
  let get i = match !lines.(i) with Some l -> l | None -> assert false in
  let seen : (string, int) Hashtbl.t = Hashtbl.create 64 in
  let hit = ref None in
  let push prop rule parents =
    consume_work work (prop_work prop);
    let key = Notation.print_proposition prop in
    match Hashtbl.find_opt seen key with
    | Some idx -> Some idx
    | None ->
        if Infer.prop_nodes prop > size_cap then None
        else (
          if !count = Array.length !lines then (
            let bigger = Array.make (2 * !count) None in
            Array.blit !lines 0 bigger 0 !count;
            lines := bigger);
          let idx = !count in
          let l = { s_prop = prop; key; rule; parents } in
          !lines.(idx) <- Some l;
          Hashtbl.add seen key idx;
          incr count;
          if !hit = None then hit := on_new_line idx l (Hashtbl.find_opt seen);
          Some idx)
  in
  setup push;
  let i = ref 0 in
  while !hit = None && !i < !count && !count < max_lines do
    let li = get !i in
    let li_work = prop_work li.s_prop in
    let unary =
      (if allow "IN" then (
         consume_work work li_work;
         [ (Infer.obverse li.s_prop, "IN") ])
       else [])
      @ (if allow "Contrap" then
           let () = consume_work work li_work in
           match Infer.contrapositive li.s_prop with
           | Some q -> [ (q, "Contrap") ]
           | None -> []
         else [])
      @ (if allow "Simp" then
           let () = consume_work work li_work in
           List.map (fun p -> (p, "Simp")) (Rules.apply_simp li.s_prop)
         else [])
      @
      if allow "Pass" then
        let () = consume_work work li_work in
        List.filter_map
          (fun (r : Relational.passive) ->
            if r.equivalent then Some (Infer.canon_prop r.p_prop, "Pass")
            else None)
          (Relational.passives li.s_prop)
      else []
    in
    List.iter
      (fun (p, rule) -> if !hit = None then ignore (push p rule [ !i ]))
      unary;
    let j = ref 0 in
    while !hit = None && !j < !i && !count < max_lines do
      let lj = get !j in
      let pair_work = li_work + prop_work lj.s_prop in
      let binary =
        (if allow "DON" then
           let () = consume_work work pair_work in
           List.map
             (fun p -> (p, "DON", [ !i; !j ]))
             (Rules.apply_don li.s_prop lj.s_prop)
           @
           let () = consume_work work pair_work in
           List.map
               (fun p -> (p, "DON", [ !j; !i ]))
               (Rules.apply_don lj.s_prop li.s_prop)
         else [])
        @
        if allow "Add" then
          let () = consume_work work pair_work in
          List.map
            (fun p -> (p, "Add", [ !i; !j ]))
            (Rules.apply_add li.s_prop lj.s_prop)
        else []
      in
      List.iter
        (fun (p, rule, parents) ->
          if !hit = None then ignore (push p rule parents))
        binary;
      incr j
    done;
    incr i
  done;
  ( Array.map
      (function Some l -> l | None -> assert false)
      (Array.sub !lines 0 !count),
    !hit )

(* ── Tautology seeding ──────────────────────────────────────────────────── *)

(* Every term occurring anywhere in the given propositions (canonicalized),
   deduped by term key in first-seen order — each gets an It line. *)
let mentioned_terms (props : prop list) : term list =
  let seen : (string, unit) Hashtbl.t = Hashtbl.create 16 in
  let out = ref [] in
  List.iter
    (fun p ->
      List.iter
        (fun (occ : Infer.occurrence) ->
          let k = Infer.term_key occ.occ_term in
          if not (Hashtbl.mem seen k) then (
            Hashtbl.add seen k ();
            out := occ.occ_term :: !out))
        (Infer.occurrences (Infer.canon_prop p)))
    props;
  List.rev !out

(* ── Ancestry extraction ────────────────────────────────────────────────── *)

(* Prune to the given roots' ancestry, keep original order, renumber from 1;
   [closing] appends a synthetic final line (the ⊥ of an indirect proof). *)
let extract (lines : sat_line array) (roots : int list)
    (closing : (string * string * int list) option) : proof =
  let keep : (int, unit) Hashtbl.t = Hashtbl.create 16 in
  let rec mark i =
    if not (Hashtbl.mem keep i) then (
      Hashtbl.add keep i ();
      List.iter mark lines.(i).parents)
  in
  List.iter mark roots;
  let order =
    List.sort compare (Hashtbl.fold (fun i () acc -> i :: acc) keep [])
  in
  let renum : (int, int) Hashtbl.t = Hashtbl.create 16 in
  List.iteri (fun n idx -> Hashtbl.add renum idx (n + 1)) order;
  let out =
    List.map
      (fun idx ->
        let l = lines.(idx) in
        {
          n = Hashtbl.find renum idx;
          l_prop = Some l.s_prop;
          text = l.key;
          rule = l.rule;
          parents = List.map (Hashtbl.find renum) l.parents;
        })
      order
  in
  let out =
    match closing with
    | None -> out
    | Some (text, rule, parents) ->
        out
        @ [
            {
              n = List.length out + 1;
              l_prop = None;
              text;
              rule;
              parents = List.map (Hashtbl.find renum) parents;
            };
          ]
  in
  { found = true; lines = out }

(* ── Direct derivation ──────────────────────────────────────────────────── *)

(* The board's size bound: nothing derived may exceed the largest input by more
   than [slack] nodes. [base] seeds the maximum with the input that is not in
   [props] — the goal for a derivation, the queried term for a term query. *)
let size_cap ~slack ~base (props : prop list) =
  List.fold_left (fun acc p -> max acc (Infer.prop_nodes p)) base props + slack

let derive ?max_lines ?max_work ?work_budget ?(slack = 8)
    (premises : prop list) (goal : prop) : proof =
  List.iter Infer.validate_prop premises;
  Infer.validate_prop goal;
  let size_cap = size_cap ~slack ~base:(Infer.prop_nodes goal) premises in
  let goal_key = Notation.print_proposition (Infer.canon_prop goal) in
  let lines, hit =
    saturate ?max_lines ?max_work ?work_budget ~size_cap
      (fun push ->
        List.iter
          (fun p -> ignore (push (Infer.canon_prop p) "premise" []))
          premises;
        List.iter
          (fun t -> ignore (push (Infer.tautology t) "It" []))
          (mentioned_terms (premises @ [ goal ])))
      (fun idx l _seen -> if l.key = goal_key then Some [ idx ] else None)
  in
  match hit with
  | Some roots -> extract lines roots None
  | None -> { found = false; lines = [] }

(* ── Refutation and indirect proof (PLAN 1.6) ───────────────────────────── *)

type entry = { e_prop : prop; e_rule : string }

(* Refute a set outright: pronominalize its particular statements (fresh
   proterms + anchors, parented on their entries) and saturate until some
   line's contradictory is already on the board — a fixed witness asserted
   and denied the same thing. Sound by Skolemization. *)
let refute_set ?max_lines ?max_work ?work_budget ?(slack = 8)
    (entries : entry list) : proof =
  List.iter (fun e -> Infer.validate_prop e.e_prop) entries;
  let size_cap =
    size_cap ~slack ~base:min_int (List.map (fun e -> e.e_prop) entries)
  in
  let used : (string, unit) Hashtbl.t = Hashtbl.create 16 in
  List.iter (fun e -> Relational.collect_names e.e_prop used) entries;
  let lines, hit =
    saturate ?max_lines ?max_work ?work_budget ~size_cap
      (fun push ->
        let idxs =
          List.map
            (fun e -> push (Infer.canon_prop e.e_prop) e.e_rule [])
            entries
        in
        List.iter2
          (fun e idx ->
            match Relational.pronominalize e.e_prop used with
            | None -> ()
            | Some { pr_prop; anchors } ->
                let parents = match idx with Some i -> [ i ] | None -> [] in
                ignore (push (Infer.canon_prop pr_prop) "Pron" parents);
                List.iter
                  (fun a -> ignore (push (Infer.canon_prop a) "Anchor" parents))
                  anchors)
          entries idxs;
        List.iter
          (fun t -> ignore (push (Infer.tautology t) "It" []))
          (mentioned_terms (List.map (fun e -> e.e_prop) entries)))
      (fun idx l seen ->
        let ck = Notation.print_proposition (Infer.contradictory l.s_prop) in
        match seen ck with
        | Some other when other <> idx -> Some [ other; idx ]
        | _ -> None)
  in
  match hit with
  | Some roots -> extract lines roots (Some ("⊥", "contradiction", roots))
  | None -> { found = false; lines = [] }

(* Assume the counterclaim — the premises plus the contradictory of the
   conclusion — and refute it; by PV the argument is then valid. *)
let indirect_proof ?max_lines ?max_work ?work_budget ?slack
    (premises : prop list) (conclusion : prop) : proof =
  List.iter Infer.validate_prop premises;
  Infer.validate_prop conclusion;
  refute_set ?max_lines ?max_work ?work_budget ?slack
    (List.map (fun prop -> { e_prop = prop; e_rule = "premise" }) premises
    @ [ { e_prop = Infer.contradictory conclusion; e_rule = "counterclaim" } ])
