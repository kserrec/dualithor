open Harness

let executable = Unix.realpath Sys.executable_name

let descriptor_target_is_open target =
  let descriptor_directory =
    List.find_opt Sys.file_exists [ "/proc/self/fd"; "/dev/fd" ]
    |> Option.value ~default:"/proc/self/fd"
  in
  let target_stats = Unix.stat target in
  let directory = Unix.opendir descriptor_directory in
  Fun.protect
    ~finally:(fun () -> Unix.closedir directory)
    (fun () ->
      let rec scan () =
        match Unix.readdir directory with
        | "." | ".." -> scan ()
        | entry -> (
            match Unix.stat (Filename.concat descriptor_directory entry) with
            | stats
              when stats.st_dev = target_stats.st_dev
                   && stats.st_ino = target_stats.st_ino ->
                true
            | _ -> scan ()
            | exception Unix.Unix_error _ -> scan ())
        | exception End_of_file -> false
      in
      scan ())

let () =
  if
    Array.length Sys.argv = 3
    && Sys.argv.(1) = "--source-descriptor-must-be-closed"
  then
    Unix._exit (if descriptor_target_is_open Sys.argv.(2) then 1 else 0)

let with_temp suffix contents run =
  let path, channel = Filename.open_temp_file "dualithor-source-" suffix in
  output_string channel contents;
  close_out channel;
  Fun.protect ~finally:(fun () -> Sys.remove path) (fun () -> run path)

let with_fifo run =
  let path, channel = Filename.open_temp_file "dualithor-source-" ".tfl" in
  close_out channel;
  Sys.remove path;
  Unix.mkfifo path 0o600;
  Fun.protect
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () -> run path)

let refuses_special_file_within ?(load = Tfl.Source_file.load) path seconds =
  match Unix.fork () with
  | 0 -> (
      match load path with
      | Error [ diagnostic ]
        when diagnostic.kind = Tfl.Source_file.File
             && diagnostic.message
                = "TFL source path must refer to a regular file" ->
          Unix._exit 0
      | _ -> Unix._exit 1)
  | pid ->
      let deadline = Unix.gettimeofday () +. seconds in
      let rec wait () =
        match Unix.waitpid [ Unix.WNOHANG ] pid with
        | 0, _ when Unix.gettimeofday () < deadline ->
            Unix.sleepf 0.01;
            wait ()
        | 0, _ ->
            (try Unix.kill pid Sys.sigkill with Unix.Unix_error _ -> ());
            ignore (Unix.waitpid [] pid);
            false
        | _, Unix.WEXITED 0 -> true
        | _ -> false
      in
      wait ()

let descriptor_is_closed_on_exec path =
  let observed = ref false in
  let after_open _descriptor =
    observed := true;
    match Unix.fork () with
    | 0 ->
        (try
           Unix.execv executable
             [|
               executable;
               "--source-descriptor-must-be-closed";
               Unix.realpath path;
             |]
         with _ -> Unix._exit 127)
    | pid -> (
        match Unix.waitpid [] pid with
        | _, Unix.WEXITED 0 -> ()
        | _ -> failwith "the source descriptor survived exec")
  in
  match Tfl.Source_file.For_testing.load ~after_open path with
  | Ok _ -> !observed
  | Error _ -> false

