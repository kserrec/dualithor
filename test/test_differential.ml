(* 1.3 acceptance: differential agreement between the OCaml parser/printer and
   the frozen JS reference engine, on
   (a) every string literal in engine/tfl.test.js, fed to all three parse
       entry points — non-formula strings must fail identically on both sides;
   (b) 10k QCheck-generated ASTs: the JS printer must reproduce the OCaml
       printed form and the JS parser must recover the exact AST;
   (c) 10k random token strings: parse outcomes (AST or error position+text)
       must agree on all three entry points.

   Documented divergences are normalized here, in the harness — never in the
   engine: the OCaml quoting hint appended to unrecognized non-ASCII
   characters (LOG 2026-07-30) is stripped before message comparison. *)

open Tfl.Notation

(* Under `dune test` the cwd is _build/default/test (the deps put engine/
   one level up); under `dune exec` from the root it is the source tree. *)
let engine_dir =
  if Sys.file_exists "../engine/shim.js" then "../engine" else "engine"

let shim = Shim_client.start ~shim_path:(engine_dir ^ "/shim.js")

(* ── Outcome comparison ─────────────────────────────────────────────────── *)

type ocaml_outcome =
  | Parsed of Yojson.Safe.t * string (* AST as JS-shaped JSON, printed form *)
  | Failed of string * int (* full message, position *)

let ocaml_parse fn src : ocaml_outcome =
  try
    match fn with
    | "parseProposition" ->
        let p = parse_proposition src in
        Parsed (Ast_json.prop_to_json p, print_proposition p)
    | "parseTerm" ->
        let t = parse_term src in
        Parsed (Ast_json.term_to_json t, print_term t)
    | "parseSignedTerm" ->
        let s = parse_signed_term src in
        Parsed (Ast_json.st_to_json s, print_signed_term s)
    | _ -> assert false
  with Parse_error { message; pos } -> Failed (message, pos)

let print_fn_of = function
  | "parseProposition" -> "printProposition"
  | "parseTerm" -> "printTerm"
  | _ -> "printSignedTerm"

let advisory = " (quote the term to use non-ASCII names)"

(* Remove the first occurrence of [advisory] (the recorded §16.4 divergence). *)
let strip_advisory msg =
  let ml = String.length msg and al = String.length advisory in
  let rec find i =
    if i + al > ml then None
    else if String.sub msg i al = advisory then Some i
    else find (i + 1)
  in
  match find 0 with
  | None -> msg
  | Some i -> String.sub msg 0 i ^ String.sub msg (i + al) (ml - i - al)

