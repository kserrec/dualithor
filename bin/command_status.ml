type t =
  | Success
  | Non_entailment
  | Input_failure
  | Incomplete_search
  | Internal_failure

let exit_code = function
  | Success -> 0
  | Non_entailment -> 1
  | Input_failure -> 2
  | Incomplete_search -> 3
  | Internal_failure -> 4

let name = function
  | Success -> "success"
  | Non_entailment -> "logical-non-entailment"
  | Input_failure -> "input-failure"
  | Incomplete_search -> "incomplete-search"
  | Internal_failure -> "internal-failure"

type unexpected_failure = { status : t; message : string }

let unexpected_failure error =
  { status = Internal_failure; message = Printexc.to_string error }

let protect run =
  match run () with
  | value -> Ok value
  | exception error -> Error (unexpected_failure error)
