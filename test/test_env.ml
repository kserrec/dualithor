(* The .env loader (2.1) feeds API keys to the OpenRouter client. The threats
   are quiet ones: stray whitespace or quotes riding along on a key breaks
   auth with no useful error, a missing file must read as "no bindings" (an
   exported key with no .env is a supported setup), and the process
   environment must beat a stale file. *)

let check name b = if not b then failwith ("test_env: " ^ name)

let () =
  let path = Filename.temp_file "tfl_env" ".env" in
  let oc = open_out path in
  output_string oc
    {|# comment line
OPENROUTER_API_KEY = sk-or-abc123
QUOTED="with spaces"
SINGLE='single'
EQUALS=a=b=c

   # indented comment
=novalue
NOEQUALS
EMPTY=
|};
  close_out oc;
  let get name = Translate.Env.get ~path name in
  check "trimmed key and value" (get "OPENROUTER_API_KEY" = Some "sk-or-abc123");
  check "double quotes stripped" (get "QUOTED" = Some "with spaces");
  check "single quotes stripped" (get "SINGLE" = Some "single");
  check "split on first = only" (get "EQUALS" = Some "a=b=c");
  check "empty value allowed" (get "EMPTY" = Some "");
  check "empty key skipped" (get "" = None);
  check "line without = skipped" (get "NOEQUALS" = None);
  check "absent name" (get "MISSING" = None);
  (* Process environment wins over the file. *)
  Unix.putenv "QUOTED" "from-process";
  check "process env wins" (get "QUOTED" = Some "from-process");
  Sys.remove path;
  check "missing file reads as no bindings"
    (Translate.Env.get ~path "OPENROUTER_API_KEY" = None);
  print_endline "test_env: 11 checks passed"
