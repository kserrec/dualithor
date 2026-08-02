(* 4.4 acceptance: the back-check run over a full model's 4.5b translations.

   The pinned test is `c02` / `c06` — GPT-5.6-terra's E-form sign inversion,
   a real, naturally occurring wrong translation from the 2026-08-01 fidelity
   run. It must be flagged **without the check being told what to look for**.
   That is the whole claim: this catches error classes nobody anticipated,
   where a prompt patch only ever fixes the one already found.

   The rest of the model's translations are the false-positive measurement.
   Pre-registered (scope-and-predictions 1B.3): 5–20% expected; above ~20% the
   check costs more coverage than it buys, and the fix is a better renderer,
   not a looser judge.

   Reads the TSV the fidelity run wrote. Spends real money on a cache miss;
   run by hand from the repo root. *)

let results = "data/results/fidelity-openai_gpt-5.6-terra.tsv"
let judge_model = "anthropic/claude-sonnet-5"
let batch = 12

(* The two known-bad items, named here so the report can score them explicitly.
   Nothing about them reaches the judge. *)
let known_bad = [ "c02"; "c06" ]

type row = { id : string; grade : string; nl : string; got : string }

let load () =
  let ic = open_in results in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () ->
      let rec go acc =
        match input_line ic with
        | l -> (
            match String.split_on_char '\t' l with
            | [ id; grade; nl; _gold; got ] when id <> "id" ->
                go ({ id; grade; nl; got } :: acc)
            | _ -> go acc)
        | exception End_of_file -> List.rev acc
      in
      go [])

let rec chunks n = function
  | [] -> []
  | l ->
      let rec take i acc = function
        | rest when i = 0 -> (List.rev acc, rest)
        | [] -> (List.rev acc, [])
        | x :: rest -> take (i - 1) (x :: acc) rest
      in
      let head, rest = take n [] l in
      head :: chunks n rest

let () =
  (* Only rows carrying a formula the engine can read: the check compares
     meanings, so an unparseable string has nothing to render. *)
  let rows =
    List.filter_map
      (fun r ->
        match Tfl.Safe.parse r.got with
        | Ok p when List.mem r.grade [ "exact"; "structural"; "equivalent"; "wrong" ] ->
            Some (r, p)
        | _ -> None)
      (load ())
  in
  Printf.printf "back-checking %d translations from %s\njudge: %s\n\n%!"
    (List.length rows) results judge_model;
  let judged = ref [] in
  List.iteri
    (fun i group ->
      Printf.printf "  batch %d%!" (i + 1);
      let pairs = List.map (fun (r, p) -> (r.nl, p)) group in
      match Lwt_main.run (Translate.Backcheck.check ~model:judge_model pairs) with
      | Ok js ->
          print_newline ();
          judged := !judged @ List.map2 (fun (r, _) j -> (r, j)) group js
      | Error why -> Printf.printf "  judge reply rejected: %s\n%!" why
      | exception Translate.Llm_client.Llm_error msg ->
          Printf.printf "  call failed: %s\n%!" msg)
    (chunks batch rows);

  let flagged (j : Translate.Backcheck.judgement) =
    Translate.Backcheck.outcome_of j <> Agrees
  in
  print_endline "\n=== the pinned test: GPT's E-form sign inversion";
  List.iter
    (fun (r, j) ->
      if List.mem r.id known_bad then
        Printf.printf "  %s  %-9s  %s\n     source:  %s\n     reading: %s\n     note:    %s\n"
          r.id
          (if flagged j then "FLAGGED" else "MISSED")
          (if flagged j then "✓" else "✗")
          j.Translate.Backcheck.nl j.Translate.Backcheck.rendering
          j.Translate.Backcheck.note)
    !judged;

  (* Everything the fidelity run graded correct is a chance to over-flag. *)
  let correct = List.filter (fun (r, _) -> r.grade <> "wrong") !judged in
  let fp = List.filter (fun (_, j) -> flagged j) correct in
  let bad = List.filter (fun (r, _) -> List.mem r.id known_bad) !judged in
  let caught = List.filter (fun (_, j) -> flagged j) bad in
  Printf.printf "\n=== summary\n";
  Printf.printf "  known-bad caught     %d/%d\n" (List.length caught) (List.length bad);
  Printf.printf "  false positives      %d/%d = %.0f%% of correct translations\n"
    (List.length fp) (List.length correct)
    (100. *. float_of_int (List.length fp) /. float_of_int (max 1 (List.length correct)));
  if fp <> [] then (
    print_endline "\n  over-flagged (these are faithful translations):";
    List.iter
      (fun (r, j) ->
        Printf.printf "    %-5s %-44s -> %-40s %s\n" r.id
          (String.sub j.Translate.Backcheck.nl 0
             (min 42 (String.length j.Translate.Backcheck.nl)))
          j.Translate.Backcheck.rendering j.Translate.Backcheck.note)
      fp);
  let ok = List.length caught = List.length bad && bad <> [] in
  print_endline
    (if ok then "\n4.4 acceptance: PASSED — both known errors flagged unaided"
     else "\n4.4 acceptance: FAILED — a known error was missed");
  if not ok then exit 1
