(* Oracle port B (PLAN 1.11): the six fuzz suites of engine/oracle.js, rebuilt
   on the OCaml engine and the 1.10 finite-model semantics. Each suite asks the
   same question as its JS original — does the engine's *syntactic* verdict
   survive contact with the semantics?

     node engine/oracle.js -n N   ↔   dune exec test/test_oracle.exe -- -n N

   The default is 1,000 iterations per suite so `dune test` stays quick; the
   20k gate is run explicitly and its timings logged (LOG.md).

   Where a suite's search is incomplete the failure is one-sided by
   construction: past the model cap the semantics samples rather than
   enumerates, which can only *miss* a counter-model, never invent one. Suite 1
   is the exception — it compares verdicts for equality — and its vocabulary
   (three general atoms, one singular, one proterm) stays under the cap at
   n = 4, so it always enumerates exhaustively. *)

open Tfl.Notation

let iters = ref 1000

let () =
  Arg.parse
    [ ("-n", Arg.Set_int iters, "N  iterations per suite (default 1000)") ]
    (fun a -> raise (Arg.Bad ("unexpected argument " ^ a)))
    "test_oracle [-n N]"

(* One deterministic stream for the whole run, as oracle.js has. *)
let rand = Random.State.make [| 20260704 |]
let gen1 g = QCheck2.Gen.generate1 ~rand g
let log = print_endline

