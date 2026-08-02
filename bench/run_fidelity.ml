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

type sentence = { s_id : string; s_nl : string; accepted : Tfl.Ast.prop list }
type decline = { d_id : string; d_nl : string }

type argument = {
  a_id : string;
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
              { s_id = id; s_nl = str "nl" j; accepted = parse_gold id (str "tfl" j) :: alts }
              :: !sentences
        | `String "decline" -> declines := { d_id = str "id" j; d_nl = str "nl" j } :: !declines
        | `String "argument" ->
            let id = str "id" j in
            let line p = (str "nl" p, parse_gold id (str "tfl" p)) in
            arguments :=
              {
                a_id = id;
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

type tally = {
  mutable exact : int;
  mutable structural : int;
  mutable equivalent : int;
  mutable wrong : int;
  mutable unparseable : int;
  mutable missing : int; (* absent, or declined when it should have translated *)
}

let empty_tally () =
  { exact = 0; structural = 0; equivalent = 0; wrong = 0; unparseable = 0; missing = 0 }

let translated t = t.exact + t.structural + t.equivalent
let attempted t = translated t + t.wrong + t.unparseable
let total t = attempted t + t.missing

let pct a b = if b = 0 then "n/a" else Printf.sprintf "%.0f%%" (100. *. float_of_int a /. float_of_int b)

let record tally (log : out_channel) id nl (accepted : Tfl.Ast.prop list)
    (o : Translate.Translator.outcome) =
  let gold_src =
    match accepted with
    | g :: _ -> Tfl.Notation.print_proposition g
    | [] -> "-"
  in
  let line grade detail =
    Printf.fprintf log "%s\t%s\t%s\t%s\t%s\n" id grade nl gold_src detail
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
  Printf.fprintf log "id\tgrade\tnl\tgold\tgot\n";
  let tally = empty_tally () in

  (* Sentences and declines together, mixed across batches. *)
  let mixed =
    List.map (fun s -> `S s) sentences @ List.map (fun d -> `D d) declines
  in
  let nbatches = (List.length mixed + batch_size - 1) / batch_size in
  let declined_right = ref 0 and declined_total = List.length declines in
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
                  match outcome_of r s.s_nl with
                  | Some o -> record tally log s.s_id s.s_nl s.accepted o
                  | None -> tally.missing <- tally.missing + 1)
              | `D d -> (
                  match outcome_of r d.d_nl with
                  | Some (Declined { reason }) ->
                      incr declined_right;
                      Printf.fprintf log "%s\tdeclined-correctly\t%s\t-\t%s\n" d.d_id d.d_nl reason
                  | Some (Translated { tfl; _ }) ->
                      Printf.fprintf log "%s\tSHOULD-HAVE-DECLINED\t%s\t-\t%s\n" d.d_id d.d_nl tfl
                  | Some (Unparseable { tfl; _ }) ->
                      (* refusing by writing nonsense is not the same as declining *)
                      Printf.fprintf log "%s\tunparseable-not-declined\t%s\t-\t%s\n" d.d_id d.d_nl tfl
                  | Some Absent | None ->
                      Printf.fprintf log "%s\tabsent\t%s\t-\t-\n" d.d_id d.d_nl))
            batch)
    (deal nbatches mixed);

  (* Arguments: one call each, so naming consistency is testable. *)
  let arg_verdict_right = ref 0 and arg_all_parsed = ref 0 in
  List.iter
    (fun a ->
      Printf.printf "  argument %s%!" a.a_id;
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
              | Some o -> record tally log a.a_id nl [ gold ] o
              | None -> tally.missing <- tally.missing + 1)
            a.a_lines got;
          (* then the end-to-end question: does the model's own translation of
             the whole argument yield the gold verdict? *)
          if List.for_all Option.is_some got then (
            incr arg_all_parsed;
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
            if v = a.a_verdict then incr arg_verdict_right;
            Printf.printf "  → engine says %s, gold %s\n%!" v a.a_verdict;
            Printf.fprintf log "%s\tverdict-%s\t(whole argument)\t%s\t%s\n" a.a_id
              (if v = a.a_verdict then "match" else "MISMATCH")
              a.a_verdict v)
          else (
            print_newline ();
            Printf.fprintf log "%s\tverdict-unavailable\t(whole argument)\t%s\t-\n" a.a_id
              a.a_verdict))
    arguments;

  Printf.printf
    "\n  faithfulness   %s correct of %d attempted  (exact %d, structural %d, equivalent %d)\n"
    (pct (translated tally) (attempted tally))
    (attempted tally) tally.exact tally.structural tally.equivalent;
  Printf.printf "  parse rate     %s (%d unparseable, %d wrong-but-parsed, %d missing)\n"
    (pct (attempted tally - tally.unparseable) (attempted tally))
    tally.unparseable tally.wrong tally.missing;
  Printf.printf "  declines       %s correctly refused (%d/%d)\n"
    (pct !declined_right declined_total) !declined_right declined_total;
  Printf.printf "  arguments      %d/%d gold verdict reproduced end-to-end (%d fully parsed)\n%!"
    !arg_verdict_right (List.length arguments) !arg_all_parsed;
  (model, translated tally, attempted tally, !declined_right, declined_total, !arg_verdict_right,
   List.length arguments, total tally)

let () =
  let data = load () in
  let s, d, a = data in
  Printf.printf "gold set: %d sentences, %d declines, %d arguments\n%!" (List.length s)
    (List.length d) (List.length a);
  let rows = List.map (fun m -> run_model m data) Translate.Config.models in
  print_endline "\n=== summary";
  Printf.printf "%-28s %-14s %-14s %s\n" "model" "faithful" "declines" "argument verdicts";
  List.iter
    (fun (m, ok, att, dr, dt, av, at, _) ->
      Printf.printf "%-28s %-14s %-14s %d/%d\n" m
        (Printf.sprintf "%s (%d/%d)" (pct ok att) ok att)
        (Printf.sprintf "%s (%d/%d)" (pct dr dt) dr dt)
        av at)
    rows;
  print_endline "\nper-item results in data/results/fidelity-*.tsv"
