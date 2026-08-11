open Harness
open Command_status

let executable =
  let path =
    if Sys.file_exists "../bin/tfl_command.exe" then "../bin/tfl_command.exe"
    else "_build/default/bin/tfl_command.exe"
  in
  Unix.realpath path

let process_exit_code = function
  | Unix.WEXITED code -> code
  | Unix.WSIGNALED signal | Unix.WSTOPPED signal -> 128 + signal

let exec_tfl directory arguments =
  try
    Unix.chdir directory;
    Unix.execv executable (Array.of_list ("tfl" :: arguments))
  with error ->
    prerr_endline (Printexc.to_string error);
    exit 127

let read_streams stdout_descriptor stderr_descriptor =
  let stdout_buffer = Buffer.create 256 and stderr_buffer = Buffer.create 256 in
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
            Unix.Unix_error ((Unix.EINTR | Unix.EAGAIN | Unix.EWOULDBLOCK), _, _)
          ->
            ())
      readable
  done;
  (Buffer.contents stdout_buffer, Buffer.contents stderr_buffer)

let run_from_streams directory arguments =
  let stdout_read, stdout_write = Unix.pipe ~cloexec:true ()
  and stderr_read, stderr_write = Unix.pipe ~cloexec:true () in
  match Unix.fork () with
  | 0 ->
      Unix.close stdout_read;
      Unix.close stderr_read;
      Unix.dup2 stdout_write Unix.stdout;
      Unix.dup2 stderr_write Unix.stderr;
      Unix.close stdout_write;
      Unix.close stderr_write;
      exec_tfl directory arguments
  | pid ->
      Unix.close stdout_write;
      Unix.close stderr_write;
      let stdout, stderr = read_streams stdout_read stderr_read in
      let _, process_status = Unix.waitpid [] pid in
      (process_exit_code process_status, stdout, stderr)

let run_from directory arguments =
  let status, stdout, stderr = run_from_streams directory arguments in
  (status, stdout ^ stderr)

let run_from_input_streams directory arguments input =
  let stdin_read, stdin_write = Unix.pipe ~cloexec:true ()
  and stdout_read, stdout_write = Unix.pipe ~cloexec:true ()
  and stderr_read, stderr_write = Unix.pipe ~cloexec:true () in
  match Unix.fork () with
  | 0 ->
      Unix.close stdin_write;
      Unix.close stdout_read;
      Unix.close stderr_read;
      Unix.dup2 stdin_read Unix.stdin;
      Unix.dup2 stdout_write Unix.stdout;
      Unix.dup2 stderr_write Unix.stderr;
      Unix.close stdin_read;
      Unix.close stdout_write;
      Unix.close stderr_write;
      exec_tfl directory arguments
  | pid ->
      Unix.close stdin_read;
      Unix.close stdout_write;
      Unix.close stderr_write;
      let input_channel = Unix.out_channel_of_descr stdin_write in
      output_string input_channel input;
      close_out input_channel;
      let stdout, stderr = read_streams stdout_read stderr_read in
      let _, process_status = Unix.waitpid [] pid in
      (process_exit_code process_status, stdout, stderr)

type running_session = {
  pid : int;
  input : out_channel;
  output : Unix.file_descr;
  errors : Unix.file_descr;
  mutable stopped : bool;
}

let start_session directory arguments =
  let stdin_read, stdin_write = Unix.pipe ~cloexec:true ()
  and stdout_read, stdout_write = Unix.pipe ~cloexec:true ()
  and stderr_read, stderr_write = Unix.pipe ~cloexec:true () in
  match Unix.fork () with
  | 0 ->
      Unix.close stdin_write;
      Unix.close stdout_read;
      Unix.close stderr_read;
      Unix.dup2 stdin_read Unix.stdin;
      Unix.dup2 stdout_write Unix.stdout;
      Unix.dup2 stderr_write Unix.stderr;
      Unix.close stdin_read;
      Unix.close stdout_write;
      Unix.close stderr_write;
      exec_tfl directory arguments
  | pid ->
      Unix.close stdin_read;
      Unix.close stdout_write;
      Unix.close stderr_write;
      {
        pid;
        input = Unix.out_channel_of_descr stdin_write;
        output = stdout_read;
        errors = stderr_read;
        stopped = false;
      }

