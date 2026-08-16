(* The fidelity gold set (data/fidelity/items.jsonl) checked against the engine.

   A gold set is the measuring instrument, and a wrong entry in it is worse
   than no measurement: every downstream number still computes, the run looks
   healthy, and the result is fiction. Three specific ways that happens, each
   guarded below.

   1. **A gold formula that does not parse.** Then the item can never be
      scored correct and the model is charged for our typo.
   2. **An argument whose stated verdict is wrong.** Then a faithful
      translation gets marked as producing the wrong answer.
   3. **Contamination.** A test sentence that also appears in the few-shot
      prompt measures copying, not translation. This one is the easiest to
      introduce by accident and the hardest to notice afterwards, because the
      contaminated items are exactly the ones that look like successes.

   PLAN 4.8 adds a fourth, and it is the one that bites late. The moment a
   prompt is changed in response to an observed error, the items that revealed
   that error stop being evaluation data — they are now part of the training
   loop, and any number computed over them is self-graded. So every item
   carries a `split`, and the guards below are asymmetric on purpose:

   - **dev** may be inspected, argued over, and lifted into the prompt.
   - **eval** may not appear in the prompt, ever, and may not be moved to dev
     after its result is known. The eval id list is pinned in this file, so
     re-labelling an item that failed takes an explicit code change rather
     than a quiet edit to a data file. *)

open Harness

let path = "../data/fidelity/items.jsonl"

let lines () =
  let ic = open_in path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () ->
      let rec go acc =
        match input_line ic with
        | l -> go (l :: acc)
        | exception End_of_file -> List.rev acc
      in
      go [])

