(* The differential harness (PLAN 1.3, extended by every port step since):
   agreement between the OCaml engine and the frozen JS reference on
   (a) every string literal in engine/tfl.test.js — non-formula strings must
       fail identically on both sides — through the parsers, printers,
       inference core, and renderer;
   (b) QCheck-generated inputs per layer (generators in Gen, result
       serialization in Result_json).

   Documented divergences are normalized here, in the harness — never in the
   engine: the OCaml quoting hint appended to unrecognized non-ASCII
   characters (LOG 2026-07-30) is stripped before message comparison. *)

open Tfl.Notation

(* Mass mode (PLAN 1.12, the handover gate): `dune test` runs the standing
   counts; `-mass` raises every gate to its handover count. The handover counts
   differ per gate by two orders of magnitude because the costs do — a parse
   round-trip is two shim calls, a relational checkArgument is four bounded
   proof searches on each side. Both numbers are visible at each call site. *)
let mass = ref false

let () =
  Arg.parse
    [ ("-mass", Arg.Set mass, " run the PLAN 1.12 handover counts") ]
    (fun a -> raise (Arg.Bad ("unexpected argument " ^ a)))
    "test_differential [-mass]"

let count standing handover = if !mass then handover else standing
let shim = Shim_client.start ~shim_path:(Shim_client.default_path ())

(* ── Parse/print comparison (1.2) ───────────────────────────────────────── *)

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

