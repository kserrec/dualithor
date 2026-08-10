(** Total, bounded loading of one regular UTF-8 [.tfl] source file. *)

type failure_kind =
  | File
  | Lexical
  | Syntactic
  | Outside_fragment
  | Resource_limit
  | Internal

type diagnostic = {
  kind : failure_kind;
  message : string;
  path : string;
  line : int option;
  column : int option;
}

type statement = {
  line : int;
  column : int;
  source : string;
  proposition : Runtime.proposition;
}

type loaded

val kind_name : failure_kind -> string
val load : string -> (loaded, diagnostic list) result
val path : loaded -> string
val runtime : loaded -> Runtime.program
val statements : loaded -> statement list

(** Synchronization hooks for deterministic filesystem-boundary regression
    tests. This module is not a stable production API. *)
module For_testing : sig
  val load :
    ?after_stat:(unit -> unit) ->
    ?after_open:(Unix.file_descr -> unit) ->
    string ->
    (loaded, diagnostic list) result
end
