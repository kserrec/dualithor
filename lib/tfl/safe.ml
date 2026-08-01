(* The total public surface (PLAN 1.14). Everything downstream of the
   translation layer calls the engine through here and nowhere else: these
   functions never raise, always return a structured failure, and never run
   unboundedly. docs/engine-surface.md is the specification, including the full
   inventory of what the engine raises and which class each refusal falls in. *)

type failure_kind =
  | Lexical (* a character or token the notation has no reading for *)
  | Syntactic (* legal tokens that do not form a proposition *)
  | Outside_fragment (* a well-formed AST the inference layer refuses *)
  | Internal
      (* an exception that should be unreachable. Not one of the three router
         classes: it classifies the engine, not the input, and it means a bug
         to fix rather than an escalation to make. It exists so the API can be
         total without a crash ever being reported as an expected outcome. *)

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
  | Internal -> "internal"

let describe (f : failure) : string =
  Printf.sprintf "%s%s: %s%s"
    (match f.where with Some w -> w ^ " " | None -> "")
    (kind_name f.kind) f.message
    (match f.pos with Some p -> Printf.sprintf " (at position %d)" p | None -> "")

(* ── Bounds ─────────────────────────────────────────────────────────────────
   The parser and every tree walk after it are recursive descent, so nesting
   depth is the one input dimension that can exhaust the stack (port-spec
   §16.5: the JS reference dies with a RangeError, the port would raise
   Stack_overflow). Nesting in this notation is exactly bracket nesting, so the
   depth is measurable from the token stream before any recursion happens.
   64 is far past anything a real formula reaches (three or four is typical)
   and far below the stack limit of any tree walk in the engine. *)
let max_depth = 64

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
   Tokenizing twice costs one linear pass and keeps a message edit from
   silently reclassifying anything. *)

let parse ?where (src : string) : (Ast.prop, failure) result =
  match Notation.tokenize src with
  | exception Notation.Parse_error { message; pos } ->
      Error { kind = Lexical; message; pos = Some pos; where }
  | exception e -> Error (unexpected ?where e)
  | tokens -> (
      match too_deep tokens with
      | Some pos -> Error { (depth_failure pos) with where }
      | None -> (
          match Notation.parse_proposition src with
          | p -> Ok p
          | exception Notation.Parse_error { message; pos } ->
              Error { kind = Syntactic; message; pos = Some pos; where }
          | exception e -> Error (unexpected ?where e)))

let parse_all (label : string) (sources : string list) :
    (Ast.prop list, failure) result =
  let rec go i = function
    | [] -> Ok []
    | src :: rest -> (
        match parse ~where:(Printf.sprintf "%s %d" label i) src with
        | Error e -> Error e
        | Ok p -> ( match go (i + 1) rest with Ok ps -> Ok (p :: ps) | e -> e))
  in
  go 1 sources

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
  let validate where p = guard ~where (fun () -> Infer.validate_prop p) in
  let rec validate_premises i = function
    | [] -> Ok ()
    | p :: rest -> (
        match validate (Printf.sprintf "premise %d" i) p with
        | Error e -> Error e
        | Ok () -> validate_premises (i + 1) rest)
  in
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
                      Decide.check_argument premises conclusion))))
