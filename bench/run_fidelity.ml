(* PLAN 4.5b — the translation-fidelity run.

   Reads the gold set, sends it through each model, and grades every result.
   Cached, so a re-run costs nothing and the numbers are reproducible.

   Two things are measured that a parse rate cannot see:

   - **Faithfulness**, by grading against the gold structure rather than its
     spelling (see bench/score.ml for why exact match is the wrong metric).
   - **Naming consistency**, by sending each argument as one call and then
     running the model's *own* premises and conclusion back through the engine.
     If a model names one relation two ways across premises, nothing connects
     and the verdict comes back wrong — which is the failure the 4.3 smoke had
     no item to catch. *)

let items_path = "data/fidelity/items.jsonl"
let results_dir = "data/results"
let batch_size = 12

(* ── Loading ─────────────────────────────────────────────────────────────── *)

type sentence = {
  s_id : string;
  s_split : string;
  s_nl : string;
  accepted : Tfl.Ast.prop list;
}

type decline = { d_id : string; d_split : string; d_nl : string }

type argument = {
  a_id : string;
  a_split : string;
  a_verdict : string;
  a_lines : (string * Tfl.Ast.prop) list; (* nl, gold — conclusion last *)
}

let mem n j = Yojson.Safe.Util.member n j
let str n j = Yojson.Safe.Util.to_string (mem n j)

let parse_gold where s =
  match Tfl.Safe.parse s with
  | Ok p -> p
  | Error _ -> failwith (Printf.sprintf "%s: gold %S does not parse (run dune test)" where s)

let load () =
  let ic = open_in items_path in
  let lines =
    Fun.protect
      ~finally:(fun () -> close_in_noerr ic)
      (fun () ->
        let rec go acc =
          match input_line ic with l -> go (l :: acc) | exception End_of_file -> List.rev acc
        in
        go [])
  in
  let sentences = ref [] and declines = ref [] and arguments = ref [] in
  List.iter
    (fun l ->
      let l = String.trim l in
      if l <> "" then
        let j = Yojson.Safe.from_string l in
        match mem "kind" j with
        | `String "sentence" ->
            let id = str "id" j in
            let alts =
              match mem "also_ok" j with
              | `Null -> []
              | a ->
                  List.map
                    (fun x -> parse_gold id (Yojson.Safe.Util.to_string x))
                    (Yojson.Safe.Util.to_list a)
            in
            sentences :=
              {
                s_id = id;
                s_split = str "split" j;
                s_nl = str "nl" j;
                accepted = parse_gold id (str "tfl" j) :: alts;
              }
              :: !sentences
        | `String "decline" ->
            declines :=
              { d_id = str "id" j; d_split = str "split" j; d_nl = str "nl" j } :: !declines
        | `String "argument" ->
            let id = str "id" j in
            let line p = (str "nl" p, parse_gold id (str "tfl" p)) in
            arguments :=
              {
                a_id = id;
                a_split = str "split" j;
                a_verdict = str "verdict" j;
                a_lines =
                  List.map line (Yojson.Safe.Util.to_list (mem "premises" j))
                  @ [ line (mem "conclusion" j) ];
              }
              :: !arguments
        | _ -> ())
    lines;
  (List.rev !sentences, List.rev !declines, List.rev !arguments)

(* Deal round-robin so each call sees a mix of constructions rather than a
   block of one group — closer to real use, and it stops a whole batch of
   declines from cueing the model that declining is expected. *)
let deal n xs =
  let buckets = Array.make n [] in
  List.iteri (fun i x -> buckets.(i mod n) <- x :: buckets.(i mod n)) xs;
  Array.to_list buckets |> List.map List.rev |> List.filter (fun b -> b <> [])

(* ── Running one model ───────────────────────────────────────────────────── *)

(* Kept per split (PLAN 4.8), because after the first prompt change only the
   eval column is a measurement — the dev column is the tuning set, and
   reporting the two blended would launder one into the other. *)
type tally = {
  mutable exact : int;
  mutable structural : int;
  mutable equivalent : int;
  mutable wrong : int;
  mutable unparseable : int;
  mutable missing : int; (* absent, or declined when it should have translated *)
  mutable declined_right : int;
  mutable declined_total : int;
  mutable arg_verdict_right : int;
  mutable arg_all_parsed : int;
  mutable arg_total : int;
}

let empty_tally () =
  {
    exact = 0;
    structural = 0;
    equivalent = 0;
    wrong = 0;
    unparseable = 0;
    missing = 0;
    declined_right = 0;
    declined_total = 0;
    arg_verdict_right = 0;
    arg_all_parsed = 0;
    arg_total = 0;
  }

