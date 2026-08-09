(* The verification test suite (PLAN 3.2): ≥30 arguments through the public
   API, `Tfl_verify.check`, end to end. Cases are drawn from
   `test/paper_cases.ml` so the two suites assert the same expectations — a
   verdict that differs between the engine surface and the public API would
   mean the API layer is editorializing. The additions here are what
   paper_cases cannot cover: malformed input, empty input, and the taxonomy
   classes the API must report rather than raise. *)

open Harness

let v_name = function
  | Tfl_verify.Valid -> "valid"
  | Invalid -> "invalid"
  | Contradicted -> "contradicted"
  | Unknown -> "unknown"
  | Error e -> "error:" ^ Tfl_verify.class_name e.error_class

let expect premises conclusion expected name =
  test name (fun () ->
      let r = Tfl_verify.check ~premises ~conclusion in
      check
        (v_name r.verdict = expected)
        (Printf.sprintf "expected %s, got %s" expected (v_name r.verdict)))

let valid ps c name = expect ps c "valid" name
let invalid ps c name = expect ps c "invalid" name

(* 5.3: numerical non-derivability abstains rather than asserting invalid. *)
let unknown ps c name = expect ps c "unknown" name

(* paper_cases' [not_valid] contract: outside the complete fragment the engine
   must at least not certify — any verdict but Valid passes. *)
let not_valid ps c name =
  test name (fun () ->
      let r = Tfl_verify.check ~premises:ps ~conclusion:c in
      check (r.verdict <> Tfl_verify.Valid) "must not certify, got valid")

let expect_error ps c expected_class expected_where name =
  test name (fun () ->
      let r = Tfl_verify.check ~premises:ps ~conclusion:c in
      match r.verdict with
      | Tfl_verify.Error e ->
          check
            (Tfl_verify.class_name e.error_class = expected_class)
            (Printf.sprintf "expected %s, got %s" expected_class
               (Tfl_verify.class_name e.error_class));
          check (e.where = expected_where) "the failing input is misnamed"
      | _ ->
          check false
            (Printf.sprintf "expected an error, got %s" (v_name r.verdict)))

(* ── Valid syllogisms (paper_cases §A) ──────────────────────────────────── *)

let () =
  valid [ "−M+P"; "−S+M" ] "−S+P" "Barbara (AAA-1)";
  valid [ "−M−P"; "−S+M" ] "−S−P" "Celarent (EAE-1)";
  valid [ "−M+P"; "+S+M" ] "+S+P" "Darii (AII-1)";
  valid [ "−M−P"; "+S+M" ] "+S−P" "Ferio (EIO-1)";
  valid [ "−P+M"; "+S−M" ] "+S−P" "Baroco (AOO-2)";
  valid [ "+M−P"; "−M+S" ] "+S−P" "Bocardo (OAO-3)";
  valid [ "+P+M"; "−M+S" ] "+S+P" "Dimatis (IAI-4)";
  valid [ "−P−M"; "+M+S" ] "+S−P" "Fresison (EIO-4)"

(* ── Invalid forms: import traps and fallacies (§B, §C) ─────────────────── *)

let () =
  invalid [ "−M+P"; "−S+M" ] "+S+P" "Barbari needs existential import";
  invalid [ "−M+P"; "−M+S" ] "+S+P" "Darapti needs existential import";
  invalid [ "−P−M"; "−M+S" ] "+S−P" "Fesapo needs existential import";
  invalid [ "−P+M"; "−S−M" ] "+S−P" "Camestros needs existential import";
  invalid [ "−P+M"; "−S+M" ] "−S+P" "undistributed middle (AAA-2)";
  invalid [ "−M+P"; "−S−M" ] "−S−P" "illicit major (AEE-1)";
  invalid [ "+M+P"; "−S+M" ] "+S+P" "IAI-1 is invalid"

(* ── Immediate inferences (§D) ──────────────────────────────────────────── *)

let () =
  valid [ "+S+P" ] "+P+S" "I converts simply";
  invalid [ "+S−P" ] "+P−S" "O does not convert";
  valid [ "−S+P" ] "−S−(−P)" "obversion: A → E";
  valid [ "−S+P" ] "−(−P)+(−S)" "contraposition: A"

(* ── Relational arguments (§E, §F) ──────────────────────────────────────── *)

let () =
  valid [ "−Horse+Animal" ] "−(Head+Horse)+(Head+Animal)"
    "De Morgan: every head of a horse is a head of an animal";
  valid
    [ "−Man+(Lov+Woman)"; "−Woman+Human" ]
    "−Man+(Lov+Human)" "dictum inside a relational object";
  valid
    [ "−Boy+(Lov+Girl)"; "−Girl+(Adm−Teacher)" ]
    "−Boy+(Lov+(Adm−Teacher))" "chained relational complexes";
  valid [ "+Boy+(Lov+Girl)" ] "+Girl+(Lov₂₁+Boy)" "passive of a particular";
  not_valid [ "−Boy+(Lov+Girl)" ] "+Girl+(Lov₂₁−Boy)"
    "the ∀∃ / ∃∀ scope trap is never certified";
  valid
    [ "−A−(R+B)"; "+C+(R+B)" ]
    "+C−A" "nothing A is R-related to a B; some C is ⊢ some C is not A";
  valid
    [ "+Boy+(Lov+Girl)"; "−Boy−(Lov+Coward)" ]
    "+Girl−Coward" "the worked indirect proof: boys, girls, cowards"

(* ── Numerical quantifiers (§G) ─────────────────────────────────────────── *)

let () =
  valid [ "+C^3−H"; "−C+E" ] "+E−H" "Table 12 — bao-3 is valid";
  (* 5.3: numerical non-derivability abstains rather than asserting invalid *)
  unknown [ "+H^1+I"; "−g+H" ] "−g+I"
    "Table 10 — kaa-1: no derivation (book says invalid)";
  valid [ "+V^2+C" ] "+V+C" "most descends to some"

(* ── Malformed and empty input (the API's own ground) ───────────────────── *)

let () =
  expect_error [] "" "syntactic" (Some "conclusion") "empty conclusion";
  expect_error [ "" ] "−A+B" "syntactic" (Some "premise 1") "empty premise";
  expect_error [ "   " ] "−A+B" "syntactic" (Some "premise 1")
    "whitespace-only premise";
  expect_error [ "\xff\xfe" ] "−A+B" "lexical" (Some "premise 1")
    "invalid bytes are a lexical refusal";
  expect_error [ "±A+B" ] "−S+P" "outside_fragment" (Some "premise 1")
    "wild sign on a general subject is outside the fragment";
  expect_error
    [ String.concat "" (List.init 100 (fun _ -> "(")) ^ "A" ]
    "−A+B" "syntactic" (Some "premise 1") "nesting past the depth cap";
  expect_error
    (List.init (Tfl.Safe.max_argument_premises + 1) (fun _ -> "−A+B"))
    "−A+B" "resource_limit" (Some "argument")
    "premise count past the public cap is a resource refusal";
  (* Empty premise list is legal input, not an error: the conclusion alone
     decides. *)
  invalid [] "−A+B" "no premises: a contingent conclusion is invalid"

let () = finish "test_verify_cases"