let items =
  List.filter_map
    (fun l ->
      let l = String.trim l in
      if l = "" then None
      else
        let j = Yojson.Safe.from_string l in
        (* the leading _comment line documents the format, not an item *)
        match Yojson.Safe.Util.member "kind" j with
        | `Null -> None
        | _ -> Some j)
    (lines ())

let mem name j = Yojson.Safe.Util.member name j
let str name j = Yojson.Safe.Util.to_string (mem name j)
let id j = str "id" j

let strings name j =
  match mem name j with
  | `Null -> []
  | l -> List.map Yojson.Safe.Util.to_string (Yojson.Safe.Util.to_list l)

let of_kind k = List.filter (fun j -> str "kind" j = k) items
let sentences = of_kind "sentence"
let arguments = of_kind "argument"
let declines = of_kind "decline"
let split j = str "split" j
let of_split s = List.filter (fun j -> split j = s) items

(* ── Every gold formula parses ─────────────────────────────────────────── *)

let must_parse where tfl =
  match Tfl.Safe.parse tfl with
  | Ok p -> p
  | Error (f : Tfl.Safe.failure) ->
      failwith
        (Printf.sprintf "%s: gold formula %S does not parse — %s [%s]" where tfl
           f.message
           (Tfl.Safe.kind_name f.kind))

let () =
  test "every sentence's gold formula parses" (fun () ->
      List.iter (fun j -> ignore (must_parse (id j) (str "tfl" j))) sentences);
  test "every argument's formulas parse" (fun () ->
      List.iter
        (fun j ->
          let where = id j in
          List.iter
            (fun p -> ignore (must_parse where (str "tfl" p)))
            (Yojson.Safe.Util.to_list (mem "premises" j));
          ignore (must_parse where (str "tfl" (mem "conclusion" j))))
        arguments);
  (* An alternate that reads back identically to the gold is noise in the
     scorer, not a real alternative — it would silently widen nothing. *)
  test "every also_ok parses and is genuinely different from the gold"
    (fun () ->
      List.iter
        (fun j ->
          let gold = must_parse (id j) (str "tfl" j) in
          List.iter
            (fun alt ->
              let p = must_parse (id j ^ " also_ok") alt in
              check
                (not (Tfl.Ast.prop_eq gold p))
                (Printf.sprintf
                   "%s: also_ok %S is the same proposition as the gold" (id j)
                   alt))
            (strings "also_ok" j))
        sentences)

(* ── Every argument's stated verdict is the engine's ───────────────────── *)

let verdict_name (r : Tfl_verify.result) =
  match r.verdict with
  | Valid -> "valid"
  | Invalid -> "invalid"
  | Contradicted -> "contradicted"
  | Unknown -> "unknown"
  | Error e -> "error:" ^ e.message

let () =
  test "every argument's stated verdict matches the engine" (fun () ->
      List.iter
        (fun j ->
          let premises =
            List.map
              (fun p -> str "tfl" p)
              (Yojson.Safe.Util.to_list (mem "premises" j))
          in
          let conclusion = str "tfl" (mem "conclusion" j) in
          let got = verdict_name (Tfl_verify.check ~premises ~conclusion) in
          let want = str "verdict" j in
          check (got = want)
            (Printf.sprintf "%s: stated %s, engine says %s" (id j) want got))
        arguments)

(* ── Declines carry no formula ─────────────────────────────────────────── *)

let () =
  test "declines have a reason and no gold formula" (fun () ->
      List.iter
        (fun j ->
          check
            (mem "tfl" j = `Null)
            (id j ^ ": a decline must not carry a gold formula");
          check
            (String.length (str "reason" j) > 0)
            (id j ^ ": decline needs a reason"))
        declines)

(* ── Hygiene: unique ids, no contamination from the prompt ─────────────── *)

let normalise s =
  String.lowercase_ascii (String.trim s)
  |> String.map (fun c -> if c = '\t' || c = '\n' then ' ' else c)

(* Every English string an item puts in front of a model, and every formula it
   grades against — arguments carry several of each. *)
let nls_of j =
  match str "kind" j with
  | "argument" ->
      str "nl" (mem "conclusion" j)
      :: List.map
           (fun p -> str "nl" p)
           (Yojson.Safe.Util.to_list (mem "premises" j))
  | _ -> [ str "nl" j ]

let tfls_of j =
  match str "kind" j with
  | "argument" ->
      str "tfl" (mem "conclusion" j)
      :: List.map
           (fun p -> str "tfl" p)
           (Yojson.Safe.Util.to_list (mem "premises" j))
  | "sentence" -> [ str "tfl" j ]
  | _ -> []

let taught_nl =
  List.map (fun (nl, _) -> normalise nl) Translate.Prompts.few_shots
  @ List.map
      (fun (nl, _) -> normalise nl)
      Translate.Prompts.untranslatable_examples

let taught_tfl =
  List.filter_map
    (fun (_, tfl) ->
      match Tfl.Safe.parse tfl with Ok p -> Some p | Error _ -> None)
    Translate.Prompts.few_shots

let () =
  test "item ids are unique" (fun () ->
      let ids = List.sort compare (List.map id items) in
      let rec dup = function
        | a :: (b :: _ as rest) -> if a = b then Some a else dup rest
        | _ -> None
      in
      match dup ids with Some d -> failwith ("duplicate id " ^ d) | None -> ());
  (* The contamination guard, PLAN 4.8. A sentence the prompt already shows the
     model is not a test of translation — so it must not be an eval sentence.
     Dev items are deliberately exempt: promoting a dev item to a few-shot is
     the intended way to fix a translation error, and the split exists so that
     doing so costs us no measurement. *)
  test "no eval sentence appears in the few-shot prompt" (fun () ->
      List.iter
        (fun j ->
          List.iter
            (fun nl ->
              check
                (not (List.mem (normalise nl) taught_nl))
                (Printf.sprintf
                   "contamination: eval item %s's sentence %S is a few-shot"
                   (id j) nl))
            (nls_of j))
        (of_split "eval"));
  test "no eval formula appears in the few-shot prompt" (fun () ->
      List.iter
        (fun j ->
          List.iter
            (fun tfl ->
              let p = must_parse (id j) tfl in
              check
                (not (List.exists (fun t -> Tfl.Ast.prop_eq t p) taught_tfl))
                (Printf.sprintf
                   "contamination: eval item %s's gold formula %S is a few-shot"
                   (id j) tfl))
            (tfls_of j))
        (of_split "eval"))

(* ── The split itself (PLAN 4.8) ───────────────────────────────────────── *)

(* Pinned because the failure this guards against is silent and self-serving:
   an eval item comes back wrong, and it becomes a dev item. Changing the
   split has to be a visible edit here, reviewable in a diff, and never a
   side effect of touching the data file. *)
let eval_ids =
  String.split_on_char ' '
    "a02 a03 a04 a06 a08 a10 b02 b05 b07 b08 c03 c04 c07 c08 d01 d04 d06 d08 \
     e02 e05 e06 e08 f02 f04 f05 f08 g02 g03 g06 h02 h05 i01 i02 i03 i05 j02 \
     j06 j08 k02 k04 k06 k08 k10"
  |> List.filter (fun s -> s <> "")

let () =
  test "every item declares a dev or eval split" (fun () ->
      List.iter
        (fun j ->
          let s = split j in
          check
            (s = "dev" || s = "eval")
            (Printf.sprintf "%s: split is %S, must be \"dev\" or \"eval\""
               (id j) s))
        items);
  test "the eval half is exactly the pinned id list" (fun () ->
      let got = List.sort compare (List.map id (of_split "eval")) in
      let want = List.sort compare eval_ids in
      let show l = String.concat " " l in
      check (got = want)
        (Printf.sprintf
           "the eval half has drifted from the pinned list.\n\
           \  in data: %s\n\
           \  pinned : %s"
           (show got) (show want)));
  (* An eval half missing a construction measures nothing about it, and the
     absence would be invisible in an aggregate score. *)
  test "every group and every categorical form is present in both halves"
    (fun () ->
      let has s p = List.exists p (of_split s) in
      List.iter
        (fun g ->
          List.iter
            (fun s ->
              check
                (has s (fun j -> str "group" j = g))
                (Printf.sprintf "group %s has no %s item" g s))
            [ "dev"; "eval" ])
        [ "A"; "B"; "C"; "D"; "E"; "F"; "G"; "H"; "I"; "J"; "K" ];
      List.iter
        (fun form ->
          List.iter
            (fun s ->
              check
                (has s (fun j -> List.mem form (strings "tags" j)))
                (Printf.sprintf "the %s half has no %s item" s form))
            [ "dev"; "eval" ])
        [ "A-form"; "E-form"; "I-form"; "O-form" ])

(* The guarantee that actually makes the split worth having: promoting a dev
   item into the prompt must cost us no eval measurement. It would cost one,
   silently, if the halves shared any sentence or formula — and they can,
   because group J's arguments are assembled from the same material as groups
   A, F and I. The first cut of this split had three such collisions
   (a01/j04/j05 and a03/i01/j08 among them); each was found by this test, not
   by inspection. *)
let () =
  let no_sharing what key_of =
    let owners = Hashtbl.create 128 in
    List.iter
      (fun j ->
        List.iter
          (fun k ->
            Hashtbl.replace owners k
              ((id j, split j)
              :: Option.value ~default:[] (Hashtbl.find_opt owners k)))
          (key_of j))
      items;
    Hashtbl.iter
      (fun k os ->
        check
          (List.length (List.sort_uniq compare (List.map snd os)) < 2)
          (Printf.sprintf "%s %S straddles the split: %s" what k
             (String.concat ", " (List.map (fun (i, s) -> i ^ "/" ^ s) os))))
      owners
  in
  test "no sentence or formula is shared across the dev/eval split" (fun () ->
      no_sharing "sentence" (fun j -> List.map normalise (nls_of j));
      (* canonical printed form, so two spellings of one proposition collide *)
      no_sharing "formula" (fun j ->
          List.map
            (fun tfl -> Tfl.Notation.print_proposition (must_parse (id j) tfl))
            (tfls_of j)))

(* ── Composition, printed so a shrinking set is visible ────────────────── *)

let () =
  let tags = Hashtbl.create 32 in
  List.iter
    (fun j ->
      List.iter
        (fun t ->
          Hashtbl.replace tags t
            (1 + Option.value ~default:0 (Hashtbl.find_opt tags t)))
        (strings "tags" j))
    items;
  let argument_sentences =
    List.fold_left
      (fun n j ->
        n + 1 + List.length (Yojson.Safe.Util.to_list (mem "premises" j)))
      0 arguments
  in
  Printf.printf
    "fidelity set: %d items — %d sentences, %d arguments (%d sentences), %d \
     declines; %d distinct tags; %d translatable sentences total\n"
    (List.length items) (List.length sentences) (List.length arguments)
    argument_sentences (List.length declines) (Hashtbl.length tags)
    (List.length sentences + argument_sentences);
  Printf.printf "  split: %d dev, %d eval\n"
    (List.length (of_split "dev"))
    (List.length (of_split "eval"));
  (* Constructions the set must not quietly lose. *)
  List.iter
    (fun t ->
      test ("covers " ^ t) (fun () ->
          check (Hashtbl.mem tags t) ("no item tagged " ^ t)))
    [
      "A-form";
      "E-form";
      "I-form";
      "O-form";
      "singular";
      "negative-term";
      "compound-term";
      "quoted-term";
      "hyphen-trap";
      "relational";
      "universal-object";
      "relational-subject";
      "nested-object";
      "numerical";
      "relation-reuse";
      "term-reuse";
      "out-of-fragment";
    ]

let () = finish "fidelity gold set"