let add a b =
  {
    exact = a.exact + b.exact;
    structural = a.structural + b.structural;
    equivalent = a.equivalent + b.equivalent;
    wrong = a.wrong + b.wrong;
    unparseable = a.unparseable + b.unparseable;
    missing = a.missing + b.missing;
    declined_right = a.declined_right + b.declined_right;
    declined_total = a.declined_total + b.declined_total;
    arg_verdict_right = a.arg_verdict_right + b.arg_verdict_right;
    arg_all_parsed = a.arg_all_parsed + b.arg_all_parsed;
    arg_total = a.arg_total + b.arg_total;
  }

let translated t = t.exact + t.structural + t.equivalent
let attempted t = translated t + t.wrong + t.unparseable

let pct a b = if b = 0 then "n/a" else Printf.sprintf "%.0f%%" (100. *. float_of_int a /. float_of_int b)

let record tally ~split (log : out_channel) id nl (accepted : Tfl.Ast.prop list)
    (o : Translate.Translator.outcome) =
  let gold_src =
    match accepted with
    | g :: _ -> Tfl.Notation.print_proposition g
    | [] -> "-"
  in
  let line grade detail =
    Printf.fprintf log "%s\t%s\t%s\t%s\t%s\t%s\n" split id grade nl gold_src detail
  in
  let grade, detail =
    match o with
    | Translate.Translator.Translated { tfl; prop; _ } ->
        let g = Bench.Score.grade_against accepted prop in
        (match g with
        | Exact -> tally.exact <- tally.exact + 1
        | Structural -> tally.structural <- tally.structural + 1
        | Equivalent -> tally.equivalent <- tally.equivalent + 1
        | Wrong -> tally.wrong <- tally.wrong + 1
        | Unparseable -> tally.unparseable <- tally.unparseable + 1);
        (Bench.Score.grade_name g, tfl)
    | Unparseable { tfl; failure; _ } ->
        tally.unparseable <- tally.unparseable + 1;
        ("unparseable", tfl ^ " [" ^ Tfl.Safe.kind_name failure.kind ^ "]")
    (* declining a sentence that has a gold formula is a miss, not a refusal *)
    | Declined { reason } ->
        tally.missing <- tally.missing + 1;
        ("declined-but-translatable", reason)
    | Absent ->
        tally.missing <- tally.missing + 1;
        ("absent", "-")
  in
  line grade detail

let outcome_of (r : Translate.Translator.run) nl =
  List.find_opt (fun (i : Translate.Translator.item) -> i.nl = nl) r.items
  |> Option.map (fun (i : Translate.Translator.item) -> i.outcome)

let call model sentences =
  match Lwt_main.run (Translate.Translator.translate ~model sentences) with
  | Ok r -> Some r
  | Error why ->
      Printf.printf "    payload rejected: %s\n%!" why;
      None
  | exception Translate.Llm_client.Llm_error msg ->
      Printf.printf "    call failed: %s\n%!" msg;
      None

