(* Executable conformance for the versioned core-language contract. The
   examples live in data so every implementation can consume the same corpus.
   This runner checks notation, inference canonicalization, exact readings,
   result vocabulary, decision completeness, and proof shape. *)

open Harness
module J = Yojson.Safe
module U = Yojson.Safe.Util

let contract = "core-0.1"

let corpus_relative_path =
  Filename.concat "data/conformance" (contract ^ ".json")

let corpus_path =
  let candidates =
    [ corpus_relative_path; Filename.concat ".." corpus_relative_path ]
  in
  match List.find_opt Sys.file_exists candidates with
  | Some path -> path
  | None -> corpus_relative_path

let failf fmt = Printf.ksprintf failwith fmt
let json_field name json = U.member name json

let json_string name json =
  match json_field name json with
  | `String s -> s
  | _ -> failf "field %S must be a string" name

let json_optional_string name json =
  match json_field name json with
  | `Null -> None
  | `String s -> Some s
  | _ -> failf "field %S must be a string or null" name

let json_bool name json =
  match json_field name json with
  | `Bool b -> b
  | _ -> failf "field %S must be a boolean" name

let json_string_list name json =
  match json_field name json with
  | `List xs ->
      List.map
        (function
          | `String s -> s
          | _ -> failf "field %S must be a list of strings" name)
        xs
  | _ -> failf "field %S must be a list" name

let parse_prop label source =
  match Tfl.Safe.parse ~where:label source with
  | Ok p -> p
  | Error f ->
      failf "%s failed to parse (%s): %s" label
        (Tfl.Safe.kind_name f.kind)
        f.message

let parse_program label source =
  match Tfl.Safe.parse_program source with
  | Error f ->
      failf "%s failed to parse (%s): %s" label
        (Tfl.Safe.kind_name f.kind)
        f.message
  | Ok p when p.errors <> [] ->
      let messages =
        List.map
          (fun (e : Tfl.Program.program_error) ->
            Printf.sprintf "line %d: %s" e.err_line e.err_message)
          p.errors
      in
      failf "%s contains unchecked program errors: %s" label
        (String.concat " | " messages)
  | Ok p ->
      List.map (fun (e : Tfl.Program.program_entry) -> e.prop) p.propositions

let method_name = function
  | Tfl.Decide.PZ -> "PZ"
  | Derivation -> "derivation"
  | Indirect -> "indirect"
  | Numerical -> "numerical"

let method_is_complete = function
  | Tfl.Decide.PZ -> true
  | Derivation | Indirect | Numerical -> false

let proof_rule_names (proof : Tfl.Derive.proof) =
  List.map (fun (line : Tfl.Derive.line) -> line.rule) proof.lines

let proof_final_text (proof : Tfl.Derive.proof) =
  match List.rev proof.lines with [] -> None | line :: _ -> Some line.text

let expected_proof expected = json_field "proof" expected
let expected_proof_kind expected = json_string "kind" (expected_proof expected)

let check_proof_shape expected proof =
  let shape = expected_proof expected in
  let got_rules = proof_rule_names proof in
  let wanted_rules = json_string_list "rules" shape in
  check (got_rules = wanted_rules)
    (Printf.sprintf "proof rules changed: got [%s], expected [%s]"
       (String.concat ", " got_rules)
       (String.concat ", " wanted_rules));
  let got_final = proof_final_text proof in
  let wanted_final = json_optional_string "final" shape in
  check (got_final = wanted_final)
    (Printf.sprintf "proof final line changed: got %s, expected %s"
       (Option.value ~default:"null" got_final)
       (Option.value ~default:"null" wanted_final));
  match json_field "explanation" shape with
  | `Null -> ()
  | `String wanted ->
      check
        (Tfl.Render.explain_proof proof = Some wanted)
        "proof explanation changed"
  | _ -> failwith "proof explanation must be a string when present"

