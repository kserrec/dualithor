type proposition = { tfl : string; canonical : string; english : string }
type term = { tfl : string; canonical : string; english : string }

type statement = {
  line : int;
  source : string;
  source_line : string;
  span : Source.span;
  proposition : proposition;
}

type program = {
  compiled_props : Ast.prop list;
  compiled_statements : statement list;
}

type operation_method =
  | PZ
  | Derivation
  | Indirect
  | Numerical
  | Bounded_saturation
  | Refutation_search
  | DNF
  | Rewrite

type incompleteness =
  | Bounded_search
  | Numerical_rule_set
  | Bounded_term_saturation
  | Bounded_refutation
  | Numerical_consistency_unavailable
  | Bounded_rewrite

type completeness = { complete : bool; reason : incompleteness option }

type proof_line = {
  number : int;
  tfl : string;
  english : string;
  rule : string;
  parents : int list;
}

type proof = { lines : proof_line list; explanation : string option }

type cancellation = {
  particular : proposition;
  universals : (proposition * int) list;
}

type certificate = {
  point : string list;
  clash : (string * string) option;
  cancellation : cancellation option;
}

type numerical_decision = {
  valid : bool;
  sum : bool;
  particular : bool;
  level : bool;
  carried_level : int;
  conclusion_level : int;
  particular_premises : int;
  particular_conclusions : int;
}

type evidence =
  | Proof of proof
  | Closure_certificate of certificate
  | Numerical_decision of numerical_decision
  | Rewrite_path of string list
  | Truth_table of { atoms : string list; rows : string list }

type query_verdict = Yes | No | Unknown
type query_support = { proposition : proposition; evidence : evidence list }

type query_result = {
  query : proposition;
  verdict : query_verdict;
  method_ : operation_method;
  completeness : completeness;
  support : query_support option;
}

type term_answer = { proposition : proposition; support : proof }

type term_result = {
  term : term;
  answers : term_answer list;
  method_ : operation_method;
  completeness : completeness;
}

type consistency_status = Consistent | Inconsistent | Undetermined

type consistency_result = {
  status : consistency_status;
  method_ : operation_method;
  completeness : completeness;
  evidence : evidence list;
}

type equivalence_result = {
  left : proposition;
  right : proposition;
  equivalent : bool;
  method_ : operation_method;
  completeness : completeness;
  evidence : evidence list;
}

let method_name = function
  | PZ -> "PZ"
  | Derivation -> "derivation"
  | Indirect -> "indirect"
  | Numerical -> "numerical"
  | Bounded_saturation -> "bounded-saturation"
  | Refutation_search -> "refutation-search"
  | DNF -> "dnf"
  | Rewrite -> "rewrite"

let incompleteness_name = function
  | Bounded_search -> "bounded-search"
  | Numerical_rule_set -> "numerical-rule-set"
  | Bounded_term_saturation -> "bounded-term-saturation"
  | Bounded_refutation -> "bounded-refutation"
  | Numerical_consistency_unavailable -> "numerical-consistency-unavailable"
  | Bounded_rewrite -> "bounded-rewrite"

let query_verdict_name = function
  | Yes -> "yes"
  | No -> "no"
  | Unknown -> "unknown"

let consistency_status_name = function
  | Consistent -> "consistent"
  | Inconsistent -> "inconsistent"
  | Undetermined -> "undetermined"

let complete = { complete = true; reason = None }
let incomplete reason = { complete = false; reason = Some reason }

let proposition_of_ast (p : Ast.prop) : proposition =
  {
    tfl = Notation.print_proposition p;
    canonical = Notation.print_proposition (Infer.canon_prop p);
    english = Render.read_prop p;
  }

let term_of_ast (t : Ast.term) : term =
  {
    tfl = Notation.print_term t;
    canonical = Notation.print_term (Infer.canon_term t);
    english = Render.read_term t;
  }

let proof_line_of_internal (line : Derive.line) : proof_line =
  {
    number = line.n;
    tfl = line.text;
    english =
      (match line.l_prop with
      | Some prop -> Render.read_prop prop
      | None -> "which is impossible");
    rule = line.rule;
    parents = line.parents;
  }

let proof_of_internal (proof : Derive.proof) : proof =
  {
    lines = List.map proof_line_of_internal proof.lines;
    explanation = Render.explain_proof proof;
  }

let cancellation_of_internal (c : Decide.cancellation) : cancellation =
  {
    particular = proposition_of_ast c.particular;
    universals =
      List.map
        (fun (prop, times) -> (proposition_of_ast prop, times))
        c.universals;
  }

