(* Human-facing command line introduced in Phase 3 and extended with the
   Phase 4 REPL and Phase 5 source diagnostics. The long-lived [horos]
   JSON-lines process remains a separate executable and protocol. *)

type diagnostic = {
  class_name : string;
  message : string;
  source : string;
  line : int option;
  column : int option;
  span : Tfl.Source.span option;
  source_line : string option;
}

let unlocated_diagnostic ~class_name ~message ~source =
  {
    class_name;
    message;
    source;
    line = None;
    column = None;
    span = None;
    source_line = None;
  }

let cli_schema = "tfl-cli-0.1"
let repl_schema = "tfl-repl-0.1"
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
  tfl repl [--json] FILE.tfl
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

let repl_help =
  {|Interactive commands:
  query PROPOSITION
      Ask whether a ground proposition follows from the loaded program.
  describe TERM
      List the supported descriptions of a term.
  consistency
      Check the loaded program for a contradiction.
  equivalence LEFT <=> RIGHT
      Compare two propositions. The <=> delimiter is command syntax.
  reload
      Reload the original file. A failed reload keeps the current program.
  help
      Show this command list.
  quit
      End the session.
|}

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

let output_json json =
  print_endline (Runtime_json.to_string json);
  flush stdout

let output_human text =
  print_string text;
  if text = "" || text.[String.length text - 1] <> '\n' then print_newline ();
  flush stdout

let outcome_json ~ok ~schema ~status_field ~exit_status_field operation status
    fields =
  `Assoc
    ([
       ("ok", `Bool ok);
       ("schema", `String schema);
       ("operation", `String operation);
       (status_field, `String (Command_status.name status));
       (exit_status_field, `Int (Command_status.exit_code status));
     ]
    @ fields)

let success_json operation status fields =
  outcome_json ~ok:true ~schema:cli_schema ~status_field:"status"
    ~exit_status_field:"exit_status" operation status fields

let diagnostic_json diagnostic =
  `Assoc
    [
      ("class", `String diagnostic.class_name);
      ("message", `String diagnostic.message);
      ("source", `String diagnostic.source);
      ("line", match diagnostic.line with Some n -> `Int n | None -> `Null);
      ("column", match diagnostic.column with Some n -> `Int n | None -> `Null);
      ( "span",
        match diagnostic.span with
        | Some span -> Runtime_json.source_span_json span
        | None -> `Null );
      ( "source_line",
        match diagnostic.source_line with
        | Some source_line -> `String source_line
        | None -> `Null );
    ]

let failure_json operation status diagnostics =
  outcome_json ~ok:false ~schema:cli_schema ~status_field:"status"
    ~exit_status_field:"exit_status" operation status
    [ ("errors", `List (List.map diagnostic_json diagnostics)) ]

(* A REPL command has an outcome status but does not terminate the session, so
   its stream schema names the per-command fields explicitly instead of
   pretending they are the process exit status. *)
let repl_success_json operation status fields =
  outcome_json ~ok:true ~schema:repl_schema ~status_field:"command_status"
    ~exit_status_field:"command_exit_status" operation status fields

