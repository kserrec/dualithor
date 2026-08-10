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

let usage =
  {|Usage:
  tfl check [--json] FILE.tfl
  tfl query [--json] FILE.tfl PROPOSITION
  tfl describe [--json] FILE.tfl TERM
  tfl render [--json] PROPOSITION

FILE.tfl must be well-formed UTF-8. PROPOSITION and TERM are single command-line
arguments; quote them in the shell when they contain spaces or special characters.

Exit statuses:
  0  success
  1  logical non-entailment
  2  input, file, usage, or compile failure
  3  incomplete search
  4  internal failure
|}

let output_json json =
  print_endline (Yojson.Safe.to_string json);
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
  let location =
    match (diagnostic.line, diagnostic.column) with
    | Some line, Some column ->
        Printf.sprintf "%s:%d:%d" diagnostic.source line column
    | Some line, None -> Printf.sprintf "%s:%d" diagnostic.source line
    | None, _ -> diagnostic.source
  in
  Printf.sprintf "%s: %s: %s" location diagnostic.class_name diagnostic.message

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

let failure_status diagnostics =
  if
    List.exists
      (fun diagnostic -> diagnostic.class_name = "internal")
      diagnostics
  then Command_status.Internal_failure
  else Command_status.Input_failure

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

let load_or_fail ~json operation path continue =
  match Tfl.Source_file.load path with
  | Ok loaded -> continue loaded
  | Error failures ->
      let diagnostics = List.map source_diagnostic failures in
      emit_failure ~json operation (failure_status diagnostics) diagnostics

let run_check ~json path =
  load_or_fail ~json "check" path (fun loaded ->
      let statements = Tfl.Source_file.statements loaded in
      let count = List.length statements in
      let human =
        Printf.sprintf "%s: OK (%d statement%s)" path count
          (if count = 1 then "" else "s")
      in
      emit_result ~json "check" Command_status.Success human
        [
          ("file", `String (Tfl.Source_file.path loaded));
          ("statements", `List (List.map located_statement_json statements));
        ])

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
        Printf.sprintf "\nSupport: %s [%s]" support.proposition.english
          support.proposition.tfl
  in
  Printf.sprintf "%s\nQuery: %s [%s]\nMethod: %s (%s)%s" outcome
    result.query.english result.query.tfl
    (Tfl.Runtime.method_name result.method_)
    (completeness_text result.completeness)
    support

let run_query ~json path source =
  load_or_fail ~json "query" path (fun loaded ->
      match Tfl.Runtime.query (Tfl.Source_file.runtime loaded) source with
      | Error failure ->
          let diagnostics = [ input_diagnostic "query" failure ] in
          emit_failure ~json "query" (failure_status diagnostics) diagnostics
      | Ok result ->
          let status = query_status result in
          emit_result ~json "query" status (query_human result)
            (("file", `String (Tfl.Source_file.path loaded))
            :: Runtime_json.query_fields result))

let describe_human (result : Tfl.Runtime.term_result) =
  let answers =
    match result.answers with
    | [] -> "  No supported descriptions were found."
    | answers ->
        answers
        |> List.map (fun (answer : Tfl.Runtime.term_answer) ->
            Printf.sprintf "  %s [%s]" answer.proposition.english
              answer.proposition.tfl)
        |> String.concat "\n"
  in
  Printf.sprintf "What follows about %s [%s]:\n%s\nMethod: %s (%s)"
    result.term.english result.term.tfl answers
    (Tfl.Runtime.method_name result.method_)
    (completeness_text result.completeness)

let run_describe ~json path source =
  load_or_fail ~json "describe" path (fun loaded ->
      match Tfl.Runtime.describe (Tfl.Source_file.runtime loaded) source with
      | Error failure ->
          let diagnostics = [ input_diagnostic "term" failure ] in
          emit_failure ~json "describe" (failure_status diagnostics) diagnostics
      | Ok result ->
          let status =
            if result.completeness.complete then Command_status.Success
            else Command_status.Incomplete_search
          in
          emit_result ~json "describe" status (describe_human result)
            (("file", `String (Tfl.Source_file.path loaded))
            :: Runtime_json.describe_fields result))

let proposition_of_ast proposition : Tfl.Runtime.proposition =
  {
    tfl = Tfl.Notation.print_proposition proposition;
    canonical =
      Tfl.Notation.print_proposition (Tfl.Infer.canon_prop proposition);
    english = Tfl.Render.read_prop proposition;
  }

let run_render ~json source =
  match Tfl.Safe.parse ~where:"proposition" source with
  | Error failure ->
      let diagnostics = [ input_diagnostic "proposition" failure ] in
      emit_failure ~json "render" (failure_status diagnostics) diagnostics
  | Ok proposition ->
      let proposition = proposition_of_ast proposition in
      let human =
        Printf.sprintf "%s\nTFL: %s" proposition.english proposition.tfl
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
  | Ok (_json, ([ "--help" ] | [ "-h" ])) ->
      output_human usage;
      exit 0
  | Ok (json, [ "check"; path ]) -> run_check ~json path
  | Ok (json, [ "query"; path; proposition ]) ->
      run_query ~json path proposition
  | Ok (json, [ "describe"; path; term ]) -> run_describe ~json path term
  | Ok (json, [ "render"; proposition ]) -> run_render ~json proposition
  | Ok (json, []) -> usage_failure ~json "a command is required"
  | Ok (json, command :: _) ->
      usage_failure ~json (Printf.sprintf "invalid arguments for %S" command)

let () =
  match main () with
  | () -> ()
  | exception error ->
      let json = Array.to_list Sys.argv |> List.exists (( = ) "--json") in
      let diagnostic =
        {
          class_name = "internal";
          message = Printexc.to_string error;
          source = "tfl";
          line = None;
          column = None;
        }
      in
      emit_failure ~json "command" Command_status.Internal_failure
        [ diagnostic ]