let certificate_of_internal (c : Decide.certificate) : certificate =
  {
    point = c.point;
    clash = c.clash;
    cancellation = Option.map cancellation_of_internal c.cancellation;
  }

let numerical_of_internal (d : Decide.numerical_decision) : numerical_decision =
  {
    valid = d.n_valid;
    sum = d.sum;
    particular = d.n_particular;
    level = d.level_ok;
    carried_level = d.carried_level;
    conclusion_level = d.conclusion_level;
    particular_premises = d.particular_premises;
    particular_conclusions = d.particular_conclusions;
  }

let optional_evidence convert = function
  | None -> []
  | Some value -> [ convert value ]

let evidence_of_decision (result : Decide.result) : evidence list =
  optional_evidence
    (fun certificate ->
      Closure_certificate (certificate_of_internal certificate))
    result.certificate
  @ optional_evidence
      (fun proof -> Proof (proof_of_internal proof))
      result.proof
  @ optional_evidence
      (fun decision -> Numerical_decision (numerical_of_internal decision))
      result.decision

let failure_for_program_error (error : Program.program_error) =
  let where = Printf.sprintf "line %d" error.err_line in
  {
    Safe.kind =
      (match error.err_kind with
      | Program.Program_lexical -> Safe.Lexical
      | Program.Program_syntactic -> Safe.Syntactic);
    message = error.err_message;
    pos = Some error.err_pos;
    end_pos = Some error.err_end_pos;
    where = Some where;
    span = Some error.err_span;
    source_line = Some error.err_source_line;
  }

let validation_failure (entry : Program.program_entry) =
  match
    Safe.guard ~where:(Printf.sprintf "line %d" entry.line) (fun () ->
        Infer.validate_prop entry.prop)
  with
  | Ok () -> None
  | Error ({ kind = Safe.Internal; _ } as failure) -> Some (entry.line, failure)
  | Error failure ->
      Some
        ( entry.line,
          {
            failure with
            span = Some entry.span;
            source_line = Some entry.source_line;
          } )

let merge_failures left right =
  let rec merge acc left right =
    match (left, right) with
    | [], remaining | remaining, [] -> List.rev_append acc remaining
    | ( ((left_line, _) as left_failure) :: left_rest,
        ((right_line, _) as right_failure) :: right_rest ) ->
        if left_line <= right_line then
          merge (left_failure :: acc) left_rest right
        else merge (right_failure :: acc) left right_rest
  in
  merge [] left right

let statement_of_entry (entry : Program.program_entry) : statement =
  {
    line = entry.line;
    source = entry.text;
    source_line = entry.source_line;
    span = entry.span;
    proposition = proposition_of_ast entry.prop;
  }

let program_of_entries entries =
  let compiled_statements = List.map statement_of_entry entries in
  {
    compiled_props =
      List.map (fun (entry : Program.program_entry) -> entry.prop) entries;
    compiled_statements;
  }

let compile_inner source =
  match Safe.parse_program source with
  | Error failure -> Error [ failure ]
  | Ok parsed -> (
      let parse_failures =
        List.map
          (fun (error : Program.program_error) ->
            (error.err_line, failure_for_program_error error))
          parsed.errors
      in
      let validation_failures =
        List.filter_map validation_failure parsed.propositions
      in
      let failures = merge_failures parse_failures validation_failures in
      if failures <> [] then Error (List.map snd failures)
      else
        match
          Safe.guard ~where:"program" (fun () ->
              program_of_entries parsed.propositions)
        with
        | Ok program -> Ok program
        | Error failure -> Error [ failure ])

let compile source =
  match compile_inner source with
  | result -> result
  | exception error -> Error [ Safe.unexpected ~where:"program" error ]

let statements program = program.compiled_statements

let guard_input ~where ~source ~range run =
  match Safe.guard ~where run with
  | Error ({ kind = Safe.Internal; _ } as failure) -> Error failure
  | Error failure -> Error (Safe.locate source range failure)
  | Ok result -> Ok result

let with_located_input ~where ~source parser run =
  match parser ?where:(Some where) source with
  | Error failure -> Error failure
  | Ok located ->
      guard_input ~where ~source ~range:located.Source.range (fun () ->
          run located.value)

let method_of_decision = function
  | Decide.PZ -> PZ
  | Decide.Derivation -> Derivation
  | Decide.Indirect -> Indirect
  | Decide.Numerical -> Numerical

