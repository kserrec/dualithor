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

let failures = ref 0

let check b msg =
  if not b then (
    incr failures;
    print_endline ("FAIL: " ^ msg))

let v_name = function
  | Tfl_verify.Valid -> "valid"
  | Invalid -> "invalid"
  | Contradicted -> "contradicted"
  | Unknown -> "unknown"
  | Error e -> "error:" ^ Tfl_verify.class_name e.error_class

let run premises conclusion = Tfl_verify.check ~premises ~conclusion

let expect premises conclusion verdict meth name =
  let r = run premises conclusion in
  check
    (v_name r.verdict = verdict)
    (Printf.sprintf "%s: expected %s, got %s" name verdict (v_name r.verdict));
  check
    (Option.map Tfl_verify.meth_name r.meth = meth)
    (Printf.sprintf "%s: wrong method" name);
  r

let roundtrip r name =
  match Tfl_verify.of_json (Tfl_verify.to_json r) with
  | Ok r' -> check (r' = r) (name ^ ": JSON round trip changed the record")
  | Error m -> check false (name ^ ": of_json failed: " ^ m)

(* ── Verdicts, methods, traces, glosses ─────────────────────────────────── *)

let () =
  (* Every decision method reachable from the public surface, each round-
     tripped through JSON as produced. *)
  let cases =
    [
      ("barbara/PZ", [ "-A+B"; "-B+C" ], "-A+C", "valid", Some "PZ");
      ("invalid/PZ", [ "-A+B" ], "+A-B", "invalid", Some "PZ");
      ( "relational valid/derivation",
        [ "+S+(Lov+Girl)"; "-Girl+Human" ],
        "+S+(Lov+Human)",
        "valid",
        Some "derivation" );
      ( "contradicted/derivation",
        [ "+S+(Lov+Girl)"; "-Girl+Human" ],
        "-S-(Lov+Human)",
        "contradicted",
        Some "derivation" );
      ( "indirect",
        [ "+Boy+(Lov+Girl)"; "-Boy-(Lov+Coward)" ],
        "+Girl-Coward",
        "valid",
        Some "indirect" );
      ( "unknown",
        [ "+Boy+(Lov+Girl)"; "-Boy-(Lov+Coward)" ],
        "+Girl+Coward",
        "unknown",
        Some "derivation" );
      ("numerical", [ "+H^1+I" ], "+H+I", "valid", Some "numerical");
      ("lexical", [ "@@@" ], "-A+C", "error:lexical", None);
      ("syntactic", [ "-A+" ], "-A+C", "error:syntactic", None);
      ("outside", [ "±A+B" ], "-S+P", "error:outside_fragment", None);
    ]
  in
  List.iter
    (fun (name, ps, c, verdict, meth) ->
      roundtrip (expect ps c verdict meth name) name)
    cases;

  (* Unknown ≠ Invalid, asserted as a *difference*: same premises, and only
     the exact method's refusal may say "invalid". *)
  let u = run [ "+Boy+(Lov+Girl)"; "-Boy-(Lov+Coward)" ] "+Girl+Coward" in
  check (u.verdict = Tfl_verify.Unknown) "search miss is Unknown";
  check (u.verdict <> Tfl_verify.Invalid) "search miss is never Invalid";

  (* No verdict comes back traceless, and framing traces number premises
     before the conclusion (the evaluation-order pin). *)
  let framed = run [ "-A+B"; "-B+C" ] "-A+C" in
  check (framed.trace <> []) "PZ verdict carries a trace";
  check
    (List.map (fun (l : Tfl_verify.trace_line) -> (l.n, l.rule)) framed.trace
    = [ (1, "premise"); (2, "premise"); (3, "conclusion") ])
    "framing trace numbers premises first, in order";
  let glossed =
    List.for_all (fun (l : Tfl_verify.trace_line) -> l.gloss <> "")
  in
  check (glossed framed.trace) "every framing line carries a gloss";

  (* Proof-carrying traces come from the proof and end at the goal (or ⊥),
     with an explanation sentence. *)
  let ind = run [ "+Boy+(Lov+Girl)"; "-Boy-(Lov+Coward)" ] "+Girl-Coward" in
  check (ind.explanation <> None) "indirect proof carries an explanation";
  check (glossed ind.trace) "every proof line carries a gloss";
  (match List.rev ind.trace with
  | last :: _ ->
      check (last.step = "\u{22A5}") "indirect trace closes at the ⊥ line";
      check
        (last.gloss = "which is impossible")
        "the ⊥ line glosses as an impossibility";
      check (last.parents <> []) "the ⊥ line names the clashing parents"
  | [] -> check false "indirect trace is empty");

  (* Error records name the failing input. *)
  let e = run [ "-A+B"; "-A+" ] "-A+C" in
  (match e.verdict with
  | Tfl_verify.Error i ->
      check (i.where = Some "premise 2") "the failing premise is named";
      check (i.pos <> None) "a parse failure carries a position"
  | _ -> check false "malformed premise 2 should be an error");
  check (e.meth = None) "errors carry no method";

  (* ── JSON: synthetic corners the engine cannot produce today ──────────── *)
  let synth =
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
    }
  in
  roundtrip synth "synthetic internal-error record";

  (* of_json is total on garbage. *)
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
  check (bad (`String "valid")) "bare string refused"

(* ── Safe.parse_program: the 1.14 gap ───────────────────────────────────── *)

let () =
  (* A normal program still parses, and a bad line is collected, not fatal. *)
  (match Tfl.Safe.parse_program "-A+B -- comment\n\n-A+\n-B+C" with
  | Ok p ->
      check (List.length p.propositions = 2) "two good program lines parsed";
      check (List.length p.errors = 1) "the bad line is collected"
  | Error _ -> check false "a normal program should parse");

  (* Nesting past the cap is a structured per-line refusal… *)
  let nest d = String.concat "" (List.init d (fun _ -> "(")) ^ "A" in
  (match Tfl.Safe.parse_program ("-A+B\n" ^ nest 100) with
  | Error { kind = Tfl.Safe.Syntactic; where = Some w; _ } ->
      check (w = "line 2") "the deep line is named"
  | _ -> check false "100 levels should be a syntactic refusal");

  (* …and at the depth that overflowed the stack (measured at 200k; LOG
     2026-08-01) it must still be that refusal, not a crash. *)
  match Tfl.Safe.parse_program (nest 300_000) with
  | Error { kind = Tfl.Safe.Syntactic; _ } -> ()
  | Ok _ -> check false "300k levels accepted"
  | Error _ -> check false "300k levels misclassified"

let () =
  if !failures > 0 then (
    Printf.printf "test_verify: %d failure(s)\n" !failures;
    exit 1)
  else print_endline "test_verify: all checks passed"
