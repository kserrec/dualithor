(* Programs, queries, and equivalence (PLAN 1.7), ported from engine/tfl.js:
   parse_program, the ? term and proposition queries, program consistency,
   the ?= equivalence neighbourhood and pairwise decision, and the
   one-world statement model (port-spec §13). *)

open Ast

(* ── parse_program ──────────────────────────────────────────────────────── *)

type program_error_kind = Program_lexical | Program_syntactic

type program_entry = {
  prop : prop;
  text : string;
  source_line : string;
  line : int;
  span : Source.span;
}

type program_error = {
  err_kind : program_error_kind;
  err_line : int;
  err_message : string;
  err_pos : int;
  err_end_pos : int;
  err_span : Source.span;
  err_source_line : string;
}

type parsed_program = {
  propositions : program_entry list;
  errors : program_error list;
}

(* Comments run from `--` (any mix of ASCII/typographic minus, two adjacent)
   to end of line. Outside quotes two adjacent minuses can never occur in valid
   notation, since negative terms are always parenthesized — but a quoted term
   carries arbitrary text, so the scan walks name and quoted tokens whole
   rather than testing every position. Deliberate deviation from the frozen
   reference, which strips naively and truncates `+"well--known"+P` into an
   "Unclosed quote" error on a valid line (LOG 2026-08-01). *)
let strip_comment (cps : int array) : int array =
  let n = Array.length cps in
  let is_minus c = c = 0x2D || c = 0x2212 in
  (* a bare name absorbs a following double quote as a double prime, so the
     whole name token is skipped before any quote can open *)
  let rec end_of_name j =
    if
      j < n
      && (Notation.is_name_char cps.(j)
         || cps.(j) = 0x22 (* a double quote here is a double prime *)
         || cps.(j) = 0x2032 (* ′ *)
         || cps.(j) = 0x2033 (* ″ *))
    then end_of_name (j + 1)
    else j
  in
  let rec end_of_quote j =
    if j >= n || cps.(j) = 0x22 then j + 1 else end_of_quote (j + 1)
  in
  let rec scan i =
    if i >= n then None
    else if Notation.is_name_start cps.(i) then scan (end_of_name (i + 1))
    else if cps.(i) = 0x22 then scan (end_of_quote (i + 1))
    else if i + 1 < n && is_minus cps.(i) && is_minus cps.(i + 1) then Some i
    else scan (i + 1)
  in
  match scan 0 with None -> cps | Some i -> Array.sub cps 0 i

(* JS String.trim: strip the same whitespace set the tokenizer skips. *)
let trim_cps_with_start (cps : int array) : int array * int =
  let n = Array.length cps in
  let s = ref 0 in
  while !s < n && Notation.is_whitespace cps.(!s) do
    incr s
  done;
  let e = ref n in
  while !e > !s && Notation.is_whitespace cps.(!e - 1) do
    decr e
  done;
  (Array.sub cps !s (!e - !s), !s)

let trim_cps cps = fst (trim_cps_with_start cps)

let cps_to_string (cps : int array) : string =
  let b = Buffer.create (Array.length cps) in
  Array.iter (fun c -> Buffer.add_utf_8_uchar b (Uchar.of_int c)) cps;
  Buffer.contents b

(* The code a program line contributes: comment stripped, then trimmed. Safe
   checks nesting depth on this same text before parsing (PLAN 3.1), so the
   two must not drift apart. *)
let line_code_with_start (raw : string) : string * int =
  let code, start =
    Notation.decode raw |> strip_comment |> trim_cps_with_start
  in
  (cps_to_string code, start)

let line_code raw = fst (line_code_with_start raw)

(* Translate a zero-based parser position in [line_code raw] back to a
   one-based Unicode code-point column in the original physical line. Kept as
   a compatibility projection of the Phase 5 span carried by program entries. *)
let source_column raw pos =
  let _, start = line_code_with_start raw in
  start + max 0 pos + 1

(* Line-oriented; per-line ParseErrors are collected, not thrown. Note:
   parse_program does not validate — fragment validation happens in the
   query functions. *)
