(* The command-line surface (PLAN 11.4, pulled earlier per the 2026-08-02
   amendment: 4.6 and 6.1 both want it).

   JSON in, JSON out, one object per line on stdin and stdout. That shape is
   chosen so the pip-installable client at release is a thin wrapper around a
   long-lived process rather than a fresh exec per call — the engine has no
   startup state worth paying for repeatedly, and a line protocol is the one
   thing every language can speak without a binding.

   **This process never crashes and never exits non-zero on bad input.** Every
   failure comes back as a JSON object: protocol failures carry an "error"
   field, while runtime compile and operation failures carry the versioned
   schema and an "errors" array. That is the 1.14 total-API discipline
   (`Tfl.Safe` returns a result and never raises) carried out to the process
   boundary, and it matters because the caller is a script that has to
   distinguish "the engine says no" from "the engine fell over". A non-zero
   exit is reserved for the process being unable to run at all. *)

let out (j : Yojson.Safe.t) =
  print_string (Yojson.Safe.to_string j);
  print_newline ();
  flush stdout

let error ?(fields = []) msg = `Assoc (("error", `String msg) :: fields)

(* Bound a request before either [Yojson] or the engine sees it. [input_line]
   allocates the complete line first, so checking [String.length] afterwards
   would leave the process vulnerable to exactly the oversized request this
   guard is meant to refuse. The reader retains at most [max_request_bytes]
   bytes and drains the remainder of an oversized line so the next request can
   still be processed. *)
let max_request_bytes = 1_048_576

type request_line = End_of_input | Request of string | Request_too_large

let read_request_line ic =
  let buffer = Buffer.create 256 in
  let oversized = ref false in
  let saw_input = ref false in
  let rec read () =
    match input_char ic with
    | '\n' -> if !oversized then Request_too_large else Request (Buffer.contents buffer)
    | char ->
        saw_input := true;
        if !oversized then ()
        else if Buffer.length buffer < max_request_bytes then
          Buffer.add_char buffer char
        else oversized := true;
        read ()
    | exception End_of_file ->
        if !oversized then Request_too_large
        else if !saw_input || Buffer.length buffer > 0 then
          Request (Buffer.contents buffer)
        else End_of_input
  in
  read ()

let request_too_large_json () =
  error
    (Printf.sprintf "request exceeds the %d-byte limit" max_request_bytes)
    ~fields:
      [
        ("class", `String "resource_limit");
        ("max_bytes", `Int max_request_bytes);
      ]

let member name json =
  match Yojson.Safe.Util.member name json with `Null -> None | v -> Some v

let string_field name json =
  match member name json with
  | Some (`String s) -> Ok s
  | Some _ -> Error (Printf.sprintf "field %S must be a string" name)
  | None -> Error (Printf.sprintf "missing field %S" name)

let string_list_field name json =
  match member name json with
  | Some (`List items) ->
      let rec go acc = function
        | [] -> Ok (List.rev acc)
        | `String s :: rest -> go (s :: acc) rest
        | _ -> Error (Printf.sprintf "field %S must be a list of strings" name)
      in
      go [] items
  | Some _ -> Error (Printf.sprintf "field %S must be a list of strings" name)
  (* An argument with no premises is legal input — the conclusion alone decides
     it — so an absent list reads as empty rather than as an error. *)
  | None -> Ok []

(* A parse failure carries its 1.14 taxonomy class, which is the whole point of
   this command: `outside_fragment` is the router's escalation signal (5.1) and
   the coverage statistic 4.6 measures, and it has to be distinguishable from a
   typo by the caller. *)
let failure_fields (f : Tfl.Safe.failure) =
  [
    ("class", `String (Tfl.Safe.kind_name f.kind));
    ("message", `String f.message);
    ("position", match f.pos with Some p -> `Int p | None -> `Null);
    ("where", match f.where with Some w -> `String w | None -> `Null);
  ]

let failure_json (f : Tfl.Safe.failure) =
  `Assoc (("ok", `Bool false) :: failure_fields f)

let runtime_schema = "horos-runtime-0.1"

