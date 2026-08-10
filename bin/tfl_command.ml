(* Human-facing Phase 3 command line. The long-lived [horos] JSON-lines
   process remains a separate executable and protocol. *)

type diagnostic = {
  class_name : string;
  message : string;
  source : string;
  line : int option;
  column : int option;
}

let cli_schema = "tfl-cli-0.1"
let hex = "0123456789ABCDEF"

let add_byte_escape buffer value =
  Buffer.add_string buffer "\\x";
  Buffer.add_char buffer hex.[value lsr 4];
  Buffer.add_char buffer hex.[value land 0x0F]

let usage =
  {|Usage:
  tfl check [--json] FILE.tfl
  tfl query [--json] FILE.tfl PROPOSITION
  tfl describe [--json] FILE.tfl TERM
  tfl render [--json] PROPOSITION
  tfl [--json] --help

FILE.tfl must name a regular, well-formed UTF-8 file. PROPOSITION and TERM are
single command-line arguments; quote them in the shell when they contain spaces or
special characters.

Exit statuses:
  0  success
  1  logical non-entailment
  2  input, file, usage, or compile failure
  3  incomplete search
  4  internal failure
|}

(* Yojson deliberately preserves string bytes without validating UTF-8. Unix
   paths do the same, so normalize every string at the final machine boundary
   instead of relying on each record builder to remember which values came
   from the operating system. *)
let escape_invalid_utf8 text =
  let escaped = Buffer.create (String.length text) in
  let rec copy byte =
    if byte < String.length text then (
      let decoded = String.get_utf_8_uchar text byte in
      if Uchar.utf_decode_is_valid decoded then (
        let width = Uchar.utf_decode_length decoded in
        Buffer.add_substring escaped text byte width;
        copy (byte + width))
      else
        let value = Char.code text.[byte] in
        add_byte_escape escaped value;
        copy (byte + 1))
  in
  copy 0;
  Buffer.contents escaped

(* Human output has trusted layout but interpolates operating-system paths and
   language text. Escape controls at those field boundaries so a hostile path
   cannot clear a terminal, create a hyperlink, or forge another output line.
   Unicode formatting controls are visible too, preventing bidi/zero-width
   path spoofing without changing ordinary UTF-8 text. *)
let is_terminal_format_control code_point =
  code_point <= 0x1F
  || (code_point >= 0x7F && code_point <= 0x9F)
  || code_point = 0x061C
  || (code_point >= 0x200B && code_point <= 0x200F)
  || (code_point >= 0x2028 && code_point <= 0x202E)
  || (code_point >= 0x2060 && code_point <= 0x206F)
  || code_point = 0xFEFF
  || (code_point >= 0xFFF9 && code_point <= 0xFFFB)

let add_code_point_escape buffer code_point =
  if code_point <= 0x7F then add_byte_escape buffer code_point
  else Buffer.add_string buffer (Printf.sprintf "\\u{%04X}" code_point)

let escape_terminal_field text =
  let escaped = Buffer.create (String.length text) in
  let rec copy byte =
    if byte < String.length text then
      let decoded = String.get_utf_8_uchar text byte in
      if Uchar.utf_decode_is_valid decoded then (
        let width = Uchar.utf_decode_length decoded in
        let code_point = Uchar.to_int (Uchar.utf_decode_uchar decoded) in
        if is_terminal_format_control code_point then
          add_code_point_escape escaped code_point
        else Buffer.add_substring escaped text byte width;
        copy (byte + width))
      else (
        add_byte_escape escaped (Char.code text.[byte]);
        copy (byte + 1))
  in
  copy 0;
  Buffer.contents escaped

