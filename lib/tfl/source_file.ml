type failure_kind =
  | File
  | Lexical
  | Syntactic
  | Name_resolution
  | Outside_fragment
  | Incomplete_search
  | Resource_limit
  | Internal

type diagnostic = {
  kind : failure_kind;
  message : string;
  path : string;
  line : int option;
  column : int option;
  span : Source.span option;
  source_line : string option;
}

type statement = {
  path : string;
  line : int;
  column : int;
  source : string;
  source_line : string;
  span : Source.span;
  proposition : Runtime.proposition;
}

type loaded = {
  source_path : string;
  compiled : Runtime.program;
  located_statements : statement list;
}

let kind_name = function
  | File -> "file"
  | Lexical -> "lexical"
  | Syntactic -> "syntactic"
  | Name_resolution -> "name_resolution"
  | Outside_fragment -> "outside_fragment"
  | Incomplete_search -> "incomplete_search"
  | Resource_limit -> "resource_limit"
  | Internal -> "internal"

let path loaded = loaded.source_path
let runtime loaded = loaded.compiled
let statements loaded = loaded.located_statements

let diagnostic ?line ?column ?span ?source_line kind path message =
  let line =
    match (line, span) with
    | Some line, _ -> Some line
    | None, Some span -> Some span.Source.start_pos.line
    | None, None -> None
  and column =
    match (column, span) with
    | Some column, _ -> Some column
    | None, Some span -> Some span.Source.start_pos.column
    | None, None -> None
  in
  { kind; message; path; line; column; span; source_line }

let file_failure path message = diagnostic File path message
let regular_file_message = "TFL source path must refer to a regular file"

let unix_failure path error =
  file_failure path (Printf.sprintf "%s: %s" path (Unix.error_message error))

let operation_failure path = function
  | Unix.Unix_error (error, _, _) -> unix_failure path error
  | Sys_error message | Invalid_argument message -> file_failure path message
  | error ->
      diagnostic Internal path
        ("Unexpected file-operation failure: " ^ Printexc.to_string error)

let close_noerr descriptor =
  try Unix.close descriptor with Unix.Unix_error _ -> ()

let regular_file_stats path =
  match Unix.stat path with
  | stats when stats.st_kind = Unix.S_REG -> Ok ()
  | _ -> Error (file_failure path regular_file_message)
  | exception error -> Error (operation_failure path error)

let open_regular ?(after_stat = fun () -> ())
    ?(after_open = fun (_ : Unix.file_descr) -> ()) path =
  match regular_file_stats path with
  | Error _ as failure -> failure
  | Ok () -> (
      match after_stat () with
      | exception error -> Error (operation_failure path error)
      | () -> (
          match
            Unix.openfile path
              [ Unix.O_RDONLY; Unix.O_NONBLOCK; Unix.O_CLOEXEC ]
              0
          with
          | descriptor -> (
              match after_open descriptor with
              | exception error ->
                  close_noerr descriptor;
                  Error (operation_failure path error)
              | () -> (
                  match Unix.fstat descriptor with
                  | stats when stats.st_kind = Unix.S_REG -> Ok descriptor
                  | _ ->
                      close_noerr descriptor;
                      Error (file_failure path regular_file_message)
                  | exception error ->
                      close_noerr descriptor;
                      Error (operation_failure path error)))
          | exception error -> Error (operation_failure path error)))

let read_bounded ?after_stat ?after_open path =
  match open_regular ?after_stat ?after_open path with
  | Error _ as failure -> failure
  | Ok descriptor ->
      Fun.protect
        ~finally:(fun () -> close_noerr descriptor)
        (fun () ->
          let chunk = Bytes.create 65_536 in
          let contents = Buffer.create 4_096 in
          let rec read total =
            let remaining = Safe.max_program_bytes + 1 - total in
            let requested = min (Bytes.length chunk) remaining in
            match Unix.read descriptor chunk 0 requested with
            | 0 -> Ok (Buffer.contents contents)
            | count when total + count > Safe.max_program_bytes ->
                Error
                  (diagnostic Resource_limit path
                     (Printf.sprintf
                        "File exceeds the %d-byte program-source limit"
                        Safe.max_program_bytes))
            | count ->
                Buffer.add_subbytes contents chunk 0 count;
                read (total + count)
          in
          match read 0 with
          | result -> result
          | exception Unix.Unix_error (error, _, _) ->
              Error (unix_failure path error)
          | exception Sys_error message -> Error (file_failure path message)
          | exception error ->
              Error
                (diagnostic Internal path
                   ("Unexpected file-read failure: " ^ Printexc.to_string error)))

