(* Robustness (PLAN 1.14): the total API under adversarial input.

   The threat is concrete — from Phase 4 on, everything this engine parses was
   written by a language model, so it will arrive truncated, in FOL notation,
   in prose, in the wrong encoding, or nested past any sane depth. The contract
   `Tfl.Safe` has to hold on all of it:

     1. no escaping exception — every call returns a result;
     2. no unbounded run — nothing takes more than a second;
     3. no `Internal` failure — that class means the engine broke rather than
        the input being bad, so a single one is a bug, not a data point;
     4. positions stay inside the source, and refusals are classified by where
        they came from, not by their text.

   Plus the pinned adversarial probe from the 2026-07-30 audit for the
   find_cancellation work cap (1.14d). *)

module G = QCheck2.Gen

let cases = ref 0
let slowest = ref 0.0
let slowest_input = ref ""

(* Every check runs through here: it is the one place that knows what "safe"
   means, so a generator can only make inputs, never weaken assertions. *)
let safe_on (src : string) : string option =
  let t0 = Unix.gettimeofday () in
  let outcome = Tfl.Safe.parse src in
  let elapsed = Unix.gettimeofday () -. t0 in
  incr cases;
  if elapsed > !slowest then (
    slowest := elapsed;
    slowest_input := src);
  if elapsed > 1.0 then
    Some (Printf.sprintf "took %.3fs on a %d-byte input" elapsed (String.length src))
  else
    match outcome with
    | Ok _ -> None
    | Error { kind = Tfl.Safe.Internal; message; _ } ->
        Some (Printf.sprintf "Internal failure (%s)" message)
    | Error { pos = Some p; _ } when p < 0 || p > String.length src ->
        Some (Printf.sprintf "position %d outside a %d-byte source" p (String.length src))
    | Error { kind = Tfl.Safe.Outside_fragment; pos = Some p; _ } ->
        Some (Printf.sprintf "a fragment refusal carried a source position (%d)" p)
    | Error _ -> None

let gate name ~count ~print gen f =
  QCheck2.Test.make ~count ~name ~print gen (fun x ->
      match f x with
      | None -> true
      | Some d ->
          Printf.eprintf "✗ %s: %s\n" name d;
          false)

(* ── Adversarial generators ─────────────────────────────────────────────── *)

(* Random bytes, including invalid UTF-8 and control characters: the parser's
   decoder has to survive them and report a position. *)
let random_bytes =
  let open G in
  let* n = int_bound 120 in
  let* chars = list_size (return n) (map Char.chr (int_bound 255)) in
  return (String.init (List.length chars) (List.nth chars))

(* Truncations of real formulas — the single most likely LLM failure: a
   response cut off mid-token. Cutting on a byte index also slices UTF-8
   sequences in half, which is the point. *)
let truncated =
  let open G in
  let* p = Gen.prop_gen in
  let printed = Tfl.Notation.print_proposition p in
  let* cut = int_bound (String.length printed) in
  return (String.sub printed 0 cut)

(* Nesting far past the depth cap, in both bracket flavours, balanced and not. *)
let deep_nesting =
  let open G in
  let* depth = int_range 1 3_000 in
  let* bracket = oneof_list [ ("(", ")"); ("[", "]") ] in
  let* balanced = bool in
  let opening, closing = bracket in
  let core = "+A+B" in
  return
    (String.concat "" (List.init depth (fun _ -> opening))
    ^ core
    ^ if balanced then String.concat "" (List.init depth (fun _ -> closing)) else "")

(* Pathological lengths: one enormous name, or an enormous run of tokens. *)
let pathological =
  let open G in
  let* n = int_range 1_000 20_000 in
  let* shape = int_bound 2 in
  return
    (match shape with
    | 0 -> "+" ^ String.make n 'A' ^ "+B"
    | 1 -> String.concat "" (List.init n (fun _ -> "+A"))
    | _ -> "+\"" ^ String.make n 'x' ^ "\"+B")

(* ── The gates ──────────────────────────────────────────────────────────── *)

let fuzz_bytes =
  gate "safe: random bytes" ~count:30_000 ~print:String.escaped random_bytes
    safe_on

let fuzz_tokens =
  gate "safe: random notation tokens" ~count:20_000 ~print:String.escaped
    Gen.token_string_gen safe_on

let fuzz_truncations =
  gate "safe: truncated formulas" ~count:30_000 ~print:String.escaped truncated
    safe_on

let fuzz_deep =
  gate "safe: nesting past the depth cap" ~count:10_000
    ~print:(fun s -> Printf.sprintf "<%d bytes>" (String.length s))
    deep_nesting safe_on

let fuzz_pathological =
  gate "safe: pathological lengths" ~count:2_000
    ~print:(fun s -> Printf.sprintf "<%d bytes>" (String.length s))
    pathological safe_on

(* check/2 over garbage on both sides: the failure has to name which input it
   came from, and a refusal must never surface as a verdict. *)
let fuzz_check =
  gate "safe: check over garbage premises and conclusions" ~count:10_000
    ~print:(fun (ps, c) -> String.concat " ; " (List.map String.escaped ps) ^ " ⊢ " ^ String.escaped c)
    (let open G in
     let src = oneof [ random_bytes; Gen.token_string_gen; truncated ] in
     let* n = int_range 1 3 in
     let* premises = list_size (return n) src in
     let* conclusion = src in
     return (premises, conclusion))
    (fun (premises, conclusion) ->
      let t0 = Unix.gettimeofday () in
      let outcome = Tfl.Safe.check ~premises ~conclusion in
      let elapsed = Unix.gettimeofday () -. t0 in
      incr cases;
      if elapsed > 1.0 then Some (Printf.sprintf "took %.3fs" elapsed)
      else
        match outcome with
        | Ok _ -> None
        | Error { kind = Tfl.Safe.Internal; message; _ } ->
            Some (Printf.sprintf "Internal failure (%s)" message)
        | Error { where = None; _ } ->
            Some "a failure did not say which input it came from"
        | Error _ -> None)