(* None = both engines agree on [src] via [fn]; Some d = disagreement d. *)
let compare_on fn src : string option =
  match (ocaml_parse fn src, Shim_client.call shim fn [ `String src ]) with
  | Parsed (ast, printed), Ok js_ast -> (
      if not (Ast_json.json_equal ast js_ast) then
        Some
          (Printf.sprintf "%s AST mismatch on %S: ocaml %s vs js %s" fn src
             (Yojson.Safe.to_string ast)
             (Yojson.Safe.to_string js_ast))
      else
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
      if pos = js_pos && Result_json.strip_advisory msg = js_msg then None
      else
        Some
          (Printf.sprintf
             "%s error mismatch on %S: ocaml (%S at %d) vs js (%S at %d)" fn src
             msg pos js_msg js_pos)
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

(* ── Shared comparison plumbing ─────────────────────────────────────────── *)

(* Lazy chaining: report the first disagreement, skip the rest. *)
let ( ||> ) (a : string option) (b : unit -> string option) =
  match a with Some _ -> a | None -> b ()

let expect_json = Shim_client.expect_json shim

(* ── 1.4: inference core A over one proposition ─────────────────────────── *)

let core_disagreement (p : Tfl.Ast.prop) : string option =
  let open Tfl.Infer in
  let pj = Ast_json.prop_to_json p in
  ( ( ( ( ( expect_json "canonProp" [ pj ] (Ast_json.prop_to_json (canon_prop p))
          ||> fun () ->
            expect_json "contradictory" [ pj ]
              (Ast_json.prop_to_json (contradictory p)) )
        ||> fun () ->
          expect_json "obverse" [ pj ] (Ast_json.prop_to_json (obverse p)) )
      ||> fun () ->
        expect_json "contrapositive" [ pj ]
          (match contrapositive p with
          | Some q -> Ast_json.prop_to_json q
          | None -> `Null) )
    ||> fun () ->
      expect_json "tautology"
        [ Ast_json.term_to_json p.subject.term ]
        (Ast_json.prop_to_json (tautology p.subject.term)) )
  ||> fun () ->
    expect_json "occurrences" [ pj ]
      (`List (List.map Result_json.occ_to_json (occurrences p))) )
  ||> fun () ->
  let ocaml = try Ok (validate_prop p) with Engine_error m -> Error m in
  match (ocaml, Shim_client.call shim "validateProp" [ pj ]) with
  | Ok (), Ok `Null -> None
  | Error m, Error { name = "EngineError"; message; _ } when m = message -> None
  | Ok (), Error e ->
      Some
        (Printf.sprintf "validateProp: ocaml accepted, js rejected (%s: %s)"
           e.name e.message)
  | Error m, Ok _ ->
      Some (Printf.sprintf "validateProp: js accepted, ocaml rejected (%s)" m)
  | Error m, Error e ->
      Some
        (Printf.sprintf "validateProp message mismatch: ocaml %S vs js %s %S" m
           e.name e.message)
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
    let corpus =
      Filename.concat
        (Filename.dirname (Shim_client.default_path ()))
        "tfl.test.js"
    in
    In_channel.with_open_bin corpus In_channel.input_all
  in
  let strings = extract_js_strings src |> List.sort_uniq compare in
  let checks = ref 0 in
  let failures = ref 0 in
  let run label d =
    incr checks;
    match d with
    | None -> ()
    | Some detail ->
        incr failures;
        Printf.eprintf "✗ corpus %s: %s\n" label detail
  in
  List.iter
    (fun s ->
      List.iter (fun fn -> run fn (compare_on fn s)) entry_points;
      (* every corpus string that parses also goes through the
         inference-core and renderer comparisons *)
      (match parse_proposition s with
      | exception _ -> ()
      | prop ->
          run "core" (core_disagreement prop);
          run "readProp"
            (expect_json "readProp"
               [ Ast_json.prop_to_json prop ]
               (`String (Tfl.Render.read_prop prop))));
      match parse_term s with
      | exception _ -> ()
      | term ->
          run "readTerm"
            (expect_json "readTerm"
               [ Ast_json.term_to_json term ]
               (`String (Tfl.Render.read_term term))))
    strings;
  Printf.printf
    "corpus gate: %d distinct strings, %d checks, %d disagreements\n"
    (List.length strings) !checks !failures;
  !failures = 0

(* ── QCheck gates, one per layer ────────────────────────────────────────── *)

let gate = Harness.gate

let diff_ast =
  gate "differential: printers and parsers agree on generated ASTs"
    ~count:(count 10_000 100_000) ~print:print_proposition Gen.prop_gen
    (fun p ->
      let ast = Ast_json.prop_to_json p in
      let printed = print_proposition p in
      (match Shim_client.call shim "printProposition" [ ast ] with
        | Ok (`String js_printed) when js_printed = printed -> None
        | _ -> Some "printProposition mismatch")
      ||> fun () ->
      match Shim_client.call shim "parseProposition" [ `String printed ] with
      | Ok js_ast when Ast_json.json_equal ast js_ast -> None
      | _ -> Some "parseProposition mismatch")

let diff_strings =
  gate "differential: parse outcomes agree on random token strings"
    ~count:(count 10_000 100_000) ~print:String.escaped Gen.token_string_gen
    (fun s ->
      List.fold_left
        (fun acc fn -> acc ||> fun () -> compare_on fn s)
        None entry_points)

let diff_core =
  gate "differential: inference core A agrees on generated props"
    ~count:(count 10_000 100_000) ~print:print_proposition Gen.prop_gen
    core_disagreement

let diff_args =
  gate
    "differential: checkArgument/checkInconsistent agree on categorical \
     arguments"
    ~count:(count 10_000 100_000) ~print:Gen.print_argument
    Gen.atomic_argument_gen (fun (premises, conclusion) ->
      let pj = `List (List.map Ast_json.prop_to_json premises) in
      let cj = Ast_json.prop_to_json conclusion in
      expect_json "checkArgument" [ pj; cj ]
        (Result_json.result_to_json
           (Tfl.Decide.check_argument premises conclusion))
      ||> fun () ->
      expect_json "checkInconsistent"
        [ `List (List.map Ast_json.prop_to_json (premises @ [ conclusion ])) ]
        (match Tfl.Decide.check_inconsistent (premises @ [ conclusion ]) with
        | Some c -> Result_json.certificate_to_json c
        | None -> `Null))

(* Whole-proof agreement for derive — line-for-line, testing that the OCaml
   saturation reproduces the JS iteration order exactly. maxLines 60 keeps
   10k+ searches affordable; order bugs surface early in the sequence. *)
let diff_derive =
  gate "differential: derive proofs agree line-for-line"
    ~count:(count 3_000 20_000) ~print:Gen.print_argument
    Gen.atomic_argument_gen (fun (premises, conclusion) ->
      expect_json "derive"
        [
          `List (List.map Ast_json.prop_to_json premises);
          Ast_json.prop_to_json conclusion;
          `Assoc [ ("maxLines", `Int 60) ];
        ]
        (Result_json.proof_to_json
           (Tfl.Derive.derive ~max_lines:60 premises conclusion)))

