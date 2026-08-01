(* 1.8 acceptance: unit tests for the TFL⁺ numerical decision, ported from
   the D9 section of engine/tfl.test.js — the paper's Tables 10–13, the
   term-matched condition (iii) discriminator, routing, level validation, and
   the level guards on the 1.7 queries. The readProp glosses and answer()
   tests belong to 1.9 / the deferred Aristotelian layer. *)

open Tfl.Notation
open Tfl.Decide

open Harness


let conditions (r : result) =
  match r.decision with
  | Some d -> (d.sum, d.n_particular, d.level_ok)
  | None -> failwith "no decision record"

let () =
  (* The paper's Tables 10–13 (Castro-Manzano et al. 2018) *)
  test "Table 10 — kaa-1 is invalid (fails the sum and particular counts)"
    (fun () ->
      let r = arg [ "+H^1+I"; "-g+H" ] "-g+I" in
      check (r.verdict = Invalid) "verdict";
      check (r.meth = Numerical) "method";
      let sum, particular, _ = conditions r in
      check (not sum) "sum fails";
      check (not particular) "particular fails");
  test "Table 11 — akt-4 is invalid on the LEVEL condition alone" (fun () ->
      let r = arg [ "-C+F"; "+M^1+C" ] "+M^2+F" in
      check (r.verdict = Invalid) "verdict";
      check (conditions r = (true, true, false)) "conditions");
  test "Table 12 — bao-3 is valid" (fun () ->
      let r = arg [ "+C^3-H"; "-C+E" ] "+E-H" in
      check (r.verdict = Valid) "verdict";
      check (conditions r = (true, true, true)) "conditions");
  test "Table 13 — ekg-2 is valid" (fun () ->
      check ((arg [ "-F-C"; "+V^2+C" ] "+V^1-F").verdict = Valid) "ekg-2");

  test "a most-conclusion is fine when a most-premise on its subject licenses \
        it" (fun () ->
      check ((arg [ "-M+P"; "+S^2+M" ] "+S^2+P").verdict = Valid) "att-1");

  test "any nonzero level routes to the decision method" (fun () ->
      check (has_level (p "+V^2+C")) "has_level positive";
      check (not (has_level (p "-S+P"))) "has_level negative";
      check ((arg [ "-M+P"; "-S+M" ] "-S+P").meth = PZ) "level 0 stays P/Z";
      check ((arg [ "+V^2+C" ] "+V+C").meth = Numerical) "leveled routes");

  (* Validation: where a level may and may not sit *)
  test "validation: a level needs a particular (+) subject" (fun () ->
      Tfl.Infer.validate_prop (p "+V^2+C");
      match Tfl.Infer.validate_prop (p "-V^2+C") with
      | () -> failwith "universal + level should be rejected"
      | exception Tfl.Infer.Engine_error _ -> ());
  test "validation: no level on the predicate, no level > 3" (fun () ->
      (match Tfl.Infer.validate_prop (p "+V+C^2") with
      | () -> failwith "predicate level should be rejected"
      | exception Tfl.Infer.Engine_error _ -> ());
      match Tfl.Infer.validate_prop (p "+V^4+C") with
      | () -> failwith "level 4 should be rejected"
      | exception Tfl.Infer.Engine_error _ -> ());
  test "validation: no level inside a compound or a relational object"
    (fun () ->
      (match Tfl.Infer.validate_prop (p "+(+A^2+B)+C") with
      | () -> failwith "compound level should be rejected"
      | exception Tfl.Infer.Engine_error _ -> ());
      match Tfl.Infer.validate_prop (p "+A+(R+B^2)") with
      | () -> failwith "object level should be rejected"
      | exception Tfl.Infer.Engine_error _ -> ());

  (* Guards on the level-0 queries (1.7 surfaces) *)
  test "guards: term/equivalence queries reject levels, consistency defers"
    (fun () ->
      (match Tfl.Program.query_term [ p "+V^2+C" ] (parse_term "V") with
      | _ -> failwith "query_term should reject levels"
      | exception Tfl.Infer.Engine_error _ -> ());
      (match Tfl.Program.equivalents (p "+V^2+C") with
      | _ -> failwith "equivalents should reject levels"
      | exception Tfl.Infer.Engine_error _ -> ());
      (match Tfl.Program.decide_equivalence (p "+V^2+C") (p "+V^1+C") with
      | _ -> failwith "decide_equivalence should reject levels"
      | exception Tfl.Infer.Engine_error _ -> ());
      let c = Tfl.Program.check_program_consistency [ p "+V^2+C" ] in
      check c.numerical "consistency defers");

  test "numericalDecision is exposed and reports the conditions directly"
    (fun () ->
      let d = numerical_decision [ p "+C^3-H"; p "-C+E" ] (p "+E-H") in
      check d.n_valid "valid";
      check (d.conclusion_level = 0) "conclusion level 0");

  test "condition (iii) is term-matched: an intermediate quantity rides its \
        own term" (fun () ->
      let r = arg [ "-B+A"; "+B^2+H" ] "+H^2+A" in
      check (r.verdict = Invalid) "att-3 shape invalid";
      check (conditions r = (true, true, false)) "level fails alone";
      check ((arg [ "-B+A"; "+B^2+H" ] "+H+A").verdict = Valid)
        "the some-conclusion follows";
      check ((arg [ "-M+P"; "+S^2+M" ] "+S^2+P").verdict = Valid)
        "att-1 carries");

  finish "numerical unit tests"