let repl_failure_json operation status diagnostics =
  outcome_json ~ok:false ~schema:repl_schema ~status_field:"command_status"
    ~exit_status_field:"command_exit_status" operation status
    [ ("errors", `List (List.map diagnostic_json diagnostics)) ]

let rendered_excerpt source_line (span : Tfl.Source.span) =
  let start_column = span.start_pos.column in
  let end_column =
    if span.end_pos.line = span.start_pos.line then span.end_pos.column
    else Tfl.Source.codepoint_length source_line + 1
  in
  let rendered = Buffer.create (String.length source_line) in
  let display_width = ref 0 and source_column = ref 1 and byte = ref 0 in
  let marker_start = ref None and marker_end = ref None in
  let mark_boundaries () =
    if !source_column = start_column then marker_start := Some !display_width;
    if !source_column = end_column then marker_end := Some !display_width
  in
  while !byte < String.length source_line do
    mark_boundaries ();
    let decoded = String.get_utf_8_uchar source_line !byte in
    if Uchar.utf_decode_is_valid decoded then (
      let width = Uchar.utf_decode_length decoded in
      let code_point = Uchar.to_int (Uchar.utf_decode_uchar decoded) in
      if is_terminal_format_control code_point then (
        let before = Buffer.length rendered in
        add_code_point_escape rendered code_point;
        display_width := !display_width + Buffer.length rendered - before)
      else (
        Buffer.add_substring rendered source_line !byte width;
        incr display_width);
      byte := !byte + width)
    else (
      add_byte_escape rendered (Char.code source_line.[!byte]);
      display_width := !display_width + 4;
      incr byte);
    incr source_column
  done;
  mark_boundaries ();
  let marker_start = Option.value ~default:!display_width !marker_start in
  let marker_end = Option.value ~default:marker_start !marker_end in
  let marker_width = max 1 (marker_end - marker_start) in
  ( Buffer.contents rendered,
    String.make marker_start ' ' ^ String.make marker_width '^' )

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
  let heading = Printf.sprintf "%s: %s: %s" location class_name message in
  match (diagnostic.source_line, diagnostic.span) with
  | Some source_line, Some span ->
      let source_line, carets = rendered_excerpt source_line span in
      Printf.sprintf "%s\n  | %s\n  | %s" heading source_line carets
  | _ -> heading

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

let emit_repl_result ~json operation status human fields =
  if json then output_json (repl_success_json operation status fields)
  else output_human human

let emit_repl_failure ~json operation status diagnostics =
  if json then output_json (repl_failure_json operation status diagnostics)
  else
    diagnostics |> List.map human_diagnostic |> String.concat "\n"
    |> output_human

let source_diagnostic (diagnostic : Tfl.Source_file.diagnostic) =
  let line, column, span, source_line =
    match diagnostic.kind with
    | Tfl.Source_file.Internal -> (None, None, None, None)
    | _ ->
        ( diagnostic.line,
          diagnostic.column,
          diagnostic.span,
          diagnostic.source_line )
  in
  {
    class_name = Tfl.Source_file.kind_name diagnostic.kind;
    message = diagnostic.message;
    source = diagnostic.path;
    line;
    column;
    span;
    source_line;
  }

let input_diagnostic label (failure : Tfl.Safe.failure) =
  let span, source_line =
    match failure.kind with
    | Tfl.Safe.Internal -> (None, None)
    | _ -> (failure.span, failure.source_line)
  in
  {
    class_name = Tfl.Safe.kind_name failure.kind;
    message = failure.message;
    source = Option.value ~default:label failure.where;
    line = Option.map (fun span -> span.Tfl.Source.start_pos.line) span;
    column = Option.map (fun span -> span.Tfl.Source.start_pos.column) span;
    span;
    source_line;
  }

let status_of_source_failures failures =
  let is_internal (failure : Tfl.Source_file.diagnostic) =
    failure.kind = Tfl.Source_file.Internal
  and is_incomplete (failure : Tfl.Source_file.diagnostic) =
    failure.kind = Tfl.Source_file.Incomplete_search
  in
  if List.exists is_internal failures then Command_status.Internal_failure
  else if List.exists is_incomplete failures then
    Command_status.Incomplete_search
  else Command_status.Input_failure

let status_of_safe_failure (failure : Tfl.Safe.failure) =
  match failure.kind with
  | Tfl.Safe.Internal -> Command_status.Internal_failure
  | Tfl.Safe.Incomplete_search -> Command_status.Incomplete_search
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
      ("source_path", `String statement.path);
      ("source", `String statement.source);
      ("source_line", `String statement.source_line);
      ("span", Runtime_json.source_span_json statement.span);
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

let query_presentation loaded result =
  ( query_status result,
    query_human result,
    file_field loaded :: Runtime_json.query_fields result )

let run_query ~json path source =
  let loaded = load_or_fail ~json "query" path in
  let result =
    Tfl.Runtime.query (Tfl.Source_file.runtime loaded) source
    |> safe_or_fail ~json ~operation:"query" ~input_label:"query"
  in
  let status, human, fields = query_presentation loaded result in
  emit_result ~json "query" status human fields

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

let describe_status (result : Tfl.Runtime.term_result) =
  if result.completeness.complete then Command_status.Success
  else Command_status.Incomplete_search

let describe_presentation loaded result =
  ( describe_status result,
    describe_human result,
    file_field loaded :: Runtime_json.describe_fields result )

let run_describe ~json path source =
  let loaded = load_or_fail ~json "describe" path in
  let result =
    Tfl.Runtime.describe (Tfl.Source_file.runtime loaded) source
    |> safe_or_fail ~json ~operation:"describe" ~input_label:"term"
  in
  let status, human, fields = describe_presentation loaded result in
  emit_result ~json "describe" status human fields

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

type repl_command =
  | Repl_query of string
  | Repl_describe of string
  | Repl_consistency
  | Repl_equivalence of string * string
  | Repl_reload
  | Repl_help
  | Repl_quit
  | Repl_empty

let command_and_argument line =
  let line = String.trim line in
  let rec boundary index =
    if index >= String.length line then None
    else
      match line.[index] with
      | ' ' | '\t' -> Some index
      | _ -> boundary (index + 1)
  in
  match boundary 0 with
  | None -> (line, "")
  | Some index ->
      ( String.sub line 0 index,
        String.sub line (index + 1) (String.length line - index - 1)
        |> String.trim )

type delimiter_scan_state =
  | Outside_name
  | Inside_bare_name
  | Inside_quoted_name

type delimiter_scan =
  | Missing_delimiter
  | Unique_delimiter of int
  | Many_delimiters

(* The delimiter belongs to the REPL grammar, so find it without repeatedly
   parsing proposition-sized substrings. These bare-name characters mirror the
   tokenizer, including its compatibility rule that a quote inside a bare name
   is a double prime rather than the start of a quoted name. *)
let code_point_at text byte =
  let decoded = String.get_utf_8_uchar text byte in
  if Uchar.utf_decode_is_valid decoded then
    ( Uchar.to_int (Uchar.utf_decode_uchar decoded),
      Uchar.utf_decode_length decoded )
  else (Char.code text.[byte], 1)

let is_ascii_letter code_point =
  (code_point >= 0x41 && code_point <= 0x5A)
  || (code_point >= 0x61 && code_point <= 0x7A)

let is_bare_name_continuation code_point =
  is_ascii_letter code_point
  || (code_point >= 0x30 && code_point <= 0x39)
  || code_point = 0x5F || code_point = 0x27 || code_point = 0x22
  || code_point = 0x2032 || code_point = 0x2033
  || (code_point >= 0x2080 && code_point <= 0x2089)

let find_equivalence_delimiter text =
  let length = String.length text in
  let delimiter_at byte =
    byte + 3 <= length
    && text.[byte] = '<'
    && text.[byte + 1] = '='
    && text.[byte + 2] = '>'
  in
  let rec scan state found byte =
    if byte >= length then
      match found with
      | None -> Missing_delimiter
      | Some position -> Unique_delimiter position
    else
      match state with
      | Inside_quoted_name ->
          if text.[byte] = '"' then scan Outside_name found (byte + 1)
          else
            let _, width = code_point_at text byte in
            scan Inside_quoted_name found (byte + width)
      | Inside_bare_name ->
          let code_point, width = code_point_at text byte in
          if is_bare_name_continuation code_point then
            scan Inside_bare_name found (byte + width)
          else scan Outside_name found byte
      | Outside_name ->
          if delimiter_at byte then
            match found with
            | None -> scan Outside_name (Some byte) (byte + 3)
            | Some _ -> Many_delimiters
          else
            let code_point, width = code_point_at text byte in
            if code_point = 0x22 then
              scan Inside_quoted_name found (byte + width)
            else if is_ascii_letter code_point then
              scan Inside_bare_name found (byte + width)
            else scan Outside_name found (byte + width)
  in
  scan Outside_name None 0

let split_equivalence_pair source =
  let delimiter = "<=>" in
  let split position =
    let left = String.sub source 0 position |> String.trim in
    let right_start = position + String.length delimiter in
    let right =
      String.sub source right_start (String.length source - right_start)
      |> String.trim
    in
    (left, right)
  in
  match find_equivalence_delimiter source with
  | Missing_delimiter -> Error "equivalence requires LEFT <=> RIGHT"
  | Unique_delimiter position ->
      let left, right = split position in
      if left = "" || right = "" then
        Error "equivalence requires a proposition on both sides of <=>"
      else Ok (left, right)
  | Many_delimiters ->
      Error "equivalence contains more than one possible <=> delimiter"

let parse_repl_command line =
  let command, argument = command_and_argument line in
  let needs_argument constructor =
    if argument = "" then Error (command ^ " requires an argument")
    else Ok (constructor argument)
  and takes_no_argument value =
    if argument = "" then Ok value
    else Error (command ^ " does not accept an argument")
  in
  match command with
  | "" -> Ok Repl_empty
  | "query" -> needs_argument (fun source -> Repl_query source)
  | "describe" -> needs_argument (fun source -> Repl_describe source)
  | "consistency" -> takes_no_argument Repl_consistency
  | "equivalence" ->
      if argument = "" then Error "equivalence requires LEFT <=> RIGHT"
      else
        Result.map
          (fun (left, right) -> Repl_equivalence (left, right))
          (split_equivalence_pair argument)
  | "reload" -> takes_no_argument Repl_reload
  | "help" -> takes_no_argument Repl_help
  | "quit" -> takes_no_argument Repl_quit
  | unknown -> Error (Printf.sprintf "unknown interactive command %S" unknown)

let consistency_status (result : Tfl.Runtime.consistency_result) =
  match result.status with
  | Tfl.Runtime.Undetermined -> Command_status.Incomplete_search
  | Tfl.Runtime.Consistent | Tfl.Runtime.Inconsistent -> Command_status.Success

let consistency_human (result : Tfl.Runtime.consistency_result) =
  let outcome =
    match result.status with
    | Tfl.Runtime.Consistent ->
        "consistent — no contradiction follows under the complete procedure"
    | Tfl.Runtime.Inconsistent -> "inconsistent — a contradiction follows"
    | Tfl.Runtime.Undetermined ->
        "undetermined — the current procedure did not decide consistency"
  in
  Printf.sprintf "%s\nMethod: %s (%s)" outcome
    (Tfl.Runtime.method_name result.method_)
    (completeness_text result.completeness)

let consistency_presentation loaded result =
  ( consistency_status result,
    consistency_human result,
    file_field loaded :: Runtime_json.consistency_fields result )

let equivalence_status (result : Tfl.Runtime.equivalence_result) =
  if result.equivalent then Command_status.Success
  else if result.completeness.complete then Command_status.Non_entailment
  else Command_status.Incomplete_search

let equivalence_human (result : Tfl.Runtime.equivalence_result) =
  let outcome =
    if result.equivalent then "equivalent — the propositions are equivalent"
    else if result.completeness.complete then
      "not equivalent — the complete procedure distinguishes the propositions"
    else "not established — the bounded procedure found no equivalence witness"
  in
  Printf.sprintf "%s\nLeft: %s [%s]\nRight: %s [%s]\nMethod: %s (%s)" outcome
    (escape_terminal_field result.left.english)
    (escape_terminal_field result.left.tfl)
    (escape_terminal_field result.right.english)
    (escape_terminal_field result.right.tfl)
    (Tfl.Runtime.method_name result.method_)
    (completeness_text result.completeness)

let equivalence_presentation loaded result =
  ( equivalence_status result,
    equivalence_human result,
    file_field loaded :: Runtime_json.equivalence_fields result )

let loaded_summary action loaded =
  let count = List.length (Tfl.Source_file.statements loaded) in
  Printf.sprintf "%s %s (%d statement%s)." action
    (escape_terminal_field (Tfl.Source_file.path loaded))
    count
    (if count = 1 then "" else "s")

let loaded_fields loaded =
  [
    file_field loaded;
    ( "statements",
      `List
        (List.map located_statement_json (Tfl.Source_file.statements loaded)) );
  ]

let repl_usage_diagnostic message =
  unlocated_diagnostic ~class_name:"usage" ~message
    ~source:"interactive command"

let emit_repl_safe_failure ~json operation input_label failure =
  emit_repl_failure ~json operation
    (status_of_safe_failure failure)
    [ input_diagnostic input_label failure ]

let emit_repl_operation ~json ~operation ~input_label ~presentation = function
  | Error failure -> emit_repl_safe_failure ~json operation input_label failure
  | Ok result ->
      let status, human, fields = presentation result in
      emit_repl_result ~json operation status human fields

let run_repl_query ~json loaded source =
  Tfl.Runtime.query (Tfl.Source_file.runtime loaded) source
  |> emit_repl_operation ~json ~operation:"query" ~input_label:"query"
       ~presentation:(query_presentation loaded)

let run_repl_describe ~json loaded source =
  Tfl.Runtime.describe (Tfl.Source_file.runtime loaded) source
  |> emit_repl_operation ~json ~operation:"describe" ~input_label:"term"
       ~presentation:(describe_presentation loaded)

let run_repl_consistency ~json loaded =
  Tfl.Runtime.check_consistency (Tfl.Source_file.runtime loaded)
  |> emit_repl_operation ~json ~operation:"consistency"
       ~input_label:"consistency"
       ~presentation:(consistency_presentation loaded)

let run_repl_equivalence ~json loaded left right =
  Tfl.Runtime.equivalent ~left ~right
  |> emit_repl_operation ~json ~operation:"equivalence"
       ~input_label:"equivalence"
       ~presentation:(equivalence_presentation loaded)

let reload_repl ~json path loaded =
  match Tfl.Source_file.load path with
  | Ok reloaded ->
      emit_repl_result ~json "reload" Command_status.Success
        (loaded_summary "Reloaded" reloaded)
        (loaded_fields reloaded);
      reloaded
  | Error failures ->
      emit_repl_failure ~json "reload"
        (status_of_source_failures failures)
        (List.map source_diagnostic failures);
      loaded

let run_repl ~json path =
  let loaded = load_or_fail ~json "repl" path in
  let history = Repl_input.create_history () in
  let input_mode = Repl_input.input_mode ~json in
  emit_repl_result ~json "ready" Command_status.Success
    (loaded_summary "Loaded" loaded ^ "\nType \"help\" for commands.")
    (loaded_fields loaded);
  let rec loop loaded =
    match
      Repl_input.read_line history ~mode:input_mode ~prompt:"tfl> "
        ~display:escape_terminal_field
    with
    | Repl_input.End_of_input ->
        emit_repl_result ~json "quit" Command_status.Success "Goodbye."
          [ ("reason", `String "end-of-input") ]
    | Repl_input.Interrupted ->
        output_human "Interrupted. The loaded program is unchanged.";
        loop loaded
    | Repl_input.Line_too_long ->
        let diagnostic =
          unlocated_diagnostic ~class_name:"resource_limit"
            ~message:
              (Printf.sprintf "interactive command exceeds the %d-byte limit"
                 Repl_input.max_line_bytes)
            ~source:"interactive command"
        in
        emit_repl_failure ~json "command" Command_status.Input_failure
          [ diagnostic ];
        loop loaded
    | Repl_input.Display_limit ->
        let diagnostic =
          unlocated_diagnostic ~class_name:"resource_limit"
            ~message:
              (Printf.sprintf
                 "interactive display exceeded the %d-byte per-line output \
                  limit; the input line was discarded"
                 Repl_input.max_editor_output_bytes)
            ~source:"interactive command"
        in
        emit_repl_failure ~json "command" Command_status.Input_failure
          [ diagnostic ];
        loop loaded
    | Repl_input.Line line -> (
        match parse_repl_command line with
        | Error message ->
            emit_repl_failure ~json "command" Command_status.Input_failure
              [ repl_usage_diagnostic message ];
            loop loaded
        | Ok Repl_empty -> loop loaded
        | Ok Repl_quit ->
            emit_repl_result ~json "quit" Command_status.Success "Goodbye."
              [ ("reason", `String "command") ]
        | Ok Repl_help ->
            emit_repl_result ~json "help" Command_status.Success repl_help
              [ ("usage", `String repl_help) ];
            loop loaded
        | Ok Repl_reload -> loop (reload_repl ~json path loaded)
        | Ok (Repl_query source) ->
            run_repl_query ~json loaded source;
            loop loaded
        | Ok (Repl_describe source) ->
            run_repl_describe ~json loaded source;
            loop loaded
        | Ok Repl_consistency ->
            run_repl_consistency ~json loaded;
            loop loaded
        | Ok (Repl_equivalence (left, right)) ->
            run_repl_equivalence ~json loaded left right;
            loop loaded)
  in
  match loop loaded with
  | () -> ()
  | exception error ->
      let unexpected = Command_status.unexpected_failure error in
      let diagnostic =
        unlocated_diagnostic ~class_name:"internal" ~message:unexpected.message
          ~source:"tfl repl"
      in
      emit_repl_failure ~json "session" unexpected.status [ diagnostic ];
      exit (Command_status.exit_code unexpected.status)

let usage_failure ~json message =
  let diagnostic =
    unlocated_diagnostic ~class_name:"usage" ~message ~source:"command line"
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
  | Ok (json, [ "repl"; path ]) -> run_repl ~json path
  | Ok (json, []) -> usage_failure ~json "a command is required"
  | Ok (json, command :: _) ->
      usage_failure ~json (Printf.sprintf "invalid arguments for %S" command)

let () =
  match Command_status.protect main with
  | Ok () -> ()
  | Error unexpected ->
      let json = Array.to_list Sys.argv |> List.exists (( = ) "--json") in
      let diagnostic =
        unlocated_diagnostic ~class_name:"internal" ~message:unexpected.message
          ~source:"tfl"
      in
      emit_failure ~json "command" unexpected.status [ diagnostic ]