let diff_passives =
  gate "differential: passives agree (prop, guard verdict, swap index)"
    ~count:(count 10_000 100_000) ~print:print_proposition
    Gen.relational_prop_gen (fun p ->
      expect_json "passives"
        [ Ast_json.prop_to_json p ]
        (`List
           (List.map Result_json.passive_to_json (Tfl.Relational.passives p))))

(* Full checkArgument on mixed relational/categorical arguments, comparing
   the whole result record — verdict, method, and proof lines (Pron/Anchor
   fresh-name sequences included). maxLines 60 on both sides bounds the four
   searches of an 'unknown'; identical fuel keeps verdicts comparable. *)
let diff_rel_args =
  gate
    "differential: checkArgument agrees on relational arguments (full records, \
     maxLines 60)"
    ~count:(count 600 5_000) ~print:Gen.print_argument
    Gen.relational_argument_gen (fun (premises, conclusion) ->
      expect_json "checkArgument"
        [
          `List (List.map Ast_json.prop_to_json premises);
          Ast_json.prop_to_json conclusion;
          `Assoc [ ("maxLines", `Int 60) ];
        ]
        (Result_json.result_to_json
           (Tfl.Decide.check_argument ~max_lines:60 premises conclusion)))

(* Documented deviation (LOG 2026-08-01): the OCaml comment stripper is
   quote-aware and the frozen reference's is not, so a source with `--` inside
   a quoted term legitimately parses differently. Those sources — and only
   those — are skipped, detected by running the reference's naive rule beside
   the engine's own. *)
let naive_strip (cps : int array) : int array =
  let n = Array.length cps in
  let is_minus c = c = 0x2D || c = 0x2212 in
  let rec find i =
    if i + 1 >= n then None
    else if is_minus cps.(i) && is_minus cps.(i + 1) then Some i
    else find (i + 1)
  in
  match find 0 with None -> cps | Some i -> Array.sub cps 0 i

let strippers_agree (src : string) : bool =
  List.for_all
    (fun line ->
      let cps = Tfl.Notation.decode line in
      naive_strip cps = Tfl.Program.strip_comment cps)
    (String.split_on_char '\n' src)

let quote_comment_skips = ref 0

let diff_parse_program =
  gate "differential: parseProgram agrees on random program sources"
    ~count:(count 2_000 30_000) ~print:String.escaped Gen.program_src_gen
    (fun src ->
      if not (strippers_agree src) then (
        incr quote_comment_skips;
        None)
      else
        expect_json "parseProgram"
          [ `String src ]
          (Result_json.program_to_json (Tfl.Program.parse_program src)))

let diff_query_term =
  gate "differential: queryTerm answers agree (content and order)"
    ~count:(count 1_000 10_000)
    ~print:(fun (program, t) ->
      String.concat "; " (List.map print_proposition program)
      ^ " ? " ^ print_term t)
    Gen.query_term_gen
    (fun (program, term) ->
      expect_json "queryTerm"
        [
          `List (List.map Ast_json.prop_to_json program);
          Ast_json.term_to_json term;
        ]
        (Result_json.query_answers_to_json
           (Tfl.Program.query_term program term)))

let diff_query_prop =
  gate "differential: queryProp three-way verdicts agree (with support)"
    ~count:(count 2_000 25_000) ~print:Gen.print_argument
    Gen.atomic_argument_gen (fun (program, query) ->
      expect_json "queryProp"
        [
          `List (List.map Ast_json.prop_to_json program);
          Ast_json.prop_to_json query;
        ]
        (Result_json.prop_query_to_json (Tfl.Program.query_prop program query)))

let diff_consistency =
  gate "differential: checkProgramConsistency agrees (atomic + relational)"
    ~count:(count 1_200 10_000) ~print:Gen.print_argument
    Gen.relational_argument_gen (fun (premises, conclusion) ->
      let program = premises @ [ conclusion ] in
      expect_json "checkProgramConsistency"
        [
          `List (List.map Ast_json.prop_to_json program);
          `Assoc [ ("maxLines", `Int 60) ];
        ]
        (Result_json.consistency_to_json
           (Tfl.Program.check_program_consistency ~max_lines:60 program)))