(* None = both engines agree on [src] via [fn]; Some d = disagreement d. *)
let compare_on fn src : string option =
  match (ocaml_parse fn src, Shim_client.call shim fn [ `String src ]) with
  | Parsed (ast, printed), Ok js_ast ->
      if not (Ast_json.json_equal ast js_ast) then
        Some
          (Printf.sprintf "%s AST mismatch on %S: ocaml %s vs js %s" fn src
             (Yojson.Safe.to_string ast)
             (Yojson.Safe.to_string js_ast))
      else (
        (* Same AST — now the printers must emit the same string. The OCaml
           AST JSON goes through the JS printer, checking both printers and
           the serialization in one pass. *)
        match Shim_client.call shim (print_fn_of fn) [ ast ] with
        | Ok (`String js_printed) when js_printed = printed -> None
        | Ok (`String js_printed) ->
            Some
              (Printf.sprintf "%s print mismatch on %S: ocaml %S vs js %S" fn
                 src printed js_printed)
        | Ok other ->
            Some
              (Printf.sprintf "%s: js printer returned non-string %s" fn
                 (Yojson.Safe.to_string other))
        | Error e ->
            Some
              (Printf.sprintf "%s: js printer errored (%s) on ocaml AST for %S"
                 fn e.message src))
  | ( Failed (msg, pos),
      Error { name = "ParseError"; message = js_msg; pos = Some js_pos } ) ->
      if pos = js_pos && strip_advisory msg = js_msg then None
      else
        Some
          (Printf.sprintf
             "%s error mismatch on %S: ocaml (%S at %d) vs js (%S at %d)" fn
             src msg pos js_msg js_pos)
  | Parsed _, Error e ->
      Some
        (Printf.sprintf "%s: ocaml parsed but js errored (%s: %s) on %S" fn
           e.name e.message src)
  | Failed (msg, _), Ok _ ->
      Some
        (Printf.sprintf "%s: js parsed but ocaml errored (%s) on %S" fn msg src)
  | Failed _, Error { name; message; _ } ->
      Some
        (Printf.sprintf "%s: js raised %s (%s) on %S — expected ParseError" fn
           name message src)

let entry_points = [ "parseProposition"; "parseTerm"; "parseSignedTerm" ]

(* ── 1.4 gate: inference core A ─────────────────────────────────────────── *)

let occ_to_json (o : Tfl.Infer.occurrence) : Yojson.Safe.t =
  let open Tfl.Infer in
  `Assoc
    [
      ("term", Ast_json.term_to_json o.occ_term);
      ( "path",
        `List
          (`String
             (match o.side with
             | On_subject -> "subject"
             | On_predicate -> "predicate")
          :: List.map
               (function Occ_neg -> `String "neg" | Occ_at i -> `Int i)
               o.steps) );
      ("sign", `Int o.occ_sign);
      ("ownWild", `Bool o.own_wild);
    ]

(* Lazy chaining: report the first disagreement, skip the rest. *)
let ( ||> ) (a : string option) (b : unit -> string option) =
  match a with Some _ -> a | None -> b ()

let expect_json fn args expected : string option =
  match Shim_client.call shim fn args with
  | Ok js when Ast_json.json_equal expected js -> None
  | Ok js ->
      Some
        (Printf.sprintf "%s mismatch: ocaml %s vs js %s" fn
           (Yojson.Safe.to_string expected)
           (Yojson.Safe.to_string js))
  | Error e ->
      Some (Printf.sprintf "%s: js errored %s (%s)" fn e.name e.message)

let core_disagreement (p : Tfl.Ast.prop) : string option =
  let open Tfl.Infer in
  let pj = Ast_json.prop_to_json p in
  expect_json "canonProp" [ pj ] (Ast_json.prop_to_json (canon_prop p))
  ||> (fun () ->
        expect_json "contradictory" [ pj ]
          (Ast_json.prop_to_json (contradictory p)))
  ||> (fun () ->
        expect_json "obverse" [ pj ] (Ast_json.prop_to_json (obverse p)))
  ||> (fun () ->
        expect_json "contrapositive" [ pj ]
          (match contrapositive p with
          | Some q -> Ast_json.prop_to_json q
          | None -> `Null))
  ||> (fun () ->
        expect_json "tautology"
          [ Ast_json.term_to_json p.subject.term ]
          (Ast_json.prop_to_json (tautology p.subject.term)))
  ||> (fun () ->
        expect_json "occurrences" [ pj ]
          (`List (List.map occ_to_json (occurrences p))))
  ||> fun () ->
  let ocaml = try Ok (validate_prop p) with Engine_error m -> Error m in
  match (ocaml, Shim_client.call shim "validateProp" [ pj ]) with
  | Ok (), Ok `Null -> None
  | Error m, Error { name = "EngineError"; message; _ } when m = message ->
      None
  | Ok (), Error e ->
      Some
        (Printf.sprintf "validateProp: ocaml accepted, js rejected (%s: %s)"
           e.name e.message)
  | Error m, Ok _ ->
      Some
        (Printf.sprintf "validateProp: js accepted, ocaml rejected (%s)" m)
  | Error m, Error e ->
      Some
        (Printf.sprintf
           "validateProp message mismatch: ocaml %S vs js %s %S" m e.name
           e.message)
  | Ok (), Ok other ->
      Some
        (Printf.sprintf "validateProp: js returned unexpected %s"
           (Yojson.Safe.to_string other))

(* ── Corpus: every string literal in tfl.test.js ────────────────────────── *)

(* A small scanner for the frozen JS test file: skips // and slash-star
   comments and backtick template literals, extracts '…' and "…" literals
   decoding the standard escapes (unknown escapes keep the escaped char,
   as in JS). Good enough for the fixed file it reads. *)
let extract_js_strings (src : string) : string list =
  let n = String.length src in
  let out = ref [] in
  let i = ref 0 in
  while !i < n do
    let c = src.[!i] in
    if c = '/' && !i + 1 < n && src.[!i + 1] = '/' then
      while !i < n && src.[!i] <> '\n' do
        incr i
      done
    else if c = '/' && !i + 1 < n && src.[!i + 1] = '*' then (
      i := !i + 2;
      while !i + 1 < n && not (src.[!i] = '*' && src.[!i + 1] = '/') do
        incr i
      done;
      i := !i + 2)
    else if c = '\'' || c = '"' then (
      let quote = c in
      let b = Buffer.create 16 in
      incr i;
      let closed = ref false in
      while (not !closed) && !i < n do
        let d = src.[!i] in
        if d = '\\' && !i + 1 < n then (
          (match src.[!i + 1] with
          | 'n' -> Buffer.add_char b '\n'
          | 't' -> Buffer.add_char b '\t'
          | 'r' -> Buffer.add_char b '\r'
          | ch -> Buffer.add_char b ch);
          i := !i + 2)
        else if d = quote then (
          closed := true;
          incr i)
        else if d = '\n' then closed := true (* not valid JS; bail *)
        else (
          Buffer.add_char b d;
          incr i)
      done;
      out := Buffer.contents b :: !out)
    else if c = '`' then (
      incr i;
      let closed = ref false in
      while (not !closed) && !i < n do
        if src.[!i] = '\\' && !i + 1 < n then i := !i + 2
        else if src.[!i] = '`' then (
          closed := true;
          incr i)
        else incr i
      done)
    else incr i
  done;
  List.rev !out

