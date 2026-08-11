open Harness
open Tfl.Runtime

let compile_ok source =
  match compile source with
  | Ok program -> program
  | Error failures ->
      failwith
        (String.concat "; "
           (List.map
              (fun (failure : Tfl.Safe.failure) -> failure.message)
              failures))

let has_evidence predicate evidence = List.exists predicate evidence

let () =
  test "compile accepts only a complete program and returns stable views"
    (fun () ->
      let program =
        compile_ok
          "−Man+Animal -- classification\n\n±Socrates*+Man\n−Man+Mortal"
      in
      match statements program with
      | [ first; second; third ] ->
          check (first.line = 1) "first source line";
          check_eq first.source "−Man+Animal";
          check_eq first.source_line "−Man+Animal -- classification";
          check
            (first.span.start_pos.codepoint_offset = 0
            && first.span.start_pos.line = 1
            && first.span.start_pos.column = 1
            && first.span.end_pos.codepoint_offset = 11
            && first.span.end_pos.line = 1
            && first.span.end_pos.column = 12)
            "the statement carries its half-open source span";
          check_eq first.proposition.tfl "−Man+Animal";
          check_eq first.proposition.canonical "−Man+Animal";
          check_eq first.proposition.english "every man is animal";
          check
            (second.line = 3
            && second.span.start_pos.codepoint_offset = 31
            && third.line = 4)
            "blank lines advance the absolute code-point offset"
      | _ -> failwith "expected three compiled statements");
  test "compile reports every malformed source line and produces no program"
    (fun () ->
      match compile "−Man+Animal\n+oops(\n+É+P\n−Dog+Animal" with
      | Ok _ -> failwith "a partial program must never compile"
      | Error [ first; second ] ->
          check (first.where = Some "line 2") "first malformed line";
          check (first.kind = Tfl.Safe.Syntactic) "line 2 is syntactic";
          check (second.where = Some "line 3") "second malformed line";
          check (second.kind = Tfl.Safe.Lexical) "line 3 is lexical";
          check
            (first.span <> None
            && Option.map
                 (fun span -> span.Tfl.Source.start_pos.column)
                 first.span
               = Some 6
            && first.source_line = Some "+oops(")
            "syntax errors retain the offending token and physical line";
          check
            (Option.map
               (fun span -> span.Tfl.Source.start_pos.column)
               second.span
             = Some 2
            && Option.map
                 (fun span -> span.Tfl.Source.end_pos.column)
                 second.span
               = Some 3
            && second.source_line = Some "+É+P")
            "lexical spans count Unicode code points rather than UTF-8 bytes"
      | Error failures ->
          failwith
            (Printf.sprintf "expected two diagnostics, got %d"
               (List.length failures)));
  test "compile attributes fragment validation to the source line" (fun () ->
      match compile "−Man+Animal\n±General+Thing" with
      | Error [ failure ] ->
          check (failure.kind = Tfl.Safe.Outside_fragment) "fragment class";
          check (failure.where = Some "line 2") "fragment line"
      | _ -> failwith "the invalid program should be refused");
  test "compile merges parse and validation failures in source order" (fun () ->
      match compile "−Man+Animal\n+oops(\n±General+Thing" with
      | Error [ first; second ] ->
          check (first.kind = Tfl.Safe.Syntactic) "line 2 is syntactic";
          check (first.where = Some "line 2") "parse failure comes first";
          check
            (second.kind = Tfl.Safe.Outside_fragment)
            "line 3 is outside the fragment";
          check (second.where = Some "line 3") "validation failure comes second"
      | Error failures ->
          failwith
            (Printf.sprintf "expected two diagnostics, got %d"
               (List.length failures))
      | Ok _ -> failwith "the mixed-invalid program should be refused");
  test "ground query exposes canonical text, completeness, and a certificate"
    (fun () ->
      let program = compile_ok "±Socrates*+Man\n−Man+Animal\n−Man+Mortal" in
      match query program "+-Socrates*+Mortal" with
      | Error failure -> failwith failure.message
      | Ok result -> (
          check (result.verdict = Yes) "supported query";
          check (result.method_ = PZ) "P/Z method";
          check result.completeness.complete "P/Z is complete";
          check_eq result.query.canonical "+Mortal+Socrates*";
          check_eq result.query.english "Socrates is a mortal";
          match result.support with
          | Some support ->
              check_eq support.proposition.english "Socrates is a mortal";
              check
                (has_evidence
                   (function Closure_certificate _ -> true | _ -> false)
                   support.evidence)
                "closure certificate"
          | None -> failwith "a yes answer needs support"));
  test "atomic open-world unknown is explicitly complete" (fun () ->
      let program = compile_ok "±Fido*+Dog\n−Dog+Animal\n−Man+Mortal" in
      match query program "±Fido*+Mortal" with
      | Ok result ->
          check (result.verdict = Unknown) "neither side follows";
          check (result.method_ = PZ) "complete atomic method";
          check result.completeness.complete "complete open-world result";
          check (result.support = None) "unknown has no fabricated support"
      | Error failure -> failwith failure.message);
  test "non-atomic unknown retains bounded-search incompleteness" (fun () ->
      let program = compile_ok "+Boy+(Lov+Girl)\n−Boy−(Lov+Coward)" in
      match query program "+Girl+Coward" with
      | Ok result ->
          check (result.verdict = Unknown) "unknown";
          check (not result.completeness.complete) "incomplete";
          check
            (result.completeness.reason = Some Bounded_search)
            "bounded-search reason"
      | Error failure -> failwith failure.message);
  test "query work exhaustion is attributed and does not poison the program"
    (fun () ->
      let pathological =
        "+("
        ^ String.concat "" (List.init 32 (fun _ -> "+A"))
        ^ ")+P"
      in
      let program = compile_ok (pathological ^ "\n−M+P") in
      (match query program "−X+Y" with
      | Error failure ->
          check (failure.kind = Tfl.Safe.Resource_limit) "resource class";
          check (failure.where = Some "query") "query attribution";
          check
            (failure.message =
             Tfl.Derive.work_limit_message Tfl.Derive.default_max_work)
            "named inference budget"
      | Ok _ -> failwith "the pathological query should exhaust its work budget");
      match query program "−M+P" with
      | Ok result -> check (result.verdict = Yes) "following query succeeds"
      | Error failure -> failwith failure.message);
  test "numerical support remains explicitly incomplete" (fun () ->
      let program = compile_ok "+C^3-H\n-C+E" in
      match query program "-E+H" with
      | Ok result -> (
          check (result.verdict = No) "the contradictory is supported";
          check (result.method_ = Numerical) "numerical method";
          check
            (result.completeness.reason = Some Numerical_rule_set)
            "numerical incompleteness";
          match result.support with
          | Some support ->
              check_eq support.proposition.tfl "+E−H";
              check
                (has_evidence
                   (function Numerical_decision _ -> true | _ -> false)
                   support.evidence)
                "numerical decision record"
          | None -> failwith "a no answer needs contradictory support")
      | Error failure -> failwith failure.message);
  test "term descriptions carry a proof for every answer" (fun () ->
      let program = compile_ok "±Socrates*+Man\n−Man+Animal\n−Man+Mortal" in
      match describe program "Socrates*" with
      | Error failure -> failwith failure.message
      | Ok result ->
          check (result.method_ = Bounded_saturation) "term method";
          check
            (result.completeness.reason = Some Bounded_term_saturation)
            "term incompleteness";
          check
            (List.map (fun answer -> answer.proposition.tfl) result.answers
            = [ "±Socrates*+Animal"; "±Socrates*+Man"; "±Socrates*+Mortal" ])
            "deterministic answers";
          List.iter
            (fun answer ->
              check (answer.support.lines <> []) "answer proof is present";
              check
                (List.for_all (fun line -> line.tfl <> "") answer.support.lines)
                "proof lines carry canonical TFL")
            result.answers);
  test "a malformed term is a total, attributed failure" (fun () ->
      let program = compile_ok "−Man+Animal" in
      match describe program "Man(" with
      | Error failure ->
          check (failure.kind = Tfl.Safe.Syntactic) "term syntax";
          check (failure.where = Some "term") "term attribution";
          check
            (Option.map
               (fun span -> span.Tfl.Source.start_pos.column)
               failure.span
             = Some 4
            && Option.map
                 (fun span -> span.Tfl.Source.end_pos.column)
                 failure.span
               = Some 5
            && failure.source_line = Some "Man(")
            "query-input syntax carries its source excerpt and token range"
      | Ok _ -> failwith "the malformed term should fail");
  test "outside-fragment query failures retain the parsed proposition span"
    (fun () ->
      let program = compile_ok "−Man+Animal" in
      match query program "  ±General+Thing " with
      | Error failure ->
          check
            (failure.kind = Tfl.Safe.Outside_fragment)
            "the parsed proposition reaches fragment validation";
          check
            (Option.map
               (fun span -> span.Tfl.Source.start_pos.column)
               failure.span
             = Some 3
            && Option.map
                 (fun span -> span.Tfl.Source.end_pos.column)
                 failure.span
               = Some 17
            && failure.source_line = Some "  ±General+Thing ")
            "fragment validation points at the proposition, excluding \
             whitespace"
      | Ok _ -> failwith "the unsupported query should fail");
  test "future compiler and incomplete-operation classes stay distinct"
    (fun () ->
      check_eq (Tfl.Safe.kind_name Tfl.Safe.Name_resolution) "name_resolution";
      check_eq
        (Tfl.Safe.kind_name Tfl.Safe.Incomplete_search)
        "incomplete_search");
  test "consistency distinguishes exact and undetermined results" (fun () ->
      let inconsistent =
        compile_ok "±Socrates*+Man\n−Man+Mortal\n±Socrates*−Mortal"
      in
      (match check_consistency inconsistent with
      | Ok result ->
          check (result.status = Inconsistent) "inconsistent";
          check result.completeness.complete "atomic result is exact";
          check
            (has_evidence
               (function Proof _ -> true | _ -> false)
               result.evidence)
            "refutation proof"
      | Error failure -> failwith failure.message);
      let non_atomic = compile_ok "+Boy+(Lov+Girl)" in
      match check_consistency non_atomic with
      | Ok result ->
          check (result.status = Undetermined) "no contradiction found";
          check
            (result.completeness.reason = Some Bounded_refutation)
            "bounded refutation reason"
      | Error failure -> failwith failure.message);
  test "equivalence exposes complete truth tables and sound rewrite paths"
    (fun () ->
      (match equivalent ~left:"-[p]+[q]" ~right:"-p+q" with
      | Ok result ->
          check result.equivalent "truth-table equivalence";
          check (result.method_ = DNF) "DNF method";
          check result.completeness.complete "truth table is complete";
          check
            (has_evidence
               (function Truth_table _ -> true | _ -> false)
               result.evidence)
            "truth-table record"
      | Error failure -> failwith failure.message);
      match equivalent ~left:"-Dog+Mammal" ~right:"-(−Mammal)+(−Dog)" with
      | Ok result ->
          check result.equivalent "rewrite equivalence";
          check (result.method_ = Rewrite) "rewrite method";
          check
            (result.completeness.reason = Some Bounded_rewrite)
            "rewrite remains incomplete";
          check
            (has_evidence
               (function
                 | Rewrite_path [ "contrapositive" ] -> true | _ -> false)
               result.evidence)
            "rewrite path"
      | Error failure -> failwith failure.message);
  test "equivalence failures identify the offending side" (fun () ->
      (match equivalent ~left:"−S+P" ~right:"not TFL" with
      | Error failure -> check (failure.where = Some "right") "right syntax"
      | Ok _ -> failwith "the malformed right side should fail");
      (match equivalent ~left:"−S+P" ~right:"±General+Thing" with
      | Error failure ->
          check
            (failure.kind = Tfl.Safe.Outside_fragment)
            "right fragment class";
          check (failure.where = Some "right") "right fragment attribution"
      | Ok _ -> failwith "the unsupported right side should fail");
      match equivalent ~left:"±General+Thing" ~right:"−S+P" with
      | Error failure ->
          check (failure.kind = Tfl.Safe.Outside_fragment) "left fragment class";
          check (failure.where = Some "left") "left fragment attribution"
      | Ok _ -> failwith "the unsupported left side should fail");
  finish "public runtime tests"
