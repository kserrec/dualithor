(* Shared unit-test plumbing for the test_*.ml suites: a tiny named-test
   runner (each executable owns its own pass/fail counters), plus the
   argument-checking helpers several suites share. *)

let passed = ref 0
let failed = ref 0

let test name f =
  try
    f ();
    incr passed
  with e ->
    incr failed;
    Printf.eprintf "✗ %s\n  %s\n" name (Printexc.to_string e)

let check cond msg = if not cond then failwith msg

let check_eq got expected =
  if got <> expected then
    failwith (Printf.sprintf "got %S, expected %S" got expected)

let summarize label =
  Printf.printf "%s: %d passed, %d failed\n" label !passed !failed

let exit_code () = if !failed > 0 then 1 else 0

let finish label =
  summarize label;
  exit (exit_code ())

(* ── Differential gates (the shim-backed suites) ────────────────────────── *)

(* A gate property: run the comparison, print the disagreement on failure. *)
let gate name ~count ~print gen compare =
  QCheck2.Test.make ~count ~name ~print gen (fun x ->
      match compare x with
      | None -> true
      | Some d ->
          Printf.eprintf "✗ %s: %s\n" name d;
          false)

(* ── Argument-checking helpers (decide/relational/numerical suites) ─────── *)

let p = Tfl.Notation.parse_proposition

let arg premises conclusion =
  Tfl.Decide.check_argument
    (List.map Tfl.Notation.parse_proposition premises)
    (Tfl.Notation.parse_proposition conclusion)

let verdict_name (r : Tfl.Decide.result) =
  match r.verdict with
  | Valid -> "valid"
  | Invalid -> "invalid"
  | Contradicted -> "contradicted"
  | Unknown -> "unknown"

let expect_verdict premises conclusion expected msg =
  let r = arg premises conclusion in
  check
    (verdict_name r = expected)
    (Printf.sprintf "%s: expected %s, got %s" msg expected (verdict_name r))

let proof_rules (r : Tfl.Decide.result) =
  match r.proof with
  | Some pr -> List.map (fun (l : Tfl.Derive.line) -> l.rule) pr.lines
  | None -> []
