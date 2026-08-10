open Harness
open Command_status

let executable =
  let path =
    if Sys.file_exists "../bin/tfl_command.exe" then "../bin/tfl_command.exe"
    else "_build/default/bin/tfl_command.exe"
  in
  Unix.realpath path

let read_streams stdout_descriptor stderr_descriptor =
  let stdout_buffer = Buffer.create 256
  and stderr_buffer = Buffer.create 256 in
  let chunk = Bytes.create 4_096 in
  let open_descriptors = ref [ stdout_descriptor; stderr_descriptor ] in
  while !open_descriptors <> [] do
    let readable, _, _ = Unix.select !open_descriptors [] [] (-1.) in
    List.iter
      (fun descriptor ->
        match Unix.read descriptor chunk 0 (Bytes.length chunk) with
        | 0 ->
            Unix.close descriptor;
            open_descriptors :=
              List.filter (( <> ) descriptor) !open_descriptors
        | count ->
            let buffer =
              if descriptor = stdout_descriptor then stdout_buffer
              else stderr_buffer
            in
            Buffer.add_subbytes buffer chunk 0 count
        | exception
            Unix.Unix_error
              ((Unix.EINTR | Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) ->
            ())
      readable
  done;
  (Buffer.contents stdout_buffer, Buffer.contents stderr_buffer)

let run_from_streams directory arguments =
  let stdout_read, stdout_write = Unix.pipe ~cloexec:true ()
  and stderr_read, stderr_write = Unix.pipe ~cloexec:true () in
  match Unix.fork () with
  | 0 -> (
      Unix.close stdout_read;
      Unix.close stderr_read;
      Unix.dup2 stdout_write Unix.stdout;
      Unix.dup2 stderr_write Unix.stderr;
      Unix.close stdout_write;
      Unix.close stderr_write;
      try
        Unix.chdir directory;
        Unix.execv executable (Array.of_list ("tfl" :: arguments))
      with error ->
        prerr_endline (Printexc.to_string error);
        exit 127)
  | pid ->
      Unix.close stdout_write;
      Unix.close stderr_write;
      let stdout, stderr = read_streams stdout_read stderr_read in
      let _, process_status = Unix.waitpid [] pid in
      let status =
        match process_status with
        | Unix.WEXITED code -> code
        | Unix.WSIGNALED signal | Unix.WSTOPPED signal -> 128 + signal
      in
      (status, stdout, stderr)

let run_from directory arguments =
  let status, stdout, stderr = run_from_streams directory arguments in
  (status, stdout ^ stderr)

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

let terminal_controls =
  [
    ("\007", "\\x07");
    ("\r", "\\x0D");
    ("\027", "\\x1B");
    ("\n", "\\x0A");
    ("\127", "\\x7F");
    ("\xC2\x85", "\\u{0085}");
    ("\xC2\x9B", "\\u{009B}");
    ("\xD8\x9C", "\\u{061C}");
    ("\xE2\x80\x8B", "\\u{200B}");
    ("\xE2\x80\xA8", "\\u{2028}");
    ("\xE2\x80\xAE", "\\u{202E}");
    ("\xE2\x81\xA6", "\\u{2066}");
    ("\xEF\xBB\xBF", "\\u{FEFF}");
    ("\xEF\xBF\xB9", "\\u{FFF9}");
  ]

let with_terminal_control_temp contents run =
  let controls = terminal_controls |> List.map fst |> String.concat "" in
  let path, channel =
    Filename.open_temp_file ("horos-command-" ^ controls ^ "spoof-") ".tfl"
  in
  output_string channel contents;
  close_out channel;
  Fun.protect
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () -> run path)

let count_char text wanted =
  String.fold_left
    (fun count character -> if character = wanted then count + 1 else count)
    0 text

