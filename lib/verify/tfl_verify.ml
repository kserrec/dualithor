(* The verification API (PLAN 3.1): the pipeline-facing surface over the
   engine. One call — [check ~premises ~conclusion] on plain strings — one
   total result record, and JSON in both directions.

   ── Unknown is NOT Invalid ──────────────────────────────────────────────
   [Valid] and [Contradicted] carry established support; [Invalid] is exact and
   is returned only by the complete level-0 atomic-categorical P/Z method.
   [Unknown] is different in kind: either bounded derivation found neither a
   proof nor a refutation, or the sound-but-incomplete numerical conditions did
   not establish the conclusion. The argument may still be valid. Anything
   routing on this record must treat [Unknown] as "abstain or escalate", never
   as "the argument is bad". *)

type error_class =
  | Lexical
  | Syntactic
  | Name_resolution
  | Outside_fragment
  | Incomplete_search
  | Resource_limit
  | Internal

type error_info = {
  error_class : error_class;
  message : string;
  pos : int option; (* 0-based index into the offending source *)
  end_pos : int option; (* exclusive 0-based Unicode code-point index *)
  where : string option; (* which input, e.g. "premise 2" *)
  span : Tfl.Source.span option;
  source_line : string option;
}

type verdict = Valid | Invalid | Contradicted | Unknown | Error of error_info
type meth = PZ | Derivation | Indirect | Numerical

(* One audit-trail line: the plus-minus step and its deterministic English
   gloss (PLAN 1.9). Proof-carrying verdicts list the proof; certificate and
   search-less verdicts list the argument itself (rule "premise" /
   "conclusion"), so no verdict comes back traceless. *)
type trace_line = {
  n : int; (* 1-based *)
  step : string;
  gloss : string;
  rule : string;
  parents : int list;
}

type result = {
  verdict : verdict;
  meth : meth option; (* None exactly when [verdict] is [Error] *)
  trace : trace_line list;
  explanation : string option; (* the one-sentence proof reading, if a proof *)
}

(* ── check ─────────────────────────────────────────────────────────────── *)

let of_failure (f : Tfl.Safe.failure) : error_info =
  {
    error_class =
      (match f.kind with
      | Tfl.Safe.Lexical -> Lexical
      | Tfl.Safe.Syntactic -> Syntactic
      | Tfl.Safe.Name_resolution -> Name_resolution
      | Tfl.Safe.Outside_fragment -> Outside_fragment
      | Tfl.Safe.Incomplete_search -> Incomplete_search
      | Tfl.Safe.Resource_limit -> Resource_limit
      | Tfl.Safe.Internal -> Internal);
    message = f.message;
    pos = f.pos;
    end_pos = f.end_pos;
    where = f.where;
    span = f.span;
    source_line = f.source_line;
  }

(* A proposition reads badly in English when its subject is a relational
   complex: +(Lov+Girl)+Boy glosses as "some lov some girl is boy", because
   the grammatical subject is a relation and the renderer has no
   relative-clause machinery to carry it. Conversion states the same thing
   with a plain term in subject position — "some boy lov some girl" — so the
   gloss describes that orientation instead. The *step* is never rewritten:
   the formal record stays the line the engine actually derived.

   [Relational.orientations] supplies a converse only for the I- and E-forms
   conversion is valid on (A and O come back unchanged), which is the guard
   that keeps a gloss from saying something the step does not. Levelled
   propositions are excluded here because the converse it builds carries
   level 0, which would understate a "most"/"many" step. *)
let readable_orientation (p : Tfl.Ast.prop) : Tfl.Ast.prop =
  let subject_is_relational (st : Tfl.Ast.signed_term) =
    match st.term with Tfl.Ast.Rel _ -> true | _ -> false
  in
  if
    (not (subject_is_relational p.subject))
    || p.subject.level <> 0 || p.predicate.level <> 0
  then p
  else
    Option.value ~default:p
      (List.find_opt
         (fun (o : Tfl.Ast.prop) -> not (subject_is_relational o.subject))
         (Tfl.Relational.orientations p))

