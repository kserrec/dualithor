(* PLAN Phase B, first-pass audit of the nine regulatory records originally
   accepted as strictly in-fragment.

   The 2026-08-02 source labels are frozen measurements, so the re-audit lives
   beside rather than overwrites them. This test makes five quiet forms of
   drift loud: changing the audited population, dropping a duplicate, storing
   a formula that does not parse canonically, storing a renderer claim the
   engine does not produce, or hand-editing the reported sensitivity counts. *)

open Harness

let normative_path = "../data/fidelity/real/labels.jsonl"
let definitions_path = "../data/fidelity/real/labels-defs.jsonl"
let audit_path = "../data/fidelity/real/audit-pass-1.jsonl"
let packet_path = "../data/fidelity/real/SECOND-ANNOTATOR-PACKET.md"

let read_jsonl path =
  let ic = open_in path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () ->
      let rec go acc =
        match input_line ic with
        | exception End_of_file -> List.rev acc
        | line when String.trim line = "" -> go acc
        | line -> go (Yojson.Safe.from_string line :: acc)
      in
      go [])

let read_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let contains haystack needle =
  let hn = String.length haystack and nn = String.length needle in
  let rec go i =
    i + nn <= hn && (String.sub haystack i nn = needle || go (i + 1))
  in
  nn = 0 || go 0

let mem name j = Yojson.Safe.Util.member name j
let str name j = Yojson.Safe.Util.to_string (mem name j)
let id j = str "id" j

let strings name j =
  match mem name j with
  | `List xs -> List.map Yojson.Safe.Util.to_string xs
  | `Null -> []
  | _ -> failwith (Printf.sprintf "%s: %s must be a string list" (id j) name)

let sort_ids rows = List.sort compare (List.map id rows)
let original_rows = read_jsonl normative_path @ read_jsonl definitions_path

let original_accepted =
  List.filter (fun j -> str "label" j = "in") original_rows

let audit_rows = read_jsonl audit_path

let find id_wanted rows =
  match List.find_opt (fun j -> id j = id_wanted) rows with
  | Some j -> j
  | None -> failwith ("missing row " ^ id_wanted)

let audit_label original =
  match List.find_opt (fun a -> id a = id original) audit_rows with
  | Some a -> str "audit_label" a
  | None -> str "label" original

let unique_by_text rows =
  let seen = Hashtbl.create 128 in
  List.filter
    (fun j ->
      let nl = str "nl" j in
      if Hashtbl.mem seen nl then false
      else (
        Hashtbl.add seen nl ();
        true))
    rows

let count_labelled_in rows label_of =
  List.length (List.filter (fun j -> label_of j = "in") rows)

let () =
  test "the first pass is exactly the nine frozen accepted records" (fun () ->
      let expected =
        List.sort compare
          [ "r25"; "r41"; "r54"; "d01"; "d03"; "d05"; "d11"; "d17"; "d47" ]
      in
      check
        (sort_ids original_accepted = expected)
        "the frozen source accepted set no longer matches the enumerated nine";
      check
        (sort_ids audit_rows = expected)
        "audit-pass-1.jsonl must contain each accepted record exactly once");

  test "the audit copies source identity and text without changing them"
    (fun () ->
      List.iter
        (fun a ->
          let source = find (id a) original_accepted in
          check_eq (str "original_label" a) "in";
          check_eq (str "source" a) (str "source" source);
          check_eq (str "nl" a) (str "nl" source))
        audit_rows);

  test "every retained formula parses canonically and renders as recorded"
    (fun () ->
      List.iter
        (fun a ->
          match str "audit_label" a with
          | "in" -> (
              check
                (strings "audit_blockers" a = [])
                (id a ^ ": an in record must have no blockers");
              match mem "formula" a with
              | `String formula -> (
                  match Tfl.Safe.parse formula with
                  | Error (failure : Tfl.Safe.failure) ->
                      failwith
                        (Printf.sprintf "%s: formula %S does not parse: %s [%s]"
                           (id a) formula failure.message
                           (Tfl.Safe.kind_name failure.kind))
                  | Ok prop ->
                      check_eq (Tfl.Notation.print_proposition prop) formula;
                      check_eq (Tfl.Render.read_prop prop) (str "rendered" a))
              | _ -> failwith (id a ^ ": an in record needs a formula"))
          | "out" ->
              check
                (mem "formula" a = `Null)
                (id a ^ ": an out record must not carry a formula");
              check
                (mem "rendered" a = `Null)
                (id a ^ ": an out record must not carry a rendering");
              check
                (strings "audit_blockers" a <> [])
                (id a ^ ": an out record needs a blocker")
          | label ->
              failwith
                (Printf.sprintf "%s: invalid audit label %S" (id a) label))
        audit_rows);

  test "the two identified false accepts are explicit" (fun () ->
      let d03 = find "d03" audit_rows and d47 = find "d47" audit_rows in
      check_eq (str "audit_label" d03) "out";
      check
        (List.mem "definitional-equivalence" (strings "audit_blockers" d03))
        "d03 must record the missing converse";
      check_eq (str "audit_label" d47) "out";
      check
        (List.mem "anaphora" (strings "audit_blockers" d47))
        "d47 must record its cross-sentence antecedent dependency");

  test "the duplicated ADA sentence remains duplicated and identically judged"
    (fun () ->
      let r41 = find "r41" audit_rows and d11 = find "d11" audit_rows in
      check_eq (str "nl" r41) (str "nl" d11);
      check_eq (str "audit_label" r41) (str "audit_label" d11);
      check
        (mem "formula" r41 = mem "formula" d11)
        "r41 and d11 must carry the same formula");

  test "the independent-human packet contains no first-pass formula" (fun () ->
      let packet = read_file packet_path in
      List.iter
        (fun a ->
          match mem "formula" a with
          | `String formula ->
              check
                (not (contains packet formula))
                (id a ^ ": first-pass formula leaked into the blinded packet")
          | _ -> ())
        audit_rows);

  test "first-pass raw and de-duplicated sensitivity counts regenerate"
    (fun () ->
      check (List.length original_rows = 110) "expected 110 sampled records";
      check
        (List.length (unique_by_text original_rows) = 107)
        "expected 107 exact sentence texts after de-duplication";
      check
        (count_labelled_in original_rows (fun j -> str "label" j) = 9)
        "frozen raw accepted count must remain 9";
      check
        (count_labelled_in (unique_by_text original_rows) (fun j ->
             str "label" j)
        = 8)
        "frozen de-duplicated accepted count must remain 8";
      check
        (count_labelled_in original_rows audit_label = 7)
        "first-pass raw accepted count must be 7";
      check
        (count_labelled_in (unique_by_text original_rows) audit_label = 6)
        "first-pass de-duplicated accepted count must be 6");

  finish "regulatory accepted-set audit"
