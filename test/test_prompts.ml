(* PLAN 4.2 — the translation prompt.

   The acceptance check is that every few-shot formula parses, and it is not a
   formality: a prompt that teaches a formula the engine cannot read would
   make every model in the study look worse than it is, and nothing else in
   the pipeline would notice — the model would faithfully copy the malformed
   shape and the harness would score it as a parse failure.

   The rest of this file guards the second, slower way the prompt can rot:
   losing coverage. The few-shot set is what teaches each construction, so a
   trimmed list silently narrows the notation the models ever see. Each
   coverage check below names the construction it keeps alive. *)

open Harness
open Translate.Prompts

let parsed =
  List.map
    (fun (nl, tfl) ->
      match Tfl.Safe.parse tfl with
      | Ok p -> (nl, tfl, p)
      | Error (f : Tfl.Safe.failure) ->
          failwith
            (Printf.sprintf "few-shot %S: %s is unparseable — %s [%s]" nl tfl
               f.message
               (Tfl.Safe.kind_name f.kind)))
    few_shots

(* A few-shot must also survive the round trip the pipeline puts it through:
   the printer's typographic output has to parse back to the same tree, or the
   formula we teach and the formula we would show back differ. *)
let () =
  test "every few-shot formula parses and round-trips" (fun () ->
      List.iter
        (fun (nl, tfl, p) ->
          let printed = Tfl.Notation.print_proposition p in
          match Tfl.Safe.parse printed with
          | Error _ ->
              failwith (Printf.sprintf "%S: printed form %S will not parse" nl printed)
          | Ok p' ->
              check (Tfl.Ast.prop_eq p p')
                (Printf.sprintf "%S: %s printed as %s, which reads differently"
                   nl tfl printed))
        parsed)

(* ── Coverage ──────────────────────────────────────────────────────────── *)

let props = List.map (fun (_, _, p) -> p) parsed

let signed_terms (p : Tfl.Ast.prop) = [ p.subject; p.predicate ]

(* Every signed term anywhere in a proposition, objects and compound elements
   included — coverage questions are about the whole tree, not the top level. *)
let rec all_signed (st : Tfl.Ast.signed_term) : Tfl.Ast.signed_term list =
  st
  :: (match st.term with
     | Tfl.Ast.Compound elems | Tfl.Ast.Rel { objects = elems; _ } ->
         List.concat_map all_signed elems
     | _ -> [])

let every_signed = List.concat_map all_signed (List.concat_map signed_terms props)

let rec terms_of (t : Tfl.Ast.term) : Tfl.Ast.term list =
  t
  :: (match t with
     | Tfl.Ast.Neg inner -> terms_of inner
     | Tfl.Ast.Compound elems | Tfl.Ast.Rel { objects = elems; _ } ->
         List.concat_map (fun (st : Tfl.Ast.signed_term) -> terms_of st.term) elems
     | _ -> [])

let every_term = List.concat_map (fun (st : Tfl.Ast.signed_term) -> terms_of st.term)
    (List.concat_map signed_terms props)

let covers name pred = test ("covers " ^ name) (fun () -> check (pred ()) name)
let exists_term f () = List.exists f every_term
let exists_signed f () = List.exists f every_signed

let form s_sign p_sign () =
  List.exists
    (fun (p : Tfl.Ast.prop) -> p.subject.sign = s_sign && p.predicate.sign = p_sign)
    props

let () =
  (* PLAN 4.2 sized this 10–15; the 2026-08-02 level-3 correction added a
     sixteenth rather than drop a working pair to make room. *)
  test "the few-shot set is 10–16 pairs, as the plan sizes it" (fun () ->
      let n = List.length few_shots in
      check (n >= 10 && n <= 16) (Printf.sprintf "%d pairs" n));
  test "no formula is taught twice" (fun () ->
      let tfls = List.sort compare (List.map snd few_shots) in
      let rec dup = function
        | a :: (b :: _ as rest) -> if a = b then Some a else dup rest
        | _ -> None
      in
      match dup tfls with
      | Some t -> failwith (Printf.sprintf "%s appears twice" t)
      | None -> ());
  covers "the A form (every S is P)" (form Tfl.Ast.Minus Tfl.Ast.Plus);
  covers "the E form (no S is P)" (form Tfl.Ast.Minus Tfl.Ast.Minus);
  covers "the I form (some S is P)" (form Tfl.Ast.Plus Tfl.Ast.Plus);
  covers "the O form (some S is not P)" (form Tfl.Ast.Plus Tfl.Ast.Minus);
  covers "the wild sign a singular subject needs"
    (exists_signed (fun st -> st.sign = Tfl.Ast.Wild));
  covers "singular terms"
    (exists_term (function Tfl.Ast.Atom { singular = true; _ } -> true | _ -> false));
  covers "negative terms"
    (exists_term (function Tfl.Ast.Neg _ -> true | _ -> false));
  covers "compound terms"
    (exists_term (function Tfl.Ast.Compound _ -> true | _ -> false));
  covers "relational complexes"
    (exists_term (function Tfl.Ast.Rel _ -> true | _ -> false));
  (* Without this one the models only ever see ∃-objects, and the ∀∃/∃∀
     distinction — the thing the notation is advertised on — goes untaught. *)
  covers "a relational with a universal object" (fun () ->
      List.exists
        (function
          | Tfl.Ast.Rel { objects; _ } ->
              List.exists (fun (st : Tfl.Ast.signed_term) -> st.sign = Tfl.Ast.Minus) objects
          | _ -> false)
        every_term);
  (* Hyphens lex as minus, so a quoted name is the only way to write one; a
     prompt that stops showing this teaches an unparseable habit. *)
  covers "a quoted name (the hyphen trap)"
    (exists_term (function
      | Tfl.Ast.Atom { name; _ } -> String.contains name ' ' || String.contains name '-'
      | _ -> false));
  covers "a TFL⁺ quantity level" (exists_signed (fun st -> st.level > 0))

(* The passive example is the one place a subscript run has to be read as
   pairing roles rather than as part of the name. If it ever degrades into a
   plain name the example still parses — it just stops being a passive, and
   silently teaches the models a relation called "Lov₂₁". *)
let () =
  test "the passive example really carries pairing subscripts" (fun () ->
      let passive =
        List.find_map
          (fun (p : Tfl.Ast.prop) ->
            match p.predicate.term with
            | Tfl.Ast.Rel { head = Tfl.Ast.Atom { name; _ }; objects } ->
                let base, roles = Tfl.Infer.head_roles name (List.length objects + 1) in
                if roles <> [] && base <> name then Some (base, roles) else None
            | _ -> None)
          props
      in
      match passive with
      | Some (_, roles) ->
          check (roles = [ 2; 1 ])
            (Printf.sprintf "expected the 2-1 swap, got [%s]"
               (String.concat ";" (List.map string_of_int roles)))
      | None -> failwith "no few-shot carries a pairing-subscript head")

(* ── The prompt actually carries the lists ─────────────────────────────── *)

let contains hay nee =
  let n = String.length nee and h = String.length hay in
  let rec go i = i + n <= h && (String.sub hay i n = nee || go (i + 1)) in
  n = 0 || go 0

let () =
  test "every few-shot pair reaches the system prompt" (fun () ->
      List.iter
        (fun (nl, tfl) ->
          check (contains system nl) (Printf.sprintf "%S missing from the prompt" nl);
          check (contains system tfl) (Printf.sprintf "%S missing from the prompt" tfl))
        few_shots);
  test "every decline example reaches the system prompt" (fun () ->
      List.iter
        (fun (nl, reason) ->
          check (contains system nl) (Printf.sprintf "%S missing from the prompt" nl);
          check (contains system reason) (Printf.sprintf "reason for %S missing" nl))
        untranslatable_examples);
  test "the JSON contract is stated" (fun () ->
      check (contains system "\"translations\"") "translations key not named";
      check (contains system "\"untranslatable\"") "untranslatable key not named";
      check (contains system "confidence") "confidence not explained");
  (* No verdicts in the prompt: a model shown a valid/invalid judgement can
     reason to the answer and fit a formula to it, which is the confound the
     fidelity claim has to avoid. *)
  test "the prompt teaches no verdicts" (fun () ->
      List.iter
        (fun word ->
          check (not (contains system word))
            (Printf.sprintf "the prompt mentions %S — it must not judge arguments" word))
        [ "valid"; "invalid"; "entail"; "follows from"; "conclusion" ]);
  test "the user message numbers the sentences it sends" (fun () ->
      let u = user [ "Every horse is an animal."; "No dog is a cat." ] in
      check (contains u "1. Every horse is an animal.") "sentence 1 missing";
      check (contains u "2. No dog is a cat.") "sentence 2 missing";
      check (contains u "2 sentences") "the count is not stated")

(* ── The level-3 polarity flip (corrected 2026-08-02) ──────────────────────
   Level 3 marks the predominant *complement*, so a "few S are P" sentence
   needs the MINUS predicate sign: `+S^3-P`. The prompt originally said only
   "^3 few"; our own gold for i04 repeated the error, and all three models
   copied it and were scored correct against it. Nothing in the pipeline
   noticed, because a wrong-but-well-formed formula parses.

   Pinned here rather than left to prose, and checked against the engine's own
   English reading rather than against our restatement of the rule. *)

let () =
  test "a `Few ...` few-shot is taught, with level 3 and a minus predicate" (fun () ->
      let few =
        List.filter
          (fun (nl, _, _) ->
            String.length nl >= 4 && String.lowercase_ascii (String.sub nl 0 4) = "few ")
          parsed
      in
      check (few <> []) "no `Few ...` pair is taught — the flip is untested";
      List.iter
        (fun (nl, tfl, (p : Tfl.Ast.prop)) ->
          check (p.subject.level = 3)
            (Printf.sprintf "%S: subject level is %d, expected 3" nl p.subject.level);
          check
            (p.predicate.sign = Tfl.Ast.Minus)
            (Printf.sprintf
               "%S is taught as %s — a `few S are P` sentence needs the MINUS predicate \
                sign, or it asserts the opposite"
               nl tfl))
        few);
  (* The independent check: the engine reads it back as the sentence says. *)
  test "every `Few ...` few-shot reads back without a negation" (fun () ->
      List.iter
        (fun (nl, _, p) ->
          if String.length nl >= 4 && String.lowercase_ascii (String.sub nl 0 4) = "few " then
            let reading = Tfl.Render.read_prop p in
            check
              (not (contains reading " not "))
              (Printf.sprintf "%S renders as %S — the polarity is inverted" nl reading))
        parsed);
  test "the notation text states that level 3 flips polarity" (fun () ->
      check (contains system "+S^3-P") "the flipped form is not shown";
      check (contains system "COMPLEMENT") "the reason for the flip is not stated")

let () = finish "translation prompt"