let gloss_of_prop p = Tfl.Render.read_prop (readable_orientation p)

let trace_of_proof (pr : Tfl.Derive.proof) : trace_line list =
  List.map
    (fun (l : Tfl.Derive.line) ->
      {
        n = l.n;
        step = l.text;
        gloss =
          (match l.l_prop with
          | Some p -> gloss_of_prop p
          (* only the synthetic ⊥ closing line of a refutation *)
          | None -> "which is impossible");
        rule = l.rule;
        parents = l.parents;
      })
    pr.lines

(* The argument itself as numbered lines, for verdicts that carry no proof
   (P/Z, numerical, failed searches). The inputs re-parsed here were already
   accepted by [Safe.check], so failures cannot occur; totality is kept by
   skipping rather than raising. *)
let trace_of_argument (premises : string list) (conclusion : string) :
    trace_line list =
  let n = ref 0 in
  let line rule src =
    match Tfl.Safe.parse src with
    | Error _ -> None
    | Ok p ->
        incr n;
        Some
          {
            n = !n;
            step = Tfl.Notation.print_proposition p;
            gloss = gloss_of_prop p;
            rule;
            parents = [];
          }
  in
  (* Premises are numbered before the conclusion; with [@] the conclusion's
     [line] call would run first (right-to-left argument evaluation) and take
     n = 1, so the two halves are sequenced explicitly. *)
  let ps = List.filter_map (line "premise") premises in
  let c = line "conclusion" conclusion in
  ps @ Option.to_list c

let check ~(premises : string list) ~(conclusion : string) : result =
  match Tfl.Safe.check ~premises ~conclusion with
  | Error f ->
      {
        verdict = Error (of_failure f);
        meth = None;
        trace = [];
        explanation = None;
      }
  | Ok r ->
      let verdict =
        match r.verdict with
        | Tfl.Decide.Valid -> Valid
        | Tfl.Decide.Invalid -> Invalid
        | Tfl.Decide.Contradicted -> Contradicted
        | Tfl.Decide.Unknown -> Unknown
      in
      let meth =
        match r.meth with
        | Tfl.Decide.PZ -> PZ
        | Tfl.Decide.Derivation -> Derivation
        | Tfl.Decide.Indirect -> Indirect
        | Tfl.Decide.Numerical -> Numerical
      in
      let trace =
        match r.proof with
        | Some pr when pr.found && pr.lines <> [] -> trace_of_proof pr
        | _ -> trace_of_argument premises conclusion
      in
      {
        verdict;
        meth = Some meth;
        trace;
        explanation = Option.bind r.proof Tfl.Render.explain_proof;
      }

(* ── JSON, both directions ─────────────────────────────────────────────────
   [to_json] and [of_json] are inverses on every record [check] can produce
   (and on every well-formed record besides); [of_json] is total — malformed
   payloads come back as [Error msg], never an exception. *)

let class_name = function
  | Lexical -> "lexical"
  | Syntactic -> "syntactic"
  | Name_resolution -> "name_resolution"
  | Outside_fragment -> "outside_fragment"
  | Incomplete_search -> "incomplete_search"
  | Resource_limit -> "resource_limit"
  | Internal -> "internal"

let meth_name = function
  | PZ -> "PZ"
  | Derivation -> "derivation"
  | Indirect -> "indirect"
  | Numerical -> "numerical"

