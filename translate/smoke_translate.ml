(* 4.3 acceptance: five hand-written sentences through all three models, with
   per-model outcomes and parse rates printed. Spends real money on a cache
   miss; run by hand, never under `dune test`.

   The five are deliberately *not* drawn from the few-shot pairs — scoring a
   model on examples it was just shown measures copying, not translation. Four
   are inside the fragment and span the constructions the prompt teaches; the
   fifth is a tense sentence the notation cannot carry, and a model that
   translates it anyway has failed the half of the contract the router claim
   depends on. *)

let sentences =
  [
    "Every auditor is an employee.";
    "No temporary worker is eligible for the pension.";
    "Some contractor works for a subsidiary.";
    "Alice supervises every intern.";
    (* should come back declined: tense, no event structure in the notation *)
    "The report was filed before the deadline.";
  ]

let show_outcome (o : Translate.Translator.outcome) =
  match o with
  | Translated { tfl; prop; confidence } ->
      Printf.sprintf "ok        %-34s [%s]  c=%.2f" tfl
        (Tfl.Render.read_prop prop) confidence
  | Unparseable { tfl; failure; confidence } ->
      Printf.sprintf "UNPARSED  %-34s (%s: %s)  c=%.2f" tfl
        (Tfl.Safe.kind_name failure.kind)
        failure.message confidence
  | Declined { reason } -> Printf.sprintf "declined  %s" reason
  | Absent -> "ABSENT    (the model returned nothing for this sentence)"

let report (r : Translate.Translator.run) =
  List.iter
    (fun (i : Translate.Translator.item) ->
      Printf.printf "  %-52s %s\n" i.nl (show_outcome i.outcome))
    r.items;
  if r.extra <> [] then
    List.iter (fun nl -> Printf.printf "  EXTRA (never sent): %s\n" nl) r.extra;
  let s = Translate.Translator.stats r.items in
  Printf.printf
    "  → %d translated, %d unparseable, %d declined, %d absent (of %d)%s\n%!"
    s.translated s.unparseable s.declined s.absent s.total
    (match Translate.Translator.parse_rate s with
    | None -> "; parse rate n/a (nothing attempted)"
    | Some p ->
        Printf.sprintf "; parse rate %.0f%% (%d/%d attempted)" (p *. 100.)
          s.translated (s.translated + s.unparseable))

let () =
  let ok =
    List.for_all
      (fun model ->
        Printf.printf "\n=== %s\n%!" model;
        match Lwt_main.run (Translate.Translator.translate ~model sentences) with
        | Ok r ->
            if r.from_cache then print_endline "  (served from cache — no spend)";
            report r;
            true
        | Error why ->
            Printf.printf "  PAYLOAD REJECTED: %s\n%!" why;
            false
        | exception Translate.Llm_client.Llm_error msg ->
            Printf.printf "  CALL FAILED: %s\n%!" msg;
            false)
      Translate.Config.models
  in
  print_newline ();
  print_endline (Translate.Llm_client.spend_report ());
  if ok then
    print_endline
      "4.3 smoke: every model returned a well-formed payload; usage appended to \
       data/usage.jsonl"
  else (
    print_endline "4.3 smoke: FAILURE";
    exit 1)
