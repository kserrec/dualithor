(* Oracle port A (PLAN 1.10): the finite-model semantics in Semantics, gated
   two ways.

   (a) Anchors — the semantic facts the whole oracle rests on (no existential
       import, the empty domain, fixed reference, the ∀∃/∃∀ scope separation),
       stated directly so a wrong port shows up as a wrong fact, not just as a
       disagreement.
   (b) Differential — vocabulary extraction, per-model evaluation and
       entailment verdicts compared against engine/oracle.js through the shim.

   Only vocabularies both engines enumerate exhaustively are compared: past
   the cap the JS oracle switches to random sampling from an LCG whose state
   is shared with its own formula generation, which is not reproducible from
   here (Semantics). Skipped instances are counted and reported. *)

open Tfl.Notation
module G = QCheck2.Gen

let max_n = 3
let cap = 300_000

(* ── (a) Anchors ────────────────────────────────────────────────────────── *)

let props = List.map parse_proposition
let entails premises conclusion =
  Semantics.entails ~max_n ~cap (props premises) (parse_proposition conclusion)

let anchors () =
  let open Harness in
  test "Barbara is valid" (fun () ->
      check (entails [ "−M+P"; "−S+M" ] "−S+P") "Barbara should entail");
  test "Darapti fails without existential import" (fun () ->
      check
        (not (entails [ "−M+P"; "−M+S" ] "+S+P"))
        "Darapti should have a counter-model (M empty)");
  test "conversion holds both ways" (fun () ->
      check (entails [ "+A+B" ] "+B+A") "I-conversion";
      check (entails [ "−A−B" ] "−B−A") "E-conversion");
  test "an unconverted A-form does not convert" (fun () ->
      check (not (entails [ "−A+B" ] "−B+A")) "A-conversion is invalid");
  test "the empty domain is a model" (fun () ->
      let empty : Semantics.model =
        { n = 0; full = 0; singular = []; unary = [ ("A", 0); ("B", 0) ]; rels = [] }
      in
      check
        (Semantics.eval_prop (parse_proposition "−A+B") empty)
        "universals hold vacuously at n = 0";
      check
        (not (Semantics.eval_prop (parse_proposition "+A+B") empty))
        "particulars fail at n = 0");
  test "fixed reference carries through a universal" (fun () ->
      check (entails [ "±s+A"; "−A+B" ] "±s+B") "singular Barbara";
      check (entails [ "±t'+A"; "−A+B" ] "±t'+B") "proterm Barbara");
  test "a propositional term is the whole domain when its statement is true"
    (fun () ->
      check (entails [ "+A+A" ] "+A+[A]") "[A] is full when A is inhabited";
      check (not (entails [ "−A+B" ] "+A+[A]")) "an empty A leaves [A] empty");
  test "relational scope: ∀∃ and ∃∀ are not equivalent" (fun () ->
      let a = parse_proposition "−A+(R+B)" in
      let naive = parse_proposition "+B+(R₂₁−A)" in
      check
        (not
           (Semantics.entails ~max_n ~cap [ a ] naive
           && Semantics.entails ~max_n ~cap [ naive ] a))
        "the Course 2 L3 scope trap must have a counter-model";
      let b = parse_proposition "+A+(R−B)" in
      let naive_b = parse_proposition "−B+(R₂₁+A)" in
      check
        (not
           (Semantics.entails ~max_n ~cap [ b ] naive_b
           && Semantics.entails ~max_n ~cap [ naive_b ] b))
        "the second scope trap must have a counter-model");
  test "a guard-approved passive is an equivalence" (fun () ->
      let a = parse_proposition "−A+(R−B)" in
      let passive = parse_proposition "−B+(R₂₁−A)" in
      check
        (Semantics.entails ~max_n ~cap [ a ] passive
        && Semantics.entails ~max_n ~cap [ passive ] a)
        "∀∀ commutes")