let corpus_gate () =
  let src =
    In_channel.with_open_bin (engine_dir ^ "/tfl.test.js") In_channel.input_all
  in
  let strings = extract_js_strings src |> List.sort_uniq compare in
  let checks = ref 0 in
  let failures = ref 0 in
  List.iter
    (fun s ->
      List.iter
        (fun fn ->
          incr checks;
          match compare_on fn s with
          | None -> ()
          | Some d ->
              incr failures;
              Printf.eprintf "✗ corpus: %s\n" d)
        entry_points;
      (* 1.4: every corpus string that parses as a proposition also goes
         through the inference-core comparisons. *)
      match parse_proposition s with
      | exception _ -> ()
      | prop -> (
          incr checks;
          match core_disagreement prop with
          | None -> ()
          | Some d ->
              incr failures;
              Printf.eprintf "✗ corpus core: %s\n" d))
    strings;
  Printf.printf "corpus gate: %d distinct strings, %d checks, %d disagreements\n"
    (List.length strings) !checks !failures;
  !failures = 0

(* ── Random ASTs and random token strings ───────────────────────────────── *)

let diff_ast =
  QCheck2.Test.make ~count:10_000
    ~name:"differential: printers and parsers agree on generated ASTs"
    ~print:print_proposition Gen.prop_gen (fun p ->
      let ast = Ast_json.prop_to_json p in
      let printed = print_proposition p in
      (match Shim_client.call shim "printProposition" [ ast ] with
      | Ok (`String js_printed) -> js_printed = printed
      | _ -> false)
      &&
      match Shim_client.call shim "parseProposition" [ `String printed ] with
      | Ok js_ast -> Ast_json.json_equal ast js_ast
      | _ -> false)

(* Random concatenations of notation tokens: mostly ill-formed, some valid,
   exercising every tokenizer/parser error path on both engines at once. *)
let token_pool =
  [
    "+"; "-"; "−"; "±"; "+-"; "("; ")"; "["; "]"; "*"; "^"; "\""; "'"; "′";
    "″"; " "; "\n"; "S"; "P"; "Dog"; "Boy'"; "p"; "q"; "x1"; "_"; "2"; "²";
    "⁰"; "₁"; "7"; "head of a horse";
  ]

let token_string_gen : string QCheck2.Gen.t =
  let open QCheck2.Gen in
  let* n = int_bound 25 in
  let* parts = list_size (return n) (oneof_list token_pool) in
  return (String.concat "" parts)

let diff_strings =
  QCheck2.Test.make ~count:10_000
    ~name:"differential: parse outcomes agree on random token strings"
    ~print:String.escaped token_string_gen (fun s ->
      List.for_all (fun fn -> compare_on fn s = None) entry_points)

(* ── 1.5 gate: inference core B ─────────────────────────────────────────── *)

let line_to_json (l : Tfl.Derive.line) : Yojson.Safe.t =
  `Assoc
    [
      ("n", `Int l.n);
      ( "prop",
        match l.l_prop with Some p -> Ast_json.prop_to_json p | None -> `Null
      );
      ("text", `String l.text);
      ("rule", `String l.rule);
      ("parents", `List (List.map (fun i -> `Int i) l.parents));
    ]

let proof_to_json (pr : Tfl.Derive.proof) : Yojson.Safe.t =
  `Assoc
    [
      ("found", `Bool pr.found);
      ("lines", `List (List.map line_to_json pr.lines));
    ]

let cancellation_to_json (c : Tfl.Decide.cancellation) : Yojson.Safe.t =
  `Assoc
    [
      ("particular", Ast_json.prop_to_json c.particular);
      ( "universals",
        `List
          (List.map
             (fun (p, times) ->
               `Assoc
                 [ ("prop", Ast_json.prop_to_json p); ("times", `Int times) ])
             c.universals) );
    ]