let () =
  test "a UTF-8 .tfl file retains physical lines and code-point columns"
    (fun () ->
      with_temp ".tfl" "　−Man+Animal\n\n\t±Socrates*+Man -- named fact\n"
        (fun path ->
          let statements =
            Tfl.Source_file.load path |> function
            | Ok loaded -> Tfl.Source_file.statements loaded
            | Error _ -> failwith "valid source file was refused"
          in
          match statements with
          | [ first; second ] ->
              check
                (first.line = 1 && first.column = 2)
                "ideographic space counts as one source column";
              check_eq first.path path;
              check_eq first.source_line "　−Man+Animal";
              check
                (first.span.start_pos.line = 1
                && first.span.start_pos.column = 2
                && first.span.end_pos.line = 1
                && first.span.end_pos.column = 13)
                "the first program entry retains its complete source span";
              check
                (second.line = 3 && second.column = 2
                && second.span.start_pos.codepoint_offset = 15)
                "blank lines and a leading tab retain stable locations";
              check_eq second.source "±Socrates*+Man"
          | _ -> failwith "expected two located statements"));
  test "compile diagnostics map trimmed parser positions to file locations"
    (fun () ->
      with_temp ".tfl" "　+É+P\n  +oops(\n" (fun path ->
          match Tfl.Source_file.load path with
          | Ok _ -> failwith "malformed source file compiled"
          | Error (first :: second :: _) ->
              check
                (first.kind = Tfl.Source_file.Lexical)
                "first failure is lexical";
              check
                (first.line = Some 1 && first.column = Some 3)
                "the non-ASCII leading space is one column, not three bytes";
              check
                (Option.map
                   (fun span -> span.Tfl.Source.start_pos.column)
                   first.span
                 = Some 3
                && Option.map
                     (fun span -> span.Tfl.Source.end_pos.column)
                     first.span
                   = Some 4
                && first.source_line = Some "　+É+P")
                "the lexical diagnostic carries its source line and caret range";
              check (second.line = Some 2)
                "the independent syntax error retains its physical line";
              check
                (Option.value ~default:0 second.column > 2)
                "the syntax position is translated past leading spaces"
          | Error _ -> failwith "expected both independent diagnostics"));
  test "malformed UTF-8 is refused at its exact file location" (fun () ->
      with_temp ".tfl" ("−S+P\n+S+" ^ "\xC3\x28") (fun path ->
          match Tfl.Source_file.load path with
          | Error [ diagnostic ] ->
              check
                (diagnostic.kind = Tfl.Source_file.Lexical)
                "invalid UTF-8 is lexical input, not an internal crash";
              check
                (diagnostic.line = Some 2 && diagnostic.column = Some 4)
                "first malformed byte location";
              check
                (Option.map
                   (fun span -> span.Tfl.Source.end_pos.column)
                   diagnostic.span
                 = Some 4
                && diagnostic.source_line = Some ("+S+" ^ "\xC3\x28"))
                "malformed UTF-8 uses a zero-width source span at the bad byte";
              check_eq diagnostic.message "File is not well-formed UTF-8"
          | _ -> failwith "expected one UTF-8 diagnostic"));
  test "the file loader requires the .tfl extension" (fun () ->
      with_temp ".txt" "−S+P\n" (fun path ->
          match Tfl.Source_file.load path with
          | Error [ diagnostic ] ->
              check
                (diagnostic.kind = Tfl.Source_file.File)
                "wrong extension is a file-input failure";
              check (diagnostic.line = None) "no fabricated source location"
          | _ -> failwith "a non-.tfl source path was accepted"));
  test "the .tfl extension is case-sensitive" (fun () ->
      with_temp ".TFL" "−S+P\n" (fun path ->
          match Tfl.Source_file.load path with
          | Error [ diagnostic ] ->
              check
                (diagnostic.kind = Tfl.Source_file.File)
                "an uppercase extension is a file-input failure";
              check_eq diagnostic.message
                "TFL source files must use the case-sensitive .tfl extension"
          | _ -> failwith "an uppercase .TFL source path was accepted"));
  test "the file loader enforces its byte cap before compilation" (fun () ->
      with_temp ".tfl"
        (String.make (Tfl.Safe.max_program_bytes + 1) 'x')
        (fun path ->
          match Tfl.Source_file.load path with
          | Error [ diagnostic ] ->
              check
                (diagnostic.kind = Tfl.Source_file.Resource_limit)
                "the loader classifies excess file bytes as a resource limit";
              check_eq diagnostic.message
                (Printf.sprintf "File exceeds the %d-byte program-source limit"
                   Tfl.Safe.max_program_bytes)
          | _ -> failwith "the loader read past its documented file-byte cap"));
  test "an invalid operating-system path is a file refusal, not an exception"
    (fun () ->
      match Tfl.Source_file.load "bad\000path.tfl" with
      | Error [ diagnostic ] ->
          check
            (diagnostic.kind = Tfl.Source_file.File)
            "an embedded NUL is invalid file input"
      | _ -> failwith "an embedded-NUL path escaped the total loader boundary");
  test "named pipes and links to them are refused without blocking" (fun () ->
      with_fifo (fun path ->
          check
            (refuses_special_file_within path 2.0)
            "a direct FIFO must be rejected without waiting for a writer";
          let link = path ^ "-link.tfl" in
          Unix.symlink path link;
          Fun.protect
            ~finally:(fun () -> if Sys.file_exists link then Sys.remove link)
            (fun () ->
              check
                (refuses_special_file_within link 2.0)
                "a symlink to a FIFO must be rejected without opening it")));
  test "a symlink to a regular source file is accepted" (fun () ->
      with_temp ".tfl" "−S+P\n" (fun path ->
          let link = path ^ "-regular-link.tfl" in
          Unix.symlink path link;
          Fun.protect
            ~finally:(fun () -> if Sys.file_exists link then Sys.remove link)
            (fun () ->
              match Tfl.Source_file.load link with
              | Ok loaded ->
                  check
                    (List.length (Tfl.Source_file.statements loaded) = 1)
                    "the regular symlink loads its target"
              | Error _ -> failwith "a symlink to a regular file was refused")));
  test "a regular path swapped to a FIFO is refused without blocking" (fun () ->
      with_temp ".tfl" "−S+P\n" (fun path ->
          let original = path ^ ".original" in
          let after_stat () =
            Sys.rename path original;
            Unix.mkfifo path 0o600
          in
          Fun.protect
            ~finally:(fun () ->
              if Sys.file_exists path then Sys.remove path;
              if Sys.file_exists original then Sys.rename original path)
            (fun () ->
              check
                (refuses_special_file_within
                   ~load:(Tfl.Source_file.For_testing.load ~after_stat)
                   path 2.0)
                "the opened descriptor must be nonblocking and reverified")));
  test "source descriptors are close-on-exec" (fun () ->
      with_temp ".tfl" "−S+P\n" (fun path ->
          check
            (descriptor_is_closed_on_exec path)
            "a child process must not inherit the source descriptor"));
  finish "source-file tests"