let () =
  test "the five public outcome classes have stable exit statuses" (fun () ->
      check (Command_status.exit_code Success = 0) "success";
      check (Command_status.exit_code Non_entailment = 1) "non-entailment";
      check (Command_status.exit_code Input_failure = 2) "input failure";
      check (Command_status.exit_code Incomplete_search = 3) "incomplete";
      check (Command_status.exit_code Internal_failure = 4) "internal";
      let unexpected =
        match Command_status.protect (fun () -> failwith "probe") with
        | Error failure -> failure
        | Ok _ -> failwith "an unexpected exception escaped its boundary"
      in
      check
        (unexpected.status = Internal_failure)
        "an unexpected exception retains internal-failure classification";
      check
        (contains unexpected.message "probe")
        "the unexpected exception remains diagnosable");
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
  test "human and machine modes use their documented output streams" (fun () ->
      let directory = Filename.get_temp_dir_name () in
      let status, stdout, stderr =
        run_from_streams directory [ "render"; "−Man+Mortal" ]
      in
      check (status = 0) "human success exit";
      check (stdout <> "" && stderr = "") "human success uses stdout only";
      let status, stdout, stderr =
        run_from_streams directory [ "render"; "--json"; "−Man+Mortal" ]
      in
      check (status = 0) "machine success exit";
      check (stderr = "") "machine success leaves stderr empty";
      ignore (json stdout);
      let status, stdout, stderr =
        run_from_streams directory [ "render"; "+oops(" ]
      in
      check (status = 2) "human failure exit";
      check (stdout = "" && stderr <> "") "human failure uses stderr only";
      let status, stdout, stderr =
        run_from_streams directory [ "--json"; "render"; "+oops(" ]
      in
      check (status = 2) "machine failure exit";
      check (stderr = "") "machine failure leaves stderr empty";
      check
        (int_field "exit_status" (json stdout) = 2)
        "machine failure stays on stdout");
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
  test "every independent file diagnostic crosses the command boundary"
    (fun () ->
      with_temp "　+É+P\n  +oops(\n" (fun path ->
          let directory = Filename.dirname path
          and file = Filename.basename path in
          let status, stdout, stderr =
            run_from_streams directory [ "check"; file ]
          in
          check (status = 2 && stdout = "") "human multi-error exit";
          check
            (contains stderr (file ^ ":1:3:")
            && contains stderr (file ^ ":2:"))
            "human output includes both file diagnostics";
          let status, stdout, stderr =
            run_from_streams directory [ "check"; "--json"; file ]
          in
          let response = json stdout in
          let errors =
            Yojson.Safe.Util.member "errors" response |> Yojson.Safe.Util.to_list
          in
          check (status = 2 && stderr = "") "machine multi-error exit";
          check (List.length errors = 2) "machine output includes both errors";
          check
            (Yojson.Safe.Util.member "line" (List.hd errors) = `Int 1
            && Yojson.Safe.Util.member "line" (List.hd (List.tl errors)) = `Int 2)
            "machine errors retain both physical lines"));
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
  test "usage failures reject missing, malformed, and duplicate arguments"
    (fun () ->
      let directory = Filename.get_temp_dir_name () in
      List.iter
        (fun arguments ->
          let status, stdout, stderr = run_from_streams directory arguments in
          check (status = 2) "human usage exit";
          check (stdout = "") "human usage leaves stdout empty";
          check
            (contains stderr "usage" && contains stderr "Usage:")
            "human usage explains the refusal")
        [ []; [ "bogus" ]; [ "check" ]; [ "render"; "−S+P"; "extra" ] ];
      List.iter
        (fun arguments ->
          let status, stdout, stderr = run_from_streams directory arguments in
          let response = json stdout in
          let first_error =
            Yojson.Safe.Util.member "errors" response
            |> Yojson.Safe.Util.to_list |> List.hd
          in
          check (status = 2 && stderr = "") "machine usage exit";
          check_eq (string_field "operation" response) "command";
          check_eq (string_field "status" response) "input-failure";
          check (int_field "exit_status" response = 2) "machine usage status";
          check_eq (string_field "class" first_error) "usage")
        [
          [ "--json" ];
          [ "bogus"; "--json" ];
          [ "--json"; "check" ];
          [ "--json"; "--json"; "--help" ];
        ]);
  test "human output visibly escapes terminal controls in paths" (fun () ->
      with_terminal_control_temp "−Man+Animal\n" (fun path ->
          let directory = Filename.dirname path
          and file = Filename.basename path in
          let assert_safe status expected output label =
            check (status = expected) (label ^ " exit");
            check (well_formed_utf8 output) (label ^ " UTF-8");
            List.iter
              (fun (raw, escaped) ->
                check
                  (contains output escaped)
                  (label ^ " visibly escapes " ^ escaped);
                if raw <> "\n" then
                  check
                    (not (contains output raw))
                    (label ^ " contains raw " ^ escaped))
              terminal_controls;
            check
              (count_char output '\n' = 1)
              (label ^ " cannot forge another output line")
          in
          let status, output = run_from directory [ "check"; file ] in
          assert_safe status 0 output "success";
          Sys.remove path;
          let status, output = run_from directory [ "check"; file ] in
          assert_safe status 2 output "failure"));
  test "machine output safely represents non-UTF-8 Unix path bytes" (fun () ->
      with_non_utf8_temp "−Man+Animal\n" (fun path ->
          check
            (not (well_formed_utf8 path))
            "the probe path contains a malformed UTF-8 byte";
          let directory = Filename.dirname path
          and file = Filename.basename path in
          let status, output = run_from directory [ "check"; file ] in
          check (status = 0) "non-UTF-8 path human success exit";
          check (well_formed_utf8 output) "human success is valid UTF-8";
          check (contains output "\\xFF")
            "human success visibly escapes the malformed path byte";
          let status, output = run_from directory [ "check"; "--json"; file ] in
          check (status = 0) "non-UTF-8 path success exit";
          check (well_formed_utf8 output) "success JSON is valid UTF-8";
          let response = json output in
          check
            (contains (string_field "file" response) "\\xFF")
            "success JSON visibly escapes the malformed path byte";
          Sys.remove path;
          let status, output = run_from directory [ "check"; file ] in
          check (status = 2) "non-UTF-8 path human failure exit";
          check (well_formed_utf8 output) "human failure is valid UTF-8";
          check (contains output "\\xFF")
            "human failure visibly escapes the malformed path byte";
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