let check_argument_evidence expected (r : Tfl.Decide.result) =
  match expected_proof_kind expected with
  | "certificate" ->
      check (Option.is_some r.certificate) "expected a P/Z certificate";
      check (Option.is_none r.proof)
        "a certificate case unexpectedly carried a proof";
      check
        (Option.is_none r.decision)
        "a certificate case carried a numerical decision"
  | "none" ->
      check (Option.is_none r.certificate) "unexpected certificate";
      check (Option.is_none r.proof) "unexpected proof";
      check (Option.is_none r.decision) "unexpected numerical decision"
  | "direct" | "direct-contradictory" | "indirect" -> (
      check
        (Option.is_none r.certificate)
        "proof case unexpectedly carried a certificate";
      check
        (Option.is_none r.decision)
        "proof case carried a numerical decision";
      match r.proof with
      | None -> failwith "expected a derivation proof"
      | Some proof -> check_proof_shape expected proof)
  | "numerical-decision" ->
      check (Option.is_some r.decision) "expected a numerical decision record";
      check (Option.is_none r.proof)
        "numerical decision unexpectedly carried a proof";
      check
        (Option.is_none r.certificate)
        "numerical decision carried a certificate"
  | other -> failf "proof kind %S is not valid for an argument result" other

let check_focus_views case expected =
  let focus = parse_prop "focus" (json_string "focus" case) in
  let printed = Tfl.Notation.print_proposition focus in
  let canonical = Tfl.Notation.print_proposition (Tfl.Infer.canon_prop focus) in
  let reading = Tfl.Render.read_prop focus in
  check_eq printed (json_string "printed" expected);
  check_eq canonical (json_string "canonical" expected);
  check_eq reading (json_string "reading" expected)

let check_argument operation expected =
  let premises =
    json_string_list "premises" operation
    |> List.mapi (fun i source ->
        parse_prop (Printf.sprintf "premise %d" (i + 1)) source)
  in
  let conclusion =
    parse_prop "conclusion" (json_string "conclusion" operation)
  in
  let r = Tfl.Decide.check_argument premises conclusion in
  check_eq (verdict_name r) (json_string "result" expected);
  check_eq (method_name r.meth) (json_string "method" expected);
  let complete = method_is_complete r.meth in
  check
    (complete = json_bool "complete" expected)
    "argument completeness changed";
  check_argument_evidence expected r

let check_argument_error operation expected =
  let premises = json_string_list "premises" operation in
  let conclusion = json_string "conclusion" operation in
  match Tfl.Safe.check ~premises ~conclusion with
  | Ok _ -> failwith "expected the guarded argument to be refused"
  | Error failure ->
      check_eq (Tfl.Safe.kind_name failure.kind) (json_string "result" expected);
      check_eq failure.message (json_string "message" expected);
      check
        (failure.where = json_optional_string "where" expected)
        "guarded argument error location changed";
      check
        (json_optional_string "method" expected = None)
        "a refused argument cannot claim a decision method";
      check
        (not (json_bool "complete" expected))
        "a refused argument cannot claim decision completeness";
      check
        (expected_proof_kind expected = "none")
        "a refused argument cannot carry proof evidence"

let query_verdict_name = function
  | Tfl.Program.Q_yes -> "yes"
  | Q_no -> "no"
  | Q_unknown -> "unknown"

let is_ground_query_complete program query (answer : Tfl.Program.prop_query) =
  match answer.support with
  | Some r -> method_is_complete r.meth
  | None ->
      let positive = Tfl.Decide.check_argument program query in
      if not (method_is_complete positive.meth) then false
      else
        let negative =
          Tfl.Decide.check_argument program (Tfl.Infer.contradictory query)
        in
        method_is_complete negative.meth

let check_ground_query operation expected =
  let program =
    parse_program "ground-query program" (json_string "program" operation)
  in
  let query = parse_prop "ground query" (json_string "query" operation) in
  let answer = Tfl.Program.query_prop program query in
  check_eq (query_verdict_name answer.q_verdict) (json_string "result" expected);
  let got_method =
    Option.map (fun r -> method_name r.Tfl.Decide.meth) answer.support
  in
  check
    (got_method = json_optional_string "method" expected)
    "ground-query support method changed";
  check
    (is_ground_query_complete program query answer
    = json_bool "complete" expected)
    "ground-query completeness changed";
  match answer.support with
  | Some r -> check_argument_evidence expected r
  | None ->
      check
        (expected_proof_kind expected = "none")
        "unsupported ground query must expect no proof"