let send session line =
  output_string session.input line;
  output_char session.input '\n';
  flush session.input

let event session =
  let buffer = Buffer.create 256 and byte = Bytes.create 1 in
  let rec read () =
    match Unix.read session.output byte 0 1 with
    | 0 -> failwith "REPL output ended before the next event"
    | _ when Bytes.get byte 0 = '\n' ->
        Buffer.contents buffer |> Yojson.Safe.from_string
    | _ ->
        Buffer.add_char buffer (Bytes.get byte 0);
        read ()
    | exception Unix.Unix_error (Unix.EINTR, _, _) -> read ()
  in
  read ()

let rec read_all descriptor buffer =
  let bytes = Bytes.create 256 in
  match Unix.read descriptor bytes 0 (Bytes.length bytes) with
  | 0 -> Buffer.contents buffer
  | count ->
      Buffer.add_subbytes buffer bytes 0 count;
      read_all descriptor buffer

let read_exact descriptor length =
  let bytes = Bytes.create length in
  let rec read offset =
    if offset = length then Bytes.to_string bytes
    else
      match Unix.read descriptor bytes offset (length - offset) with
      | 0 -> failwith "stream ended before the expected bytes"
      | count -> read (offset + count)
      | exception Unix.Unix_error (Unix.EINTR, _, _) -> read offset
  in
  read 0

