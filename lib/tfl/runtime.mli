(** Total production runtime for complete TFL programs. *)

type program
type proposition = { tfl : string; canonical : string; english : string }
type term = { tfl : string; canonical : string; english : string }
type statement = { line : int; source : string; proposition : proposition }

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

val method_name : operation_method -> string
val incompleteness_name : incompleteness -> string
val query_verdict_name : query_verdict -> string
val consistency_status_name : consistency_status -> string
val compile : string -> (program, Safe.failure list) result
val statements : program -> statement list
val query : program -> string -> (query_result, Safe.failure) result
val describe : program -> string -> (term_result, Safe.failure) result
val check_consistency : program -> (consistency_result, Safe.failure) result

val equivalent :
  left:string -> right:string -> (equivalence_result, Safe.failure) result
