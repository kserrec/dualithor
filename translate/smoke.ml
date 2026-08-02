(* 2.2 acceptance: one live "reply OK" round-trip per model slug. Spends a
   fraction of a cent; run by hand, never under `dune test`. *)

let () =
  let ok =
    List.for_all
      (fun model ->
        Printf.printf "%-28s " model;
        match
          Lwt_main.run
            (Translate.Llm_client.complete ~model
               ~system:
                 "You are a connectivity smoke test. Answer with the single \
                  word OK."
               ~user:"reply OK" ~max_tokens:1000 ())
        with
        | {
         Translate.Llm_client.content;
         prompt_tokens;
         completion_tokens;
         cost;
        } ->
            Printf.printf "-> %S (%d+%d tok%s)\n%!" (String.trim content)
              prompt_tokens completion_tokens
              (match cost with
              | Some c -> Printf.sprintf ", $%.6f" c
              | None -> "");
            String.trim content <> ""
        | exception Translate.Llm_client.Llm_error msg ->
            Printf.printf "FAILED: %s\n%!" msg;
            false)
      Translate.Config.models
  in
  print_endline (Translate.Llm_client.spend_report ());
  if ok then
    print_endline
      "smoke: all three models responded; usage appended to data/usage.jsonl"
  else (
    print_endline "smoke: FAILURE";
    exit 1)