(* ── (b) Differential against engine/oracle.js ──────────────────────────── *)

let engine_dir =
  if Sys.file_exists "../engine/shim.js" then "../engine" else "engine"

let shim = Shim_client.start ~shim_path:(engine_dir ^ "/shim.js")

type tally = { mutable compared : int; mutable entailed : int; mutable skipped : int }

let new_tally () = { compared = 0; entailed = 0; skipped = 0 }

let model_to_json (m : Semantics.model) : Yojson.Safe.t =
  let obj l = `Assoc (List.map (fun (k, v) -> (k, `Int v)) l) in
  `Assoc
    [
      ("n", `Int m.n);
      ("singular", obj m.singular);
      ("unary", obj m.unary);
      ( "rels",
        `Assoc
          (List.map
             (fun (k, tuples) ->
               ( k,
                 `List
                   (List.map
                      (fun t ->
                        `List
                          (Array.to_list (Array.map (fun x -> `Int x) t)))
                      tuples) ))
             m.rels) );
    ]

let expect_json fn args expected : string option =
  match Shim_client.call shim fn args with
  | Ok js when Ast_json.json_equal expected js -> None
  | Ok js ->
      Some
        (Printf.sprintf "%s mismatch: ocaml %s vs js %s" fn
           (Yojson.Safe.to_string expected)
           (Yojson.Safe.to_string js))
  | Error e -> Some (Printf.sprintf "%s: js errored %s (%s)" fn e.name e.message)