let diff_equivalence =
  gate "differential: equivalents + decideEquivalence agree"
    ~count:(count 3_000 30_000)
    ~print:(fun (a, b) -> print_proposition a ^ " ?= " ^ print_proposition b)
    Gen.equivalence_pair_gen
    (fun (a, b) ->
      expect_json "equivalents"
        [ Ast_json.prop_to_json a ]
        (Result_json.equivalents_to_json (Tfl.Program.equivalents a))
      ||> fun () ->
      expect_json "decideEquivalence"
        [ Ast_json.prop_to_json a; Ast_json.prop_to_json b ]
        (Result_json.decision_to_json (Tfl.Program.decide_equivalence a b)))

let diff_numerical =
  gate "differential: the numerical decision agrees (full decision records)"
    ~count:(count 10_000 100_000) ~print:Gen.print_argument
    Gen.leveled_argument_gen (fun (premises, conclusion) ->
      expect_json "checkArgument"
        [
          `List (List.map Ast_json.prop_to_json premises);
          Ast_json.prop_to_json conclusion;
        ]
        (Result_json.result_to_json
           (Tfl.Decide.check_argument premises conclusion)))

let diff_render =
  gate "differential: readProp/readTerm strings agree byte-for-byte"
    ~count:(count 10_000 100_000) ~print:print_proposition Gen.prop_gen
    (fun p ->
      expect_json "readProp"
        [ Ast_json.prop_to_json p ]
        (`String (Tfl.Render.read_prop p))
      ||> fun () ->
      expect_json "readTerm"
        [ Ast_json.term_to_json p.subject.term ]
        (`String (Tfl.Render.read_term p.subject.term)))

(* explainProof over real bounded proofs (direct and indirect, found or not):
   the OCaml proof record crosses the pipe in the JS proof shape, so both
   explainers narrate the very same proof. *)
let diff_explain =
  gate "differential: explainProof narrations agree" ~count:(count 1_500 10_000)
    ~print:Gen.print_argument Gen.relational_argument_gen
    (fun (premises, conclusion) ->
      let compare_proof (proof : Tfl.Derive.proof) =
        expect_json "explainProof"
          [ Result_json.proof_to_json proof ]
          (match Tfl.Render.explain_proof proof with
          | Some s -> `String s
          | None -> `Null)
      in
      compare_proof (Tfl.Derive.derive ~max_lines:60 premises conclusion)
      ||> fun () ->
      compare_proof
        (Tfl.Derive.indirect_proof ~max_lines:60 premises conclusion))

(* ── 1.12: the two coverage gaps the 2026-07-30 bughunt probed ──────────── *)

(* (a) Arbitrary-shape arguments through checkArgument, comparing the
   *outcome*: both engines reject with the same EngineError, or both decide
   and agree on the whole record. Rejection agreement is what the
   fragment-shaped generators never tested — and there are two ways to be
   rejected, validateProp's fragment rules and the numerical guard that fires
   when a quantity level rides a non-categorical argument. *)
type tally = { mutable decided : int; mutable rejected : int }

let arbitrary_tally = { decided = 0; rejected = 0 }
let valid_tally = { decided = 0; rejected = 0 }

let compare_check_argument tally (premises, conclusion) : string option =
  let args =
    [
      `List (List.map Ast_json.prop_to_json premises);
      Ast_json.prop_to_json conclusion;
      `Assoc [ ("maxLines", `Int 60) ];
    ]
  in
  let ocaml =
    try
      Ok
        (Result_json.result_to_json
           (Tfl.Decide.check_argument ~max_lines:60 premises conclusion))
    with Tfl.Infer.Engine_error m -> Error m
  in
  match (ocaml, Shim_client.call shim "checkArgument" args) with
  | Ok expected, Ok js ->
      if Ast_json.json_equal expected js then (
        tally.decided <- tally.decided + 1;
        None)
      else
        Some
          (Printf.sprintf "checkArgument mismatch: ocaml %s vs js %s"
             (Yojson.Safe.to_string expected)
             (Yojson.Safe.to_string js))
  | Error m, Error { name = "EngineError"; message; _ } when m = message ->
      tally.rejected <- tally.rejected + 1;
      None
  | Ok _, Error e ->
      Some
        (Printf.sprintf "checkArgument: ocaml decided, js raised %s (%s)" e.name
           e.message)
  | Error m, Ok js ->
      Some
        (Printf.sprintf "checkArgument: ocaml rejected (%s), js decided %s" m
           (Yojson.Safe.to_string js))
  | Error m, Error e ->
      Some
        (Printf.sprintf "checkArgument rejection mismatch: ocaml %S vs js %s %S"
           m e.name e.message)

