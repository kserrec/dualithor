(* 1.7 acceptance: unit tests for programs, queries, and equivalence, ported
   from the D4 section of engine/tfl.test.js. The statementModel oracle-
   agreement test is ported directly (it needs no oracle); checkExpression
   tests are courseware-only and not ported (spec §13/§15). *)

open Tfl.Notation
open Tfl.Program
open Harness

(* The paper's Socrates/Fido program (Castro-Manzano et al. 2018 §6). *)
let fido =
  List.map p
    [
      "±Socrates*+Man";
      "±Fido*+Dog";
      "−Man+Animal";
      "−Dog+Animal";
      "−Man+Mortal";
    ]

(* A quoted term carries arbitrary text, `--` included; the naive stripper the
   frozen reference uses truncates the line into an "Unclosed quote" error on a
   formula that parses perfectly on its own (bughunt 2026-08-01). *)
let () =
  test "a quoted term containing -- is not a comment" (fun () ->
      let r = parse_program "+\"well--known\"+P" in
      check (List.length r.errors = 0) "no error expected";
      check (List.length r.propositions = 1) "the line should yield one prop";
      match r.propositions with
      | [ e ] ->
          check_eq (Tfl.Notation.print_proposition e.prop) "+\"well--known\"+P"
      | _ -> failwith "expected exactly one proposition");
  test "a comment after a quoted term still works" (fun () ->
      let r = parse_program "+\"well-known\"+P -- a comment" in
      check (List.length r.errors = 0) "no error expected";
      check (List.length r.propositions = 1) "one prop, comment stripped")

let () =
  (* parse_program *)
  test "parseProgram: -- comments and blank lines are skipped" (fun () ->
      let r =
        parse_program
          "−Man+Animal  -- all men are animals\n\n\
           -- a whole-line comment\n\
           ±Socrates*+Man"
      in
      check (r.errors = []) "no errors";
      check
        (List.map (fun e -> e.text) r.propositions
        = [ "−Man+Animal"; "±Socrates*+Man" ])
        "texts";
      check
        (List.map (fun e -> e.line) r.propositions = [ 1; 4 ])
        "line numbers");
  test "parseProgram: a bad line is reported, the rest survive" (fun () ->
      let r = parse_program "−Man+Animal\n+oops(\n−Dog+Animal" in
      check (List.length r.propositions = 2) "two good lines";
      check (List.length r.errors = 1) "one error";
      check ((List.hd r.errors).err_line = 2) "error on line 2");
  test "parseProgram: -- never collides with double negation" (fun () ->
      let r = parse_program "−(−p)+q -- not-not-p implies q" in
      check (List.length r.propositions = 1) "one proposition";
      check
        (Tfl.Infer.prop_eq_up_to (List.hd r.propositions).prop (p "−(−p)+q"))
        "prop survives");

  (* ? term *)
  test "? Socrates* saturates the singular facts, strongest forms only"
    (fun () ->
      let answers =
        query_term fido (parse_term "Socrates*")
        |> List.map snd |> List.sort String.compare
      in
      check
        (answers
        = [ "±Socrates*+Animal"; "±Socrates*+Man"; "±Socrates*+Mortal" ])
        (String.concat " | " answers));
  test "? Fido* stops where the rules do (no dog-mortality rule)" (fun () ->
      let answers =
        query_term fido (parse_term "Fido*")
        |> List.map snd |> List.sort String.compare
      in
      check
        (answers = [ "±Fido*+Animal"; "±Fido*+Dog" ])
        (String.concat " | " answers));
  test "? term drops tautologies from the answer set" (fun () ->
      let answers = query_term fido (parse_term "Man") |> List.map snd in
      check
        (not
           (List.exists (fun t -> t = "−Man+Man" || t = "−Man−(−Man)") answers))
        "no tautologies");

  (* ? proposition *)
  test "? proposition: yes / no / unknown" (fun () ->
      check
        ((query_prop fido (p "±Socrates*+Mortal")).q_verdict = Q_yes)
        "proven";
      check
        ((query_prop fido (p "±Socrates*−Animal")).q_verdict = Q_no)
        "refuted";
      check
        ((query_prop fido (p "±Fido*+Mortal")).q_verdict = Q_unknown)
        "open world");
  test "? proposition: the paper's query carries a proof" (fun () ->
      let r = query_prop fido (p "±Socrates*+Mortal") in
      check (r.q_verdict = Q_yes) "yes";
      check (r.support <> None) "support attached");
  test "? proposition: numerical support for the contradictory returns no"
    (fun () ->
      let program = List.map p [ "+C^3-H"; "-C+E" ] in
      let r = query_prop program (p "-E+H") in
      check (r.q_verdict = Q_no) "the numerical contradictory is supported";
      match r.support with
      | Some support ->
          check (support.meth = Tfl.Decide.Numerical) "numerical support"
      | None -> failwith "no support attached");

  (* Program consistency *)
  test "a consistent program reports consistent" (fun () ->
      check (check_program_consistency fido).consistent "consistent");
  test "an inconsistent program returns the contradiction derivation" (fun () ->
      let bad =
        List.map p [ "±Socrates*+Man"; "−Man+Mortal"; "±Socrates*−Mortal" ]
      in
      let res = check_program_consistency bad in
      check (not res.consistent) "inconsistent";
      check res.complete "complete (atomic-categorical)";
      check (res.certificate <> None) "P/Z certificate present";
      match res.c_proof with
      | Some pr ->
          let last = List.nth pr.lines (List.length pr.lines - 1) in
          check (last.text = "⊥") "proof ends in ⊥"
      | None -> failwith "no proof");

  (* ?= statement *)
  test "?= closes a statement under obversion and contraposition" (fun () ->
      let eq = equivalents (p "−S+P") in
      let texts = List.map (fun e -> e.eq_text) eq in
      check ((List.hd eq).eq_rule = "given") "first is given";
      check
        (List.mem (print_proposition (Tfl.Infer.obverse (p "−S+P"))) texts)
        "obverse present";
      (match Tfl.Infer.contrapositive (p "−S+P") with
      | Some c -> check (List.mem (print_proposition c) texts) "contrapositive"
      | None -> failwith "no contrapositive");
      List.iter
        (fun e ->
          check (decide_equivalence (p "−S+P") e.eq_prop).equivalent e.eq_text)
        eq);
  test "?= terminates (canonical form absorbs DN and conversion)" (fun () ->
      check (List.length (equivalents (p "+p+q")) <= 8) "bounded");

  (* ?= A, B *)
  test "?= term-logic pair decided by the rewrite path" (fun () ->
      let r = decide_equivalence (p "−Dog+Mammal") (p "−(−Mammal)+(−Dog)") in
      check (r.e_method = "rewrite") "method";
      check r.equivalent "equivalent";
      match r.e_path with
      | Some path ->
          check (List.mem "contrapositive" path) "path mentions contrap"
      | None -> failwith "no path");
  test "?= propositional pair decided by the DNF fingerprint" (fun () ->
      let r = decide_equivalence (p "−p+q") (p "−(−q)+(−p)") in
      check (r.e_method = "dnf") "method";
      check r.equivalent "equivalent";
      match r.dnf with
      | Some rows ->
          check (not (List.mem "+p−q" rows)) "excluded world";
          check (List.length rows = 3) "three worlds"
      | None -> failwith "no dnf");
  test "?= DNF catches an equivalence the immediate rules miss" (fun () ->
      let a = p "+p+p" and b = p "−(−p)+p" in
      check
        (not
           (List.exists
              (fun e -> Tfl.Infer.prop_eq_up_to e.eq_prop b)
              (equivalents a)))
        "rewrite cannot reach it";
      let r = decide_equivalence a b in
      check (r.e_method = "dnf") "method";
      check r.equivalent "equivalent");
  test "?= reports genuine non-equivalence" (fun () ->
      check
        (not (decide_equivalence (p "−p+q") (p "+p+q")).equivalent)
        "different forms";
      check
        (not (decide_equivalence (p "−S+P") (p "−P+S")).equivalent)
        "no A-conversion");
  test "?= caps the union, not each input, before truth-table enumeration"
    (fun () ->
      let left = p "+(+a+b+c+d+e+f+g+h)+i" in
      let right = p "+(+j+k+l+m+n+o+p)+q" in
      let r = decide_equivalence left right in
      check (r.e_method = "rewrite") "17 union atoms must bypass DNF";
      check (not r.equivalent) "the disjoint conjunctions are not rewrites";
      check (r.atoms = None && r.dnf = None) "no oversized truth table");
  test "?= bounds DNF bytes even when 16 long atom names fit the atom cap"
    (fun () ->
      let names =
        List.init 16 (fun i ->
            Printf.sprintf "p%02d_%s" i (String.make 60 (Char.chr (97 + i))))
      in
      let conjunction =
        String.concat "" (List.map (fun name -> "+" ^ name) names)
      in
      (* X -> X is true on every assignment, so the former implementation
         materialized all 65,536 long rows even when comparing it to itself. *)
      let tautology = p ("−(" ^ conjunction ^ ")+(" ^ conjunction ^ ")") in
      let r = decide_equivalence tautology tautology in
      check (r.e_method = "rewrite") "oversized DNF must use rewrite";
      check r.equivalent "the bounded rewrite still recognizes identity";
      check (r.atoms = None && r.dnf = None) "no DNF was materialized";
      check (r.e_path = Some []) "identity carries the empty rewrite path");
  test "?= bounds truth-table evaluation work for wide formulas" (fun () ->
      let names = List.init 16 (fun i -> Printf.sprintf "p%d" i) in
      let repeated =
        List.init 12 (fun _ -> names)
        |> List.flatten
        |> List.map (fun name -> "+" ^ name)
        |> String.concat ""
      in
      let tautology = p ("−(" ^ repeated ^ ")+(" ^ repeated ^ ")") in
      let r = decide_equivalence tautology tautology in
      check (r.e_method = "rewrite") "excessive evaluation must use rewrite";
      check r.equivalent "the work fallback still recognizes identity");

  (* statement_model *)
  test "statementModel: propositional only — general terms opt out" (fun () ->
      check (statement_model (p "−p+q") <> None) "propositional in";
      check (statement_model (p "−Dog+Mammal") = None) "uppercase out";
      check (statement_model (p "±Socrates*+Wise") = None) "singular out");
  test "statementModel agrees with the oracle on the one-world reading"
    (fun () ->
      match statement_model (p "−p+q") with
      | Some (_, sat) ->
          let asg p_v q_v name = if name = "p" then p_v else q_v in
          check (not (sat (asg true false))) "p→q false at p,¬q";
          check (sat (asg true true)) "true at p,q";
          check (sat (asg false false)) "true at ¬p,¬q"
      | None -> failwith "no model");

  finish "program unit tests"
