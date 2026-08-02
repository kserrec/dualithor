(* PLAN 4.3 — the harness's classification step, tested without a network call.

   The threat here is misattribution, and it is silent. If a formula is paired
   with the wrong sentence, every downstream number still computes: the parse
   rate looks fine, the back-check compares a formula against a sentence it was
   never meant for, and the fidelity audit measures nothing. Nothing later in
   the pipeline can detect it. So the matching rule is pinned here — including
   its deliberate refusals, which are as load-bearing as its matches. *)

open Harness
open Translate

let payload translations untranslatable : Schema.payload =
  {
    translations =
      List.map
        (fun (nl, tfl, confidence) : Schema.translation -> { nl; tfl; confidence })
        translations;
    untranslatable =
      List.map (fun (nl, reason) : Schema.untranslatable -> { nl; reason }) untranslatable;
  }

let outcome_name (o : Translator.outcome) =
  match o with
  | Translated _ -> "translated"
  | Unparseable _ -> "unparseable"
  | Declined _ -> "declined"
  | Absent -> "absent"

let classify_one sentence p =
  match Translator.classify p [ sentence ] with
  | [ item ], extra -> (item.outcome, extra)
  | _ -> failwith "classify returned the wrong number of items"

let expect name sentence p want =
  test name (fun () ->
      let got, _ = classify_one sentence p in
      check_eq (outcome_name got) want)

(* ── The four outcomes ─────────────────────────────────────────────────── *)

let () =
  expect "a well-formed formula translates" "Every auditor is an employee."
    (payload [ ("Every auditor is an employee.", "-Auditor+Employee", 0.9) ] [])
    "translated";
  (* A malformed formula must survive as data carrying its taxonomy class —
     discarding it would erase the distinction the router claim is built on. *)
  test "a malformed formula is kept, with its taxonomy class" (fun () ->
      let got, _ =
        classify_one "Every auditor is an employee."
          (payload [ ("Every auditor is an employee.", "-Auditor+", 0.4) ] [])
      in
      match got with
      | Unparseable { tfl; failure; confidence } ->
          check_eq tfl "-Auditor+";
          check (confidence = 0.4) "confidence not carried through";
          check
            (List.mem (Tfl.Safe.kind_name failure.kind) [ "lexical"; "syntactic" ])
            ("expected a parse class, got " ^ Tfl.Safe.kind_name failure.kind)
      | other -> failwith ("expected unparseable, got " ^ outcome_name other));
  expect "a declined sentence is a first-class outcome"
    "The report was filed before the deadline."
    (payload [] [ ("The report was filed before the deadline.", "tense") ])
    "declined";
  (* Without this, a model that quietly drops a sentence shrinks the
     denominator and flatters every rate we report. *)
  expect "a dropped sentence is reported, not forgotten" "Every auditor is an employee."
    (payload [ ("Some contractor works for a subsidiary.", "+C+(Work+S)", 0.8) ] [])
    "absent"

(* ── The matching rule, and what it refuses ────────────────────────────── *)

let () =
  expect "case and whitespace differences still match"
    "Every  auditor is an employee."
    (payload [ ("every auditor is an employee.", "-Auditor+Employee", 0.9) ] [])
    "translated";
  expect "leading and trailing whitespace still match" "Every auditor is an employee."
    (payload [ ("\n  Every auditor is an employee.  ", "-Auditor+Employee", 0.9) ] [])
    "translated";
  (* The refusal that matters: a paraphrase is not a match. Pairing a formula
     with a sentence it may not be about is worse than reporting nothing,
     because nothing downstream can detect it. *)
  expect "a paraphrase does NOT match — absent beats a wrong pairing"
    "Every auditor is an employee."
    (payload [ ("All auditors are employees.", "-Auditor+Employee", 0.9) ] [])
    "absent";
  test "an unmatched reply is surfaced as extra, not silently dropped" (fun () ->
      let _, extra =
        classify_one "Every auditor is an employee."
          (payload [ ("All auditors are employees.", "-Auditor+Employee", 0.9) ] [])
      in
      check_eq (String.concat "|" extra) "All auditors are employees.")

(* ── Ordering, duplicates, and the counts ──────────────────────────────── *)

let () =
  test "items come back in input order, whatever order the model answered in"
    (fun () ->
      let sentences = [ "First."; "Second."; "Third." ] in
      let p =
        payload
          [ ("Third.", "-C+D", 0.7); ("First.", "-A+B", 0.9) ]
          [ ("Second.", "tense") ]
      in
      let items, _ = Translator.classify p sentences in
      check_eq
        (String.concat "," (List.map (fun (i : Translator.item) -> i.nl) items))
        "First.,Second.,Third.";
      check_eq
        (String.concat "," (List.map (fun i -> outcome_name i.Translator.outcome) items))
        "translated,declined,translated");
  test "a repeated sentence uses the first answer and surfaces the duplicate"
    (fun () ->
      let p =
        payload
          [ ("Every auditor is an employee.", "-Auditor+Employee", 0.9);
            ("Every auditor is an employee.", "-Auditor+Manager", 0.2) ]
          []
      in
      let items, extra = Translator.classify p [ "Every auditor is an employee." ] in
      (match (List.hd items).outcome with
      | Translated { tfl; _ } -> check_eq tfl "-Auditor+Employee"
      | other -> failwith ("expected translated, got " ^ outcome_name other));
      check (List.length extra = 1) "the duplicate should surface as extra");
  (* parse_rate is over attempted translations only: folding declines in would
     let a model raise its score by declining everything difficult. *)
  test "parse rate counts attempts, not declines" (fun () ->
      let sentences = [ "a"; "b"; "c"; "d" ] in
      let p =
        payload
          [ ("a", "-A+B", 0.9); ("b", "-A+", 0.5); ("c", "-C+D", 0.8) ]
          [ ("d", "tense") ]
      in
      let items, _ = Translator.classify p sentences in
      let s = Translator.stats items in
      check (s.total = 4 && s.translated = 2 && s.unparseable = 1 && s.declined = 1)
        (Printf.sprintf "counts wrong: %d/%d/%d/%d" s.total s.translated s.unparseable
           s.declined);
      match Translator.parse_rate s with
      | Some r -> check (Float.abs (r -. (2. /. 3.)) < 1e-9) "expected 2/3"
      | None -> failwith "expected a rate");
  test "parse rate is absent when nothing was attempted" (fun () ->
      let items, _ = Translator.classify (payload [] [ ("a", "tense") ]) [ "a" ] in
      check (Translator.parse_rate (Translator.stats items) = None)
        "an all-declined run has no parse rate")

let () = finish "translator harness"
