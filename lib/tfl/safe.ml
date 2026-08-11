(* The total public surface (PLAN 1.14). Everything downstream of the
   translation layer calls the engine through here and nowhere else: these
   functions never raise, always return a structured failure, and never run
   unboundedly. docs/engine-surface.md is the specification, including the full
   inventory of what the engine raises and which class each refusal falls in. *)

type failure_kind =
  | Lexical (* a character or token the notation has no reading for *)
  | Syntactic (* legal tokens that do not form a proposition *)
  | Name_resolution (* a parsed name cannot be resolved by the compiler *)
  | Outside_fragment (* a well-formed AST the inference layer refuses *)
  | Incomplete_search (* an operation stopped without a complete result *)
  | Resource_limit (* valid-shaped input exceeds a public work or size bound *)
  | Internal
(* an exception that should be unreachable. It classifies the engine, not the
   input, and it means a bug to fix rather than an escalation to make. It
   exists so the API can be total without a crash ever being reported as an
   expected outcome. *)

type failure = {
  kind : failure_kind;
  message : string; (* the engine's own text, unmodified *)
  pos : int option; (* 0-based index into the source; parse failures only *)
  end_pos : int option; (* exclusive 0-based code-point offset *)
  where : string option; (* which input, for the multi-input entry points *)
  span : Source.span option;
  source_line : string option;
}

let kind_name = function
  | Lexical -> "lexical"
  | Syntactic -> "syntactic"
  | Name_resolution -> "name_resolution"
  | Outside_fragment -> "outside_fragment"
  | Incomplete_search -> "incomplete_search"
  | Resource_limit -> "resource_limit"
  | Internal -> "internal"

(* ── Bounds ─────────────────────────────────────────────────────────────────
   The parser and every tree walk after it are recursive descent, so nesting
   depth is the one input dimension that can exhaust the stack (port-spec
   §16.5: the JS reference dies with a RangeError, the port would raise
   Stack_overflow). Nesting in this notation is exactly bracket nesting, so the
   depth is measurable from the token stream before any recursion happens.
   64 is far past anything a real formula reaches (three or four is typical)
   and far below the stack limit of any tree walk in the engine. *)
let max_depth = 64
let max_source_bytes = 65_536
let max_program_bytes = 1_048_576
let max_program_lines = 10_000
let max_program_propositions = 1_024
let max_argument_bytes = 1_048_576
let max_argument_premises = 1_024

let resource_failure ?where message =
  {
    kind = Resource_limit;
    message;
    pos = None;
    end_pos = None;
    where;
    span = None;
    source_line = None;
  }

let source_too_large ?where src =
  if String.length src <= max_source_bytes then None
  else
    Some
      (resource_failure ?where
         (Printf.sprintf "Source exceeds the %d-byte limit" max_source_bytes))

let depth_failure pos end_pos =
  {
    kind = Syntactic;
    message =
      Printf.sprintf "Nesting deeper than %d levels is not accepted" max_depth;
    pos = Some pos;
    end_pos = Some end_pos;
    where = None;
    span = None;
    source_line = None;
  }

(* Some src = the position at which [src] first exceeds [max_depth]. *)
let too_deep (tokens : Notation.token array) : Source.range option =
  let depth = ref 0 in
  let over = ref None in
  Array.iter
    (fun (t : Notation.token) ->
      match t.kind with
      | Notation.Tok_lparen | Notation.Tok_lbracket ->
          incr depth;
          if !depth > max_depth && !over = None then
            over :=
              Some (Source.range ~start_offset:t.pos ~end_offset:t.end_pos)
      | Notation.Tok_rparen | Notation.Tok_rbracket -> decr depth
      | _ -> ())
    tokens;
  !over

let unexpected ?where e =
  {
    kind = Internal;
    message = Printexc.to_string e;
    pos = None;
    end_pos = None;
    where;
    span = None;
    source_line = None;
  }

let locate source source_range failure =
  match failure.kind with
  | Internal -> failure
  | _ ->
      let span = Source.span_of_range source source_range in
      {
        failure with
        span = Some span;
        source_line = Source.line_text source span.Source.start_pos.line;
      }

(* Run a post-parse engine call, mapping its refusal — and anything it should
   not raise, Stack_overflow included — onto a structured failure. A
   Parse_error reaching here would itself be a surprise (nothing downstream of
   the parser produces one), so it lands in Internal with the rest. *)
let guard ?where (f : unit -> 'a) : ('a, failure) result =
  match f () with
  | v -> Ok v
  | exception Infer.Engine_error message ->
      Error
        {
          kind = Outside_fragment;
          message;
          pos = None;
          end_pos = None;
          where;
          span = None;
          source_line = None;
        }
  | exception e -> Error (unexpected ?where e)

(* ── Entry points ───────────────────────────────────────────────────────────
   Lexical and syntactic refusals are the same OCaml exception, so the class
   comes from *where* it was raised, never from the message text: the tokenizer
   runs first on its own, and a failure there is lexical by construction.
   The accepted token array is then passed directly to the parser: lexical and
   syntactic phases remain distinct without decoding and allocating the source
   twice. *)

let parse_with ?where parser (src : string) =
  match source_too_large ?where src with
  | Some failure -> Error failure
  | None -> (
      match Notation.tokenize src with
      | exception Notation.Parse_error { message; pos; end_pos } ->
          Error
            (locate src
               (Source.range ~start_offset:pos ~end_offset:end_pos)
               {
                 kind = Lexical;
                 message;
                 pos = Some pos;
                 end_pos = Some end_pos;
                 where;
                 span = None;
                 source_line = None;
               })
      | exception e -> Error (unexpected ?where e)
      | tokens -> (
          match too_deep tokens with
          | Some range ->
              Error
                (locate src range
                   {
                     (depth_failure range.Source.start_offset
                        range.Source.end_offset)
                     with
                     where;
                   })
          | None -> (
              match parser tokens with
              | parsed -> Ok parsed
              | exception Notation.Parse_error { message; pos; end_pos } ->
                  Error
                    (locate src
                       (Source.range ~start_offset:pos ~end_offset:end_pos)
                       {
                         kind = Syntactic;
                         message;
                         pos = Some pos;
                         end_pos = Some end_pos;
                         where;
                         span = None;
                         source_line = None;
                       })
              | exception e -> Error (unexpected ?where e))))

let parse_located ?where (src : string) :
    (Ast.prop Source.located, failure) result =
  parse_with ?where Notation.parse_proposition_located_tokens src

let parse ?where (src : string) : (Ast.prop, failure) result =
  Result.map
    (fun (located : Ast.prop Source.located) -> located.value)
    (parse_located ?where src)

let parse_term_located ?where (src : string) :
    (Ast.term Source.located, failure) result =
  parse_with ?where Notation.parse_term_located_tokens src

let parse_term ?where (src : string) : (Ast.term, failure) result =
  Result.map
    (fun (located : Ast.term Source.located) -> located.value)
    (parse_term_located ?where src)

let parse_all_located (label : string) (sources : string list) :
    (Ast.prop Source.located list, failure) result =
  let rec go i acc = function
    | [] -> Ok (List.rev acc)
    | src :: rest -> (
        match parse_located ~where:(Printf.sprintf "%s %d" label i) src with
        | Error e -> Error e
        | Ok p -> go (i + 1) (p :: acc) rest)
  in
  go 1 [] sources

let parse_all (label : string) (sources : string list) :
    (Ast.prop list, failure) result =
  Result.map
    (List.map (fun (located : Ast.prop Source.located) -> located.value))
    (parse_all_located label sources)

(* The guarded program-loading path. Cap the aggregate, physical-line count,
   line size, and parsed proposition count around [Program.parse_program].
   Depth is checked per line before recursive parsing, on the same
   comment-stripped text the program parser reads. *)
let parse_program (src : string) : (Program.parsed_program, failure) result =
  if String.length src > max_program_bytes then
    Error
      (resource_failure
         (Printf.sprintf "Program source exceeds the %d-byte limit"
            max_program_bytes))
  else
    let line_count =
      String.fold_left
        (fun count char -> if char = '\n' then count + 1 else count)
        1 src
    in
    if line_count > max_program_lines then
      Error
        (resource_failure
           (Printf.sprintf "Program exceeds the %d-line limit" max_program_lines))
    else
      let line_failure (n, line_offset, raw) =
        let where = Printf.sprintf "line %d" n in
        if String.length raw > max_source_bytes then
          let line_range =
            Source.range ~start_offset:0
              ~end_offset:(Source.codepoint_length raw)
          in
          Some
            {
              (resource_failure ~where
                 (Printf.sprintf "Program line exceeds the %d-byte limit"
                    max_source_bytes))
              with
              span =
                Some
                  (Source.span_on_line ~line:n ~line_offset ~column_offset:0
                     line_range);
              source_line = Some raw;
            }
        else
          let code, code_start = Program.line_code_with_start raw in
          match Notation.tokenize code with
          (* a tokenizer refusal is that line's own recorded error — the
             program parser reports it in [errors] *)
          | exception _ -> None
          | tokens ->
              Option.map
                (fun range ->
                  {
                    (depth_failure range.Source.start_offset
                       range.Source.end_offset)
                    with
                    where = Some where;
                    span =
                      Some
                        (Source.span_on_line ~line:n ~line_offset
                           ~column_offset:code_start range);
                    source_line = Some raw;
                  })
                (too_deep tokens)
      in
      let rec number line line_offset acc = function
        | [] -> List.rev acc
        | raw :: rest ->
            number (line + 1)
              (line_offset + Source.codepoint_length raw + 1)
              ((line, line_offset, raw) :: acc)
              rest
      in
      let numbered = number 1 0 [] (String.split_on_char '\n' src) in
      match List.find_map line_failure numbered with
      | Some f -> Error f
      | None -> (
          match guard (fun () -> Program.parse_program src) with
          | Error _ as error -> error
          | Ok program
            when List.length program.propositions > max_program_propositions ->
              Error
                (resource_failure ~where:"program"
                   (Printf.sprintf "Program exceeds the %d-proposition limit"
                      max_program_propositions))
          | Ok program -> Ok program)

(* Parse every input, then decide. A refusal from the inference layer —
   including the guards that fire on propositions the parser accepted — comes
   back as Outside_fragment, never as an exception and never as a verdict.

   Fragment validation is run per proposition, under that proposition's own
   label, before the decision: check_argument validates its whole input at the
   head, so without this pass a refusal would be reported against the argument
   when a single premise is at fault. Every failure names an input; a genuine
   whole-argument refusal (levels with no categorical route, an inconsistency
   check on a non-categorical set) names "argument". *)
let check ~(premises : string list) ~(conclusion : string) :
    (Decide.result, failure) result =
  let argument_budget () =
    let rec add_premises count remaining = function
      | [] ->
          if String.length conclusion > remaining then
            Error
              (resource_failure ~where:"argument"
                 (Printf.sprintf "Argument source exceeds the %d-byte limit"
                    max_argument_bytes))
          else Ok ()
      | source :: rest ->
          if count >= max_argument_premises then
            Error
              (resource_failure ~where:"argument"
                 (Printf.sprintf "Argument exceeds the %d-premise limit"
                    max_argument_premises))
          else
            let size = String.length source in
            if size > remaining then
              Error
                (resource_failure ~where:"argument"
                   (Printf.sprintf "Argument source exceeds the %d-byte limit"
                      max_argument_bytes))
            else add_premises (count + 1) (remaining - size) rest
    in
    add_premises 0 max_argument_bytes premises
  in
  let validate where source (located : Ast.prop Source.located) =
    match guard ~where (fun () -> Infer.validate_prop located.value) with
    | Error ({ kind = Internal; _ } as failure) -> Error failure
    | Error failure -> Error (locate source located.range failure)
    | Ok () -> Ok ()
  in
  let rec validate_premises i sources located =
    match (sources, located) with
    | [], [] -> Ok ()
    | source :: source_rest, proposition :: proposition_rest -> (
        match validate (Printf.sprintf "premise %d" i) source proposition with
        | Error e -> Error e
        | Ok () -> validate_premises (i + 1) source_rest proposition_rest)
    | _ -> Error (unexpected ~where:"argument" (Failure "premise mismatch"))
  in
  match argument_budget () with
  | Error e -> Error e
  | Ok () -> (
      match parse_all_located "premise" premises with
      | Error e -> Error e
      | Ok located_premises -> (
          match parse_located ~where:"conclusion" conclusion with
          | Error e -> Error e
          | Ok located_conclusion -> (
              match validate_premises 1 premises located_premises with
              | Error e -> Error e
              | Ok () -> (
                  match validate "conclusion" conclusion located_conclusion with
                  | Error e -> Error e
                  | Ok () ->
                      let premises =
                        List.map
                          (fun (located : Ast.prop Source.located) ->
                            located.value)
                          located_premises
                      and conclusion = located_conclusion.value in
                      guard ~where:"argument" (fun () ->
                          Decide.check_argument premises conclusion)))))