let parse_program (src : string) : parsed_program =
  let propositions = ref [] in
  let errors = ref [] in
  let line_offset = ref 0 in
  List.iteri
    (fun i raw ->
      let line = i + 1 in
      let code, code_start = line_code_with_start raw in
      let source_span range =
        Source.span_on_line ~line ~line_offset:!line_offset
          ~column_offset:code_start range
      in
      let record_error err_kind message pos end_pos =
        let range = Source.range ~start_offset:pos ~end_offset:end_pos in
        errors :=
          {
            err_kind;
            err_line = line;
            err_message = message;
            err_pos = pos;
            err_end_pos = end_pos;
            err_span = source_span range;
            err_source_line = raw;
          }
          :: !errors
      in
      (if code <> "" then
         match Notation.tokenize code with
         | exception Notation.Parse_error { message; pos; end_pos } ->
             record_error Program_lexical message pos end_pos
         | tokens -> (
             match Notation.parse_proposition_located_tokens tokens with
             | located ->
                 propositions :=
                   {
                     prop = located.value;
                     text = code;
                     source_line = raw;
                     line;
                     span = source_span located.range;
                   }
                   :: !propositions
             | exception Notation.Parse_error { message; pos; end_pos } ->
                 record_error Program_syntactic message pos end_pos));
      line_offset := !line_offset + Source.codepoint_length raw + 1)
    (String.split_on_char '\n' src);
  { propositions = List.rev !propositions; errors = List.rev !errors }

(* ── ? term query: "what is T?" ─────────────────────────────────────────── *)

let any_level props = List.exists Decide.has_level props

(* Saturate the program on DON + Simp about the term (plus the immediate
   equivalences for canonical bookkeeping — never Add, whose compounds would
   bury the answer), collect every derived proposition about the term, then
   keep only the strongest. Strongest first. *)
type term_answer = {
  answer_prop : prop;
  answer_text : string;
  answer_proof : Derive.proof;
}

let query_term_detailed ?max_lines ?(slack = 6) (program : prop list)
    (term : term) : term_answer list =
  List.iter Infer.validate_prop program;
  if any_level program then
    Infer.engine_error
      "“what is …?” saturation is a level-0 query; ask a numerical syllogism \
       as an argument (premises ⊢ conclusion) instead";
  Infer.validate_term term;
  let key = Infer.term_key term in
  let size_cap = Derive.size_cap ~slack ~base:(Infer.node_count term) program in
  let lines, (_ : unit option) =
    Derive.saturate
      ~max_lines:(Option.value max_lines ~default:300)
      ~rules:[ "IN"; "Contrap"; "Simp"; "DON" ]
      ~size_cap
      (fun push ->
        List.iter
          (fun p -> ignore (push (Infer.canon_prop p) "fact" []))
          program;
        List.iter
          (fun t -> ignore (push (Infer.tautology t) "It" []))
          (Derive.mentioned_terms program))
      (fun _ _ _ -> None)
  in
  (* Collect props "about" the term: skip It lines; find an orientation whose
     subject is the term; drop the term's own tautology and its obverse;
     dedupe by prop key. *)
  let cands = ref [] in
  let seen : (string, unit) Hashtbl.t = Hashtbl.create 16 in
  Array.iteri
    (fun idx (l : Derive.sat_line) ->
      if l.rule <> "It" then
        match
          List.find_opt
            (fun o -> Infer.term_key o.subject.term = key)
            (Relational.orientations l.s_prop)
        with
        | None -> ()
        | Some display ->
            let ts = display.subject.term in
            let dk = Infer.prop_key display in
            if
              dk <> Infer.prop_key (Infer.tautology ts)
              && dk <> Infer.prop_key (Infer.obverse (Infer.tautology ts))
              && not (Hashtbl.mem seen dk)
            then (
              Hashtbl.add seen dk ();
              cands := (display, idx) :: !cands))
    lines;
  let cands = List.rev !cands in
  (* Unary entailment a ⊢ b (equivalences + Simp weakening), small-fuel. *)
  let implies (a, _) (b, _) =
    let b_key = Notation.print_proposition (Infer.canon_prop b) in
    if Notation.print_proposition (Infer.canon_prop a) = b_key then true
    else
      let cap = max (Infer.prop_nodes a) (Infer.prop_nodes b) + 2 in
      let _, hit =
        Derive.saturate ~max_lines:60
          ~rules:[ "IN"; "Contrap"; "Simp" ]
          ~size_cap:cap
          (fun push -> ignore (push (Infer.canon_prop a) "a" []))
          (fun _ l _ -> if l.key = b_key then Some () else None)
      in
      hit <> None
  in
  let kept = ref [] in
  List.iter
    (fun c ->
      if not (List.exists (fun k -> implies k c) !kept) then
        kept := List.filter (fun k -> not (implies c k)) !kept @ [ c ])
    cands;
  let sorted =
    List.sort
      (fun (a, _) (b, _) ->
        let d = Infer.prop_nodes b - Infer.prop_nodes a in
        if d <> 0 then d
        else
          String.compare
            (Notation.print_proposition a)
            (Notation.print_proposition b))
      !kept
  in
  List.map
    (fun (p, idx) ->
      {
        answer_prop = p;
        answer_text = Notation.print_proposition p;
        answer_proof = Derive.extract lines [ idx ] None;
      })
    sorted