let check_term_query operation expected =
  let program =
    parse_program "term-query program" (json_string "program" operation)
  in
  let term = Tfl.Notation.parse_term (json_string "term" operation) in
  let answers = Tfl.Program.query_term program term |> List.map snd in
  let wanted = json_string_list "result" expected in
  check (answers = wanted)
    (Printf.sprintf "term-query answers changed: got [%s], expected [%s]"
       (String.concat ", " answers)
       (String.concat ", " wanted));
  check_eq (json_string "method" expected) "bounded-saturation";
  check
    (not (json_bool "complete" expected))
    "term query cannot claim completeness";
  check
    (expected_proof_kind expected = "not-exposed")
    "term-query proof shape must record that proofs are not exposed"

let consistency_result_name (r : Tfl.Program.consistency) =
  if not r.consistent then "inconsistent"
  else if r.complete then "consistent"
  else if r.numerical then "numerical-undecided"
  else "no-contradiction-found"

let consistency_method_name (r : Tfl.Program.consistency) =
  if r.complete then "PZ"
  else if r.numerical then "numerical"
  else "refutation-search"

let check_consistency operation expected =
  let program =
    parse_program "consistency program" (json_string "program" operation)
  in
  let r = Tfl.Program.check_program_consistency program in
  check_eq (consistency_result_name r) (json_string "result" expected);
  check_eq (consistency_method_name r) (json_string "method" expected);
  check
    (r.complete = json_bool "complete" expected)
    "consistency completeness changed";
  match (expected_proof_kind expected, r.c_proof) with
  | "refutation", Some proof -> check_proof_shape expected proof
  | "none", None -> ()
  | "refutation", None -> failwith "expected a consistency refutation"
  | "none", Some _ -> failwith "unexpected consistency proof"
  | other, _ -> failf "proof kind %S is not valid for consistency" other

let check_equivalence operation expected =
  let left = parse_prop "equivalence left" (json_string "left" operation) in
  let right = parse_prop "equivalence right" (json_string "right" operation) in
  let r = Tfl.Program.decide_equivalence left right in
  let wanted_result =
    match json_field "result" expected with
    | `Bool b -> b
    | _ -> failwith "equivalence result must be boolean"
  in
  check (r.equivalent = wanted_result) "equivalence result changed";
  check_eq r.e_method (json_string "method" expected);
  let complete = String.equal r.e_method "dnf" in
  check
    (complete = json_bool "complete" expected)
    "equivalence completeness changed";
  match expected_proof_kind expected with
  | "rewrite-path" ->
      check
        (r.e_path = Some (json_string_list "rules" (expected_proof expected)))
        "rewrite equivalence path changed"
  | "truth-table" ->
      check (Option.is_some r.atoms) "truth-table result lost its atoms";
      check (Option.is_some r.dnf) "truth-table result lost its DNF rows";
      check (Option.is_none r.e_path)
        "truth-table result carried a rewrite path"
  | "none" ->
      check (Option.is_none r.atoms) "rewrite miss carried truth-table atoms";
      check (Option.is_none r.dnf) "rewrite miss carried DNF rows";
      check (Option.is_none r.e_path) "rewrite miss carried a path"
  | other -> failf "proof kind %S is not valid for equivalence" other

let register_case case =
  let id = json_string "id" case in
  let rule = json_string "rule" case in
  check (String.trim rule <> "") (id ^ " has an empty rule description");
  let operation = json_field "operation" case in
  let expected = json_field "expected" case in
  test id (fun () ->
      check_focus_views case expected;
      match json_string "kind" operation with
      | "argument" -> check_argument operation expected
      | "argument-error" -> check_argument_error operation expected
      | "ground-query" -> check_ground_query operation expected
      | "term-query" -> check_term_query operation expected
      | "consistency" -> check_consistency operation expected
      | "equivalence" -> check_equivalence operation expected
      | other -> failf "unknown operation kind %S" other)

let () =
  let document = J.from_file corpus_path in
  check_eq (json_string "contract" document) contract;
  let cases = U.to_list (json_field "cases" document) in
  let seen = Hashtbl.create (List.length cases) in
  List.iter
    (fun case ->
      let id = json_string "id" case in
      check (not (Hashtbl.mem seen id)) ("duplicate conformance id: " ^ id);
      Hashtbl.add seen id ();
      register_case case)
    cases;
  check (List.length cases >= 26) "core corpus unexpectedly lost required cases";
  finish (contract ^ " conformance")