let opt f = function Some v -> f v | None -> `Null

let position_to_json (position : Tfl.Source.position) =
  `Assoc
    [
      ("codepoint_offset", `Int position.codepoint_offset);
      ("line", `Int position.line);
      ("column", `Int position.column);
    ]

let span_to_json (span : Tfl.Source.span) =
  `Assoc
    [
      ("start", position_to_json span.start_pos);
      ("end", position_to_json span.end_pos);
    ]

let trace_line_to_json (l : trace_line) : Yojson.Safe.t =
  `Assoc
    [
      ("n", `Int l.n);
      ("step", `String l.step);
      ("gloss", `String l.gloss);
      ("rule", `String l.rule);
      ("parents", `List (List.map (fun i -> `Int i) l.parents));
    ]

let to_json (r : result) : Yojson.Safe.t =
  let verdict =
    match r.verdict with
    | Valid -> `String "valid"
    | Invalid -> `String "invalid"
    | Contradicted -> `String "contradicted"
    | Unknown -> `String "unknown"
    | Error e ->
        `Assoc
          [
            ( "error",
              `Assoc
                [
                  ("class", `String (class_name e.error_class));
                  ("message", `String e.message);
                  ("pos", opt (fun i -> `Int i) e.pos);
                  ("end_pos", opt (fun i -> `Int i) e.end_pos);
                  ("where", opt (fun s -> `String s) e.where);
                  ("span", opt span_to_json e.span);
                  ("source_line", opt (fun s -> `String s) e.source_line);
                ] );
          ]
  in
  `Assoc
    [
      ("verdict", verdict);
      ("method", opt (fun m -> `String (meth_name m)) r.meth);
      ("trace", `List (List.map trace_line_to_json r.trace));
      ("explanation", opt (fun s -> `String s) r.explanation);
    ]

let of_json (json : Yojson.Safe.t) : (result, string) Stdlib.result =
  let open Yojson.Safe.Util in
  try
    let opt_of f j = match j with `Null -> None | j -> Some (f j) in
    let position_of_json j =
      {
        Tfl.Source.codepoint_offset = j |> member "codepoint_offset" |> to_int;
        line = j |> member "line" |> to_int;
        column = j |> member "column" |> to_int;
      }
    in
    let span_of_json j =
      {
        Tfl.Source.start_pos = j |> member "start" |> position_of_json;
        end_pos = j |> member "end" |> position_of_json;
      }
    in
    let error_class_of = function
      | "lexical" -> Lexical
      | "syntactic" -> Syntactic
      | "name_resolution" -> Name_resolution
      | "outside_fragment" -> Outside_fragment
      | "incomplete_search" -> Incomplete_search
      | "resource_limit" -> Resource_limit
      | "internal" -> Internal
      | s -> failwith ("unknown error class " ^ s)
    in
    let verdict =
      match member "verdict" json with
      | `String "valid" -> Valid
      | `String "invalid" -> Invalid
      | `String "contradicted" -> Contradicted
      | `String "unknown" -> Unknown
      | `Assoc _ as v ->
          let e = member "error" v in
          Error
            {
              error_class = error_class_of (e |> member "class" |> to_string);
              message = e |> member "message" |> to_string;
              pos = opt_of to_int (member "pos" e);
              end_pos = opt_of to_int (member "end_pos" e);
              where = opt_of to_string (member "where" e);
              span = opt_of span_of_json (member "span" e);
              source_line = opt_of to_string (member "source_line" e);
            }
      | _ -> failwith "unreadable verdict"
    in
    let meth =
      opt_of
        (fun j ->
          match to_string j with
          | "PZ" -> PZ
          | "derivation" -> Derivation
          | "indirect" -> Indirect
          | "numerical" -> Numerical
          | s -> failwith ("unknown method " ^ s))
        (member "method" json)
    in
    let trace =
      List.map
        (fun l ->
          {
            n = l |> member "n" |> to_int;
            step = l |> member "step" |> to_string;
            gloss = l |> member "gloss" |> to_string;
            rule = l |> member "rule" |> to_string;
            parents = l |> member "parents" |> to_list |> List.map to_int;
          })
        (json |> member "trace" |> to_list)
    in
    let explanation = opt_of to_string (member "explanation" json) in
    Ok { verdict; meth; trace; explanation }
  with
  | Type_error (m, _) -> Result.Error m
  | Failure m -> Result.Error m
