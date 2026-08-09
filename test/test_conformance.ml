(* Executable core-0.1 conformance corpus (PLAN Phase 1). The examples live
   in data, not in this executable, so another implementation can consume the
   same contract. This runner checks notation, inference canonicalization,
   exact readings, result vocabulary, decision completeness, and proof shape. *)

open Harness
module J = Yojson.Safe
module U = Yojson.Safe.Util

let corpus_path =
  match
    List.find_opt Sys.file_exists
      [ "data/conformance/core-0.1.json"; "../data/conformance/core-0.1.json" ]
  with
  | Some path -> path
  | None -> "data/conformance/core-0.1.json"

let failf fmt = Printf.ksprintf failwith fmt
let field name json = U.member name json

let string name json =
  match field name json with
  | `String s -> s
  | _ -> failf "field %S must be a string" name

let optional_string name json =
  match field name json with
  | `Null -> None
  | `String s -> Some s
  | _ -> failf "field %S must be a string or null" name

let bool name json =
  match field name json with
  | `Bool b -> b
  | _ -> failf "field %S must be a boolean" name

let string_list name json =
  match field name json with
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

let verdict_name (r : Tfl.Decide.result) =
  match r.verdict with
  | Valid -> "valid"
  | Invalid -> "invalid"
  | Contradicted -> "contradicted"
  | Unknown -> "unknown"

let method_name = function
  | Tfl.Decide.PZ -> "PZ"
  | Derivation -> "derivation"
  | Indirect -> "indirect"
  | Numerical -> "numerical"

let proof_rules (proof : Tfl.Derive.proof) =
  List.map (fun (line : Tfl.Derive.line) -> line.rule) proof.lines

let proof_final (proof : Tfl.Derive.proof) =
  match List.rev proof.lines with [] -> None | line :: _ -> Some line.text

let expected_proof expected = field "proof" expected

let check_rules_and_final expected proof =
  let shape = expected_proof expected in
  let wanted_rules = string_list "rules" shape in
  check
    (proof_rules proof = wanted_rules)
    (Printf.sprintf "proof rules changed: got [%s], expected [%s]"
       (String.concat ", " (proof_rules proof))
       (String.concat ", " wanted_rules));
  let wanted_final = optional_string "final" shape in
  check
    (proof_final proof = wanted_final)
    (Printf.sprintf "proof final line changed: got %s, expected %s"
       (Option.value ~default:"null" (proof_final proof))
       (Option.value ~default:"null" wanted_final))

let check_decide_proof expected (r : Tfl.Decide.result) =
  let kind = string "kind" (expected_proof expected) in
  match kind with
  | "certificate" ->
      check (r.certificate <> None) "expected a P/Z certificate";
      check (r.proof = None) "a certificate case unexpectedly carried a proof";
      check (r.decision = None)
        "a certificate case carried a numerical decision"
  | "none" ->
      check (r.certificate = None) "unexpected certificate";
      check (r.proof = None) "unexpected proof";
      check (r.decision = None) "unexpected numerical decision"
  | "direct" | "direct-contradictory" | "indirect" -> (
      check (r.certificate = None)
        "proof case unexpectedly carried a certificate";
      check (r.decision = None) "proof case carried a numerical decision";
      match r.proof with
      | None -> failwith "expected a derivation proof"
      | Some proof -> check_rules_and_final expected proof)
  | "numerical-decision" ->
      check (r.decision <> None) "expected a numerical decision record";
      check (r.proof = None) "numerical decision unexpectedly carried a proof";
      check (r.certificate = None) "numerical decision carried a certificate"
  | other -> failf "proof kind %S is not valid for an argument result" other

let check_focus case expected =
  let focus = parse_prop "focus" (string "focus" case) in
  let printed = Tfl.Notation.print_proposition focus in
  let canonical = Tfl.Notation.print_proposition (Tfl.Infer.canon_prop focus) in
  let reading = Tfl.Render.read_prop focus in
  check_eq printed (string "printed" expected);
  check_eq canonical (string "canonical" expected);
  check_eq reading (string "reading" expected)

let check_argument operation expected =
  let premises =
    string_list "premises" operation
    |> List.mapi (fun i source ->
        parse_prop (Printf.sprintf "premise %d" (i + 1)) source)
  in
  let conclusion = parse_prop "conclusion" (string "conclusion" operation) in
  let r = Tfl.Decide.check_argument premises conclusion in
  check_eq (verdict_name r) (string "result" expected);
  check_eq (method_name r.meth) (string "method" expected);
  let complete = r.meth = Tfl.Decide.PZ in
  check (complete = bool "complete" expected) "argument completeness changed";
  check_decide_proof expected r

let query_verdict_name = function
  | Tfl.Program.Q_yes -> "yes"
  | Q_no -> "no"
  | Q_unknown -> "unknown"

