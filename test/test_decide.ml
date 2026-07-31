(* 1.5 acceptance: unit tests for inference core B, ported from the D2
   argument sections of engine/tfl.test.js — P/Z inconsistency, the REGAL
   categorical verdicts, statement arguments, singulars/identity (incl. a
   traced DON derivation), Simp/Add, and derivation-trace shape. The
   relational-derivation and oracle-spot-check sections arrive with 1.6/1.10;
   the quantity-level guard test arrives with 1.8. *)

open Tfl.Notation
open Tfl.Decide

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
let p = parse_proposition
let arg premises conclusion = check_argument (List.map p premises) (p conclusion)

let verdict_is expected r msg =
  check (r.verdict = expected)
    (Printf.sprintf "%s: got %s" msg
       (match r.verdict with
       | Valid -> "valid"
       | Invalid -> "invalid"
       | Contradicted -> "contradicted"
       | Unknown -> "unknown"))

let valid premises conclusion msg = verdict_is Valid (arg premises conclusion) msg
let invalid premises conclusion msg = verdict_is Invalid (arg premises conclusion) msg

let () =
  (* P/Z inconsistency *)
  test "A against O is inconsistent" (fun () ->
      check (check_inconsistent [ p "−A+B"; p "+A−B" ] <> None) "A vs O");
  test "transitive chain plus denial is inconsistent" (fun () ->
      check
        (check_inconsistent [ p "−A+B"; p "−B+C"; p "+A−C" ] <> None)
        "chain");
  test "a lone particular is consistent" (fun () ->
      check (check_inconsistent [ p "+A+B" ] = None) "lone particular");
  test "all-universal sets are consistent (no import)" (fun () ->
      check (check_inconsistent [ p "−A+B"; p "−B−A" ] = None) "universals");

  (* Categorical validity: the REGAL verdicts *)
  test "Barbara is valid" (fun () ->
      valid [ "−M+P"; "−S+M" ] "−S+P" "Barbara");
  test "Celarent is valid" (fun () ->
      valid [ "−M−P"; "−S+M" ] "−S−P" "Celarent");
  test "Darii and Ferio are valid" (fun () ->
      valid [ "−M+P"; "+S+M" ] "+S+P" "Darii";
      valid [ "−M−P"; "+S+M" ] "+S−P" "Ferio");
  test "undistributed middle is invalid" (fun () ->
      invalid [ "−M+P"; "−M+S" ] "−S+P" "undistributed middle");
  test "illicit process is invalid" (fun () ->
      invalid [ "−M+P"; "−S+M" ] "−P+S" "illicit process");
  test "two particular premises are invalid (irregular)" (fun () ->
      invalid [ "+M+P"; "+S+M" ] "+S+P" "two particulars");
  test "subalternation fails without an existence premise" (fun () ->
      invalid [ "−A+B" ] "+A+B" "subalternation");
  test "subalternation succeeds with +A+A added" (fun () ->
      valid [ "−A+B"; "+A+A" ] "+A+B" "subalternation with import");
  test "obverted premises still cancel (sign algebra through negation)"
    (fun () -> valid [ "−M−(−P)"; "−S+M" ] "−S+P" "obverted Barbara");
  test "cross-form sorites is valid" (fun () ->
      valid [ "−A+B"; "−B+C"; "−C+D"; "+A+A" ] "+A+D" "sorites");

  (* Statement arguments *)
  test "modus ponens is Barbara" (fun () ->
      valid [ "−p+q"; "+p+p" ] "+q+q" "MP";
      valid [ "−p+q"; "+p+p" ] "+q+p" "MP with conjunction");
  test "modus tollens needs a universal used twice" (fun () ->
      valid [ "−p+q"; "+(−q)+(−q)" ] "+(−p)+(−p)" "MT");
  test "hypothetical syllogism is valid" (fun () ->
      valid [ "−p+q"; "−q+r" ] "−p+r" "HS");
  test "affirming the consequent is invalid" (fun () ->
      invalid [ "−p+q"; "+q+q" ] "+p+p" "AC");

  (* Singulars and identity *)
  test "singular Barbara (Socrates is mortal)" (fun () ->
      valid
        [ "−Human+Mortal"; "±Socrates*+Human" ]
        "±Socrates*+Mortal" "singular Barbara");
  test "shared predicate proves nothing about singulars" (fun () ->
      invalid
        [ "±Socrates*+Mortal"; "±Aristotle*+Mortal" ]
        "±Socrates*+Aristotle*" "shared predicate");
  test "Twain/Clemens: identity chains fall out of the algebra" (fun () ->
      valid
        [ "±Twain*+Clemens*"; "±Twain*+Humorist" ]
        "±Clemens*+Humorist" "identity chain";
      (* and via DON with wild quantity, as a traced derivation *)
      let proof =
        Tfl.Derive.derive
          [ p "±Twain*+Clemens*"; p "±Twain*+Humorist" ]
          (p "±Clemens*+Humorist")
      in
      check proof.found "derivation not found";
      check
        (List.exists (fun (l : Tfl.Derive.line) -> l.rule = "DON") proof.lines)
        "expected a DON step");
  test "identity is transitive through DON" (fun () ->
      valid
        [ "±Hesperus*+Phosphorus*"; "±Phosphorus*+Venus*" ]
        "±Hesperus*+Venus*" "identity transitivity");

  (* Simp and Add *)
  test "Simp drops a conjunct at a net-+ occurrence" (fun () ->
      valid [ "−S+(+A+B)" ] "−S+A" "Simp");
  test "statement Simp: some X is Y, so some X is X" (fun () ->
      valid [ "+X+Y" ] "+X+X" "statement Simp");
  test "Add builds a compound conclusion from shared subjects" (fun () ->
      valid [ "−S+A"; "−S+B" ] "−S+(+A+B)" "Add");

  (* Derivation traces *)
  test "traces are numbered, parent-linked, and end at the goal" (fun () ->
      let proof = Tfl.Derive.derive [ p "−M+P"; p "−S+M" ] (p "−S+P") in
      check proof.found "Barbara derivation not found";
      let last = List.nth proof.lines (List.length proof.lines - 1) in
      (match last.l_prop with
      | Some lp -> check (Tfl.Infer.prop_eq_up_to lp (p "−S+P")) "ends at goal"
      | None -> failwith "last line has no prop");
      List.iter
        (fun (l : Tfl.Derive.line) ->
          List.iter
            (fun par -> check (par < l.n) "parents precede their line")
            l.parents)
        proof.lines;
      check
        (List.length
           (List.filter
              (fun (l : Tfl.Derive.line) -> l.rule = "premise")
              proof.lines)
        <= 2)
        "at most 2 premise lines");

  Printf.printf "decide unit tests: %d passed, %d failed\n" !passed !failed;
  exit (if !failed > 0 then 1 else 0)
