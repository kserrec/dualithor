(** Unicode-code-point source locations.

    All offsets and columns count Unicode code points, not UTF-8 bytes. Every
    range and span is half-open. *)

type range = { start_offset : int; end_offset : int }
type position = { codepoint_offset : int; line : int; column : int }
type span = { start_pos : position; end_pos : position }
type 'a located = { value : 'a; range : range }

val range : start_offset:int -> end_offset:int -> range
val codepoint_length : string -> int
val span_of_range : string -> range -> span

val span_on_line :
  line:int -> line_offset:int -> column_offset:int -> range -> span

val line_text : string -> int -> string option