(* ── Contract unit checks ───────────────────────────────────────────────── *)

let unit_checks () =
  let open Harness in
  let kind_of src =
    match Tfl.Safe.parse src with
    | Ok _ -> "ok"
    | Error f -> Tfl.Safe.kind_name f.kind
  in
  test "a well-formed proposition parses" (fun () ->
      check (kind_of "−S+P" = "ok") "−S+P should parse");
  test "an unreadable character is lexical" (fun () ->
      check (kind_of "+A+\xff\xfe" = "lexical") "invalid UTF-8 is lexical";
      check (kind_of "+É+P" = "lexical") "a non-ASCII bare name is lexical");
  test "legal tokens that do not form a proposition are syntactic" (fun () ->
      check (kind_of "+A" = "syntactic") "a proposition needs two signed terms";
      check (kind_of "+A+(B" = "syntactic") "an unclosed group is syntactic";
      check (kind_of "+A+B+C" = "syntactic") "trailing input is syntactic");
  test "a parsed proposition the fragment refuses is outside_fragment" (fun () ->
      (* ± on a general subject parses fine and validation rejects it. *)
      check
        (match Tfl.Safe.check ~premises:[ "±A+B" ] ~conclusion:"−S+P" with
        | Error { kind = Tfl.Safe.Outside_fragment; _ } -> true
        | _ -> false)
        "±A+B should be refused by the fragment, not the parser";
      (* The procedure guard the 1.12 arbitrary-shape gate surfaced: a legal
         proposition whose level has no categorical route. *)
      check
        (match
           Tfl.Safe.check ~premises:[ "+a^1+(+a+a)" ] ~conclusion:"+a+a"
         with
        | Error { kind = Tfl.Safe.Outside_fragment; _ } -> true
        | _ -> false)
        "a levelled non-categorical argument is a fragment refusal");
  test "the depth cap admits legitimate nesting and refuses the rest" (fun () ->
      let nest d = String.concat "" (List.init d (fun _ -> "(")) ^ "A"
                   ^ String.concat "" (List.init d (fun _ -> ")")) in
      check (kind_of ("+" ^ nest 60 ^ "+B") = "ok") "60 levels still parses";
      check (kind_of ("+" ^ nest 200 ^ "+B") = "syntactic") "200 levels is refused");
  test "failures name the input they came from" (fun () ->
      match Tfl.Safe.check ~premises:[ "−S+P"; "!!" ] ~conclusion:"−S+P" with
      | Error { where = Some w; _ } -> check_eq w "premise 2"
      | _ -> failwith "expected a failure naming premise 2")

(* ── 1.14(d): the cancellation work cap ─────────────────────────────────────
   The 2026-07-30 audit's probe: an inconsistent set whose clash can never
   cancel, plus u disjoint junk universals the re-use search must explore.
   Uncapped this is 4^u nodes — measured 1.9s at u=11 and ×4 per premise after
   that, so ~days at u=20. The verdict is decided before the search runs, so
   the cap can only cost the certificate its decoration. *)
let cancellation_probe () =
  let open Harness in
  let props u =
    List.map Tfl.Notation.parse_proposition
      ([ "+A+B"; "−B−B" ]
      @ List.init u (fun i -> Printf.sprintf "−J%d+K%d" i i))
  in
  test "the cancellation search is capped (20 junk universals, <1s)" (fun () ->
      let t0 = Unix.gettimeofday () in
      let certificate = Tfl.Decide.check_inconsistent (props 20) in
      let elapsed = Unix.gettimeofday () -. t0 in
      check (elapsed < 1.0)
        (Printf.sprintf "the capped search took %.3fs" elapsed);
      match certificate with
      | None -> failwith "the set is inconsistent; the closure should say so"
      | Some c ->
          check (c.cancellation = None)
            "past the budget the certificate reports no cancellation");
  (* The probe's own pair can never cancel — that is why the audit chose it —
     so the positive control needs a set that does: Barbara's counterclaim,
     where the particular and the two universals sum to zero per term. *)
  test "the cap does not cost ordinary sets their cancellation" (fun () ->
      let barbara_denied =
        List.map Tfl.Notation.parse_proposition [ "−M+P"; "−S+M"; "+S−P" ]
      in
      match Tfl.Decide.check_inconsistent barbara_denied with
      | Some { cancellation = Some c; _ } ->
          check
            (List.length c.universals = 2)
            "both universals should be in the cancellation"
      | _ -> failwith "Barbara's counterclaim should carry a cancellation")

let () =
  unit_checks ();
  cancellation_probe ();
  Harness.summarize "safe contract";
  let failures =
    QCheck_base_runner.run_tests ~verbose:true
      [
        fuzz_bytes; fuzz_tokens; fuzz_truncations; fuzz_deep; fuzz_pathological;
        fuzz_check;
      ]
  in
  Printf.printf "adversarial inputs: %d, slowest %.3fs on %d bytes\n" !cases
    !slowest
    (String.length !slowest_input);
  exit (if Harness.exit_code () <> 0 || failures <> 0 then 1 else 0)
