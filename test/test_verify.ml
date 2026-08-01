(* The verification API (PLAN 3.1). Threats guarded here:
   - a router treating Unknown as Invalid (the distinction is the interface's
     central contract);
   - JSON that does not survive the round trip — 4.x serializes results to
     disk and reads them back, so to_json/of_json must be exact inverses;
   - of_json raising on malformed payloads (it faces files, not just us);
   - a traceless verdict (the auditable-trace claim is a paper selling point);
   - trace numbering scrambled by evaluation order (caught live: [@] evaluated
     the conclusion's counter increment before the premises');
   - the 1.14 gap: deep nesting on the program-loading path must be a
     structured refusal, not a Stack_overflow. *)

open Harness

let v_name = function
  | Tfl_verify.Valid -> "valid"
  | Invalid -> "invalid"
  | Contradicted -> "contradicted"
  | Unknown -> "unknown"
  | Error e -> "error:" ^ Tfl_verify.class_name e.error_class

let run premises conclusion = Tfl_verify.check ~premises ~conclusion

let check_roundtrip r =
  match Tfl_verify.of_json (Tfl_verify.to_json r) with
  | Ok r' -> check (r' = r) "JSON round trip changed the record"
  | Error m -> check false ("of_json failed: " ^ m)

(* ── Verdicts, methods, traces, glosses ─────────────────────────────────── *)

(* Every decision method reachable from the public surface, each round-
   tripped through JSON as produced. *)
let case name premises conclusion verdict meth =
  test name (fun () ->
      let r = run premises conclusion in
      check
        (v_name r.verdict = verdict)
        (Printf.sprintf "expected %s, got %s" verdict (v_name r.verdict));
      check (Option.map Tfl_verify.meth_name r.meth = meth) "wrong method";
      check_roundtrip r)

let () =
  case "barbara/PZ" [ "-A+B"; "-B+C" ] "-A+C" "valid" (Some "PZ");
  case "invalid/PZ" [ "-A+B" ] "+A-B" "invalid" (Some "PZ");
  case "relational valid/derivation"
    [ "+S+(Lov+Girl)"; "-Girl+Human" ]
    "+S+(Lov+Human)" "valid" (Some "derivation");
  case "contradicted/derivation"
    [ "+S+(Lov+Girl)"; "-Girl+Human" ]
    "-S-(Lov+Human)" "contradicted" (Some "derivation");
  case "indirect"
    [ "+Boy+(Lov+Girl)"; "-Boy-(Lov+Coward)" ]
    "+Girl-Coward" "valid" (Some "indirect");
  case "unknown"
    [ "+Boy+(Lov+Girl)"; "-Boy-(Lov+Coward)" ]
    "+Girl+Coward" "unknown" (Some "derivation");
  case "numerical" [ "+H^1+I" ] "+H+I" "valid" (Some "numerical");
  case "lexical" [ "@@@" ] "-A+C" "error:lexical" None;
  case "syntactic" [ "-A+" ] "-A+C" "error:syntactic" None;
  case "outside" [ "±A+B" ] "-S+P" "error:outside_fragment" None

let glossed = List.for_all (fun (l : Tfl_verify.trace_line) -> l.gloss <> "")

