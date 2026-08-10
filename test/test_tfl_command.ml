open Harness
open Command_status

let executable =
  let path =
    if Sys.file_exists "../bin/tfl_command.exe" then "../bin/tfl_command.exe"
    else "_build/default/bin/tfl_command.exe"
  in
  Unix.realpath path

let read_all descriptor =
  let channel = Unix.in_channel_of_descr descriptor in
  let buffer = Buffer.create 256 in
  let chunk = Bytes.create 4_096 in
  let rec read () =
    match input channel chunk 0 (Bytes.length chunk) with
    | 0 -> ()
    | count ->
        Buffer.add_subbytes buffer chunk 0 count;
        read ()
  in
  read ();
  close_in channel;
  Buffer.contents buffer

let run_from directory arguments =
  let read_end, write_end = Unix.pipe ~cloexec:true () in
  match Unix.fork () with
  | 0 -> (
      Unix.close read_end;
      Unix.dup2 write_end Unix.stdout;
      Unix.dup2 write_end Unix.stderr;
      Unix.close write_end;
      try
        Unix.chdir directory;
        Unix.execv executable (Array.of_list ("tfl" :: arguments))
      with error ->
        prerr_endline (Printexc.to_string error);
        exit 127)
  | pid ->
      Unix.close write_end;
      let output = read_all read_end in
      let _, process_status = Unix.waitpid [] pid in
      let status =
        match process_status with
        | Unix.WEXITED code -> code
        | Unix.WSIGNALED signal | Unix.WSTOPPED signal -> 128 + signal
      in
      (status, output)

let with_temp contents run =
  let path, channel = Filename.open_temp_file "horos-command-" ".tfl" in
  output_string channel contents;
  close_out channel;
  Fun.protect ~finally:(fun () -> Sys.remove path) (fun () -> run path)

let json output = Yojson.Safe.from_string output

let well_formed_utf8 text =
  let rec scan byte =
    if byte >= String.length text then true
    else
      let decoded = String.get_utf_8_uchar text byte in
      Uchar.utf_decode_is_valid decoded
      && scan (byte + Uchar.utf_decode_length decoded)
  in
  scan 0

let string_field name value =
  match Yojson.Safe.Util.member name value with
  | `String result -> result
  | _ -> failwith ("missing string field " ^ name)

let int_field name value =
  match Yojson.Safe.Util.member name value with
  | `Int result -> result
  | _ -> failwith ("missing integer field " ^ name)

let contains text fragment =
  let text_length = String.length text
  and fragment_length = String.length fragment in
  let rec search offset =
    offset + fragment_length <= text_length
    && (String.sub text offset fragment_length = fragment || search (offset + 1))
  in
  fragment = "" || search 0

let with_non_utf8_temp contents run =
  let path, channel = Filename.open_temp_file "horos-command-\255-" ".tfl" in
  output_string channel contents;
  close_out channel;
  Fun.protect
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () -> run path)

