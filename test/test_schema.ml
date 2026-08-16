(* PLAN 4.1 — the translation contract's validator.

   The threat this guards is quiet, not loud: a payload the validator waves
   through when it should not becomes a translation we score, and a payload it
   rejects when it should not becomes a translation failure charged to the
   model. Both corrupt the parse-rate and fidelity numbers the paper reports,
   and neither announces itself. So the cases below come in pairs — what must
   be accepted, and what must be refused — and the refusals are checked for
   naming *which* field went wrong, because that reason is the only evidence
   we will have when a model's rate collapses mid-run. *)

open Harness
open Translate.Schema

let ok name raw f =
  test name (fun () ->
      match of_string raw with
      | Error why -> failwith (Printf.sprintf "%s: rejected — %s" name why)
      | Ok p -> f p)

(* [needle] must appear in the reason: a rejection that does not say where is
   as good as no rejection when we are reading a run log. *)
let rejects name raw needle =
  test name (fun () ->
      match of_string raw with
      | Ok _ ->
          failwith (Printf.sprintf "%s: accepted a malformed payload" name)
      | Error why ->
          let contains hay nee =
            let n = String.length nee and h = String.length hay in
            let rec go i =
              i + n <= h && (String.sub hay i n = nee || go (i + 1))
            in
            n = 0 || go 0
          in
          check (contains why needle)
            (Printf.sprintf "%s: reason %S does not mention %S" name why needle))

(* ── Accepted ──────────────────────────────────────────────────────────── *)

let full =
  {|{"translations": [{"nl": "Every horse is an animal.", "tfl": "-Horse+Animal", "confidence": 0.9},
                     {"nl": "Some boy is tall.", "tfl": "+Boy+Tall", "confidence": 1}],
     "untranslatable": [{"nl": "The train left before the bell rang.", "reason": "tense"}]}|}

let () =
  ok "a full payload" full (fun p ->
      check (List.length p.translations = 2) "expected two translations";
      check (List.length p.untranslatable = 1) "expected one decline";
      let t = List.hd p.translations in
      check_eq t.tfl "-Horse+Animal";
      check (t.confidence = 0.9) "confidence not carried";
      (* an integer confidence is a number too — models emit 1, not 1.0 *)
      check ((List.nth p.translations 1).confidence = 1.0) "int confidence";
      check_eq (List.hd p.untranslatable).reason "tense");
  ok "an absent untranslatable array reads as empty"
    {|{"translations": [{"nl": "a", "tfl": "-A+B", "confidence": 0}]}|}
    (fun p ->
      check (p.untranslatable = []) "expected no declines";
      check (List.length p.translations = 1) "expected one translation");
  ok "an absent translations array reads as empty"
    {|{"untranslatable": [{"nl": "a", "reason": "tense"}]}|} (fun p ->
      check (p.translations = []) "expected no translations");
  ok "both arrays may be empty" {|{"translations": [], "untranslatable": []}|}
    (fun p ->
      check (p.translations = [] && p.untranslatable = []) "expected empty");
  ok "unknown top-level keys are ignored"
    {|{"translations": [], "untranslatable": [], "notes": "chatty model"}|}
    (fun p -> check (p.translations = []) "expected empty");
  (* Fencing is a formatting habit, not a translation failure. *)
  ok "a ```json fence comes off"
    ("```json\n" ^ full ^ "\n```")
    (fun p ->
      check (List.length p.translations = 2) "expected two translations");
  ok "a bare ``` fence comes off"
    ("```\n" ^ full ^ "\n```")
    (fun p ->
      check (List.length p.translations = 2) "expected two translations");
  ok "surrounding whitespace is tolerated"
    ("\n\n  " ^ full ^ "  \n")
    (fun p ->
      check (List.length p.translations = 2) "expected two translations")

(* ── Refused ───────────────────────────────────────────────────────────── *)

let () =
  rejects "prose instead of JSON" "Sure! Here are the translations:" "not JSON";
  rejects "a truncated payload" {|{"translations": [{"nl": "a",|} "not JSON";
  rejects "a top-level array" {|[{"nl": "a", "tfl": "-A+B"}]|} "payload";
  rejects "an empty object — no answer at all" {|{}|} "neither";
  rejects "translations is not an array" {|{"translations": {"nl": "a"}}|}
    "translations";
  rejects "an item that is not an object" {|{"translations": ["-A+B"]}|}
    "translations[0]";
  rejects "a missing tfl" {|{"translations": [{"nl": "a", "confidence": 1}]}|}
    "translations[0].tfl";
  rejects "an empty tfl — a formula that says nothing"
    {|{"translations": [{"nl": "a", "tfl": "", "confidence": 1}]}|}
    "translations[0].tfl";
  rejects "a tfl that is not a string"
    {|{"translations": [{"nl": "a", "tfl": ["-A+B"], "confidence": 1}]}|}
    "translations[0].tfl";
  rejects "a missing nl — nothing to attribute the formula to"
    {|{"translations": [{"tfl": "-A+B", "confidence": 1}]}|}
    "translations[0].nl";
  rejects "a missing confidence"
    {|{"translations": [{"nl": "a", "tfl": "-A+B"}]}|}
    "translations[0].confidence";
  rejects "a worded confidence"
    {|{"translations": [{"nl": "a", "tfl": "-A+B", "confidence": "high"}]}|}
    "translations[0].confidence";
  rejects "a confidence above 1"
    {|{"translations": [{"nl": "a", "tfl": "-A+B", "confidence": 1.5}]}|}
    "translations[0].confidence";
  rejects "a negative confidence"
    {|{"translations": [{"nl": "a", "tfl": "-A+B", "confidence": -0.1}]}|}
    "translations[0].confidence";
  (* The index in the reason must point at the offending item, not the first. *)
  rejects "the second item is named, not the first"
    {|{"translations": [{"nl": "a", "tfl": "-A+B", "confidence": 1},
                        {"nl": "b", "tfl": "-C+D"}]}|}
    "translations[1].confidence";
  rejects "a decline with no reason" {|{"untranslatable": [{"nl": "a"}]}|}
    "untranslatable[0].reason";
  rejects "a decline with an empty reason"
    {|{"untranslatable": [{"nl": "a", "reason": ""}]}|}
    "untranslatable[0].reason"

(* NaN cannot be written in JSON, so it can only arrive through [validate] —
   which is the entry point the harness will use if it ever hands us a value
   it built itself. *)
let () =
  test "NaN is not a confidence" (fun () ->
      let j =
        `Assoc
          [
            ( "translations",
              `List
                [
                  `Assoc
                    [
                      ("nl", `String "a");
                      ("tfl", `String "-A+B");
                      ("confidence", `Float Float.nan);
                    ];
                ] );
          ]
      in
      match validate j with
      | Ok _ -> failwith "NaN accepted as a confidence"
      | Error _ -> ())

let () = finish "translation schema"
