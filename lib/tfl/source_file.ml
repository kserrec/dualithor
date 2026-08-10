type failure_kind =
  | File
  | Lexical
  | Syntactic
  | Outside_fragment
  | Resource_limit
  | Internal

type diagnostic = {
  kind : failure_kind;
  message : string;
  path : string;
  line : int option;
  column : int option;
}

type statement = {
  line : int;
  column : int;
  source : string;
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
  | Outside_fragment -> "outside_fragment"
  | Resource_limit -> "resource_limit"
  | Internal -> "internal"

let path loaded = loaded.source_path
let runtime loaded = loaded.compiled
let statements loaded = loaded.located_statements

let diagnostic ?line ?column kind path message =
  { kind; message; path; line; column }

let file_failure path message = diagnostic File path message

let read_bounded path =
  match open_in_bin path with
  | exception Sys_error message -> Error (file_failure path message)
  | channel ->
      Fun.protect
        ~finally:(fun () -> close_in_noerr channel)
        (fun () ->
          let chunk = Bytes.create 65_536 in
          let contents = Buffer.create 4_096 in
          let rec read total =
            let remaining = Safe.max_program_bytes + 1 - total in
            let requested = min (Bytes.length chunk) remaining in
            match input channel chunk 0 requested with
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
          | exception Sys_error message -> Error (file_failure path message)
          | exception error ->
              Error
                (diagnostic Internal path
                   ("Unexpected file-read failure: " ^ Printexc.to_string error)))

let validate_utf8 path source =
  let rec scan byte line column =
    if byte >= String.length source then Ok ()
    else
      let decoded = String.get_utf_8_uchar source byte in
      if not (Uchar.utf_decode_is_valid decoded) then
        Error
          (diagnostic ~line ~column Lexical path "File is not well-formed UTF-8")
      else
        let code_point = Uchar.to_int (Uchar.utf_decode_uchar decoded) in
        let next_byte = byte + Uchar.utf_decode_length decoded in
        if code_point = 0x0A then scan next_byte (line + 1) 1
        else scan next_byte line (column + 1)
  in
  scan 0 1 1

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
  | Safe.Outside_fragment -> Outside_fragment
  | Safe.Resource_limit -> Resource_limit
  | Safe.Internal -> Internal

let source_line lines number =
  if number > 0 && number <= Array.length lines then lines.(number - 1) else ""

let source_column lines number position =
  Program.source_column (source_line lines number) position

let diagnostic_of_safe path lines (failure : Safe.failure) =
  let line = line_number failure.where in
  let column =
    Option.map
      (fun number ->
        source_column lines number (Option.value ~default:0 failure.pos))
      line
  in
  diagnostic ?line ?column (safe_kind failure.kind) path failure.message

let locate_statement lines (statement : Runtime.statement) =
  {
    line = statement.line;
    column = source_column lines statement.line 0;
    source = statement.source;
    proposition = statement.proposition;
  }

let compile path source =
  let lines = Array.of_list (String.split_on_char '\n' source) in
  match Runtime.compile source with
  | Error failures -> Error (List.map (diagnostic_of_safe path lines) failures)
  | Ok compiled ->
      let located_statements =
        Runtime.statements compiled |> List.map (locate_statement lines)
      in
      Ok { source_path = path; compiled; located_statements }

let load path =
  if not (Filename.check_suffix path ".tfl") then
    Error
      [
        file_failure path
          "TFL source files must use the case-sensitive .tfl extension";
      ]
  else
    match read_bounded path with
    | Error failure -> Error [ failure ]
    | Ok source -> (
        match validate_utf8 path source with
        | Error failure -> Error [ failure ]
        | Ok () -> compile path source)