let () =
  test "the five public outcome classes have stable exit statuses" (fun () ->
      check (Command_status.exit_code Success = 0) "success";
      check (Command_status.exit_code Non_entailment = 1) "non-entailment";
      check (Command_status.exit_code Input_failure = 2) "input failure";
      check (Command_status.exit_code Incomplete_search = 3) "incomplete";
      check (Command_status.exit_code Internal_failure = 4) "internal");
  test "an installed-style tfl command checks a file outside the repository"
    (fun () ->
      with_temp "　±Socrates*+Man\n−Man+Mortal\n" (fun path ->
          let directory = Filename.dirname path
          and file = Filename.basename path in
          let status, output = run_from directory [ "check"; file ] in
          check (status = 0) "human check exit";
          check (contains output "OK (2 statements)") "human check output";
          let status, output = run_from directory [ "check"; "--json"; file ] in
          let response = json output in
          check
            (status = 0 && int_field "exit_status" response = 0)
            "JSON check exit";
          check_eq (string_field "schema" response) "tfl-cli-0.1";
          let statements =
            Yojson.Safe.Util.member "statements" response
            |> Yojson.Safe.Util.to_list
          in
          check (List.length statements = 2) "two statement records";
          check
            (Yojson.Safe.Util.member "column" (List.hd statements) = `Int 2)
            "machine location uses a code-point column"));
  test "query exits distinguish support, non-entailment, and incompleteness"
    (fun () ->
      with_temp "±Socrates*+Man\n−Man+Mortal\n" (fun atomic_path ->
          let directory = Filename.dirname atomic_path
          and file = Filename.basename atomic_path in
          let status, output =
            run_from directory [ "query"; file; "±Socrates*+Mortal" ]
          in
          check (status = 0 && contains output "yes — the query follows") "yes";
          let status, output =
            run_from directory [ "query"; file; "±Socrates*+Bird" ]
          in
          check
            (status = 1
            && contains output "neither the query nor its contradictory follows"
            )
            "complete open-world non-entailment";
          let status, output =
            run_from directory [ "query"; "--json"; file; "±Socrates*+Bird" ]
          in
          let response = json output in
          check
            (status = 1
            && string_field "status" response = "logical-non-entailment"
            && string_field "verdict" response = "unknown")
            "machine non-entailment record";
          let status, output =
            run_from directory [ "query"; file; "±Socrates*−Mortal" ]
          in
          check
            (status = 1 && contains output "no — the contradictory follows")
            "complete contradictory support is non-entailment");
      with_temp "+Boy+(Lov+Girl)\n−Boy−(Lov+Coward)\n" (fun relational_path ->
          let directory = Filename.dirname relational_path
          and file = Filename.basename relational_path in
          let status, output =
            run_from directory [ "query"; file; "+Girl+Coward" ]
          in
          check
            (status = 3
            && contains output "current procedure did not decide the query")
            "human incomplete result";
          let status, output =
            run_from directory [ "query"; "--json"; file; "+Girl+Coward" ]
          in
          let response = json output in
          check
            (status = 3
            && string_field "status" response = "incomplete-search"
            && int_field "exit_status" response = 3)
            "machine incomplete result");
      with_temp "+C^3-H\n-C+E\n" (fun numerical_path ->
          let directory = Filename.dirname numerical_path
          and file = Filename.basename numerical_path in
          let status, output =
            run_from directory [ "query"; "--json"; file; "-E+H" ]
          in
          let response = json output in
          check
            (status = 3
            && string_field "verdict" response = "no"
            && string_field "status" response = "incomplete-search")
            "incomplete contradictory support does not overclaim non-entailment"));
  test "file failures carry human and machine line-column locations" (fun () ->
      with_temp "　+É+P\n" (fun path ->
          let directory = Filename.dirname path
          and file = Filename.basename path in
          let status, output = run_from directory [ "check"; file ] in
          check
            (status = 2 && contains output (file ^ ":1:3: lexical:"))
            "human compile diagnostic";
          let status, output = run_from directory [ "check"; "--json"; file ] in
          let response = json output in
          let first_error =
            Yojson.Safe.Util.member "errors" response
            |> Yojson.Safe.Util.to_list |> List.hd
          in
          check
            (status = 2
            && string_field "status" response = "input-failure"
            && Yojson.Safe.Util.member "line" first_error = `Int 1
            && Yojson.Safe.Util.member "column" first_error = `Int 3)
            "machine compile diagnostic"));
  test "describe and render expose human text and corresponding JSON" (fun () ->
      with_temp "±Socrates*+Man\n−Man+Mortal\n" (fun path ->
          let directory = Filename.dirname path
          and file = Filename.basename path in
          let status, output =
            run_from directory [ "describe"; file; "Socrates*" ]
          in
          check
            (status = 3 && contains output "Socrates is a mortal")
            "descriptions are supported but explicitly non-exhaustive";
          let status, output =
            run_from directory [ "describe"; "--json"; file; "Socrates*" ]
          in
          let response = json output in
          check
            (status = 3
            && string_field "method" response = "bounded-saturation"
            && Yojson.Safe.Util.member "answers" response <> `Null)
            "description JSON record");
      let status, output =
        run_from (Filename.get_temp_dir_name ()) [ "render"; "−Man+Mortal" ]
      in
      check
        (status = 0 && contains output "every man is mortal")
        "human rendering";
      let status, output =
        run_from
          (Filename.get_temp_dir_name ())
          [ "render"; "--json"; "−Man+Mortal" ]
      in
      let response = json output in
      check
        (status = 0 && Yojson.Safe.Util.member "proposition" response <> `Null)
        "render JSON record");
  test "help documents every public status" (fun () ->
      let status, output =
        run_from (Filename.get_temp_dir_name ()) [ "--help" ]
      in
      check (status = 0) "help exit";
      List.iter
        (fun fragment ->
          check (contains output fragment) ("help has " ^ fragment))
        [
          "0  success";
          "1  logical non-entailment";
          "2  input, file, usage, or compile failure";
          "3  incomplete search";
          "4  internal failure";
        ];
      List.iter
        (fun arguments ->
          let status, output =
            run_from (Filename.get_temp_dir_name ()) arguments
          in
          check (status = 0) "machine help exit";
          check (well_formed_utf8 output) "machine help is valid UTF-8";
          let response = json output in
          check
            (Yojson.Safe.Util.member "ok" response = `Bool true)
            "machine help succeeds";
          check_eq (string_field "schema" response) "tfl-cli-0.1";
          check_eq (string_field "operation" response) "help";
          check_eq (string_field "status" response) "success";
          check (int_field "exit_status" response = 0) "machine help status";
          check
            (contains (string_field "usage" response) "4  internal failure")
            "machine help carries usage text")
        [
          [ "--json"; "--help" ];
          [ "--help"; "--json" ];
          [ "--json"; "-h" ];
          [ "-h"; "--json" ];
        ]);
  test "machine output safely represents non-UTF-8 Unix path bytes" (fun () ->
      with_non_utf8_temp "−Man+Animal\n" (fun path ->
          check
            (not (well_formed_utf8 path))
            "the probe path contains a malformed UTF-8 byte";
          let directory = Filename.dirname path
          and file = Filename.basename path in
          let status, output = run_from directory [ "check"; "--json"; file ] in
          check (status = 0) "non-UTF-8 path success exit";
          check (well_formed_utf8 output) "success JSON is valid UTF-8";
          let response = json output in
          check
            (contains (string_field "file" response) "\\xFF")
            "success JSON visibly escapes the malformed path byte";
          Sys.remove path;
          let status, output = run_from directory [ "check"; "--json"; file ] in
          check (status = 2) "non-UTF-8 path failure exit";
          check (well_formed_utf8 output) "failure JSON is valid UTF-8";
          let response = json output in
          let first_error =
            Yojson.Safe.Util.member "errors" response
            |> Yojson.Safe.Util.to_list |> List.hd
          in
          check
            (contains (string_field "source" first_error) "\\xFF")
            "failure source visibly escapes the malformed path byte";
          check
            (contains (string_field "message" first_error) "\\xFF")
            "failure message visibly escapes the malformed path byte"));
  finish "tfl command tests"
