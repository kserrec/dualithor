(* PLAN 4.6 — regenerate every historical number in
   docs/coverage-report-2026-08-02.md from the committed labels.

   This exists because the report's tables were first computed by throwaway
   scripts. Committed labels with no committed derivation is a quiet trap: edit
   one label and every table in the report goes stale with nothing to say so.
   Run this and diff against the report.

   Reads   data/fidelity/real/labels.jsonl        (normative, PROTOCOL.md)
           data/fidelity/real/labels-defs.jsonl   (D1/D2, PROTOCOL-2.md)
   These labels belong to the flawed frozen samples; see the 2026-08-11 erratum.
   Writes nothing. Prints. *)

let normative = "data/fidelity/real/labels.jsonl"
let defs = "data/fidelity/real/labels-defs.jsonl"

type row = {
  id : string;
  group : string;
  label : string;
  blockers : string list;
}

let read_rows path group_of =
  let ic = open_in path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () ->
      let rec go acc =
        match input_line ic with
        | exception End_of_file -> List.rev acc
        | "" -> go acc
        | line ->
            let j = Yojson.Safe.from_string line in
            let str k = Yojson.Safe.Util.(to_string (member k j)) in
            let blockers =
              match Yojson.Safe.Util.member "blockers" j with
              | `List l -> List.map Yojson.Safe.Util.to_string l
              | _ -> []
            in
            go
              ({
                 id = str "id";
                 group = group_of j;
                 label = str "label";
                 blockers;
               }
              :: acc)
      in
      go [])

let pct a b = if b = 0 then 0. else 100. *. float_of_int a /. float_of_int b

(* "Strict" is the label itself. "Ambient-deontic" additionally admits a
   sentence whose ONLY blocker is the modality — see CRITERIA.md for why both
   are reported rather than one being chosen. *)
let is_strict r = r.label = "in"
let is_ambient r = is_strict r || r.blockers = [ "deontic" ]

let all_blockers =
  [
    "multi-clause";
    "deontic";
    "cross-reference";
    "tense";
    "arithmetic";
    "not-a-proposition";
    "defeasible";
  ]

let report name rows =
  let n = List.length rows in
  let s = List.filter is_strict rows and a = List.filter is_ambient rows in
  Printf.printf "\n%s  (n=%d)\n" name n;
  Printf.printf "  strict            %2d/%d = %3.0f%%   %s\n" (List.length s) n
    (pct (List.length s) n)
    (String.concat " " (List.map (fun r -> r.id) s));
  Printf.printf "  ambient-deontic   %2d/%d = %3.0f%%\n" (List.length a) n
    (pct (List.length a) n);
  Printf.printf "  blocked >= twice  %2d/%d\n"
    (List.length (List.filter (fun r -> List.length r.blockers >= 2) rows))
    n;
  List.iter
    (fun b ->
      let k = List.length (List.filter (fun r -> List.mem b r.blockers) rows) in
      if k > 0 then Printf.printf "    %-18s %2d  %3.0f%%\n" b k (pct k n))
    all_blockers

(* What coverage would be if a set of blockers were solved: a sentence is
   reachable when every blocker on it is in the solved set. This is what shows
   that sentence-splitting alone buys three points — the sentences it fixes are
   usually deontic as well. *)
let ceiling rows solved =
  List.length
    (List.filter
       (fun r -> List.for_all (fun b -> List.mem b solved) r.blockers)
       rows)

let () =
  let norm = read_rows normative (fun _ -> "normative") in
  let d =
    read_rows defs (fun j -> Yojson.Safe.Util.(to_string (member "domain" j)))
  in
  let d1 = List.filter (fun r -> r.group = "D1-definitions") d in
  let d2 = List.filter (fun r -> r.group = "D2-standards-of-identity") d in
  print_endline
    "HISTORICAL INVALIDATED MEASUREMENT — see \
     data/fidelity/real/ERRATUM-2026-08-11.md";
  print_endline "coverage of real regulatory text (PLAN 4.6)";
  print_endline
    "regenerated from the committed labels; diff against \
     docs/coverage-report-2026-08-02.md";
  report "normative regulation (7 CFR 273, 20 CFR 416, 24 CFR 5)" norm;
  report "D1  definitions sections (20 CFR 416, 24 CFR 5)" d1;
  report "D2  standards of identity (21 CFR 131/133/137)" d2;
  report "D1+D2 combined" d;
  print_endline "\nceiling analysis over the normative sample";
  List.iter
    (fun (solved, label) ->
      let k = ceiling norm solved in
      Printf.printf "  %-46s %2d/%d = %3.0f%%\n" label k (List.length norm)
        (pct k (List.length norm)))
    [
      ([], "nothing (today)");
      ([ "deontic" ], "ambient deontic (a convention, not a build)");
      ([ "multi-clause" ], "sentence splitting only");
      ([ "deontic"; "multi-clause" ], "splitting AND ambient deontic");
      ( [ "deontic"; "multi-clause"; "cross-reference" ],
        "... plus opaque cross-references" );
      ( [ "deontic"; "multi-clause"; "cross-reference"; "tense" ],
        "... plus a temporal layer" );
      ( [ "deontic"; "multi-clause"; "cross-reference"; "tense"; "arithmetic" ],
        "... plus arithmetic" );
    ]