let run_model model (sentences, declines, arguments) =
  Printf.printf "\n=== %s\n%!" model;
  (try Sys.mkdir results_dir 0o755 with _ -> ());
  let log = open_out (Filename.concat results_dir ("fidelity-" ^ String.map (function '/' -> '_' | c -> c) model ^ ".tsv")) in
  Fun.protect ~finally:(fun () -> close_out_noerr log) @@ fun () ->
  Printf.fprintf log "split\tid\tgrade\tnl\tgold\tgot\n";
  let dev = empty_tally () and ev = empty_tally () in
  let tally_of = function "dev" -> dev | _ -> ev in
  List.iter (fun d -> let t = tally_of d.d_split in t.declined_total <- t.declined_total + 1) declines;
  List.iter (fun a -> let t = tally_of a.a_split in t.arg_total <- t.arg_total + 1) arguments;

  (* Sentences and declines together, mixed across batches. *)
  let mixed =
    List.map (fun s -> `S s) sentences @ List.map (fun d -> `D d) declines
  in
  let nbatches = (List.length mixed + batch_size - 1) / batch_size in
  List.iteri
    (fun i batch ->
      Printf.printf "  batch %d/%d (%d sentences)%!" (i + 1) nbatches (List.length batch);
      let nls = List.map (function `S s -> s.s_nl | `D d -> d.d_nl) batch in
      match call model nls with
      | None -> print_newline ()
      | Some r ->
          if r.from_cache then print_string " [cached]";
          print_newline ();
          List.iter
            (fun entry ->
              match entry with
              | `S s -> (
                  let tally = tally_of s.s_split in
                  match outcome_of r s.s_nl with
                  | Some o -> record tally ~split:s.s_split log s.s_id s.s_nl s.accepted o
                  | None -> tally.missing <- tally.missing + 1)
              | `D d -> (
                  let tally = tally_of d.d_split in
                  let line grade detail =
                    Printf.fprintf log "%s\t%s\t%s\t%s\t-\t%s\n" d.d_split d.d_id grade d.d_nl
                      detail
                  in
                  match outcome_of r d.d_nl with
                  | Some (Declined { reason }) ->
                      tally.declined_right <- tally.declined_right + 1;
                      line "declined-correctly" reason
                  | Some (Translated { tfl; _ }) -> line "SHOULD-HAVE-DECLINED" tfl
                  (* refusing by writing nonsense is not the same as declining *)
                  | Some (Unparseable { tfl; _ }) -> line "unparseable-not-declined" tfl
                  | Some Absent | None -> line "absent" "-"))
            batch)
    (deal nbatches mixed);

  (* Arguments: one call each, so naming consistency is testable. *)
  List.iter
    (fun a ->
      Printf.printf "  argument %s%!" a.a_id;
      let tally = tally_of a.a_split in
      let nls = List.map fst a.a_lines in
      match call model nls with
      | None -> print_newline ()
      | Some r ->
          if r.from_cache then print_string " [cached]";
          let got =
            List.map
              (fun (nl, _) ->
                match outcome_of r nl with
                | Some (Translated { tfl; _ }) -> Some tfl
                | _ -> None)
              a.a_lines
          in
          (* grade each line against its gold *)
          List.iter2
            (fun (nl, gold) _ ->
              match outcome_of r nl with
              | Some o -> record tally ~split:a.a_split log a.a_id nl [ gold ] o
              | None -> tally.missing <- tally.missing + 1)
            a.a_lines got;
          (* then the end-to-end question: does the model's own translation of
             the whole argument yield the gold verdict? *)
          if List.for_all Option.is_some got then (
            tally.arg_all_parsed <- tally.arg_all_parsed + 1;
            let srcs = List.map Option.get got in
            let n = List.length srcs in
            let premises = List.filteri (fun i _ -> i < n - 1) srcs in
            let conclusion = List.nth srcs (n - 1) in
            let v =
              match (Tfl_verify.check ~premises ~conclusion).verdict with
              | Valid -> "valid"
              | Invalid -> "invalid"
              | Contradicted -> "contradicted"
              | Unknown -> "unknown"
              | Error _ -> "error"
            in
            if v = a.a_verdict then tally.arg_verdict_right <- tally.arg_verdict_right + 1;
            Printf.printf "  → engine says %s, gold %s\n%!" v a.a_verdict;
            Printf.fprintf log "%s\t%s\tverdict-%s\t(whole argument)\t%s\t%s\n" a.a_split a.a_id
              (if v = a.a_verdict then "match" else "MISMATCH")
              a.a_verdict v)
          else (
            print_newline ();
            Printf.fprintf log "%s\t%s\tverdict-unavailable\t(whole argument)\t%s\t-\n" a.a_split
              a.a_id a.a_verdict))
    arguments;

  let report label t =
    Printf.printf
      "\n  [%s] faithfulness   %s correct of %d attempted  (exact %d, structural %d, \
       equivalent %d)\n"
      label
      (pct (translated t) (attempted t))
      (attempted t) t.exact t.structural t.equivalent;
    Printf.printf "  [%s] parse rate     %s (%d unparseable, %d wrong-but-parsed, %d missing)\n"
      label
      (pct (attempted t - t.unparseable) (attempted t))
      t.unparseable t.wrong t.missing;
    Printf.printf "  [%s] declines       %s correctly refused (%d/%d)\n" label
      (pct t.declined_right t.declined_total)
      t.declined_right t.declined_total;
    Printf.printf
      "  [%s] arguments      %d/%d gold verdict reproduced end-to-end (%d fully parsed)\n%!" label
      t.arg_verdict_right t.arg_total t.arg_all_parsed
  in
  (* eval first: it is the number that survives a prompt change *)
  report "eval" ev;
  report " dev" dev;
  report " all" (add dev ev);
  (model, [ ("eval", ev); ("dev", dev); ("all", add dev ev) ])

let () =
  let data = load () in
  let s, d, a = data in
  let in_split sp =
    List.length (List.filter (fun x -> x.s_split = sp) s)
    + List.length (List.filter (fun x -> x.d_split = sp) d)
    + List.length (List.filter (fun x -> x.a_split = sp) a)
  in
  Printf.printf "gold set: %d sentences, %d declines, %d arguments — %d dev, %d eval\n%!"
    (List.length s) (List.length d) (List.length a) (in_split "dev") (in_split "eval");
  let rows = List.map (fun m -> run_model m data) Translate.Config.models in
  print_endline "\n=== summary";
  Printf.printf "%-28s %-6s %-14s %-14s %s\n" "model" "split" "faithful" "declines"
    "argument verdicts";
  List.iter
    (fun (m, splits) ->
      List.iter
        (fun (label, t) ->
          Printf.printf "%-28s %-6s %-14s %-14s %d/%d\n" m label
            (Printf.sprintf "%s (%d/%d)" (pct (translated t) (attempted t)) (translated t)
               (attempted t))
            (Printf.sprintf "%s (%d/%d)"
               (pct t.declined_right t.declined_total)
               t.declined_right t.declined_total)
            t.arg_verdict_right t.arg_total)
        splits)
    rows;
  print_endline "\nper-item results in data/results/fidelity-*.tsv (first column is the split)"