let query_method compiled_props proposition (result : Program.prop_query) =
  match result.support with
  | Some support -> method_of_decision support.meth
  | None ->
      if List.exists Decide.has_level (proposition :: compiled_props) then
        Numerical
      else if
        Decide.is_atomic_categorical
          (Infer.contradictory proposition :: compiled_props)
      then PZ
      else Derivation

let query_completeness = function
  | PZ -> complete
  | Numerical -> incomplete Numerical_rule_set
  | Derivation | Indirect -> incomplete Bounded_search
  | Bounded_saturation | Refutation_search | DNF | Rewrite -> assert false

let query_verdict_of_internal = function
  | Program.Q_yes -> Yes
  | Program.Q_no -> No
  | Program.Q_unknown -> Unknown

let query_support_of_decision proposition verdict decision : query_support =
  let supported =
    match verdict with
    | Yes -> proposition
    | No -> Infer.contradictory proposition
    | Unknown -> assert false
  in
  {
    proposition = proposition_of_ast supported;
    evidence = evidence_of_decision decision;
  }

let query program source =
  with_located_input ~where:"query" ~source Safe.parse_located
    (fun proposition ->
      let result = Program.query_prop program.compiled_props proposition in
      let method_ = query_method program.compiled_props proposition result in
      let verdict = query_verdict_of_internal result.q_verdict in
      let support =
        Option.map
          (query_support_of_decision proposition verdict)
          result.support
      in
      {
        query = proposition_of_ast proposition;
        verdict;
        method_;
        completeness = query_completeness method_;
        support;
      })

let term_answer_of_internal (answer : Program.term_answer) : term_answer =
  {
    proposition = proposition_of_ast answer.answer_prop;
    support = proof_of_internal answer.answer_proof;
  }

let describe program source =
  with_located_input ~where:"term" ~source Safe.parse_term_located (fun term ->
      let answers =
        Program.query_term_detailed program.compiled_props term
        |> List.map term_answer_of_internal
      in
      {
        term = term_of_ast term;
        answers;
        method_ = Bounded_saturation;
        completeness = incomplete Bounded_term_saturation;
      })

let consistency_status_of_internal (result : Program.consistency) =
  if not result.consistent then Inconsistent
  else if result.complete then Consistent
  else Undetermined

let consistency_profile (result : Program.consistency) =
  if result.numerical then
    (Numerical, incomplete Numerical_consistency_unavailable)
  else if result.complete then (PZ, complete)
  else (Refutation_search, incomplete Bounded_refutation)

let consistency_evidence (result : Program.consistency) =
  optional_evidence
    (fun certificate ->
      Closure_certificate (certificate_of_internal certificate))
    result.certificate
  @ optional_evidence
      (fun proof -> Proof (proof_of_internal proof))
      result.c_proof

let check_consistency program =
  Safe.guard ~where:"program" (fun () ->
      let result = Program.check_program_consistency program.compiled_props in
      let method_, completeness = consistency_profile result in
      {
        status = consistency_status_of_internal result;
        method_;
        completeness;
        evidence = consistency_evidence result;
      })

let equivalence_profile (result : Program.equivalence_decision) =
  if result.e_method = "dnf" then
    ( DNF,
      complete,
      [
        Truth_table
          {
            atoms = Option.value ~default:[] result.atoms;
            rows = Option.value ~default:[] result.dnf;
          };
      ] )
  else
    ( Rewrite,
      incomplete Bounded_rewrite,
      optional_evidence (fun path -> Rewrite_path path) result.e_path )

let equivalent ~left ~right =
  match Safe.parse_located ~where:"left" left with
  | Error failure -> Error failure
  | Ok left_located -> (
      let left_prop = left_located.value in
      match Safe.parse_located ~where:"right" right with
      | Error failure -> Error failure
      | Ok right_located -> (
          let right_prop = right_located.value in
          match
            guard_input ~where:"left" ~source:left ~range:left_located.range
              (fun () -> Infer.validate_prop left_prop)
          with
          | Error failure -> Error failure
          | Ok () -> (
              match
                guard_input ~where:"right" ~source:right
                  ~range:right_located.range (fun () ->
                    Infer.validate_prop right_prop)
              with
              | Error failure -> Error failure
              | Ok () ->
                  Safe.guard ~where:"equivalence" (fun () ->
                      let result =
                        Program.decide_equivalence left_prop right_prop
                      in
                      let method_, completeness, evidence =
                        equivalence_profile result
                      in
                      {
                        left = proposition_of_ast left_prop;
                        right = proposition_of_ast right_prop;
                        equivalent = result.equivalent;
                        method_;
                        completeness;
                        evidence;
                      }))))
