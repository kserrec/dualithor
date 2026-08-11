(** Source positions shared by the parser, compiler, runtime, and interfaces.

    Offsets and columns count Unicode code points, never UTF-8 bytes. Spans are
    half-open: [start_pos] is included and [end_pos] is the first position after
    the source construct. *)

type range = { start_offset : int; end_offset : int }
type position = { codepoint_offset : int; line : int; column : int }
type span = { start_pos : position; end_pos : position }
type 'a located = { value : 'a; range : range }

let range ~start_offset ~end_offset =
  let start_offset = max 0 start_offset in
  { start_offset; end_offset = max start_offset end_offset }

let decoded_width decoded = max 1 (Uchar.utf_decode_length decoded)

let codepoint_length text =
  let byte = ref 0 and count = ref 0 in
  while !byte < String.length text do
    let decoded = String.get_utf_8_uchar text !byte in
    byte := !byte + decoded_width decoded;
    incr count
  done;
  !count

let position_at text requested_offset =
  let target = max 0 requested_offset in
  let byte = ref 0 and offset = ref 0 and line = ref 1 and column = ref 1 in
  while !byte < String.length text && !offset < target do
    let decoded = String.get_utf_8_uchar text !byte in
    let code_point = Uchar.to_int (Uchar.utf_decode_uchar decoded) in
    byte := !byte + decoded_width decoded;
    incr offset;
    if code_point = 0x0A then (
      incr line;
      column := 1)
    else incr column
  done;
  { codepoint_offset = !offset; line = !line; column = !column }

let span_of_range text source_range =
  {
    start_pos = position_at text source_range.start_offset;
    end_pos = position_at text source_range.end_offset;
  }

let span_on_line ~line ~line_offset ~column_offset source_range =
  let position offset =
    {
      codepoint_offset = line_offset + column_offset + offset;
      line;
      column = column_offset + offset + 1;
    }
  in
  {
    start_pos = position source_range.start_offset;
    end_pos = position source_range.end_offset;
  }

let line_text text requested_line =
  if requested_line < 1 then None
  else
    let length = String.length text in
    let rec find_start line byte =
      if line = requested_line then Some byte
      else if byte >= length then None
      else
        match String.index_from_opt text byte '\n' with
        | None -> None
        | Some newline -> find_start (line + 1) (newline + 1)
    in
    match find_start 1 0 with
    | None -> None
    | Some start ->
        let stop =
          match String.index_from_opt text start '\n' with
          | Some newline -> newline
          | None -> length
        in
        Some (String.sub text start (stop - start))