let ground_query_complete program query (answer : Tfl.Program.prop_query) =
  match answer.support with
  | Some r -> r.meth = Tfl.Decide.PZ
  | None ->
      let positive = Tfl.Decide.check_argument program query in
      if positive.meth <> Tfl.Decide.PZ then false
      else
        let negative =
          Tfl.Decide.check_argument program (Tfl.Infer.contradictory query)
        in
        negative.meth = Tfl.Decide.PZ

let check_ground_query operation expected =
  let program =
    parse_program "ground-query program" (string "program" operation)
  in
  let query = parse_prop "ground query" (string "query" operation) in
  let answer = Tfl.Program.query_prop program query in
  check_eq (query_verdict_name answer.q_verdict) (string "result" expected);
  let got_method =
    Option.map (fun r -> method_name r.Tfl.Decide.meth) answer.support
  in
  check
    (got_method = optional_string "method" expected)
    "ground-query support method changed";
  check
    (ground_query_complete program query answer = bool "complete" expected)
    "ground-query completeness changed";
  match answer.support with
  | Some r -> check_decide_proof expected r
  | None ->
      check
        (string "kind" (expected_proof expected) = "none")
        "unsupported ground query must expect no proof"

let check_term_query operation expected =
  let program =
    parse_program "term-query program" (string "program" operation)
  in
  let term = Tfl.Notation.parse_term (string "term" operation) in
  let answers = Tfl.Program.query_term program term |> List.map snd in
  let wanted = string_list "result" expected in
  check (answers = wanted)
    (Printf.sprintf "term-query answers changed: got [%s], expected [%s]"
       (String.concat ", " answers)
       (String.concat ", " wanted));
  check_eq (string "method" expected) "bounded-saturation";
  check (not (bool "complete" expected)) "term query cannot claim completeness";
  check
    (string "kind" (expected_proof expected) = "not-exposed")
    "term-query proof shape must record that proofs are not exposed"

let consistency_result (r : Tfl.Program.consistency) =
  if not r.consistent then "inconsistent"
  else if r.complete then "consistent"
  else if r.numerical then "numerical-undecided"
  else "no-contradiction-found"

let consistency_method (r : Tfl.Program.consistency) =
  if r.complete then "PZ"
  else if r.numerical then "numerical"
  else "refutation-search"

let check_consistency operation expected =
  let program =
    parse_program "consistency program" (string "program" operation)
  in
  let r = Tfl.Program.check_program_consistency program in
  check_eq (consistency_result r) (string "result" expected);
  check_eq (consistency_method r) (string "method" expected);
  check
    (r.complete = bool "complete" expected)
    "consistency completeness changed";
  let kind = string "kind" (expected_proof expected) in
  match (kind, r.c_proof) with
  | "refutation", Some proof -> check_rules_and_final expected proof
  | "none", None -> ()
  | "refutation", None -> failwith "expected a consistency refutation"
  | "none", Some _ -> failwith "unexpected consistency proof"
  | other, _ -> failf "proof kind %S is not valid for consistency" other

let check_equivalence operation expected =
  let left = parse_prop "equivalence left" (string "left" operation) in
  let right = parse_prop "equivalence right" (string "right" operation) in
  let r = Tfl.Program.decide_equivalence left right in
  let wanted_result =
    match field "result" expected with
    | `Bool b -> b
    | _ -> failwith "equivalence result must be boolean"
  in
  check (r.equivalent = wanted_result) "equivalence result changed";
  check_eq r.e_method (string "method" expected);
  check
    (r.e_method = "dnf" = bool "complete" expected)
    "equivalence completeness changed";
  let kind = string "kind" (expected_proof expected) in
  match kind with
  | "rewrite-path" ->
      check
        (r.e_path = Some (string_list "rules" (expected_proof expected)))
        "rewrite equivalence path changed"
  | "truth-table" ->
      check (r.atoms <> None) "truth-table result lost its atoms";
      check (r.dnf <> None) "truth-table result lost its DNF rows";
      check (r.e_path = None) "truth-table result carried a rewrite path"
  | other -> failf "proof kind %S is not valid for equivalence" other

let check_case case =
  let id = string "id" case in
  let rule = string "rule" case in
  check (String.trim rule <> "") (id ^ " has an empty rule description");
  let operation = field "operation" case in
  let expected = field "expected" case in
  test id (fun () ->
      check_focus case expected;
      match string "kind" operation with
      | "argument" -> check_argument operation expected
      | "ground-query" -> check_ground_query operation expected
      | "term-query" -> check_term_query operation expected
      | "consistency" -> check_consistency operation expected
      | "equivalence" -> check_equivalence operation expected
      | other -> failf "unknown operation kind %S" other)

let () =
  let document = J.from_file corpus_path in
  check_eq (string "contract" document) "core-0.1";
  let cases = U.to_list (field "cases" document) in
  let seen = Hashtbl.create (List.length cases) in
  List.iter
    (fun case ->
      let id = string "id" case in
      check (not (Hashtbl.mem seen id)) ("duplicate conformance id: " ^ id);
      Hashtbl.add seen id ();
      check_case case)
    cases;
  check (List.length cases >= 15) "core corpus unexpectedly lost required cases";
  finish "core-0.1 conformance"