let () =
  (* Unknown ≠ Invalid, asserted as a *difference*: same premises, and only
     the exact method's refusal may say "invalid". *)
  test "a search miss is Unknown, never Invalid" (fun () ->
      let u = run [ "+Boy+(Lov+Girl)"; "-Boy-(Lov+Coward)" ] "+Girl+Coward" in
      check (u.verdict = Tfl_verify.Unknown) "search miss is Unknown";
      check (u.verdict <> Tfl_verify.Invalid) "search miss is never Invalid");

  (* No verdict comes back traceless, and framing traces number premises
     before the conclusion (the evaluation-order pin). *)
  test "framing traces are numbered, ordered, and glossed" (fun () ->
      let framed = run [ "-A+B"; "-B+C" ] "-A+C" in
      check (framed.trace <> []) "PZ verdict carries a trace";
      check
        (List.map
           (fun (l : Tfl_verify.trace_line) -> (l.n, l.rule))
           framed.trace
        = [ (1, "premise"); (2, "premise"); (3, "conclusion") ])
        "framing trace numbers premises first, in order";
      check (glossed framed.trace) "every framing line carries a gloss");

  (* Proof-carrying traces come from the proof and end at the goal (or ⊥),
     with an explanation sentence. *)
  test "an indirect trace closes at ⊥ with parents and glosses" (fun () ->
      let ind = run [ "+Boy+(Lov+Girl)"; "-Boy-(Lov+Coward)" ] "+Girl-Coward" in
      check (ind.explanation <> None) "indirect proof carries an explanation";
      check (glossed ind.trace) "every proof line carries a gloss";
      match List.rev ind.trace with
      | last :: _ ->
          check (last.step = "\u{22A5}") "indirect trace closes at the ⊥ line";
          check
            (last.gloss = "which is impossible")
            "the ⊥ line glosses as an impossibility";
          check (last.parents <> []) "the ⊥ line names the clashing parents"
      | [] -> check false "indirect trace is empty");

  test "an error names the failing input and carries no method" (fun () ->
      let e = run [ "-A+B"; "-A+" ] "-A+C" in
      (match e.verdict with
      | Tfl_verify.Error i ->
          check (i.where = Some "premise 2") "the failing premise is named";
          check (i.pos <> None) "a parse failure carries a position"
      | _ -> check false "malformed premise 2 should be an error");
      check (e.meth = None) "errors carry no method")

(* ── JSON: synthetic corners the engine cannot produce today ────────────── *)

let () =
  test "a synthetic internal-error record survives the round trip" (fun () ->
      check_roundtrip
        {
          Tfl_verify.verdict =
            Tfl_verify.Error
              {
                error_class = Tfl_verify.Internal;
                message = "boom";
                pos = None;
                where = None;
              };
          meth = None;
          trace =
            [
              {
                n = 1;
                step = "\u{22A5}";
                gloss = "g";
                rule = "r";
                parents = [ 1; 2 ];
              };
            ];
          explanation = Some "e";
        });

  test "of_json is total on garbage" (fun () ->
      let bad j =
        match Tfl_verify.of_json j with Ok _ -> false | Error _ -> true
      in
      check (bad (`Assoc [ ("verdict", `Int 42) ])) "non-string verdict refused";
      check (bad (`Assoc [])) "empty object refused";
      check
        (bad
           (`Assoc
              [
                ("verdict", `String "valid");
                ("method", `String "telepathy");
                ("trace", `List []);
                ("explanation", `Null);
              ]))
        "unknown method name refused";
      check (bad (`String "valid")) "bare string refused")

(* ── Safe.parse_program: the 1.14 gap ───────────────────────────────────── *)

let nest d = String.concat "" (List.init d (fun _ -> "(")) ^ "A"

let () =
  test "a normal program parses and a bad line is collected, not fatal"
    (fun () ->
      match Tfl.Safe.parse_program "-A+B -- comment\n\n-A+\n-B+C" with
      | Ok p ->
          check (List.length p.propositions = 2) "two good program lines parsed";
          check (List.length p.errors = 1) "the bad line is collected"
      | Error _ -> check false "a normal program should parse");

  test "nesting past the cap is a structured per-line refusal" (fun () ->
      match Tfl.Safe.parse_program ("-A+B\n" ^ nest 100) with
      | Error { kind = Tfl.Safe.Syntactic; where = Some w; _ } ->
          check (w = "line 2") "the deep line is named"
      | _ -> check false "100 levels should be a syntactic refusal");

  (* at the depth that overflowed the stack (measured at 200k; LOG
     2026-08-01) it must still be that refusal, not a crash *)
  test "300k levels is still a refusal, not a crash" (fun () ->
      match Tfl.Safe.parse_program (nest 300_000) with
      | Error { kind = Tfl.Safe.Syntactic; _ } -> ()
      | Ok _ -> check false "300k levels accepted"
      | Error _ -> check false "300k levels misclassified");

  (* The depth pass decodes and tokenizes each line itself, ahead of the
     parser — so it is a second place hostile bytes reach, and it must be as
     total as the parser is. Each of these is a per-line recorded error, not
     a raise and not a whole-program refusal. *)
  test "hostile bytes stay per-line errors, never a raise" (fun () ->
      List.iter
        (fun (name, src) ->
          match Tfl.Safe.parse_program src with
          | Ok _ -> ()
          | Error _ -> check false (name ^ ": refused the whole program")
          | exception e ->
              check false (name ^ ": raised " ^ Printexc.to_string e))
        [
          ("invalid utf-8", "\xff\xfe\xfd");
          ("lone surrogate", "\xed\xa0\x80");
          ("nul bytes", "\x00\x00\n\x00");
          ("control chars", "\x01\x02\x1b[31m");
          ("deep line with invalid bytes", nest 100 ^ "\xff");
        ])

let () = finish "test_verify"
