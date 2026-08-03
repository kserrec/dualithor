(* PLAN 4.6, first sample — normative regulatory text.

   Implements `data/fidelity/real/PROTOCOL.md` exactly and nothing beyond it.
   The extraction pipeline lives in `Cfr`, shared with the definitional sample
   so the two cannot drift apart. Deterministic: the same eCFR snapshot
   reproduces the sample byte for byte.

   Input:  data/raw/cfr-{title}-{part}.xml   (gitignored; US federal, public domain)
   Output: data/fidelity/real/sample.jsonl   (committed) *)

open Bench.Cfr

let sources =
  [ ("7", "273", "SNAP: certification of eligible households");
    ("20", "416", "SSI for the aged, blind, and disabled");
    ("24", "5", "HUD programs: general requirements") ]

let per_part = 20
let out_path = "data/fidelity/real/sample.jsonl"

let json_escape s =
  let b = Buffer.create (String.length s + 8) in
  String.iter
    (fun c ->
      match c with
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | c when Char.code c < 0x20 -> Buffer.add_string b (Printf.sprintf "\\u%04x" (Char.code c))
      | c -> Buffer.add_char b c)
    s;
  Buffer.contents b

let () =
  let oc = open_out out_path in
  Fun.protect ~finally:(fun () -> close_out_noerr oc) @@ fun () ->
  let total = ref 0 in
  List.iter
    (fun (title, part, subject) ->
      let path = Printf.sprintf "data/raw/cfr-%s-%s.xml" title part in
      if not (Sys.file_exists path) then
        failwith (path ^ " missing — see data/fidelity/real/PROTOCOL.md for the fetch URL");
      let candidates =
        paragraphs (read_file path)
        |> List.map (fun p -> squeeze (decode (strip_tags p)))
        |> List.concat_map split_sentences
        |> List.map (fun s -> squeeze (strip_markers s))
        |> List.filter is_candidate
      in
      let picked = take_every_kth candidates per_part in
      Printf.printf "%-14s %5d paragraphs-worth of candidates, sampled %d\n%!"
        (Printf.sprintf "%s CFR %s" title part)
        (List.length candidates) (List.length picked);
      List.iteri
        (fun i s ->
          incr total;
          Printf.fprintf oc
            {|{"id": "r%02d", "source": "%s CFR %s", "subject": "%s", "n": %d, "nl": "%s"}|}
            !total title part subject i (json_escape s);
          output_char oc '\n')
        picked)
    sources;
  Printf.printf "\nwrote %d sentences to %s\n" !total out_path