let query_term ?max_lines ?slack (program : prop list) (term : term) :
    (prop * string) list =
  query_term_detailed ?max_lines ?slack program term
  |> List.map (fun answer -> (answer.answer_prop, answer.answer_text))

(* ── ? proposition query: the three-way verdict ─────────────────────────── *)

type query_verdict = Q_yes | Q_no | Q_unknown
type prop_query = { q_verdict : query_verdict; support : Decide.result option }

let query_prop ?max_lines ?slack (program : prop list) (query : prop) :
    prop_query =
  List.iter Infer.validate_prop program;
  Infer.validate_prop query;
  let yes = Decide.check_argument ?max_lines ?slack program query in
  match yes.verdict with
  | Valid -> { q_verdict = Q_yes; support = Some yes }
  | Contradicted -> { q_verdict = Q_no; support = Some yes }
  | _ ->
      (* P/Z invalidity and numerical abstention have not yet tried the
         contradictory. Non-atomic derivation already does so inside
         [check_argument], returning [Contradicted] when it succeeds. *)
      if yes.meth = PZ || yes.meth = Numerical then
        let no =
          Decide.check_argument ?max_lines ?slack program
            (Infer.contradictory query)
        in
        if no.verdict = Valid then { q_verdict = Q_no; support = Some no }
        else { q_verdict = Q_unknown; support = None }
      else { q_verdict = Q_unknown; support = None }

(* ── Program consistency ────────────────────────────────────────────────── *)

type consistency = {
  consistent : bool;
  complete : bool;
  numerical : bool; (* true only for the leveled-fact-base early return *)
  certificate : Decide.certificate option;
  c_proof : Derive.proof option;
}

let check_program_consistency ?max_lines ?slack (program : prop list) :
    consistency =
  List.iter Infer.validate_prop program;
  if any_level program then
    (* Numerical inconsistency is undefined in the source paper; report the
       leveled fact base as undecided. *)
    {
      consistent = true;
      complete = false;
      numerical = true;
      certificate = None;
      c_proof = None;
    }
  else
    let entries =
      List.map (fun prop -> { Derive.e_prop = prop; e_rule = "fact" }) program
    in
    if Decide.is_atomic_categorical program then
      match Decide.check_inconsistent program with
      | None ->
          {
            consistent = true;
            complete = true;
            numerical = false;
            certificate = None;
            c_proof = None;
          }
      | Some cert ->
          let proof = Derive.refute_set ?max_lines ?slack entries in
          {
            consistent = false;
            complete = true;
            numerical = false;
            certificate = Some cert;
            c_proof = (if proof.found then Some proof else None);
          }
    else
      let proof = Derive.refute_set ?max_lines ?slack entries in
      if proof.found then
        {
          consistent = false;
          complete = false;
          numerical = false;
          certificate = None;
          c_proof = Some proof;
        }
      else
        {
          consistent = true;
          complete = false;
          numerical = false;
          certificate = None;
          c_proof = None;
        }

(* ── ?= equivalence neighbourhood ───────────────────────────────────────── *)

