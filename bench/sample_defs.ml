(* PLAN 4.6, second sample — definitional regulatory text.

   The default mode implements the dated correction protocol after the original
   2026-08-02 run was found to reverse sentences within every paragraph. The
   explicit [--legacy] mode reproduces that frozen historical sample. Extraction,
   filtering, and sampling remain shared with the normative sampler.

   D1 — sections headed "Definitions" in the same three parts the normative
        sample came from. Holds the corpus constant, varies only genre.
   D2 — standards of identity (21 CFR 131/133/137): definitional regulation from
        a different agency and subject, to check D1 is not an artifact of three
        particular parts.

   Output: data/fidelity/real/sample-defs-corrected-2026-08-11.jsonl
   Legacy: data/fidelity/real/sample-defs.jsonl *)

open Bench.Cfr

let per_source = 10

type mode = Corrected | Legacy

let mode =
  match Array.to_list Sys.argv with
  | [ _ ] -> Corrected
  | [ _; "--legacy" ] -> Legacy
  | _ -> failwith "usage: sample_defs.exe [--legacy]"

let out_path =
  match mode with
  | Corrected -> "data/fidelity/real/sample-defs-corrected-2026-08-11.jsonl"
  | Legacy -> "data/fidelity/real/sample-defs.jsonl"

let candidates =
  match mode with
  | Corrected -> candidates_of
  | Legacy -> candidates_of_legacy_reversed

let d1 = [ ("7", "273", "SNAP"); ("20", "416", "SSI"); ("24", "5", "HUD") ]

let d2 =
  [
    ("21", "131", "milk and cream");
    ("21", "133", "cheeses and related products");
    ("21", "137", "cereal flours and related products");
  ]

let path title part = Printf.sprintf "data/raw/cfr-%s-%s.xml" title part

let load title part =
  let p = path title part in
  if not (Sys.file_exists p) then
    failwith (p ^ " missing — fetch URL is in data/fidelity/real/PROTOCOL-2.md");
  read_file p

let () =
  let oc = open_out out_path in
  Fun.protect ~finally:(fun () -> close_out_noerr oc) @@ fun () ->
  let total = ref 0 in
  let emit domain title part subject picked =
    List.iteri
      (fun i s ->
        incr total;
        Printf.fprintf oc
          {|{"id": "d%02d", "domain": "%s", "source": "%s CFR %s", "subject": "%s", "n": %d, "nl": "%s"}|}
          !total domain title part subject i (json_escape s);
        output_char oc '\n')
      picked
  in
  (* D1: genre selected by section heading, then every candidate sentence in
     those sections enters the pool — tractable or not. *)
  List.iter
    (fun (title, part, subject) ->
      let secs =
        sections (load title part)
        |> List.filter (fun (head, _) -> contains ~needle:"Definition" head)
      in
      let cands = List.concat_map (fun (_, b) -> candidates b) secs in
      let picked = take_every_kth cands per_source in
      Printf.printf
        "D1 %-12s %2d definition sections, %4d candidates, sampled %d\n%!"
        (Printf.sprintf "%s CFR %s" title part)
        (List.length secs) (List.length cands) (List.length picked);
      emit "D1-definitions" title part subject picked)
    d1;
  (* D2: the whole part is definitional by construction (standards of identity),
     so every section counts. *)
  List.iter
    (fun (title, part, subject) ->
      let cands = candidates (load title part) in
      let picked = take_every_kth cands per_source in
      Printf.printf "D2 %-12s %4d candidates, sampled %d\n%!"
        (Printf.sprintf "%s CFR %s" title part)
        (List.length cands) (List.length picked);
      emit "D2-standards-of-identity" title part subject picked)
    d2;
  Printf.printf "\nwrote %d sentences to %s\n" !total out_path