let runtime_failure_json failures =
  `Assoc
    [
      ("ok", `Bool false);
      ("schema", `String runtime_schema);
      ("errors", `List (List.map (fun f -> `Assoc (failure_fields f)) failures));
    ]

let proposition_json (p : Tfl.Runtime.proposition) =
  `Assoc
    [
      ("tfl", `String p.tfl);
      ("canonical", `String p.canonical);
      ("english", `String p.english);
    ]

let term_json (term : Tfl.Runtime.term) =
  `Assoc
    [
      ("tfl", `String term.tfl);
      ("canonical", `String term.canonical);
      ("english", `String term.english);
    ]

let statement_json (statement : Tfl.Runtime.statement) =
  `Assoc
    [
      ("line", `Int statement.line);
      ("source", `String statement.source);
      ("proposition", proposition_json statement.proposition);
    ]

let completeness_json (completeness : Tfl.Runtime.completeness) =
  `Assoc
    [
      ("complete", `Bool completeness.complete);
      ( "reason",
        match completeness.reason with
        | Some reason -> `String (Tfl.Runtime.incompleteness_name reason)
        | None -> `Null );
    ]

let proof_json (proof : Tfl.Runtime.proof) =
  `Assoc
    [
      ( "lines",
        `List
          (List.map
             (fun (line : Tfl.Runtime.proof_line) ->
               `Assoc
                 [
                   ("number", `Int line.number);
                   ("tfl", `String line.tfl);
                   ("english", `String line.english);
                   ("rule", `String line.rule);
                   ("parents", `List (List.map (fun n -> `Int n) line.parents));
                 ])
             proof.lines) );
      ( "explanation",
        match proof.explanation with
        | Some explanation -> `String explanation
        | None -> `Null );
    ]

let cancellation_json (cancellation : Tfl.Runtime.cancellation) =
  `Assoc
    [
      ("particular", proposition_json cancellation.particular);
      ( "universals",
        `List
          (List.map
             (fun (proposition, times) ->
               `Assoc
                 [
                   ("proposition", proposition_json proposition);
                   ("times", `Int times);
                 ])
             cancellation.universals) );
    ]

let certificate_json (certificate : Tfl.Runtime.certificate) =
  `Assoc
    [
      ("point", `List (List.map (fun point -> `String point) certificate.point));
      ( "clash",
        match certificate.clash with
        | Some (left, right) -> `List [ `String left; `String right ]
        | None -> `Null );
      ( "cancellation",
        match certificate.cancellation with
        | Some cancellation -> cancellation_json cancellation
        | None -> `Null );
    ]

let numerical_json (decision : Tfl.Runtime.numerical_decision) =
  `Assoc
    [
      ("valid", `Bool decision.valid);
      ( "conditions",
        `Assoc
          [
            ("sum", `Bool decision.sum);
            ("particular", `Bool decision.particular);
            ("level", `Bool decision.level);
          ] );
      ("carried_level", `Int decision.carried_level);
      ("conclusion_level", `Int decision.conclusion_level);
      ("particular_premises", `Int decision.particular_premises);
      ("particular_conclusions", `Int decision.particular_conclusions);
    ]

let evidence_json = function
  | Tfl.Runtime.Proof proof ->
      `Assoc [ ("kind", `String "proof"); ("proof", proof_json proof) ]
  | Tfl.Runtime.Closure_certificate certificate ->
      `Assoc
        [
          ("kind", `String "closure-certificate");
          ("certificate", certificate_json certificate);
        ]
  | Tfl.Runtime.Numerical_decision decision ->
      `Assoc
        [
          ("kind", `String "numerical-decision");
          ("decision", numerical_json decision);
        ]
  | Tfl.Runtime.Rewrite_path path ->
      `Assoc
        [
          ("kind", `String "rewrite-path");
          ("path", `List (List.map (fun step -> `String step) path));
        ]
  | Tfl.Runtime.Truth_table { atoms; rows } ->
      `Assoc
        [
          ("kind", `String "truth-table");
          ("atoms", `List (List.map (fun atom -> `String atom) atoms));
          ("rows", `List (List.map (fun row -> `String row) rows));
        ]

let evidence_list_json evidence = `List (List.map evidence_json evidence)

let query_support_json (support : Tfl.Runtime.query_support option) =
  match support with
  | None -> `Null
  | Some support ->
      `Assoc
        [
          ("proposition", proposition_json support.proposition);
          ("evidence", evidence_list_json support.evidence);
        ]

let term_answer_json (answer : Tfl.Runtime.term_answer) =
  `Assoc
    [
      ("proposition", proposition_json answer.proposition);
      ("support", proof_json answer.support);
    ]

let compile_fields program =
  [
    ( "statements",
      `List (List.map statement_json (Tfl.Runtime.statements program)) );
  ]

let query_fields (result : Tfl.Runtime.query_result) =
  [
    ("query", proposition_json result.query);
    ("verdict", `String (Tfl.Runtime.query_verdict_name result.verdict));
    ("method", `String (Tfl.Runtime.method_name result.method_));
    ("completeness", completeness_json result.completeness);
    ("support", query_support_json result.support);
  ]

let describe_fields (result : Tfl.Runtime.term_result) =
  [
    ("term", term_json result.term);
    ("answers", `List (List.map term_answer_json result.answers));
    ("method", `String (Tfl.Runtime.method_name result.method_));
    ("completeness", completeness_json result.completeness);
  ]

let consistency_fields (result : Tfl.Runtime.consistency_result) =
  [
    ("status", `String (Tfl.Runtime.consistency_status_name result.status));
    ("method", `String (Tfl.Runtime.method_name result.method_));
    ("completeness", completeness_json result.completeness);
    ("evidence", evidence_list_json result.evidence);
  ]

let equivalence_fields (result : Tfl.Runtime.equivalence_result) =
  [
    ("left", proposition_json result.left);
    ("right", proposition_json result.right);
    ("equivalent", `Bool result.equivalent);
    ("method", `String (Tfl.Runtime.method_name result.method_));
    ("completeness", completeness_json result.completeness);
    ("evidence", evidence_list_json result.evidence);
  ]

let runtime_success operation fields =
  `Assoc
    (("ok", `Bool true)
    :: ("schema", `String runtime_schema)
    :: ("operation", `String operation)
    :: fields)

let compile_program source =
  match Tfl.Runtime.compile source with
  | Ok program -> Ok program
  | Error failures -> Error (runtime_failure_json failures)

let with_string_field name json continue =
  match string_field name json with
  | Error message -> error message
  | Ok value -> continue value

let with_string_fields first_name second_name json continue =
  match (string_field first_name json, string_field second_name json) with
  | Error message, _ | _, Error message -> error message
  | Ok first_value, Ok second_value -> continue first_value second_value

let with_compiled_program source continue =
  match compile_program source with
  | Error response -> response
  | Ok program -> continue program

let runtime_response operation fields_of_result = function
  | Error failure -> runtime_failure_json [ failure ]
  | Ok result -> runtime_success operation (fields_of_result result)

let cmd_compile json =
  with_string_field "program" json (fun source ->
      match compile_program source with
      | Error response -> response
      | Ok program -> runtime_success "compile" (compile_fields program))

let cmd_query json =
  with_string_fields "program" "query" json (fun source query ->
      with_compiled_program source (fun program ->
          Tfl.Runtime.query program query
          |> runtime_response "query" query_fields))

let cmd_describe json =
  with_string_fields "program" "term" json (fun source term ->
      with_compiled_program source (fun program ->
          Tfl.Runtime.describe program term
          |> runtime_response "describe" describe_fields))

let cmd_consistency json =
  with_string_field "program" json (fun source ->
      with_compiled_program source (fun program ->
          Tfl.Runtime.check_consistency program
          |> runtime_response "consistency" consistency_fields))

let cmd_equivalence json =
  with_string_fields "left" "right" json (fun left right ->
      Tfl.Runtime.equivalent ~left ~right
      |> runtime_response "equivalence" equivalence_fields)

let cmd_check json =
  match (string_list_field "premises" json, string_field "conclusion" json) with
  | Error m, _ | _, Error m -> error m
  | Ok premises, Ok conclusion ->
      Tfl_verify.to_json (Tfl_verify.check ~premises ~conclusion)

let cmd_parse json =
  match string_field "tfl" json with
  | Error m -> error m
  | Ok src -> (
      match Tfl.Safe.parse src with
      | Error f -> failure_json f
      | Ok p ->
          `Assoc
            [
              ("ok", `Bool true);
              (* the canonical spelling, so a caller can normalize without
                 reimplementing the printer *)
              ("tfl", `String (Tfl.Notation.print_proposition p));
              ("english", `String (Tfl.Render.read_prop p));
            ])

let cmd_render json =
  match string_field "tfl" json with
  | Error m -> error m
  | Ok src -> (
      match Tfl.Safe.parse src with
      | Error f -> failure_json f
      | Ok p ->
          `Assoc [ ("ok", `Bool true); ("english", `String (Tfl.Render.read_prop p)) ])

let commands =
  [
    ("check", cmd_check);
    ("parse", cmd_parse);
    ("render", cmd_render);
    ("compile", cmd_compile);
    ("query", cmd_query);
    ("describe", cmd_describe);
    ("consistency", cmd_consistency);
    ("equivalence", cmd_equivalence);
  ]

let handle (line : string) : Yojson.Safe.t =
  match Yojson.Safe.from_string line with
  | exception _ -> error "line is not valid JSON"
  | (`Assoc _ as json) -> (
      match string_field "cmd" json with
      | Error m ->
          error m
            ~fields:
              [ ("commands", `List (List.map (fun (n, _) -> `String n) commands)) ]
      | Ok name -> (
          match List.assoc_opt name commands with
          | Some f -> (
              (* Belt and braces over Tfl.Safe's own totality: an unexpected
                 exception here would kill the stream and take every queued
                 request with it, so it becomes one error line instead. *)
              try f json
              with e -> error ("internal: " ^ Printexc.to_string e))
          | None ->
              error
                (Printf.sprintf "unknown cmd %S" name)
                ~fields:
                  [
                    ( "commands",
                      `List (List.map (fun (n, _) -> `String n) commands) );
                  ]))
  | _ -> error "request must be a JSON object"

let usage program_name =
  program_name
  ^ {| — JSON over stdio, one request per line.

  {"cmd":"check","premises":["-M+P","-S+M"],"conclusion":"-S+P"}
  {"cmd":"parse","tfl":"-Man+Mortal"}
  {"cmd":"render","tfl":"+Officer^1+(Sign+Contract)"}
  {"cmd":"query","program":"+-Socrates*+Man\n-Man+Mortal","query":"+-Socrates*+Mortal"}
  {"cmd":"describe","program":"+-Socrates*+Man\n-Man+Mortal","term":"Socrates*"}
  {"cmd":"consistency","program":"+-Socrates*+Man\n+-Socrates*-Man"}
  {"cmd":"equivalence","left":"-Dog+Mammal","right":"-(−Mammal)+(−Dog)"}

Every reply is one JSON object. Protocol failures carry an "error" field.
Runtime compile or operation failures carry "ok":false, schema
"horos-runtime-0.1", and an "errors" array; each error has a class (lexical |
syntactic | outside_fragment | resource_limit | internal), which is the
fragment-membership signal. The older check, parse, and render commands retain
their original response shapes.

Long-lived bidirectional callers must use request/reply lockstep: write one
nonblank request, flush it, and read its reply before sending the next. Blank
lines are ignored and receive no reply.
|}

let () =
  if Array.length Sys.argv > 1 then (
    (* No flags, deliberately: the protocol is the interface. Anything on the
       command line is a request for help. *)
    print_string (usage (Filename.basename Sys.argv.(0)));
    exit (if Sys.argv.(1) = "--help" || Sys.argv.(1) = "-h" then 0 else 2));
  let rec loop () =
    match read_request_line stdin with
    | End_of_input -> ()
    | Request_too_large ->
        out (request_too_large_json ());
        loop ()
    | Request line ->
        if String.trim line <> "" then out (handle line);
        loop ()
  in
  loop ()