type equivalent_entry = {
  eq_prop : prop;
  eq_text : string;
  eq_rule : string; (* 'given' or the last op name *)
  reading : string;
  path : string list;
}

(* BFS closure of the canonical prop under the bidirectional immediate rules
   obverse and contrapositive (conversion and DN are absorbed by canonical
   form, so the closure is finite; node cap 64). *)
let equivalents ?(max_nodes = 64) (p : prop) : equivalent_entry list =
  Infer.validate_prop p;
  if Decide.has_level p then
    Infer.engine_error
      "the immediate rules (obversion, contraposition) are defined at level 0; \
       a numerical quantifier has no equivalence neighbourhood here";
  let start = Infer.canon_prop p in
  let start_key = Notation.print_proposition start in
  let nodes : (string, prop * string list) Hashtbl.t = Hashtbl.create 16 in
  let order = ref [ start_key ] in
  Hashtbl.add nodes start_key (start, []);
  let queue = Queue.create () in
  Queue.add start queue;
  let ops =
    [
      ("obverse", fun q -> Some (Infer.obverse q));
      ("contrapositive", Infer.contrapositive);
    ]
  in
  while (not (Queue.is_empty queue)) && Hashtbl.length nodes < max_nodes do
    let cur = Queue.pop queue in
    let cur_key = Notation.print_proposition cur in
    let _, cur_path = Hashtbl.find nodes cur_key in
    List.iter
      (fun (name, fn) ->
        match fn cur with
        | None -> ()
        | Some r ->
            let key = Notation.print_proposition r in
            if not (Hashtbl.mem nodes key) then (
              Hashtbl.add nodes key (r, cur_path @ [ name ]);
              order := key :: !order;
              Queue.add r queue))
      ops
  done;
  List.rev_map
    (fun key ->
      let prop, path = Hashtbl.find nodes key in
      {
        eq_prop = prop;
        eq_text = Notation.print_proposition prop;
        eq_rule =
          (match path with
          | [] -> "given"
          | _ -> List.nth path (List.length path - 1));
        reading =
          (match path with
          | [] -> "the statement itself"
          | [ one ] -> "its " ^ one
          | many -> "its " ^ String.concat " then " many);
        path;
      })
    !order

(* ── The one-world statement model ──────────────────────────────────────── *)

let statement_atom_limit = 16

(* A 16-atom truth table has only 65,536 assignments, but its returned DNF can
   still be made arbitrarily large through long atom names, and a wide formula
   can make evaluating those assignments arbitrarily expensive. Keep both the
   materialized output and the approximate AST-node visits within explicit
   process budgets. Crossing either budget falls back to the bounded rewrite
   method below; it never weakens a positive equivalence result into a crash or
   an unbounded allocation. *)
let max_dnf_bytes = 8 * 1_024 * 1_024
let max_truth_table_node_visits = 8 * 1_024 * 1_024

let truth_table_fits_budget atoms a b =
  let row_count = 1 lsl List.length atoms in
  (* Every row writes every atom once. U+2212 is the longer of the two signs
     in UTF-8, so this is an upper bound independent of the assignment. *)
  let max_row_bytes =
    List.fold_left
      (fun total name -> total + String.length "−" + String.length name)
      0 atoms
  in
  let output_fits =
    max_row_bytes <= max_dnf_bytes / row_count
  in
  let nodes_per_row = Infer.prop_nodes a + Infer.prop_nodes b in
  let work_fits =
    nodes_per_row <= max_truth_table_node_visits / row_count
  in
  output_fits && work_fits

(* Non-null only when the prop is purely propositional: every atom
   lowercase-initial (ASCII per the §16.4 narrowing), non-singular; no
   relational complexes; 1–16 atoms. Semantics over a one-member universe. *)