exception Stop (* the suite's failure budget is spent *)

let fail bad ~limit lines =
  incr bad;
  List.iter log lines;
  if !bad >= limit then raise Stop

(* Run [body] up to [n] times, stopping early on Stop; returns the number of
   iterations actually run. *)
let repeat n body =
  let k = ref 0 in
  (try
     while !k < n do
       incr k;
       body ()
     done
   with Stop -> ());
  !k

let premise_lines premises conclusion =
  List.map (fun p -> "    premise    " ^ print_proposition p) premises
  @ [ "    conclusion " ^ print_proposition conclusion ]

let proof_lines (proof : Tfl.Derive.proof) =
  List.map
    (fun (l : Tfl.Derive.line) ->
      Printf.sprintf "    %d. %s  [%s%s]" l.n l.text l.rule
        (if l.parents = [] then ""
         else " " ^ String.concat "," (List.map string_of_int l.parents)))
    proof.lines

(* ── 1. Categorical exactness ───────────────────────────────────────────────
   checkArgument's P/Z verdict must *equal* semantic entailment on random
   categorical arguments, proterms included — this is the fragment where the
   engine claims a complete decision method. *)

let fuzz_categorical n =
  let bad = ref 0 and valids = ref 0 in
  let ran =
    repeat n (fun () ->
        let premises, conclusion = gen1 Gen.sem_categorical_argument in
        let engine_valid =
          (Tfl.Decide.check_argument premises conclusion).verdict
          = Tfl.Decide.Valid
        in
        (* Each particular needs at most one witness, so n = 4 comfortably
           covers 1–3 premises plus the denied conclusion. *)
        let semantic =
          Semantics.entails ~max_n:4 ~cap:400_000 premises conclusion
        in
        if engine_valid then incr valids;
        if engine_valid <> semantic then
          fail bad ~limit:5
            (Printf.sprintf "  MISMATCH engine=%b semantic=%b" engine_valid
               semantic
            :: premise_lines premises conclusion))
  in
  (!bad, Printf.sprintf "%d/%d valid" !valids ran)

(* ── 2. Rule-step soundness ─────────────────────────────────────────────────
   Every single rewrite the engine's rules produce must be semantically
   entailed by the lines it was drawn from, relational and compound hosts
   included. *)

let fuzz_steps n =
  let bad = ref 0 and steps = ref 0 in
  let ran =
    repeat n (fun () ->
        let shape = Random.State.int rand 3 in
        let draw () =
          match shape with
          | 0 -> gen1 (Gen.sem_relational_prop [ "A"; "B" ] "R")
          | 1 -> gen1 (Gen.sem_compound_prop [ "A"; "B" ])
          | _ -> gen1 (Gen.sem_categorical_prop [ "A"; "B" ])
        in
        let a = draw () in
        let b = draw () in
        let results =
          (* The generators occasionally build engine-invalid props; the JS
             oracle skips those iterations and so do we. *)
          try
            Some
              ([ (Tfl.Infer.obverse a, [ a ]) ]
              @ (match Tfl.Infer.contrapositive a with
                | Some c -> [ (c, [ a ]) ]
                | None -> [])
              @ List.map (fun p -> (p, [ a ])) (Tfl.Rules.apply_simp a)
              @ List.filter_map
                  (fun (r : Tfl.Relational.passive) ->
                    if r.equivalent then
                      Some (Tfl.Infer.canon_prop r.p_prop, [ a ])
                    else None)
                  (Tfl.Relational.passives a)
              @ List.map (fun p -> (p, [ a; b ])) (Tfl.Rules.apply_don a b)
              @ List.map (fun p -> (p, [ a; b ])) (Tfl.Rules.apply_don b a)
              @ List.map (fun p -> (p, [ a; b ])) (Tfl.Rules.apply_add a b)
              @ [ (Tfl.Infer.tautology a.subject.term, []) ])
          with Tfl.Infer.Engine_error _ -> None
        in
        match results with
        | None -> ()
        | Some results ->
            List.iter
              (fun (p, parents) ->
                incr steps;
                if not (Semantics.entails ~max_n:3 ~cap:60_000 parents p) then
                  fail bad ~limit:5
                    [
                      Printf.sprintf "  UNSOUND step: %s ⊢ %s"
                        (String.concat " , " (List.map print_proposition parents))
                        (print_proposition p);
                    ])
              results)
  in
  ignore ran;
  (!bad, Printf.sprintf "%d steps checked" !steps)

(* ── 3. Relational derivation soundness ─────────────────────────────────────
   Whenever derive() finds a proof, no small model may satisfy the premises and
   refute the conclusion. *)

let fuzz_relational_derivations n =
  let bad = ref 0 and proved = ref 0 in
  let rel () = gen1 (Gen.sem_relational_prop [ "A"; "B" ] "R") in
  let ran =
    repeat n (fun () ->
        let p1 = rel () in
        let p2 = rel () in
        let premises = [ p1; p2 ] in
        let conclusion = rel () in
        match
          try Some (Tfl.Derive.derive ~max_lines:120 premises conclusion)
          with Tfl.Infer.Engine_error _ -> None
        with
        | Some proof when proof.found -> (
            incr proved;
            match
              Semantics.counter_model ~max_n:3 ~cap:120_000 premises conclusion
            with
            | None -> ()
            | Some m ->
                fail bad ~limit:3
                  ((("  UNSOUND derivation (counter-model " ^ Semantics.show_model m
                   ^ "):")
                   :: premise_lines premises conclusion)
                  @ proof_lines proof))
        | _ -> ())
  in
  (!bad, Printf.sprintf "%d proofs found in %d tries" !proved ran)

(* ── 4. Passive equivalence ─────────────────────────────────────────────────
   The two deterministic scope traps from Course 2 L3 must have counter-models
   and must be guarded off; then every guard-approved passive must be a
   two-way semantic equivalence. *)

let scope_traps bad =
  List.iter
    (fun (active, naive) ->
      let a = parse_proposition active and q = parse_proposition naive in
      if
        Semantics.entails ~max_n:3 ~cap:120_000 [ a ] q
        && Semantics.entails ~max_n:3 ~cap:120_000 [ q ] a
      then
        fail bad ~limit:5
          [
            Printf.sprintf "  SCOPE TRAP MISSED: %s is model-equivalent to %s"
              active naive;
          ];
      let key = Tfl.Infer.prop_key q in
      match
        List.find_opt
          (fun (r : Tfl.Relational.passive) -> Tfl.Infer.prop_key r.p_prop = key)
          (Tfl.Relational.passives a)
      with
      | Some { equivalent = false; _ } -> ()
      | _ ->
          fail bad ~limit:5
            [
              Printf.sprintf
                "  GUARD FAILURE: passive of %s not flagged as non-equivalent"
                active;
            ])
    [ ("−A+(R+B)", "+B+(R₂₁−A)"); ("+A+(R−B)", "−B+(R₂₁+A)") ]

let fuzz_passive_equivalence n =
  let bad = ref 0 and equivs = ref 0 and traps = ref 0 in
  (try scope_traps bad with Stop -> ());
  let ran =
    repeat n (fun () ->
        let p = gen1 (Gen.sem_passive_prop [ "A"; "B" ] "R") in
        match
          try Some (Tfl.Relational.passives p)
          with Tfl.Infer.Engine_error _ -> None
        with
        | None -> ()
        | Some results ->
            List.iter
              (fun (r : Tfl.Relational.passive) ->
                if not r.equivalent then incr traps
                else (
                  incr equivs;
                  (* maxN 2 keeps arity-3 relations enumerable; the ∀∃/∃∀ scope
                     separations all show up by two elements. *)
                  if
                    (not (Semantics.entails ~max_n:2 ~cap:60_000 [ p ] r.p_prop))
                    || not (Semantics.entails ~max_n:2 ~cap:60_000 [ r.p_prop ] p)
                  then
                    fail bad ~limit:5
                      [
                        Printf.sprintf "  NOT EQUIVALENT: %s vs %s"
                          (print_proposition p)
                          (print_proposition r.p_prop);
                      ]))
              results)
  in
  ignore ran;
  (!bad, Printf.sprintf "%d equivalences, %d guarded off" !equivs !traps)

(* ── 5. Indirect-proof soundness ────────────────────────────────────────────
   A found refutation of the counterclaim must mean genuine entailment — the
   soundness of the pronominalization step, checked model-theoretically. *)

let fuzz_indirect_proofs n =
  let bad = ref 0 and proved = ref 0 in
  let rel () = gen1 (Gen.sem_relational_prop [ "A"; "B" ] "R") in
  let ran =
    repeat n (fun () ->
        let p1 = rel () in
        let p2 = rel () in
        let premises = [ p1; p2 ] in
        let conclusion = rel () in
        match
          try Some (Tfl.Derive.indirect_proof ~max_lines:150 premises conclusion)
          with Tfl.Infer.Engine_error _ -> None
        with
        | Some proof when proof.found -> (
            incr proved;
            match
              Semantics.counter_model ~max_n:3 ~cap:120_000 premises conclusion
            with
            | None -> ()
            | Some m ->
                fail bad ~limit:3
                  ((("  UNSOUND indirect proof (counter-model "
                    ^ Semantics.show_model m ^ "):")
                   :: premise_lines premises conclusion)
                  @ proof_lines proof))
        | _ -> ())
  in
  (!bad, Printf.sprintf "%d refutations found in %d tries" !proved ran)

(* ── 6. Statement-model agreement ───────────────────────────────────────────
   A propositional statement's one-world truth (statement_model) must equal the
   finite-model semantics at n = 1 on every assignment, and decide_equivalence's
   DNF verdict must equal mutual one-world entailment. *)

let one_world (atoms : string array) (bits : int) : Semantics.model =
  {
    n = 1;
    full = 1;
    singular = [];
    unary =
      Array.to_list
        (Array.mapi
           (fun i name -> (name, if bits land (1 lsl i) <> 0 then 1 else 0))
           atoms);
    rels = [];
  }

let assignment (atoms : string array) (bits : int) (name : string) : bool =
  let rec idx i = if atoms.(i) = name then i else idx (i + 1) in
  bits land (1 lsl idx 0) <> 0

let fuzz_statement_model n =
  let bad = ref 0 and checked = ref 0 and eq_checked = ref 0 in
  let ran =
    repeat n (fun () ->
        let a = gen1 Gen.statement_prop_gen in
        match Tfl.Program.statement_model a with
        | None -> ()
        | Some (atoms_a, sat_a) ->
            let arr = Array.of_list atoms_a in
            for bits = 0 to (1 lsl Array.length arr) - 1 do
              incr checked;
              if sat_a (assignment arr bits) <> Semantics.eval_prop a (one_world arr bits)
              then
                fail bad ~limit:5
                  [
                    Printf.sprintf "  MODEL MISMATCH %s at assignment %d"
                      (print_proposition a) bits;
                  ]
            done;
            (* (ii) decide_equivalence's DNF verdict vs mutual one-world
               entailment. *)
            let b = gen1 Gen.statement_prop_gen in
            (match Tfl.Program.statement_model b with
            | None -> ()
            | Some (atoms_b, _) ->
                let dec = Tfl.Program.decide_equivalence a b in
                if dec.e_method = "dnf" then (
                  incr eq_checked;
                  let union =
                    Array.of_list
                      (List.sort_uniq String.compare (atoms_a @ atoms_b))
                  in
                  let same = ref true in
                  for bits = 0 to (1 lsl Array.length union) - 1 do
                    let w = one_world union bits in
                    if Semantics.eval_prop a w <> Semantics.eval_prop b w then
                      same := false
                  done;
                  if dec.equivalent <> !same then
                    fail bad ~limit:5
                      [
                        Printf.sprintf
                          "  EQUIV MISMATCH %s vs %s: engine=%b semantic=%b"
                          (print_proposition a) (print_proposition b)
                          dec.equivalent !same;
                      ])))
  in
  ignore ran;
  (!bad, Printf.sprintf "%d evals, %d equivalences checked" !checked !eq_checked)

(* ── Runner ─────────────────────────────────────────────────────────────── *)

let suites =
  [
    ("categorical exactness", fuzz_categorical);
    ("rule-step soundness", fuzz_steps);
    ("relational derivation soundness", fuzz_relational_derivations);
    ("passive equivalence", fuzz_passive_equivalence);
    ("indirect-proof soundness", fuzz_indirect_proofs);
    ("statement-model agreement", fuzz_statement_model);
  ]

let () =
  Printf.printf "oracle suites: %d iterations each\n%!" !iters;
  let failed = ref false in
  let started = Unix.gettimeofday () in
  List.iter
    (fun (name, fn) ->
      let t0 = Unix.gettimeofday () in
      let mismatches, note = fn !iters in
      Printf.printf "%s %s: %d failures (%s, %.1fs)\n%!"
        (if mismatches = 0 then "✓" else "✗")
        name mismatches note
        (Unix.gettimeofday () -. t0);
      if mismatches > 0 then failed := true)
    suites;
  Printf.printf "total %.1fs\n" (Unix.gettimeofday () -. started);
  exit (if !failed then 1 else 0)
