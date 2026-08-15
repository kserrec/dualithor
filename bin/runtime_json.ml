let hex = "0123456789ABCDEF"

let add_byte_escape buffer value =
  Buffer.add_string buffer "\\x";
  Buffer.add_char buffer hex.[value lsr 4];
  Buffer.add_char buffer hex.[value land 0x0F]

(* Yojson preserves string bytes without validating UTF-8. Normalize every
   string at the final machine boundary so a malformed source excerpt cannot
   make an otherwise valid response cease to be JSON. *)
let escape_invalid_utf8 text =
  let escaped = Buffer.create (String.length text) in
  let rec copy byte =
    if byte < String.length text then (
      let decoded = String.get_utf_8_uchar text byte in
      if Uchar.utf_decode_is_valid decoded then (
        let width = Uchar.utf_decode_length decoded in
        Buffer.add_substring escaped text byte width;
        copy (byte + width))
      else (
        add_byte_escape escaped (Char.code text.[byte]);
        copy (byte + 1)))
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

let to_string json = Yojson.Safe.to_string (json_with_valid_utf8 json)
let option_json convert = function Some value -> convert value | None -> `Null

let source_position_json (position : Tfl.Source.position) =
  `Assoc
    [
      ("codepoint_offset", `Int position.codepoint_offset);
      ("line", `Int position.line);
      ("column", `Int position.column);
    ]

let source_span_json (span : Tfl.Source.span) =
  `Assoc
    [
      ("start", source_position_json span.start_pos);
      ("end", source_position_json span.end_pos);
    ]

let failure_fields (failure : Tfl.Safe.failure) =
  let pos, end_pos, span, source_line =
    match failure.kind with
    | Tfl.Safe.Internal -> (None, None, None, None)
    | _ -> (failure.pos, failure.end_pos, failure.span, failure.source_line)
  in
  [
    ("class", `String (Tfl.Safe.kind_name failure.kind));
    ("message", `String failure.message);
    ("position", option_json (fun position -> `Int position) pos);
    ("end_position", option_json (fun position -> `Int position) end_pos);
    ("where", option_json (fun where -> `String where) failure.where);
    ("span", option_json source_span_json span);
    ("source_line", option_json (fun line -> `String line) source_line);
  ]

let failure_json failure = `Assoc (("ok", `Bool false) :: failure_fields failure)
let runtime_schema = "dualithor-runtime-0.1"

let runtime_failure_json failures =
  `Assoc
    [
      ("ok", `Bool false);
      ("schema", `String runtime_schema);
      ("errors", `List (List.map (fun f -> `Assoc (failure_fields f)) failures));
    ]

let proposition_json (proposition : Tfl.Runtime.proposition) =
  `Assoc
    [
      ("tfl", `String proposition.tfl);
      ("canonical", `String proposition.canonical);
      ("english", `String proposition.english);
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
      ("source_line", `String statement.source_line);
      ("span", source_span_json statement.span);
      ("proposition", proposition_json statement.proposition);
    ]

let completeness_json (completeness : Tfl.Runtime.completeness) =
  `Assoc
    [
      ("complete", `Bool completeness.complete);
      ( "reason",
        option_json
          (fun reason -> `String (Tfl.Runtime.incompleteness_name reason))
          completeness.reason );
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
        option_json (fun explanation -> `String explanation) proof.explanation
      );
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
        option_json
          (fun (left, right) -> `List [ `String left; `String right ])
          certificate.clash );
      ("cancellation", option_json cancellation_json certificate.cancellation);
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

let query_support_json =
  option_json (fun (support : Tfl.Runtime.query_support) ->
      `Assoc
        [
          ("proposition", proposition_json support.proposition);
          ("evidence", evidence_list_json support.evidence);
        ])

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