let vocab_to_json (v : Semantics.vocab) : Yojson.Safe.t =
  `Assoc
    [
      ("unary", `List (List.map (fun s -> `String s) v.unary));
      ("singular", `List (List.map (fun s -> `String s) v.singular));
      ( "rels",
        `List
          (List.map
             (fun (name, arity) ->
               `Assoc [ ("name", `String name); ("arity", `Int arity) ])
             v.rels) );
    ]

(* Vocabulary agreement first: it decides which models exist at all, so a
   divergence here would silently weaken every entailment comparison. *)
let diff_vocab =
  Harness.gate "differential: vocabOf agrees (names, kinds, order)"
    ~count:5_000 ~print:print_proposition
    (G.oneof
       [
         Gen.sem_categorical_prop [ "A"; "B"; "C" ];
         Gen.sem_relational_prop [ "A"; "B" ] "R";
       ])
    (fun p ->
      expect_json "oracleVocab"
        [ `List [ Ast_json.prop_to_json p ] ]
        (vocab_to_json (Semantics.vocab_of [ p ])))

(* Per-model evaluation: the entailment gate below only compares an aggregate
   over many models, so a term-level bug can cancel out. This one cannot. *)
let model_of (p : Tfl.Ast.prop) : Semantics.model G.t =
  let open G in
  let v = Semantics.vocab_of [ p ] in
  let rec assoc keys value =
    match keys with
    | [] -> return []
    | k :: rest ->
        let* x = value in
        let* tail = assoc rest value in
        return ((k, x) :: tail)
  in
  (* A singular or proterm needs somewhere to point, so those vocabularies
     have no empty-domain model. *)
  let* n = if v.singular = [] then int_range 0 3 else int_range 1 3 in
  let* singular =
    if n = 0 then return [] else assoc v.singular (int_bound (n - 1))
  in
  let* unary = assoc v.unary (int_bound ((1 lsl n) - 1)) in
  let* rels =
    let rec go = function
      | [] -> return []
      | (base, arity) :: rest ->
          let tuples = Semantics.all_tuples n arity in
          let* mask = int_bound ((1 lsl List.length tuples) - 1) in
          let* tail = go rest in
          return
            ((Semantics.key_of base arity, Semantics.subset tuples mask) :: tail)
    in
    go v.rels
  in
  return
    ({ n; full = (1 lsl n) - 1; singular; unary; rels } : Semantics.model)

let diff_eval =
  Harness.gate "differential: evalProp agrees model by model" ~count:10_000
    ~print:(fun (p, m) -> print_proposition p ^ "  @  " ^ Semantics.show_model m)
    (let open G in
     let* p =
       oneof
         [
           Gen.sem_categorical_prop [ "A"; "B"; "C" ];
           Gen.sem_relational_prop [ "A"; "B" ] "R";
         ]
     in
     let* m = model_of p in
     return (p, m))
    (fun (p, m) ->
      expect_json "oracleEvalProp"
        [ Ast_json.prop_to_json p; model_to_json m ]
        (`Bool (Semantics.eval_prop p m)))

(* Entailment verdicts: the acceptance check for 1.10. *)
let entailment_gate name ~count ~max_n ~tally gen =
  Harness.gate name ~count ~print:Gen.print_argument gen
    (fun (premises, conclusion) ->
      let all = premises @ [ conclusion ] in
      if not (Semantics.exhaustive_upto (Semantics.vocab_of all) ~max_n ~cap)
      then (
        tally.skipped <- tally.skipped + 1;
        None)
      else
        let ours = Semantics.entails ~max_n ~cap premises conclusion in
        tally.compared <- tally.compared + 1;
        if ours then tally.entailed <- tally.entailed + 1;
        match
          expect_json "oracleEntails"
            [
              `List (List.map Ast_json.prop_to_json premises);
              Ast_json.prop_to_json conclusion;
              `Assoc [ ("maxN", `Int max_n); ("cap", `Int cap) ];
            ]
            (`Bool ours)
        with
        | None -> None
        | Some d ->
            Some
              (d ^ " — ocaml counter-model: "
              ^
              match Semantics.counter_model ~max_n ~cap premises conclusion with
              | Some m -> Semantics.show_model m
              | None -> "none"))

let categorical_tally = new_tally ()
let relational_tally = new_tally ()

let diff_categorical =
  entailment_gate "differential: entailment agrees on categorical arguments"
    ~count:3_000 ~max_n:3 ~tally:categorical_tally Gen.sem_categorical_argument

(* Relational vocabularies blow past the cap at n = 3 (a binary relation alone
   contributes 2⁹ extensions), so these run at n ≤ 2 — where the ∀∃/∃∀ scope
   separations already show up. *)
let diff_relational =
  entailment_gate "differential: entailment agrees on relational arguments"
    ~count:2_000 ~max_n:2 ~tally:relational_tally Gen.sem_relational_argument

(* Harness self-test: a wrong verdict must be DETECTED, or a clean run means
   nothing. Darapti is semantically invalid here (no existential import), so
   claiming entailment has to come back as a disagreement. *)
let negative_control () =
  let premises = props [ "−M+P"; "−M+S" ] and conclusion = parse_proposition "+S+P" in
  match
    expect_json "oracleEntails"
      [
        `List (List.map Ast_json.prop_to_json premises);
        Ast_json.prop_to_json conclusion;
        `Assoc [ ("maxN", `Int max_n); ("cap", `Int cap) ];
      ]
      (`Bool true)
  with
  | Some _ -> true
  | None ->
      prerr_endline
        "✗ negative control: harness failed to detect a wrong entailment verdict";
      false

let report label t =
  Printf.printf "%s: %d compared (%d entailed), %d skipped past the cap\n" label
    t.compared t.entailed t.skipped

let () =
  anchors ();
  Harness.summarize "semantics anchors";
  let control_ok = negative_control () in
  let qcheck_failures =
    QCheck_base_runner.run_tests ~verbose:true
      [ diff_vocab; diff_eval; diff_categorical; diff_relational ]
  in
  Shim_client.stop shim;
  report "categorical entailment" categorical_tally;
  report "relational entailment" relational_tally;
  exit
    (if Harness.exit_code () <> 0 || (not control_ok) || qcheck_failures <> 0
     then 1
     else 0)
