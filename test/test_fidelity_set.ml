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
      contaminated items are exactly the ones that look like successes. *)

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
        match Yojson.Safe.Util.member "kind" j with `Null -> None | _ -> Some j)
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

(* ── Every gold formula parses ─────────────────────────────────────────── *)

let must_parse where tfl =
  match Tfl.Safe.parse tfl with
  | Ok p -> p
  | Error (f : Tfl.Safe.failure) ->
      failwith
        (Printf.sprintf "%s: gold formula %S does not parse — %s [%s]" where tfl
           f.message (Tfl.Safe.kind_name f.kind))

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
  test "every also_ok parses and is genuinely different from the gold" (fun () ->
      List.iter
        (fun j ->
          let gold = must_parse (id j) (str "tfl" j) in
          List.iter
            (fun alt ->
              let p = must_parse (id j ^ " also_ok") alt in
              check
                (not (Tfl.Ast.prop_eq gold p))
                (Printf.sprintf "%s: also_ok %S is the same proposition as the gold"
                   (id j) alt))
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
            List.map (fun p -> str "tfl" p) (Yojson.Safe.Util.to_list (mem "premises" j))
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
          check (mem "tfl" j = `Null)
            (id j ^ ": a decline must not carry a gold formula");
          check (String.length (str "reason" j) > 0) (id j ^ ": decline needs a reason"))
        declines)

(* ── Hygiene: unique ids, no contamination from the prompt ─────────────── *)

let normalise s =
  String.lowercase_ascii (String.trim s)
  |> String.map (fun c -> if c = '\t' || c = '\n' then ' ' else c)

let all_nl =
  List.concat_map
    (fun j ->
      match str "kind" j with
      | "argument" ->
          str "nl" (mem "conclusion" j)
          :: List.map (fun p -> str "nl" p) (Yojson.Safe.Util.to_list (mem "premises" j))
      | _ -> [ str "nl" j ])
    items

let () =
  test "item ids are unique" (fun () ->
      let ids = List.sort compare (List.map id items) in
      let rec dup = function
        | a :: (b :: _ as rest) -> if a = b then Some a else dup rest
        | _ -> None
      in
      match dup ids with Some d -> failwith ("duplicate id " ^ d) | None -> ());
  (* The contamination guard. A sentence the prompt already shows the model is
     not a test of translation. *)
  test "no gold sentence appears in the few-shot prompt" (fun () ->
      let taught =
        List.map (fun (nl, _) -> normalise nl) Translate.Prompts.few_shots
        @ List.map (fun (nl, _) -> normalise nl) Translate.Prompts.untranslatable_examples
      in
      List.iter
        (fun nl ->
          check
            (not (List.mem (normalise nl) taught))
            (Printf.sprintf "contamination: %S is a few-shot example" nl))
        all_nl);
  test "no gold formula appears in the few-shot prompt" (fun () ->
      let taught =
        List.filter_map
          (fun (_, tfl) ->
            match Tfl.Safe.parse tfl with Ok p -> Some p | Error _ -> None)
          Translate.Prompts.few_shots
      in
      List.iter
        (fun j ->
          let p = must_parse (id j) (str "tfl" j) in
          check
            (not (List.exists (fun t -> Tfl.Ast.prop_eq t p) taught))
            (Printf.sprintf "contamination: %s's gold formula is a few-shot"  (id j)))
        sentences)

(* ── Composition, printed so a shrinking set is visible ────────────────── *)

let () =
  let tags = Hashtbl.create 32 in
  List.iter
    (fun j ->
      List.iter
        (fun t ->
          Hashtbl.replace tags t (1 + Option.value ~default:0 (Hashtbl.find_opt tags t)))
        (strings "tags" j))
    items;
  let argument_sentences =
    List.fold_left
      (fun n j -> n + 1 + List.length (Yojson.Safe.Util.to_list (mem "premises" j)))
      0 arguments
  in
  Printf.printf
    "fidelity set: %d items — %d sentences, %d arguments (%d sentences), %d declines; \
     %d distinct tags; %d translatable sentences total\n"
    (List.length items) (List.length sentences) (List.length arguments)
    argument_sentences (List.length declines) (Hashtbl.length tags)
    (List.length sentences + argument_sentences);
  (* Constructions the set must not quietly lose. *)
  List.iter
    (fun t ->
      test ("covers " ^ t) (fun () ->
          check (Hashtbl.mem tags t) ("no item tagged " ^ t)))
    [ "A-form"; "E-form"; "I-form"; "O-form"; "singular"; "negative-term";
      "compound-term"; "quoted-term"; "hyphen-trap"; "relational";
      "universal-object"; "relational-subject"; "nested-object"; "numerical";
      "relation-reuse"; "term-reuse"; "out-of-fragment" ]

let () = finish "fidelity gold set"