let diff_arbitrary_args =
  gate
    "differential: checkArgument agrees on arbitrary shapes (errors compared \
     too)"
    ~count:(count 2_000 20_000) ~print:Gen.print_argument
    Gen.arbitrary_argument_gen
    (compare_check_argument arbitrary_tally)

(* The other half of (a): the same shapes made fragment-valid, so the whole
   decision record gets compared on propterm / compound / nested relational
   arguments. Costed like diff_rel_args — most of these run four bounded
   searches on each side. *)
let diff_valid_arbitrary_args =
  gate
    "differential: checkArgument agrees on arbitrary *valid* shapes (full \
     records)"
    ~count:(count 400 4_000) ~print:Gen.print_argument
    Gen.valid_arbitrary_argument_gen
    (compare_check_argument valid_tally)

(* (b) Consistency-proof narrations. refute_set proofs carry `fact` lines,
   a rule the derive/indirect proofs of diff_explain never produce, so the
   renderer's fact clause was previously ungated. *)
let narrated = ref 0

let diff_consistency_narration =
  gate "differential: consistency-proof narrations agree (fact lines)"
    ~count:(count 1_500 20_000) ~print:Gen.print_argument
    Gen.atomic_argument_gen (fun (premises, conclusion) ->
      let program = premises @ [ conclusion ] in
      match
        (Tfl.Program.check_program_consistency ~max_lines:60 program).c_proof
      with
      | None -> None
      | Some proof ->
          incr narrated;
          expect_json "explainProof"
            [ Result_json.proof_to_json proof ]
            (match Tfl.Render.explain_proof proof with
            | Some s -> `String s
            | None -> `Null))

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

let () =
  let control_ok = negative_control () in
  let corpus_ok = corpus_gate () in
  let qcheck_failures =
    QCheck_base_runner.run_tests ~verbose:true
      [
        diff_ast;
        diff_strings;
        diff_core;
        diff_args;
        diff_derive;
        diff_passives;
        diff_rel_args;
        diff_parse_program;
        diff_query_term;
        diff_query_prop;
        diff_consistency;
        diff_equivalence;
        diff_numerical;
        diff_render;
        diff_explain;
        diff_arbitrary_args;
        diff_valid_arbitrary_args;
        diff_consistency_narration;
      ]
  in
  Shim_client.stop shim;
  (* Coverage the two new gates actually reached — a gate that never fires
     proves nothing, so the counts go in the report. *)
  Printf.printf
    "arbitrary shapes: %d decided identically, %d rejected identically\n\
     arbitrary valid shapes: %d decided identically, %d rejected identically\n\
     consistency narrations: %d proofs narrated\n\
     parseProgram: %d sources skipped (quoted-comment deviation)\n"
    arbitrary_tally.decided arbitrary_tally.rejected valid_tally.decided
    valid_tally.rejected !narrated !quote_comment_skips;
  exit
    (if (not control_ok) || (not corpus_ok) || qcheck_failures <> 0 then 1
     else 0)