let certificate_to_json (c : Tfl.Decide.certificate) : Yojson.Safe.t =
  `Assoc
    [
      ("point", `List (List.map (fun k -> `String k) c.point));
      ( "clash",
        match c.clash with
        | Some (a, b) -> `List [ `String a; `String b ]
        | None -> `Null );
      ( "cancellation",
        match c.cancellation with
        | Some x -> cancellation_to_json x
        | None -> `Null );
    ]

let result_to_json (r : Tfl.Decide.result) : Yojson.Safe.t =
  `Assoc
    ([
       ( "verdict",
         `String
           (match r.verdict with
           | Valid -> "valid"
           | Invalid -> "invalid"
           | Contradicted -> "contradicted"
           | Unknown -> "unknown") );
       ( "method",
         `String
           (match r.meth with
           | PZ -> "PZ"
           | Derivation -> "derivation"
           | Indirect -> "indirect"
           | Numerical -> "numerical") );
     ]
    @ (match r.certificate with
      | Some c -> [ ("certificate", certificate_to_json c) ]
      | None -> [])
    @
    match r.proof with
    | Some pr -> [ ("proof", proof_to_json pr) ]
    | None -> [])

(* Random atomic-categorical arguments: sides are atoms under 0–2 negations
   over a small name pool (so terms actually interact), ± only on bare fixed
   references, all levels 0 — the fragment where the JS engine decides by P/Z
   without the 1.6/1.8 layers. *)
let atomic_argument_gen : (Tfl.Ast.prop list * Tfl.Ast.prop) QCheck2.Gen.t =
  let open QCheck2.Gen in
  let open Tfl.Ast in
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

let print_argument (premises, conclusion) =
  String.concat "; " (List.map print_proposition premises)
  ^ " ⊢ " ^ print_proposition conclusion

let argument_disagreement (premises, conclusion) : string option =
  let pj = `List (List.map Ast_json.prop_to_json premises) in
  let cj = Ast_json.prop_to_json conclusion in
  expect_json "checkArgument" [ pj; cj ]
    (result_to_json (Tfl.Decide.check_argument premises conclusion))
  ||> fun () ->
  expect_json "checkInconsistent"
    [ `List (List.map Ast_json.prop_to_json (premises @ [ conclusion ])) ]
    (match Tfl.Decide.check_inconsistent (premises @ [ conclusion ]) with
    | Some c -> certificate_to_json c
    | None -> `Null)

let diff_args =
  QCheck2.Test.make ~count:10_000
    ~name:"differential: checkArgument/checkInconsistent agree on categorical \
           arguments"
    ~print:print_argument atomic_argument_gen (fun a ->
      match argument_disagreement a with
      | None -> true
      | Some d ->
          Printf.eprintf "✗ args: %s\n" d;
          false)

(* Whole-proof agreement for derive — line-for-line, testing that the OCaml
   saturation reproduces the JS iteration order exactly. maxLines 60 keeps
   10k+ searches affordable; order bugs surface early in the sequence. *)
let diff_derive =
  QCheck2.Test.make ~count:3_000
    ~name:"differential: derive proofs agree line-for-line"
    ~print:print_argument atomic_argument_gen (fun (premises, conclusion) ->
      let expected =
        proof_to_json (Tfl.Derive.derive ~max_lines:60 premises conclusion)
      in
      match
        expect_json "derive"
          [
            `List (List.map Ast_json.prop_to_json premises);
            Ast_json.prop_to_json conclusion;
            `Assoc [ ("maxLines", `Int 60) ];
          ]
          expected
      with
      | None -> true
      | Some d ->
          Printf.eprintf "✗ derive: %s\n" d;
          false)

(* ── 1.6 gate: relational layer ─────────────────────────────────────────── *)

let passive_to_json (r : Tfl.Relational.passive) : Yojson.Safe.t =
  `Assoc
    [
      ("prop", Ast_json.prop_to_json r.p_prop);
      ("equivalent", `Bool r.equivalent);
      ("swapped", `Int r.swapped);
    ]

(* Random relational propositions over a small shared pool: subject a signed
   atom (± only on fixed references), predicate usually a relational complex
   (heads occasionally carrying pairing subscripts, objects occasionally
   nested), sometimes a plain atom to hit the no-passive paths. *)
let relational_prop_gen : Tfl.Ast.prop QCheck2.Gen.t =
  let open QCheck2.Gen in
  let open Tfl.Ast in
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
    (* predicates are + or − only (a ± predicate is outside the fragment;
       invalid-input agreement is the 1.4 validateProp gate's job) *)
    let* sign = oneof_list [ Plus; Minus ] in
    let* term =
      oneof_weighted
        [ (4, rel_term); (1, oneof_weighted [ (3, general); (1, fixed) ]) ]
    in
    return { sign; term; level = 0 }
  in
  return { subject; predicate }

let print_prop = print_proposition

let diff_passives =
  QCheck2.Test.make ~count:10_000
    ~name:"differential: passives agree (prop, guard verdict, swap index)"
    ~print:print_prop relational_prop_gen (fun p ->
      match
        expect_json "passives"
          [ Ast_json.prop_to_json p ]
          (`List (List.map passive_to_json (Tfl.Relational.passives p)))
      with
      | None -> true
      | Some d ->
          Printf.eprintf "✗ passives: %s\n" d;
          false)

(* Full checkArgument on mixed relational/categorical arguments, comparing
   the whole result record — verdict, method, and proof lines (Pron/Anchor
   fresh-name sequences included). maxLines 150 on both sides bounds the four
   searches of an 'unknown'; identical fuel keeps verdicts comparable. *)
let relational_argument_gen :
    (Tfl.Ast.prop list * Tfl.Ast.prop) QCheck2.Gen.t =
  let open QCheck2.Gen in
  let* n = int_range 1 2 in
  let* premises = list_size (return n) relational_prop_gen in
  let* conclusion = relational_prop_gen in
  return (premises, conclusion)

let diff_rel_args =
  QCheck2.Test.make ~count:600
    ~name:"differential: checkArgument agrees on relational arguments \
           (full records, maxLines 60)"
    ~print:print_argument relational_argument_gen (fun (premises, conclusion) ->
      let expected =
        result_to_json
          (Tfl.Decide.check_argument ~max_lines:60 premises conclusion)
      in
      match
        expect_json "checkArgument"
          [
            `List (List.map Ast_json.prop_to_json premises);
            Ast_json.prop_to_json conclusion;
            `Assoc [ ("maxLines", `Int 60) ];
          ]
          expected
      with
      | None -> true
      | Some d ->
          Printf.eprintf "✗ rel args: %s\n" d;
          false)

(* ── 1.7 gate: programs, queries, equivalence ───────────────────────────── *)

let program_to_json (r : Tfl.Program.parsed_program) : Yojson.Safe.t =
  `Assoc
    [
      ( "propositions",
        `List
          (List.map
             (fun (e : Tfl.Program.program_entry) ->
               `Assoc
                 [
                   ("prop", Ast_json.prop_to_json e.prop);
                   ("text", `String e.text);
                   ("line", `Int e.line);
                 ])
             r.propositions) );
      ( "errors",
        `List
          (List.map
             (fun (e : Tfl.Program.program_error) ->
               `Assoc
                 [
                   ("line", `Int e.err_line);
                   ("message", `String (strip_advisory e.err_message));
                   ("pos", `Int e.err_pos);
                 ])
             r.errors) );
    ]

let query_answers_to_json (answers : (Tfl.Ast.prop * string) list) :
    Yojson.Safe.t =
  `List
    (List.map
       (fun (p, text) ->
         `Assoc [ ("prop", Ast_json.prop_to_json p); ("text", `String text) ])
       answers)

let prop_query_to_json (r : Tfl.Program.prop_query) : Yojson.Safe.t =
  `Assoc
    (( "verdict",
       `String
         (match r.q_verdict with
         | Q_yes -> "yes"
         | Q_no -> "no"
         | Q_unknown -> "unknown") )
    ::
    (match r.support with
    | Some s -> [ ("support", result_to_json s) ]
    | None -> []))

let consistency_to_json (r : Tfl.Program.consistency) : Yojson.Safe.t =
  `Assoc
    ([ ("consistent", `Bool r.consistent); ("complete", `Bool r.complete) ]
    @ (if r.numerical then [ ("numerical", `Bool true) ] else [])
    @ (match r.certificate with
      | Some c ->
          [
            ("certificate", certificate_to_json c);
            ( "proof",
              match r.c_proof with Some p -> proof_to_json p | None -> `Null
            );
          ]
      | None -> (
          match r.c_proof with
          | Some p -> [ ("proof", proof_to_json p) ]
          | None -> [])))

let equivalents_to_json (es : Tfl.Program.equivalent_entry list) :
    Yojson.Safe.t =
  `List
    (List.map
       (fun (e : Tfl.Program.equivalent_entry) ->
         `Assoc
           [
             ("prop", Ast_json.prop_to_json e.eq_prop);
             ("text", `String e.eq_text);
             ("rule", `String e.eq_rule);
             ("reading", `String e.reading);
             ("path", `List (List.map (fun s -> `String s) e.path));
           ])
       es)

let decision_to_json (r : Tfl.Program.equivalence_decision) : Yojson.Safe.t =
  `Assoc
    ([
       ("equivalent", `Bool r.equivalent); ("method", `String r.e_method);
     ]
    @ (match r.atoms with
      | Some atoms ->
          [ ("atoms", `List (List.map (fun s -> `String s) atoms)) ]
      | None -> [])
    @ (match r.dnf with
      | Some rows -> [ ("dnf", `List (List.map (fun s -> `String s) rows)) ]
      | None -> [])
    @
    if r.e_method = "rewrite" then
      [
        ( "path",
          match r.e_path with
          | Some path -> `List (List.map (fun s -> `String s) path)
          | None -> `Null );
      ]
    else [])

(* Random program sources: printed props, comment tails, garbage lines. *)
let program_src_gen : string QCheck2.Gen.t =
  let open QCheck2.Gen in
  let prop_line =
    map print_proposition (oneof [ relational_prop_gen; Gen.prop_gen ])
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

let diff_parse_program =
  QCheck2.Test.make ~count:2_000
    ~name:"differential: parseProgram agrees on random program sources"
    ~print:String.escaped program_src_gen (fun src ->
      match
        expect_json "parseProgram" [ `String src ]
          (program_to_json (Tfl.Program.parse_program src))
      with
      | None -> true
      | Some d ->
          Printf.eprintf "✗ parseProgram: %s\n" d;
          false)

(* Term queries over small atomic programs (the categorical fragment the
   query saturation serves). *)
let query_term_gen :
    (Tfl.Ast.prop list * Tfl.Ast.term) QCheck2.Gen.t =
  let open QCheck2.Gen in
  let open Tfl.Ast in
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

let diff_query_term =
  QCheck2.Test.make ~count:1_000
    ~name:"differential: queryTerm answers agree (content and order)"
    ~print:(fun (program, t) ->
      String.concat "; " (List.map print_proposition program)
      ^ " ? " ^ print_term t)
    query_term_gen (fun (program, term) ->
      match
        expect_json "queryTerm"
          [
            `List (List.map Ast_json.prop_to_json program);
            Ast_json.term_to_json term;
          ]
          (query_answers_to_json (Tfl.Program.query_term program term))
      with
      | None -> true
      | Some d ->
          Printf.eprintf "✗ queryTerm: %s\n" d;
          false)

let diff_query_prop =
  QCheck2.Test.make ~count:2_000
    ~name:"differential: queryProp three-way verdicts agree (with support)"
    ~print:print_argument atomic_argument_gen (fun (program, query) ->
      match
        expect_json "queryProp"
          [
            `List (List.map Ast_json.prop_to_json program);
            Ast_json.prop_to_json query;
          ]
          (prop_query_to_json (Tfl.Program.query_prop program query))
      with
      | None -> true
      | Some d ->
          Printf.eprintf "✗ queryProp: %s\n" d;
          false)

let diff_consistency =
  QCheck2.Test.make ~count:1_200
    ~name:"differential: checkProgramConsistency agrees (atomic + relational)"
    ~print:print_argument relational_argument_gen
    (fun (premises, conclusion) ->
      let program = premises @ [ conclusion ] in
      match
        expect_json "checkProgramConsistency"
          [
            `List (List.map Ast_json.prop_to_json program);
            `Assoc [ ("maxLines", `Int 60) ];
          ]
          (consistency_to_json
             (Tfl.Program.check_program_consistency ~max_lines:60 program))
      with
      | None -> true
      | Some d ->
          Printf.eprintf "✗ consistency: %s\n" d;
          false)

(* Statement propositions (lowercase atoms, negs/compounds/propterms) for the
   DNF path; the relational/categorical generators cover the rewrite path. *)
let statement_prop_gen : Tfl.Ast.prop QCheck2.Gen.t =
  let open QCheck2.Gen in
  let open Tfl.Ast in
  let atom = map (fun n -> Atom { name = n; singular = false }) (oneof_list [ "p"; "q"; "r" ]) in
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

let equivalence_pair_gen : (Tfl.Ast.prop * Tfl.Ast.prop) QCheck2.Gen.t =
  let open QCheck2.Gen in
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

let diff_equivalence =
  QCheck2.Test.make ~count:3_000
    ~name:"differential: equivalents + decideEquivalence agree"
    ~print:(fun (a, b) -> print_proposition a ^ " ?= " ^ print_proposition b)
    equivalence_pair_gen (fun (a, b) ->
      match
        expect_json "equivalents"
          [ Ast_json.prop_to_json a ]
          (equivalents_to_json (Tfl.Program.equivalents a))
        ||> fun () ->
        expect_json "decideEquivalence"
          [ Ast_json.prop_to_json a; Ast_json.prop_to_json b ]
          (decision_to_json (Tfl.Program.decide_equivalence a b))
      with
      | None -> true
      | Some d ->
          Printf.eprintf "✗ equivalence: %s\n" d;
          false)

(* Harness self-test: a real divergence must be DETECTED, or a clean run means
   nothing. "+É+P" is the documented §16.4 case — the JS reference parses É as
   a bare name, the OCaml engine raises a lexical error. *)
let negative_control () =
  match compare_on "parseProposition" "+\u{00C9}+P" with
  | Some _ -> true
  | None ->
      prerr_endline
        "✗ negative control: harness failed to detect the §16.4 divergence";
      false

let diff_core =
  QCheck2.Test.make ~count:10_000
    ~name:"differential: inference core A agrees on generated props"
    ~print:print_proposition Gen.prop_gen (fun p ->
      match core_disagreement p with
      | None -> true
      | Some d ->
          Printf.eprintf "✗ core: %s\n" d;
          false)

let () =
  let control_ok = negative_control () in
  let corpus_ok = corpus_gate () in
  let qcheck_failures =
    QCheck_base_runner.run_tests ~verbose:true
      [
        diff_ast; diff_strings; diff_core; diff_args; diff_derive;
        diff_passives; diff_rel_args; diff_parse_program; diff_query_term;
        diff_query_prop; diff_consistency; diff_equivalence;
      ]
  in
  Shim_client.stop shim;
  exit
    (if (not control_ok) || (not corpus_ok) || qcheck_failures <> 0 then 1
     else 0)
