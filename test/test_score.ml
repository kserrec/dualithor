(* The fidelity scorer (PLAN 4.5b). This decides the headline number, so its
   two failure directions are both expensive: too strict and every model looks
   worse than it is because it chose a different stem; too loose and a wrong
   reading scores as correct, which would make the whole experiment fiction.

   The specific loose failure guarded here is the converse trap. Plain
   structural isomorphism cannot tell `-Trustee+Fiduciary` from
   `-Fiduciary+Trustee` — they are the same shape under the renaming that swaps
   the two names — so an illicit conversion of an A-form would score as a
   success. Anchoring the renaming to the term names is what blocks it. *)

open Harness

let p = Tfl.Notation.parse_proposition
let grade gold got = Bench.Score.grade_name (Bench.Score.grade_against [ p gold ] (p got))
let expect name gold got want = test name (fun () -> check_eq (grade gold got) want)

(* ── Must match: naming is arbitrary ───────────────────────────────────── *)

let () =
  expect "identical formulas are exact" "-Trustee+Fiduciary" "-Trustee+Fiduciary" "exact";
  expect "different term names, same shape" "-Trustee+Fiduciary" "-Trustee2+Fiduciary9"
    "structural";
  (* The case from the 4.3 smoke: models abbreviate verbs. *)
  expect "an abbreviated relation name still matches" "+Contractor+(Work+Subsidiary)"
    "+Contractor+(Wrk+Subsidiary)" "structural";
  expect "a lengthened relation name still matches" "+Contractor+(Work+Subsidiary)"
    "+Contractor+(Work_for+Subsidiary)" "structural";
  expect "underscores and case are ignored" "-Registered_Voter+Citizen"
    "-registeredvoter+Citizen" "structural";
  (* Compound elements are unordered in the notation. *)
  (* Compound elements are unordered in the notation, so this is the same
     term written two ways — a structural match, not a literal one. *)
  expect "compound element order does not matter" "-(+Written+Notice)+Record"
    "-(+Notice+Written)+Record" "structural"

(* ── Must NOT match: these are different claims ────────────────────────── *)

let () =
  (* The trap this scorer exists to survive. *)
  expect "an A-form converse is NOT a match" "-Trustee+Fiduciary" "-Fiduciary+Trustee"
    "wrong";
  expect "a subsequence collision cannot license an A-form converse"
    "-Cat+Educated" "-Educated+Cat" "wrong";
  expect "a swapped relational is NOT a match" "+Auditor+(Review+Report)"
    "+Report+(Review+Auditor)" "wrong";
  expect "unrelated terms do not match" "-Trustee+Fiduciary" "-Penguin+Aircraft" "wrong";
  expect "quantity differs" "-Trustee+Fiduciary" "+Trustee+Fiduciary" "wrong";
  expect "quality differs" "-Trustee+Fiduciary" "-Trustee-Fiduciary" "wrong";
  expect "a universal object is not a particular one" "-Auditor+(Review-Report)"
    "-Auditor+(Review+Report)" "wrong";
  expect "a quantity level is not dropped silently" "+Claimant^2+Veteran"
    "+Claimant+Veteran" "wrong";
  expect "a singular is not a plain term" "+-Maria*+Trustee" "+Maria+Trustee" "wrong";
  expect "a negative term is not a plain one" "-(-Resident)+Taxpayer" "-Resident+Taxpayer"
    "wrong"

(* ── The renaming has to stay a bijection ──────────────────────────────── *)

let () =
  (* Two distinct gold terms may not collapse onto one model term, nor the
     reverse — that would let "every A is B" match "every A is A". *)
  expect "two gold terms may not collapse into one" "-Trustee+Fiduciary"
    "-Trustee+Trustee" "wrong";
  (* Consistency across the whole proposition, not per position. *)
  expect "a name must map the same way throughout"
    "-(Manager+Department)+Manager" "-(Manager+Department)+Department" "wrong"

(* ── Equivalent-but-differently-shaped is a success, one grade down ────── *)

let () =
  (* Obversion: same claim, different shape. The engine proves it both ways,
     so the structural test failing is not the model being wrong. *)
  expect "obverted form grades as equivalent" "-Trustee+Fiduciary"
    "-Trustee-(-Fiduciary)" "equivalent";
  expect "I-form conversion grades as equivalent" "+Director+Shareholder"
    "+Shareholder+Director" "equivalent";
  test "correctness counts exact, structural and equivalent" (fun () ->
      List.iter
        (fun g -> check (Bench.Score.counts_as_correct g) "should count as correct")
        [ Bench.Score.Exact; Bench.Score.Structural; Bench.Score.Equivalent ];
      List.iter
        (fun g ->
          check (not (Bench.Score.counts_as_correct g)) "should not count as correct")
        [ Bench.Score.Wrong; Bench.Score.Unparseable ])

(* ── also_ok: the best grade across accepted readings wins ─────────────── *)

let () =
  test "an also_ok reading scores on its own merits" (fun () ->
      let accepted = [ p "-(+Temporary+Contractor)-Fiduciary"; p "-\"temporary contractor\"-Fiduciary" ] in
      let got = p "-\"temporary contractor\"-Fiduciary" in
      check_eq (Bench.Score.grade_name (Bench.Score.grade_against accepted got)) "exact")

let () = finish "fidelity scorer"