let rec json_with_valid_utf8 (json : Yojson.Safe.t) : Yojson.Safe.t =
  match json with
  | `String text -> `String (escape_invalid_utf8 text)
  | `Assoc fields ->
      `Assoc
        (List.map
           (fun (name, value) ->
             (escape_invalid_utf8 name, json_with_valid_utf8 value))
           fields)
  | `List values -> `List (List.map json_with_valid_utf8 values)
  | (`Null | `Bool _ | `Int _ | `Intlit _ | `Float _) as scalar -> scalar

let output_json json =
  print_endline (Yojson.Safe.to_string (json_with_valid_utf8 json));
  flush stdout

let output_human text =
  print_string text;
  if text = "" || text.[String.length text - 1] <> '\n' then print_newline ();
  flush stdout

let success_json operation status fields =
  `Assoc
    (("ok", `Bool true)
    :: ("schema", `String cli_schema)
    :: ("operation", `String operation)
    :: ("status", `String (Command_status.name status))
    :: ("exit_status", `Int (Command_status.exit_code status))
    :: fields)

let diagnostic_json diagnostic =
  `Assoc
    [
      ("class", `String diagnostic.class_name);
      ("message", `String diagnostic.message);
      ("source", `String diagnostic.source);
      ("line", match diagnostic.line with Some n -> `Int n | None -> `Null);
      ("column", match diagnostic.column with Some n -> `Int n | None -> `Null);
    ]

let failure_json operation status diagnostics =
  `Assoc
    [
      ("ok", `Bool false);
      ("schema", `String cli_schema);
      ("operation", `String operation);
      ("status", `String (Command_status.name status));
      ("exit_status", `Int (Command_status.exit_code status));
      ("errors", `List (List.map diagnostic_json diagnostics));
    ]

let human_diagnostic diagnostic =
  let source = escape_terminal_field diagnostic.source
  and class_name = escape_terminal_field diagnostic.class_name
  and message = escape_terminal_field diagnostic.message in
  let location =
    match (diagnostic.line, diagnostic.column) with
    | Some line, Some column -> Printf.sprintf "%s:%d:%d" source line column
    | Some line, None -> Printf.sprintf "%s:%d" source line
    | None, _ -> source
  in
  Printf.sprintf "%s: %s: %s" location class_name message

let emit_result ~json operation status human fields =
  if json then output_json (success_json operation status fields)
  else output_human human;
  exit (Command_status.exit_code status)

let emit_failure ~json operation status diagnostics =
  if json then output_json (failure_json operation status diagnostics)
  else (
    List.iter
      (fun diagnostic -> prerr_endline (human_diagnostic diagnostic))
      diagnostics;
    flush stderr);
  exit (Command_status.exit_code status)

let source_diagnostic (diagnostic : Tfl.Source_file.diagnostic) =
  {
    class_name = Tfl.Source_file.kind_name diagnostic.kind;
    message = diagnostic.message;
    source = diagnostic.path;
    line = diagnostic.line;
    column = diagnostic.column;
  }

let input_diagnostic label (failure : Tfl.Safe.failure) =
  {
    class_name = Tfl.Safe.kind_name failure.kind;
    message = failure.message;
    source = Option.value ~default:label failure.where;
    line = Option.map (fun _ -> 1) failure.pos;
    column = Option.map (fun position -> position + 1) failure.pos;
  }

let status_of_source_failures failures =
  let is_internal (failure : Tfl.Source_file.diagnostic) =
    failure.kind = Tfl.Source_file.Internal
  in
  if List.exists is_internal failures then Command_status.Internal_failure
  else Command_status.Input_failure

let status_of_safe_failure (failure : Tfl.Safe.failure) =
  match failure.kind with
  | Tfl.Safe.Internal -> Command_status.Internal_failure
  | _ -> Command_status.Input_failure

let safe_or_fail ~json ~operation ~input_label = function
  | Ok result -> result
  | Error failure ->
      emit_failure ~json operation
        (status_of_safe_failure failure)
        [ input_diagnostic input_label failure ]

let located_statement_json (statement : Tfl.Source_file.statement) =
  `Assoc
    [
      ("line", `Int statement.line);
      ("column", `Int statement.column);
      ("source", `String statement.source);
      ("proposition", Runtime_json.proposition_json statement.proposition);
    ]

let completeness_text (completeness : Tfl.Runtime.completeness) =
  if completeness.complete then "complete"
  else
    match completeness.reason with
    | Some reason -> "incomplete: " ^ Tfl.Runtime.incompleteness_name reason
    | None -> "incomplete"

let load_or_fail ~json operation path =
  match Tfl.Source_file.load path with
  | Ok loaded -> loaded
  | Error failures ->
      let diagnostics = List.map source_diagnostic failures in
      emit_failure ~json operation
        (status_of_source_failures failures)
        diagnostics

let file_field loaded = ("file", `String (Tfl.Source_file.path loaded))

let run_check ~json path =
  let loaded = load_or_fail ~json "check" path in
  let statements = Tfl.Source_file.statements loaded in
  let count = List.length statements in
  let human =
    Printf.sprintf "%s: OK (%d statement%s)"
      (escape_terminal_field path)
      count
      (if count = 1 then "" else "s")
  in
  emit_result ~json "check" Command_status.Success human
    [
      file_field loaded;
      ("statements", `List (List.map located_statement_json statements));
    ]

let query_status (result : Tfl.Runtime.query_result) =
  match result.verdict with
  | Tfl.Runtime.Yes -> Command_status.Success
  | (Tfl.Runtime.No | Tfl.Runtime.Unknown) when result.completeness.complete ->
      Command_status.Non_entailment
  | Tfl.Runtime.No | Tfl.Runtime.Unknown -> Command_status.Incomplete_search

let query_human (result : Tfl.Runtime.query_result) =
  let outcome =
    match result.verdict with
    | Tfl.Runtime.Yes -> "yes — the query follows"
    | Tfl.Runtime.No when result.completeness.complete ->
        "no — the contradictory follows"
    | Tfl.Runtime.No ->
        "contradicted — the contradictory follows, but the procedure is not \
         exhaustive"
    | Tfl.Runtime.Unknown when result.completeness.complete ->
        "unknown — neither the query nor its contradictory follows"
    | Tfl.Runtime.Unknown ->
        "unknown — the current procedure did not decide the query"
  in
  let support =
    match result.support with
    | None -> ""
    | Some support ->
        Printf.sprintf "\nSupport: %s [%s]"
          (escape_terminal_field support.proposition.english)
          (escape_terminal_field support.proposition.tfl)
  in
  Printf.sprintf "%s\nQuery: %s [%s]\nMethod: %s (%s)%s" outcome
    (escape_terminal_field result.query.english)
    (escape_terminal_field result.query.tfl)
    (Tfl.Runtime.method_name result.method_)
    (completeness_text result.completeness)
    support

let run_query ~json path source =
  let loaded = load_or_fail ~json "query" path in
  let result =
    Tfl.Runtime.query (Tfl.Source_file.runtime loaded) source
    |> safe_or_fail ~json ~operation:"query" ~input_label:"query"
  in
  let status = query_status result in
  emit_result ~json "query" status (query_human result)
    (file_field loaded :: Runtime_json.query_fields result)

let describe_human (result : Tfl.Runtime.term_result) =
  let answers =
    match result.answers with
    | [] -> "  No supported descriptions were found."
    | answers ->
        answers
        |> List.map (fun (answer : Tfl.Runtime.term_answer) ->
            Printf.sprintf "  %s [%s]"
              (escape_terminal_field answer.proposition.english)
              (escape_terminal_field answer.proposition.tfl))
        |> String.concat "\n"
  in
  Printf.sprintf "What follows about %s [%s]:\n%s\nMethod: %s (%s)"
    (escape_terminal_field result.term.english)
    (escape_terminal_field result.term.tfl)
    answers
    (Tfl.Runtime.method_name result.method_)
    (completeness_text result.completeness)

let run_describe ~json path source =
  let loaded = load_or_fail ~json "describe" path in
  let result =
    Tfl.Runtime.describe (Tfl.Source_file.runtime loaded) source
    |> safe_or_fail ~json ~operation:"describe" ~input_label:"term"
  in
  let status =
    if result.completeness.complete then Command_status.Success
    else Command_status.Incomplete_search
  in
  emit_result ~json "describe" status (describe_human result)
    (file_field loaded :: Runtime_json.describe_fields result)

let proposition_of_ast proposition : Tfl.Runtime.proposition =
  {
    tfl = Tfl.Notation.print_proposition proposition;
    canonical =
      Tfl.Notation.print_proposition (Tfl.Infer.canon_prop proposition);
    english = Tfl.Render.read_prop proposition;
  }

let run_render ~json source =
  let proposition =
    Tfl.Safe.parse ~where:"proposition" source
    |> safe_or_fail ~json ~operation:"render" ~input_label:"proposition"
    |> proposition_of_ast
  in
  let human =
    Printf.sprintf "%s\nTFL: %s"
      (escape_terminal_field proposition.english)
      (escape_terminal_field proposition.tfl)
  in
  emit_result ~json "render" Command_status.Success human
    [ ("proposition", Runtime_json.proposition_json proposition) ]

let usage_failure ~json message =
  let diagnostic =
    {
      class_name = "usage";
      message;
      source = "command line";
      line = None;
      column = None;
    }
  in
  if json then
    emit_failure ~json "command" Command_status.Input_failure [ diagnostic ]
  else (
    prerr_endline (human_diagnostic diagnostic);
    prerr_endline "";
    prerr_string usage;
    flush stderr;
    exit (Command_status.exit_code Command_status.Input_failure))

let extract_json arguments =
  let rec collect json kept = function
    | [] -> Ok (json, List.rev kept)
    | "--json" :: rest when not json -> collect true kept rest
    | "--json" :: _ -> Error "--json may be supplied only once"
    | argument :: rest -> collect json (argument :: kept) rest
  in
  collect false [] arguments

let main () =
  let arguments = Array.to_list Sys.argv |> List.tl in
  let initial_json = List.exists (( = ) "--json") arguments in
  match extract_json arguments with
  | Error message -> usage_failure ~json:initial_json message
  | Ok (json, ([ "--help" ] | [ "-h" ])) ->
      emit_result ~json "help" Command_status.Success usage
        [ ("usage", `String usage) ]
  | Ok (json, [ "check"; path ]) -> run_check ~json path
  | Ok (json, [ "query"; path; proposition ]) ->
      run_query ~json path proposition
  | Ok (json, [ "describe"; path; term ]) -> run_describe ~json path term
  | Ok (json, [ "render"; proposition ]) -> run_render ~json proposition
  | Ok (json, []) -> usage_failure ~json "a command is required"
  | Ok (json, command :: _) ->
      usage_failure ~json (Printf.sprintf "invalid arguments for %S" command)

let () =
  match Command_status.protect main with
  | Ok () -> ()
  | Error unexpected ->
      let json = Array.to_list Sys.argv |> List.exists (( = ) "--json") in
      let diagnostic =
        {
          class_name = "internal";
          message = unexpected.message;
          source = "tfl";
          line = None;
          column = None;
        }
      in
      emit_failure ~json "command" unexpected.status [ diagnostic ]
