(* The total public surface (PLAN 1.14). Everything downstream of the
   translation layer calls the engine through here and nowhere else: these
   functions never raise, always return a structured failure, and never run
   unboundedly. docs/engine-surface.md is the specification, including the full
   inventory of what the engine raises and which class each refusal falls in. *)

type failure_kind =
  | Lexical (* a character or token the notation has no reading for *)
  | Syntactic (* legal tokens that do not form a proposition *)
  | Outside_fragment (* a well-formed AST the inference layer refuses *)
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
  where : string option; (* which input, for the multi-input entry points *)
}

let kind_name = function
  | Lexical -> "lexical"
  | Syntactic -> "syntactic"
  | Outside_fragment -> "outside_fragment"
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
  { kind = Resource_limit; message; pos = None; where }

let source_too_large ?where src =
  if String.length src <= max_source_bytes then None
  else
    Some
      (resource_failure ?where
         (Printf.sprintf "Source exceeds the %d-byte limit" max_source_bytes))

let depth_failure pos =
  {
    kind = Syntactic;
    message =
      Printf.sprintf "Nesting deeper than %d levels is not accepted" max_depth;
    pos = Some pos;
    where = None;
  }

(* Some src = the position at which [src] first exceeds [max_depth]. *)
let too_deep (tokens : Notation.token array) : int option =
  let depth = ref 0 in
  let over = ref None in
  Array.iter
    (fun (t : Notation.token) ->
      match t.kind with
      | Notation.Tok_lparen | Notation.Tok_lbracket ->
          incr depth;
          if !depth > max_depth && !over = None then over := Some t.pos
      | Notation.Tok_rparen | Notation.Tok_rbracket -> decr depth
      | _ -> ())
    tokens;
  !over

let unexpected ?where e =
  { kind = Internal; message = Printexc.to_string e; pos = None; where }

(* Run a post-parse engine call, mapping its refusal — and anything it should
   not raise, Stack_overflow included — onto a structured failure. A
   Parse_error reaching here would itself be a surprise (nothing downstream of
   the parser produces one), so it lands in Internal with the rest. *)
let guard ?where (f : unit -> 'a) : ('a, failure) result =
  match f () with
  | v -> Ok v
  | exception Infer.Engine_error message ->
      Error { kind = Outside_fragment; message; pos = None; where }
  | exception e -> Error (unexpected ?where e)

(* ── Entry points ───────────────────────────────────────────────────────────
   Lexical and syntactic refusals are the same OCaml exception, so the class
   comes from *where* it was raised, never from the message text: the tokenizer
   runs first on its own, and a failure there is lexical by construction.
   The accepted token array is then passed directly to the parser: lexical and
   syntactic phases remain distinct without decoding and allocating the source
   twice. *)

let parse ?where (src : string) : (Ast.prop, failure) result =
  match source_too_large ?where src with
  | Some failure -> Error failure
  | None -> (
      match Notation.tokenize src with
      | exception Notation.Parse_error { message; pos } ->
          Error { kind = Lexical; message; pos = Some pos; where }
      | exception e -> Error (unexpected ?where e)
      | tokens -> (
          match too_deep tokens with
          | Some pos -> Error { (depth_failure pos) with where }
          | None -> (
              match Notation.parse_proposition_tokens tokens with
              | p -> Ok p
              | exception Notation.Parse_error { message; pos } ->
                  Error { kind = Syntactic; message; pos = Some pos; where }
              | exception e -> Error (unexpected ?where e))))

let parse_all (label : string) (sources : string list) :
    (Ast.prop list, failure) result =
  let rec go i acc = function
    | [] -> Ok (List.rev acc)
    | src :: rest -> (
        match parse ~where:(Printf.sprintf "%s %d" label i) src with
        | Error e -> Error e
        | Ok p -> go (i + 1) (p :: acc) rest)
  in
  go 1 [] sources

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
           (Printf.sprintf "Program exceeds the %d-line limit"
              max_program_lines))
    else
      let line_failure (n, raw) =
        let where = Printf.sprintf "line %d" n in
        if String.length raw > max_source_bytes then
          Some
            (resource_failure ~where
               (Printf.sprintf "Program line exceeds the %d-byte limit"
                  max_source_bytes))
        else
          match Notation.tokenize (Program.line_code raw) with
          (* a tokenizer refusal is that line's own recorded error — the
             program parser reports it in [errors] *)
          | exception _ -> None
          | tokens ->
              Option.map
                (fun pos -> { (depth_failure pos) with where = Some where })
                (too_deep tokens)
      in
      let numbered =
        List.mapi (fun i raw -> (i + 1, raw)) (String.split_on_char '\n' src)
      in
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
  let validate where p = guard ~where (fun () -> Infer.validate_prop p) in
  let rec validate_premises i = function
    | [] -> Ok ()
    | p :: rest -> (
        match validate (Printf.sprintf "premise %d" i) p with
        | Error e -> Error e
        | Ok () -> validate_premises (i + 1) rest)
  in
  match argument_budget () with
  | Error e -> Error e
  | Ok () -> (
      match parse_all "premise" premises with
      | Error e -> Error e
      | Ok premises -> (
          match parse ~where:"conclusion" conclusion with
          | Error e -> Error e
          | Ok conclusion -> (
              match validate_premises 1 premises with
              | Error e -> Error e
              | Ok () -> (
                  match validate "conclusion" conclusion with
                  | Error e -> Error e
                  | Ok () ->
                      guard ~where:"argument" (fun () ->
                          Decide.check_argument premises conclusion)))))
