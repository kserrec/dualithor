open Harness

let with_temp suffix contents run =
  let path, channel = Filename.open_temp_file "horos-source-" suffix in
  output_string channel contents;
  close_out channel;
  Fun.protect ~finally:(fun () -> Sys.remove path) (fun () -> run path)

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
              check
                (second.line = 3 && second.column = 2)
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
  finish "source-file tests"