let input_result_json = function
  | Repl_input.Line line ->
      `Assoc [ ("kind", `String "line"); ("line", `String line) ]
  | Repl_input.End_of_input -> `Assoc [ ("kind", `String "end-of-input") ]
  | Repl_input.Interrupted -> `Assoc [ ("kind", `String "interrupted") ]
  | Repl_input.Line_too_long -> `Assoc [ ("kind", `String "line-too-long") ]
  | Repl_input.Display_limit -> `Assoc [ ("kind", `String "display-limit") ]

let run_editing_reader ?output_limit ?(history_entries = []) input =
  let input_read, input_write = Unix.pipe ~cloexec:true ()
  and output_read, output_write = Unix.pipe ~cloexec:true ()
  and report_read, report_write = Unix.pipe ~cloexec:true () in
  match Unix.fork () with
  | 0 ->
      Unix.close input_write;
      Unix.close output_read;
      Unix.close report_read;
      Unix.dup2 input_read Unix.stdin;
      Unix.dup2 output_write Unix.stdout;
      Unix.close input_read;
      Unix.close output_write;
      let report_channel = Unix.out_channel_of_descr report_write in
      let report =
        try
          let history = Repl_input.create_history () in
          List.iter (Repl_input.remember history) history_entries;
          let entered_terminal_scope = ref false in
          let editing_reader history ~prompt ~display =
            let terminal_scope run =
              entered_terminal_scope := true;
              run ()
            in
            Repl_input.read_terminal_line ~terminal_scope ?output_limit history
              ~prompt ~display
          in
          let result =
            Repl_input.read_line ~editing_reader history
              ~mode:Repl_input.Editing_terminal ~prompt:"tfl> "
              ~display:(fun text -> text)
          in
          let next = Repl_input.read_plain_line stdin in
          `Assoc
            [
              ("result", input_result_json result);
              ("next", input_result_json next);
              ( "history",
                `List (List.map (fun line -> `String line) history.entries) );
              ("history_bytes", `Int history.bytes);
              ("entered_terminal_scope", `Bool !entered_terminal_scope);
            ]
        with error -> `Assoc [ ("error", `String (Printexc.to_string error)) ]
      in
      flush stdout;
      Yojson.Safe.to_channel report_channel report;
      output_char report_channel '\n';
      close_out report_channel;
      Unix._exit 0
  | pid ->
      Unix.close input_read;
      Unix.close output_write;
      Unix.close report_write;
      let input_channel = Unix.out_channel_of_descr input_write in
      output_string input_channel input;
      close_out input_channel;
      let output = read_all output_read (Buffer.create 64) in
      let report =
        read_all report_read (Buffer.create 128) |> Yojson.Safe.from_string
      in
      let _, process_status = Unix.waitpid [] pid in
      Unix.close output_read;
      Unix.close report_read;
      check
        (process_exit_code process_status = 0)
        "the editing-reader probe exits successfully";
      (output, report)

let stop_session session =
  if not session.stopped then (
    session.stopped <- true;
    close_out_noerr session.input;
    let _, process_status = Unix.waitpid [] session.pid in
    let stderr = read_all session.errors (Buffer.create 32) in
    Unix.close session.output;
    Unix.close session.errors;
    (process_exit_code process_status, stderr))
  else (0, "")

let replace_file path contents =
  let channel = open_out_bin path in
  output_string channel contents;
  close_out channel

let with_temp contents run =
  let path, channel = Filename.open_temp_file "horos-command-" ".tfl" in
  output_string channel contents;
  close_out channel;
  Fun.protect ~finally:(fun () -> Sys.remove path) (fun () -> run path)

let json output = Yojson.Safe.from_string output

let json_records output =
  output |> String.split_on_char '\n'
  |> List.filter (fun line -> line <> "")
  |> List.map json

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

let bool_field name value =
  match Yojson.Safe.Util.member name value with
  | `Bool result -> result
  | _ -> failwith ("missing Boolean field " ^ name)

let result_or_fail label = function
  | Ok value -> value
  | Error _ -> failwith (label ^ " unexpectedly failed")

let check_json_fields label record fields =
  List.iter
    (fun (name, expected) ->
      let actual = Yojson.Safe.Util.member name record in
      check (actual = expected)
        (Printf.sprintf "%s field %S differs from the runtime serializer" label
           name))
    fields

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
          let first = List.hd statements in
          check
            (Yojson.Safe.Util.member "column" first = `Int 2)
            "machine location uses a code-point column";
          check_eq (string_field "source_path" first) file;
          check_eq (string_field "source_line" first) "　±Socrates*+Man";
          let start =
            Yojson.Safe.Util.member "span" first
            |> Yojson.Safe.Util.member "start"
          and finish =
            Yojson.Safe.Util.member "span" first
            |> Yojson.Safe.Util.member "end"
          in
          check
            (Yojson.Safe.Util.member "codepoint_offset" start = `Int 1
            && Yojson.Safe.Util.member "column" start = `Int 2
            && Yojson.Safe.Util.member "column" finish = `Int 16)
            "the statement JSON carries a half-open code-point span"));
  test "terminal fallback keeps prompts and interrupt recovery" (fun () ->
      let choose ~json ~term ~stdin_is_terminal ~stdout_is_terminal =
        Repl_input.choose_input_mode ~json ~term ~stdin_is_terminal
          ~stdout_is_terminal
      in
      check
        (choose ~json:false ~term:(Some "dumb") ~stdin_is_terminal:true
           ~stdout_is_terminal:true
        = Repl_input.Plain_terminal)
        "a dumb terminal uses the interactive plain reader";
      check
        (choose ~json:false ~term:(Some "xterm") ~stdin_is_terminal:true
           ~stdout_is_terminal:true
        = Repl_input.Editing_terminal)
        "a capable terminal uses the history editor";
      check
        (choose ~json:false ~term:(Some "xterm") ~stdin_is_terminal:false
           ~stdout_is_terminal:true
        = Repl_input.Piped)
        "redirected input stays non-interactive";
      check
        (choose ~json:true ~term:(Some "xterm") ~stdin_is_terminal:true
           ~stdout_is_terminal:true
        = Repl_input.Piped)
        "JSON sessions remain non-interactive";
      let input_read, input_write = Unix.pipe ~cloexec:true ()
      and output_read, output_write = Unix.pipe ~cloexec:true () in
      match Unix.fork () with
      | 0 ->
          Unix.close input_write;
          Unix.close output_read;
          Unix.dup2 input_read Unix.stdin;
          Unix.dup2 output_write Unix.stdout;
          Unix.close input_read;
          Unix.close output_write;
          let result =
            Repl_input.read_line (Repl_input.create_history ())
              ~mode:Repl_input.Plain_terminal ~prompt:"tfl> "
              ~display:(fun text -> text)
          in
          print_endline
            (match result with
            | Repl_input.Interrupted -> "interrupted"
            | Repl_input.End_of_input -> "end-of-input"
            | Repl_input.Line _ -> "line"
            | Repl_input.Line_too_long -> "line-too-long"
            | Repl_input.Display_limit -> "display-limit");
          flush stdout;
          Unix._exit 0
      | pid ->
          Unix.close input_read;
          Unix.close output_write;
          check_eq (read_exact output_read 5) "tfl> ";
          Unix.kill pid Sys.sigint;
          let readable, _, _ = Unix.select [ output_read ] [] [] 2.0 in
          Unix.close input_write;
          let remainder = read_all output_read (Buffer.create 32) in
          let _, process_status = Unix.waitpid [] pid in
          Unix.close output_read;
          check (readable <> []) "the interrupted reader responds promptly";
          check
            (process_exit_code process_status = 0)
            "the fallback reader survives SIGINT";
          check
            (contains remainder "interrupted")
            "SIGINT returns an interrupted input result");
  test "terminal redraw restores the saved prompt origin" (fun () ->
      check_eq (Repl_input.prompt_text "tfl> ") "\0277tfl> ";
      check_eq
        (Repl_input.refresh_text ~prompt:"tfl> "
           ~display:(fun text -> text)
           "abcdefghijklmnopqrs")
        "\0278\027[Jtfl> abcdefghijklmnopqrs");
  test "the editing reader wires redraw, line results, and history" (fun () ->
      let output, report = run_editing_reader "ab\127\nnext\n" in
      check_eq output "\0277tfl> ab\0278\027[Jtfl> a\n";
      let result = Yojson.Safe.Util.member "result" report
      and next = Yojson.Safe.Util.member "next" report in
      check_eq (string_field "kind" result) "line";
      check_eq (string_field "line" result) "a";
      check_eq (string_field "kind" next) "line";
      check_eq (string_field "line" next) "next";
      check
        (Yojson.Safe.Util.member "history" report = `List [ `String "a" ])
        "the submitted editing line reaches history";
      check
        (int_field "history_bytes" report = 1)
        "the editing read accounts for retained history bytes";
      check
        (bool_field "entered_terminal_scope" report)
        "the editing path enters the terminal-management scope");
  test "the editing reader wires both history arrows and draft restoration"
    (fun () ->
      let output, report =
        run_editing_reader ~history_entries:[ "one"; "two" ]
          "draft\027[A\027[B\nnext\n"
      in
      check_eq output
        "\0277tfl> draft\0278\027[Jtfl> two\0278\027[Jtfl> draft\n";
      let result = Yojson.Safe.Util.member "result" report
      and next = Yojson.Safe.Util.member "next" report in
      check_eq (string_field "kind" result) "line";
      check_eq (string_field "line" result) "draft";
      check_eq (string_field "kind" next) "line";
      check_eq (string_field "line" next) "next";
      check
        (Yojson.Safe.Util.member "history" report
        = `List [ `String "one"; `String "two"; `String "draft" ])
        "history arrows return to the draft before submission";
      check
        (int_field "history_bytes" report = 11)
        "history accounting includes the restored draft");
  test "terminal rendering has a strict per-line output budget" (fun () ->
      let budget = Repl_input.create_output_budget ~limit:8 () in
      check (Repl_input.reserve_output budget 3) "first write fits";
      check (budget.used = 3) "accepted output is charged";
      check
        (not (Repl_input.reserve_output budget 6))
        "a write crossing the limit is refused atomically";
      check (budget.used = 3) "a refused write consumes no budget";
      check (Repl_input.reserve_output budget 5) "the exact remainder fits";
      check (budget.used = 8) "the budget has an exact ceiling");
  test "the editing reader enforces its budget and drains only that line"
    (fun () ->
      let output, report =
        run_editing_reader ~output_limit:23 "abcd\127forbidden\nnext\n"
      in
      check_eq output "\0277tfl> abcd\n";
      let result = Yojson.Safe.Util.member "result" report
      and next = Yojson.Safe.Util.member "next" report in
      check_eq (string_field "kind" result) "display-limit";
      check_eq (string_field "kind" next) "line";
      check_eq (string_field "line" next) "next";
      check
        (Yojson.Safe.Util.member "history" report = `List [])
        "a refused display line is not retained in history";
      check
        (int_field "history_bytes" report = 0)
        "a refused display line consumes no history bytes");
  test "an oversized terminal edit can return below the limit" (fun () ->
      let editor = Repl_input.create_editor_buffer ~limit:3 () in
      check (Repl_input.append_editor_byte editor 0x61) "first byte accepted";
      check (Repl_input.append_editor_byte editor 0x62) "second byte accepted";
      check (Repl_input.append_editor_byte editor 0x63) "limit byte accepted";
      check
        (not (Repl_input.append_editor_byte editor 0x64))
        "the byte beyond the limit is refused";
      check
        (Repl_input.editor_result editor = Repl_input.Line_too_long)
        "an uncorrected overflow is rejected";
      Repl_input.erase_editor_code_point editor;
      check
        (Repl_input.editor_result editor = Repl_input.Line "ab")
        "Backspace restores an acceptable edited line");
  test "interactive history is bounded and navigable without a runtime package"
    (fun () ->
      let history = Repl_input.create_history ~capacity:3 () in
      List.iter
        (Repl_input.remember history)
        [ "one"; "two"; "two"; "three"; "four" ];
      check
        (history.entries = [ "two"; "three"; "four" ])
        "history retains the newest bounded entries and removes adjacent \
         duplicates";
      let navigation = Repl_input.create_navigation () in
      check_eq (Repl_input.older history navigation "draft") "four";
      check_eq (Repl_input.older history navigation "four") "three";
      check_eq (Repl_input.older history navigation "three") "two";
      check_eq (Repl_input.older history navigation "two") "two";
      check_eq (Repl_input.newer history navigation "two") "three";
      check_eq (Repl_input.newer history navigation "three") "four";
      check_eq (Repl_input.newer history navigation "four") "draft");
  test "history is editing-only and bounded by total bytes" (fun () ->
      let history = Repl_input.create_history ~byte_capacity:7 () in
      let retain mode line =
        Repl_input.remember_result history ~mode (Repl_input.Line line)
      in
      retain Repl_input.Piped "secret";
      retain Repl_input.Plain_terminal "plain";
      check (history.entries = []) "non-editing input is not retained";
      retain Repl_input.Editing_terminal "abc";
      retain Repl_input.Editing_terminal "def";
      retain Repl_input.Editing_terminal "ghij";
      check
        (history.entries = [ "def"; "ghij" ] && history.bytes = 7)
        "oldest entries leave when the byte budget is crossed";
      retain Repl_input.Editing_terminal "12345678";
      check
        (history.entries = [ "def"; "ghij" ] && history.bytes = 7)
        "one over-budget entry cannot evict usable history");
  test "the non-interactive human transcript recovers from malformed input"
    (fun () ->
      with_temp "±Socrates*+Man\n−Man+Mortal\n" (fun path ->
          let directory = Filename.dirname path
          and file = Filename.basename path in
          let transcript =
            String.concat "\n"
              [
                "help";
                "query +oops(";
                "query ±Socrates*+Mortal";
                "consistency";
                "equivalence −Dog+Mammal <=> −(−Mammal)+(−Dog)";
                "quit";
                "";
              ]
          in
          let status, stdout, stderr =
            run_from_input_streams directory [ "repl"; file ] transcript
          in
          check (status = 0) "handled command failures do not fail the session";
          check (stderr = "")
            ("the human dialogue stays on standard output; stderr was "
           ^ String.escaped stderr);
          List.iter
            (fun fragment ->
              check (contains stdout fragment) ("transcript has " ^ fragment))
            [
              "Loaded";
              "Interactive commands:";
              "syntactic";
              "yes — the query follows";
              "consistent";
              "equivalent — the propositions are equivalent";
              "Goodbye.";
            ];
          check
            (not (contains stdout "tfl>"))
            "a pipe receives records without terminal prompts"));
  test "equivalence delimiters ignore quoted names and bare-name primes"
    (fun () ->
      with_temp "−Man+Mortal\n" (fun path ->
          let directory = Filename.dirname path
          and file = Filename.basename path in
          let transcript =
            String.concat "\n"
              [
                "equivalence +\"a<=>b\"+P <=> +\"a<=>b\"+P";
                "equivalence +A\"+P <=> +A\"+P";
                "quit";
                "";
              ]
          in
          let status, stdout, stderr =
            run_from_input_streams directory [ "repl"; "--json"; file ]
              transcript
          in
          let records = json_records stdout in
          check (status = 0 && stderr = "") "quoted delimiter session exit";
          check (List.length records = 4) "ready, two results, and quit";
          List.iter
            (fun record ->
              check_eq (string_field "operation" record) "equivalence";
              check (bool_field "equivalent" record) "reflexive equivalence")
            [ List.nth records 1; List.nth records 2 ]));
  test "many equivalence delimiters are rejected in bounded time" (fun () ->
      with_temp "−Man+Mortal\n" (fun path ->
          let directory = Filename.dirname path
          and file = Filename.basename path in
          let transcript = Buffer.create 40_032 in
          Buffer.add_string transcript "equivalence ";
          for _ = 1 to 10_000 do
            Buffer.add_string transcript "<=>"
          done;
          Buffer.add_string transcript "\nquit\n";
          let started = Unix.gettimeofday () in
          let status, stdout, stderr =
            run_from_input_streams directory [ "repl"; "--json"; file ]
              (Buffer.contents transcript)
          in
          let elapsed = Unix.gettimeofday () -. started in
          let records = json_records stdout in
          check (status = 0 && stderr = "") "ambiguous delimiter session exit";
          check
            (List.length records = 3)
            "ready, bounded failure, and quit are emitted";
          let failure = List.nth records 1 in
          check
            (not (bool_field "ok" failure))
            "many delimiters remain a handled input failure";
          check (elapsed < 5.0)
            (Printf.sprintf
               "40 KB of delimiters is rejected promptly (observed %.3fs)"
               elapsed)));
  test "end-of-input closes an initialized JSON session cleanly" (fun () ->
      with_temp "−Man+Mortal\n" (fun path ->
          let directory = Filename.dirname path
          and file = Filename.basename path in
          let status, stdout, stderr =
            run_from_input_streams directory [ "repl"; "--json"; file ] ""
          in
          let records = json_records stdout in
          check (status = 0) "end-of-input is a successful session exit";
          check (stderr = "") "JSON end-of-input leaves standard error empty";
          check (List.length records = 2) "ready and quit are the only records";
          check_eq (string_field "operation" (List.hd records)) "ready";
          let quit = List.hd (List.tl records) in
          check_eq (string_field "operation" quit) "quit";
          check_eq (string_field "reason" quit) "end-of-input";
          let status, stdout, stderr =
            run_from_input_streams directory [ "repl"; "--json"; file ]
              "consistency"
          in
          let records = json_records stdout in
          check (status = 0) "an unterminated final command is processed";
          check (stderr = "") "unterminated JSON input leaves stderr empty";
          check (List.length records = 3) "ready, result, and quit are emitted";
          check_eq
            (string_field "operation" (List.hd (List.tl records)))
            "consistency";
          let quit = List.hd (List.tl (List.tl records)) in
          check_eq (string_field "reason" quit) "end-of-input"));
  test "the JSON REPL covers every operation, reload, and state preservation"
    (fun () ->
      with_temp "±Socrates*+Man\n−Man+Mortal\n" (fun path ->
          let directory = Filename.dirname path
          and file = Filename.basename path in
          let runtime =
            Tfl.Source_file.load path
            |> result_or_fail "direct source load"
            |> Tfl.Source_file.runtime
          in
          let expected_query =
            Tfl.Runtime.query runtime "±Socrates*+Mortal"
            |> result_or_fail "direct query"
          and expected_description =
            Tfl.Runtime.describe runtime "Socrates*"
            |> result_or_fail "direct description"
          and expected_consistency =
            Tfl.Runtime.check_consistency runtime
            |> result_or_fail "direct consistency check"
          and expected_equivalence =
            Tfl.Runtime.equivalent ~left:"−Dog+Mammal"
              ~right:"−(−Mammal)+(−Dog)"
            |> result_or_fail "direct equivalence check"
          in
          let session = start_session directory [ "repl"; "--json"; file ] in
          Fun.protect
            ~finally:(fun () -> ignore (stop_session session))
            (fun () ->
              let ready = event session in
              check_eq (string_field "schema" ready) "tfl-repl-0.1";
              check_eq (string_field "operation" ready) "ready";
              check
                (List.length
                   (Yojson.Safe.Util.member "statements" ready
                   |> Yojson.Safe.Util.to_list)
                = 2)
                "ready exposes the loaded program";
              send session "help";
              let help = event session in
              check_eq (string_field "operation" help) "help";
              check
                (contains (string_field "usage" help) "reload")
                "session help documents reload";
              send session "query ±Socrates*+Mortal";
              let query = event session in
              check_eq (string_field "operation" query) "query";
              check_eq (string_field "verdict" query) "yes";
              check_eq (string_field "method" query) "PZ";
              check
                (Yojson.Safe.Util.member "support" query <> `Null)
                "query carries runtime proof support";
              check_json_fields "query" query
                (Runtime_json.query_fields expected_query);
              send session "describe Socrates*";
              let description = event session in
              check_eq (string_field "operation" description) "describe";
              check_eq
                (string_field "command_status" description)
                "incomplete-search";
              check
                (Yojson.Safe.Util.member "answers" description <> `Null)
                "description carries runtime answers";
              check_json_fields "description" description
                (Runtime_json.describe_fields expected_description);
              send session "consistency";
              let consistency = event session in
              check_eq (string_field "operation" consistency) "consistency";
              check_eq (string_field "status" consistency) "consistent";
              check
                (Yojson.Safe.Util.member "evidence" consistency <> `Null)
                "consistency carries runtime evidence";
              check_json_fields "consistency" consistency
                (Runtime_json.consistency_fields expected_consistency);
              send session "equivalence −Dog+Mammal <=> −(−Mammal)+(−Dog)";
              let equivalence = event session in
              check_eq (string_field "operation" equivalence) "equivalence";
              check (bool_field "equivalent" equivalence) "equivalence verdict";
              check
                (Yojson.Safe.Util.member "evidence" equivalence <> `Null)
                "equivalence carries runtime evidence";
              check_json_fields "equivalence" equivalence
                (Runtime_json.equivalence_fields expected_equivalence);
              send session "query +oops(";
              let malformed = event session in
              check
                (not (bool_field "ok" malformed))
                "malformed query is a recoverable failure";
              send session "query ±Socrates*+Mortal";
              check_eq (string_field "verdict" (event session)) "yes";
              send session "not-a-command";
              let unknown_command = event session in
              check_eq (string_field "operation" unknown_command) "command";
              check
                (not (bool_field "ok" unknown_command))
                "unknown command is recoverable";
              let oversized =
                String.make (Repl_input.max_line_bytes + 1) 'x'
                ^ "not-a-command"
              in
              send session oversized;
              let too_long = event session in
              check_eq (string_field "operation" too_long) "command";
              check_eq (string_field "command_status" too_long) "input-failure";
              let first_error =
                Yojson.Safe.Util.member "errors" too_long
                |> Yojson.Safe.Util.to_list |> List.hd
              in
              check_eq (string_field "class" first_error) "resource_limit";
              send session "consistency";
              let after_oversized = event session in
              check_eq (string_field "operation" after_oversized) "consistency";
              check_eq (string_field "status" after_oversized) "consistent";
              replace_file path "±Socrates*+Bird\n";
              send session "reload";
              let reloaded = event session in
              check_eq (string_field "operation" reloaded) "reload";
              check
                (List.length
                   (Yojson.Safe.Util.member "statements" reloaded
                   |> Yojson.Safe.Util.to_list)
                = 1)
                "reload replaces the complete program";
              send session "query ±Socrates*+Mortal";
              check_eq (string_field "verdict" (event session)) "unknown";
              send session "query ±Socrates*+Bird";
              check_eq (string_field "verdict" (event session)) "yes";
              replace_file path "+oops(\n";
              send session "reload";
              let failed_reload = event session in
              check
                (not (bool_field "ok" failed_reload))
                "a malformed replacement is refused";
              send session "query ±Socrates*+Bird";
              check_eq (string_field "verdict" (event session)) "yes";
              send session "quit";
              let quit = event session in
              check_eq (string_field "operation" quit) "quit";
              check_eq (string_field "reason" quit) "command";
              let status, stderr = stop_session session in
              check (status = 0) "quit exits the session successfully";
              check (stderr = "") "JSON session leaves standard error empty")));
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
            (status = 2
            && contains output (file ^ ":1:3: lexical:")
            && contains output "\n  | 　+É+P\n"
            && contains output "^")
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
            && Yojson.Safe.Util.member "column" first_error = `Int 3
            && string_field "source_line" first_error = "　+É+P"
            && Yojson.Safe.Util.member "column"
                 (Yojson.Safe.Util.member "start"
                    (Yojson.Safe.Util.member "span" first_error))
               = `Int 3
            && Yojson.Safe.Util.member "column"
                 (Yojson.Safe.Util.member "end"
                    (Yojson.Safe.Util.member "span" first_error))
               = `Int 4)
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
            && contains stderr (file ^ ":2:")
            && contains stderr "　+É+P" && contains stderr "+oops("
            && count_char stderr '^' >= 2)
            "human output includes both file diagnostics";
          let status, stdout, stderr =
            run_from_streams directory [ "check"; "--json"; file ]
          in
          let response = json stdout in
          let errors =
            Yojson.Safe.Util.member "errors" response
            |> Yojson.Safe.Util.to_list
          in
          check (status = 2 && stderr = "") "machine multi-error exit";
          check (List.length errors = 2) "machine output includes both errors";
          check
            (Yojson.Safe.Util.member "line" (List.hd errors) = `Int 1
            && Yojson.Safe.Util.member "line" (List.hd (List.tl errors))
               = `Int 2)
            "machine errors retain both physical lines"));
  test "query-input failures carry source excerpts and ranges in both modes"
    (fun () ->
      with_temp "−Man+Animal\n" (fun path ->
          let directory = Filename.dirname path
          and file = Filename.basename path
          and query = "　+É+P" in
          let status, output = run_from directory [ "query"; file; query ] in
          check
            (status = 2
            && contains output "query:1:3: lexical:"
            && contains output query && contains output "^")
            "human query diagnostic has the source and caret";
          let status, output =
            run_from directory [ "query"; "--json"; file; query ]
          in
          let response = json output in
          let failure =
            Yojson.Safe.Util.member "errors" response
            |> Yojson.Safe.Util.to_list |> List.hd
          in
          let span = Yojson.Safe.Util.member "span" failure in
          check
            (status = 2
            && string_field "class" failure = "lexical"
            && string_field "source_line" failure = query
            && Yojson.Safe.Util.member "codepoint_offset"
                 (Yojson.Safe.Util.member "start" span)
               = `Int 2
            && Yojson.Safe.Util.member "column"
                 (Yojson.Safe.Util.member "start" span)
               = `Int 3
            && Yojson.Safe.Util.member "column"
                 (Yojson.Safe.Util.member "end" span)
               = `Int 4)
            "machine query diagnostic has an explicit code-point span";
          let status, output =
            run_from directory [ "query"; file; "  ±General+Thing " ]
          in
          check
            (status = 2
            && contains output "outside_fragment"
            && contains output "±General+Thing"
            && count_char output '^' = 14)
            "human fragment refusal is distinct and underlines the proposition";
          let status, output =
            run_from directory [ "query"; "--json"; file; "  ±General+Thing " ]
          in
          let refusal =
            Yojson.Safe.Util.member "errors" (json output)
            |> Yojson.Safe.Util.to_list |> List.hd
          in
          check
            (status = 2
            && string_field "class" refusal = "outside_fragment"
            && Yojson.Safe.Util.member "column"
                 (Yojson.Safe.Util.member "start"
                    (Yojson.Safe.Util.member "span" refusal))
               = `Int 3)
            "machine fragment refusal is separate from syntax and search status"));
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
      check
        (contains output "tfl repl [--json] FILE.tfl")
        "help documents the interactive shell";
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
        [
          [];
          [ "bogus" ];
          [ "check" ];
          [ "repl" ];
          [ "render"; "−S+P"; "extra" ];
        ];
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
          [ "--json"; "repl" ];
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
                check (contains output escaped)
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