let validate_utf8 path source =
  let rec scan byte codepoint_offset line column =
    if byte >= String.length source then Ok ()
    else
      let decoded = String.get_utf_8_uchar source byte in
      if not (Uchar.utf_decode_is_valid decoded) then
        let start_pos = { Source.codepoint_offset; line; column } in
        let end_pos = start_pos in
        Error
          (diagnostic
             ~span:{ Source.start_pos; end_pos }
             ?source_line:(Source.line_text source line)
             Lexical path "File is not well-formed UTF-8")
      else
        let code_point = Uchar.to_int (Uchar.utf_decode_uchar decoded) in
        let next_byte = byte + Uchar.utf_decode_length decoded in
        if code_point = 0x0A then
          scan next_byte (codepoint_offset + 1) (line + 1) 1
        else scan next_byte (codepoint_offset + 1) line (column + 1)
  in
  scan 0 0 1 1

let line_number = function
  | None -> None
  | Some where ->
      let prefix = "line " in
      let prefix_length = String.length prefix in
      if
        String.length where > prefix_length
        && String.sub where 0 prefix_length = prefix
      then
        int_of_string_opt
          (String.sub where prefix_length (String.length where - prefix_length))
      else None

let safe_kind = function
  | Safe.Lexical -> Lexical
  | Safe.Syntactic -> Syntactic
  | Safe.Name_resolution -> Name_resolution
  | Safe.Outside_fragment -> Outside_fragment
  | Safe.Incomplete_search -> Incomplete_search
  | Safe.Resource_limit -> Resource_limit
  | Safe.Internal -> Internal

let line_at lines number =
  if number > 0 && number <= Array.length lines then lines.(number - 1) else ""

let column_at lines number position =
  Program.source_column (line_at lines number) position

let diagnostic_of_safe path lines (failure : Safe.failure) =
  match failure.kind with
  | Safe.Internal -> diagnostic Internal path failure.message
  | _ ->
      let fallback_line = line_number failure.where in
      let line, column =
        match failure.span with
        | Some span ->
            (Some span.Source.start_pos.line, Some span.Source.start_pos.column)
        | None ->
            ( fallback_line,
              Option.map
                (fun number ->
                  column_at lines number (Option.value ~default:0 failure.pos))
                fallback_line )
      in
      let excerpt =
        match failure.source_line with
        | Some _ as excerpt -> excerpt
        | None -> Option.map (line_at lines) line
      in
      diagnostic ?line ?column ?span:failure.span ?source_line:excerpt
        (safe_kind failure.kind) path failure.message

let locate_statement path (statement : Runtime.statement) =
  {
    path;
    line = statement.line;
    column = statement.span.start_pos.column;
    source = statement.source;
    source_line = statement.source_line;
    span = statement.span;
    proposition = statement.proposition;
  }

let compile path source =
  let lines = Array.of_list (String.split_on_char '\n' source) in
  match Runtime.compile source with
  | Error failures -> Error (List.map (diagnostic_of_safe path lines) failures)
  | Ok compiled ->
      let located_statements =
        Runtime.statements compiled |> List.map (locate_statement path)
      in
      Ok { source_path = path; compiled; located_statements }

let load_with_hooks ?after_stat ?after_open path =
  if not (Filename.check_suffix path ".tfl") then
    Error
      [
        file_failure path
          "TFL source files must use the case-sensitive .tfl extension";
      ]
  else
    match read_bounded ?after_stat ?after_open path with
    | Error failure -> Error [ failure ]
    | Ok source -> (
        match validate_utf8 path source with
        | Error failure -> Error [ failure ]
        | Ok () -> compile path source)

let load path = load_with_hooks path

module For_testing = struct
  let load = load_with_hooks
end
