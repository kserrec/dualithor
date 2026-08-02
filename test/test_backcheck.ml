(* PLAN 4.4 — the back-check's offline half: rendering, and reading the judge.

   The first test below is the one that decides whether the mechanism can work
   at all. If a meaning-inverting formula renders into the *same* English as the
   correct one, no judge — human or model — could ever tell them apart, and the
   whole check is structurally incapable of catching the error class it exists
   for. That has to be established before any money is spent asking a model. *)

open Harness
open Translate

let p = Tfl.Notation.parse_proposition

(* ── The mechanism has to be capable of the catch ──────────────────────── *)

let () =
  test "the sign inversion renders differently from the correct formula" (fun () ->
      (* c02: "No non-member is eligible."
         gold  -(-Member)-Eligible      GPT wrote  -(-Member)+Eligible *)
      let good = Backcheck.render (p "-(-Member)-Eligible") in
      let bad = Backcheck.render (p "-(-Member)+Eligible") in
      check (good <> bad)
        (Printf.sprintf
           "both formulas render as %S — the back-check could never catch this" good);
      Printf.printf "  gold renders as: %S\n  GPT renders as:  %S\n" good bad);
  test "quantity changes survive rendering" (fun () ->
      check
        (Backcheck.render (p "-Trustee+Fiduciary") <> Backcheck.render (p "+Trustee+Fiduciary"))
        "every/some render identically");
  test "quantity levels survive rendering" (fun () ->
      check
        (Backcheck.render (p "+Claimant^2+Veteran") <> Backcheck.render (p "+Claimant+Veteran"))
        "most/some render identically — a dropped quantifier would be invisible");
  test "relational scope survives rendering" (fun () ->
      check
        (Backcheck.render (p "-Auditor+(Review+Report)")
        <> Backcheck.render (p "-Auditor+(Review-Report)"))
        "some/every object renders identically");
  (* 3.4's readable orientation should be in force: a relational subject reads
     subject-first rather than word-for-word. *)
  test "a relational subject reads subject-first" (fun () ->
      let r = Backcheck.render (p "+(Lov+Girl)+Boy") in
      check
        (String.length r > 0 && String.sub r 0 4 = "some")
        (Printf.sprintf "expected a subject-first reading, got %S" r))

(* ── Reading the judge's reply ─────────────────────────────────────────── *)

let ok_reply n raw =
  match Backcheck.parse_reply n raw with
  | Ok v -> v
  | Error why -> failwith ("rejected a good reply: " ^ why)

let rejects name n raw =
  test name (fun () ->
      match Backcheck.parse_reply n raw with
      | Ok _ -> failwith "accepted a malformed judge reply"
      | Error _ -> ())

let () =
  test "a well-formed reply is read" (fun () ->
      let v =
        ok_reply 2
          {|{"judgements":[{"n":1,"score":2,"note":""},{"n":2,"score":0,"note":"opposite"}]}|}
      in
      check (List.length v = 2) "expected two judgements");
  test "a fenced reply is read" (fun () ->
      let v = ok_reply 1 "```json\n{\"judgements\":[{\"n\":1,\"score\":1,\"note\":\"weaker\"}]}\n```" in
      check (List.length v = 1) "fence not stripped");
  rejects "prose instead of JSON" 1 "Sure, here are my judgements:";
  rejects "no judgements array" 1 {|{"results":[]}|};
  rejects "a score outside 0..2" 1 {|{"judgements":[{"n":1,"score":5,"note":""}]}|};
  rejects "an index past the end" 1 {|{"judgements":[{"n":7,"score":2,"note":""}]}|};
  rejects "a non-numeric score" 1 {|{"judgements":[{"n":1,"score":"good","note":""}]}|}

(* ── Failing closed ────────────────────────────────────────────────────── *)

let () =
  test "score maps to outcome" (fun () ->
      let j score = Backcheck.{ nl = "a"; rendering = "b"; score; note = "" } in
      check_eq (Backcheck.outcome_name (Backcheck.outcome_of (j 2))) "agrees";
      check_eq (Backcheck.outcome_name (Backcheck.outcome_of (j 1))) "partial";
      check_eq (Backcheck.outcome_name (Backcheck.outcome_of (j 0))) "disagrees");
  (* A partial reading is the case a human should look at; folding it into
     "agrees" would hide precisely the near-misses this check exists for. *)
  test "partial is not silently treated as agreement" (fun () ->
      let j = Backcheck.{ nl = "a"; rendering = "b"; score = 1; note = "weaker" } in
      check (Backcheck.outcome_of j <> Backcheck.Agrees) "partial must not read as agreement")

let () = finish "back-check"