let statement_model (p : prop) :
    (string list * ((string -> bool) -> bool)) option =
  let atoms : (string, unit) Hashtbl.t = Hashtbl.create 16 in
  let atom_order = ref [] in
  let ok = ref true in
  let rec scan_t t =
    match t with
    | Atom { name; singular } ->
        if singular || name = "" || not (name.[0] >= 'a' && name.[0] <= 'z')
        then ok := false
        else if not (Hashtbl.mem atoms name) then (
          Hashtbl.add atoms name ();
          atom_order := name :: !atom_order)
    | Neg t -> scan_t t
    | Compound els -> List.iter (fun e -> scan_t e.term) els
    | Rel _ -> ok := false
    | PropTerm (Inner_prop q) -> scan_p q
    | PropTerm (Inner_term t) -> scan_t t
  and scan_p q =
    scan_t q.subject.term;
    scan_t q.predicate.term
  in
  scan_p p;
  let n = Hashtbl.length atoms in
  if (not !ok) || n = 0 || n > statement_atom_limit then None
  else
    let rec eval_t t asg =
      match t with
      | Atom { name; _ } -> asg name
      | Neg t -> not (eval_t t asg)
      | Compound els ->
          List.for_all
            (fun e ->
              if e.sign = Minus then not (eval_t e.term asg)
              else eval_t e.term asg)
            els
      | PropTerm (Inner_prop q) -> eval_p q asg
      | PropTerm (Inner_term t) -> eval_t t asg
      | Rel _ -> assert false (* excluded by the scan *)
    and eval_p q asg =
      let s = eval_t q.subject.term asg in
      let pv = eval_t q.predicate.term asg in
      let qual = if q.predicate.sign = Plus then pv else not pv in
      if q.subject.sign = Minus then (not s) || qual else s && qual
    in
    Some (List.rev !atom_order, eval_p p)

(* ── ?= A, B: decide equivalence ────────────────────────────────────────── *)

type equivalence_decision = {
  equivalent : bool;
  e_method : string; (* "dnf" | "rewrite" *)
  atoms : string list option;
  dnf : string list option;
  e_path : string list option;
}

let decide_equivalence ?max_nodes (a : prop) (b : prop) : equivalence_decision =
  Infer.validate_prop a;
  Infer.validate_prop b;
  if Decide.has_level a || Decide.has_level b then
    Infer.engine_error
      "equivalence is decided at level 0; numerical quantifiers are compared \
       only through the decision method";
  let rewrite () =
    let closure = equivalents ?max_nodes a in
    let b_key = Notation.print_proposition (Infer.canon_prop b) in
    let hit =
      List.find_opt
        (fun e ->
          Notation.print_proposition (Infer.canon_prop e.eq_prop) = b_key)
        closure
    in
    {
      equivalent = hit <> None;
      e_method = "rewrite";
      atoms = None;
      dnf = None;
      e_path = (match hit with Some e -> Some e.path | None -> None);
    }
  in
  match (statement_model a, statement_model b) with
  | Some (atoms_a, sat_a), Some (atoms_b, sat_b) ->
      let atoms = List.sort_uniq String.compare (atoms_a @ atoms_b) in
      if
        List.length atoms > statement_atom_limit
        || not (truth_table_fits_budget atoms a b)
      then rewrite ()
      else
        let arr = Array.of_list atoms in
        let n = Array.length arr in
        let positions : (string, int) Hashtbl.t = Hashtbl.create n in
        Array.iteri (fun i name -> Hashtbl.add positions name i) arr;
        let rows = ref [] in
        let equal = ref true in
        for m = 0 to (1 lsl n) - 1 do
          let asg name =
            m land (1 lsl Hashtbl.find positions name) <> 0
          in
          let va = sat_a asg and vb = sat_b asg in
          if va <> vb then equal := false;
          if va then (
            let row = Buffer.create (n * 4) in
            (* Preserve the reference ordering: true atoms first, then false
               atoms, with each group in sorted atom order. *)
            Array.iteri
              (fun i name ->
                if m land (1 lsl i) <> 0 then (
                  Buffer.add_char row '+';
                  Buffer.add_string row name))
              arr;
            Array.iteri
              (fun i name ->
                if m land (1 lsl i) = 0 then (
                  Buffer.add_string row "−";
                  Buffer.add_string row name))
              arr;
            rows := Buffer.contents row :: !rows)
        done;
        {
          equivalent = !equal;
          e_method = "dnf";
          atoms = Some atoms;
          dnf = Some (List.rev !rows);
          e_path = None;
        }
  | _ -> rewrite ()
