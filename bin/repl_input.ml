(* Optional terminal input for the human REPL.  A pipe or a terminal without
   cursor-control support stays on the bounded line reader below; capable
   terminals get a deliberately small, in-memory history editor without
   making a line-editing package part of the Dualithor runtime. *)

type read_result =
  | Line of string
  | End_of_input
  | Interrupted
  | Line_too_long
  | Display_limit

let max_line_bytes = 1_048_576
let max_history_bytes = 16 * 1_048_576
let max_editor_output_bytes = 16 * 1_048_576

type history = {
  capacity : int;
  byte_capacity : int;
  mutable bytes : int;
  mutable entries : string list;
}

type navigation = {
  mutable position : int option;
  mutable draft : string option;
}

let create_history ?(capacity = 100) ?(byte_capacity = max_history_bytes) () =
  if capacity < 1 then invalid_arg "history capacity must be positive";
  if byte_capacity < 1 then invalid_arg "history byte capacity must be positive";
  { capacity; byte_capacity; bytes = 0; entries = [] }

let create_navigation () = { position = None; draft = None }

let newest_entry = function
  | [] -> None
  | entries -> Some (List.hd (List.rev entries))

let rec trim_history history =
  if
    List.length history.entries > history.capacity
    || history.bytes > history.byte_capacity
  then
    match history.entries with
    | [] -> history.bytes <- 0
    | oldest :: rest ->
        history.entries <- rest;
        history.bytes <- history.bytes - String.length oldest;
        trim_history history

let remember history line =
  let line_bytes = String.length line in
  if
    line_bytes <= history.byte_capacity
    && String.trim line <> ""
    && newest_entry history.entries <> Some line
  then (
    let entries = history.entries @ [ line ] in
    history.entries <- entries;
    history.bytes <- history.bytes + line_bytes;
    trim_history history)

let older history navigation current =
  let count = List.length history.entries in
  if count = 0 then current
  else
    let position =
      match navigation.position with
      | None ->
          navigation.draft <- Some current;
          count - 1
      | Some position -> max 0 (position - 1)
    in
    navigation.position <- Some position;
    List.nth history.entries position

let newer history navigation current =
  match navigation.position with
  | None -> current
  | Some position ->
      let next = position + 1 in
      if next < List.length history.entries then (
        navigation.position <- Some next;
        List.nth history.entries next)
      else (
        navigation.position <- None;
        Option.value ~default:"" navigation.draft)

type input_mode = Piped | Plain_terminal | Editing_terminal

let remember_result history ~mode = function
  | Line line when mode = Editing_terminal -> remember history line
  | _ -> ()

let choose_input_mode ~json ~term ~stdin_is_terminal ~stdout_is_terminal =
  if json || not (stdin_is_terminal && stdout_is_terminal) then Piped
  else
    match term with
    | Some "" | Some "dumb" -> Plain_terminal
    | _ -> Editing_terminal

let input_mode ~json =
  let is_terminal descriptor = try Unix.isatty descriptor with _ -> false in
  choose_input_mode ~json ~term:(Sys.getenv_opt "TERM")
    ~stdin_is_terminal:(is_terminal Unix.stdin)
    ~stdout_is_terminal:(is_terminal Unix.stdout)

let read_plain_line channel =
  let buffer = Buffer.create 256 in
  let oversized = ref false in
  let received_input = ref false in
  let rec read () =
    match input_char channel with
    | '\n' ->
        if !oversized then Line_too_long else Line (Buffer.contents buffer)
    | character ->
        received_input := true;
        if !oversized then ()
        else if Buffer.length buffer < max_line_bytes then
          Buffer.add_char buffer character
        else oversized := true;
        read ()
    | exception End_of_file ->
        if !oversized then Line_too_long
        else if !received_input then Line (Buffer.contents buffer)
        else End_of_input
  in
  read ()

let previous_utf8_boundary buffer =
  let rec find byte =
    if byte <= 0 then 0
    else if Char.code (Buffer.nth buffer byte) land 0xC0 = 0x80 then
      find (byte - 1)
    else byte
  in
  let length = Buffer.length buffer in
  if length = 0 then 0 else find (length - 1)

let write text =
  output_string stdout text;
  flush stdout

type output_budget = { limit : int; mutable used : int }

exception Display_budget_exceeded

let create_output_budget ?(limit = max_editor_output_bytes) () =
  if limit < 1 then invalid_arg "editor output limit must be positive";
  { limit; used = 0 }

let reserve_output budget bytes =
  if bytes < 0 then invalid_arg "editor output size must be nonnegative";
  if bytes > budget.limit - budget.used then false
  else (
    budget.used <- budget.used + bytes;
    true)

let write_with_budget budget text =
  if reserve_output budget (String.length text) then write text
  else raise Display_budget_exceeded

let prompt_text prompt = "\0277" ^ prompt
let refresh_text ~prompt ~display line = "\0278\027[J" ^ prompt ^ display line

let refresh ~write ~prompt ~display line =
  write (refresh_text ~prompt ~display line)

exception Interrupt

let with_interrupt_handler run =
  let previous_signal =
    Sys.signal Sys.sigint (Sys.Signal_handle (fun _ -> raise Interrupt))
  in
  Fun.protect
    ~finally:(fun () -> ignore (Sys.signal Sys.sigint previous_signal))
    run

let read_byte buffer =
  let rec read () =
    match Unix.read Unix.stdin buffer 0 1 with
    | 0 -> None
    | _ -> Some (Char.code (Bytes.get buffer 0))
    | exception Unix.Unix_error (Unix.EINTR, _, _) -> read ()
  in
  read ()

let read_byte_with_timeout buffer =
  let rec ready () =
    match Unix.select [ Unix.stdin ] [] [] 0.04 with
    | [], _, _ -> None
    | _ -> read_byte buffer
    | exception Unix.Unix_error (Unix.EINTR, _, _) -> ready ()
  in
  ready ()

type escape_key = Older | Newer | Delete | Ignore

let read_escape_key buffer =
  match read_byte_with_timeout buffer with
  | Some 0x5B -> (
      match read_byte_with_timeout buffer with
      | Some 0x41 -> Older
      | Some 0x42 -> Newer
      | Some 0x33 -> (
          match read_byte_with_timeout buffer with
          | Some 0x7E -> Delete
          | _ -> Ignore)
      | _ -> Ignore)
  | _ -> Ignore

let with_raw_terminal run =
  let original = Unix.tcgetattr Unix.stdin in
  let raw =
    { original with c_icanon = false; c_echo = false; c_vmin = 1; c_vtime = 0 }
  in
  with_interrupt_handler (fun () ->
      Unix.tcsetattr Unix.stdin Unix.TCSANOW raw;
      Fun.protect
        ~finally:(fun () -> Unix.tcsetattr Unix.stdin Unix.TCSANOW original)
        run)

type echo_state = { pending : Buffer.t; mutable expected_width : int }

let create_echo_state () = { pending = Buffer.create 4; expected_width = 0 }

let flush_echo ~write ~display echo =
  if Buffer.length echo.pending > 0 then (
    write (display (Buffer.contents echo.pending));
    Buffer.clear echo.pending;
    echo.expected_width <- 0)

let clear_echo echo =
  Buffer.clear echo.pending;
  echo.expected_width <- 0

let expected_utf8_width byte =
  if byte >= 0xC2 && byte <= 0xDF then 2
  else if byte >= 0xE0 && byte <= 0xEF then 3
  else if byte >= 0xF0 && byte <= 0xF4 then 4
  else 1

let rec echo_byte ~write ~display echo byte =
  if Buffer.length echo.pending = 0 then
    if byte < 0x80 then write (display (String.make 1 (Char.chr byte)))
    else (
      Buffer.add_char echo.pending (Char.chr byte);
      echo.expected_width <- expected_utf8_width byte;
      if echo.expected_width = 1 then flush_echo ~write ~display echo)
  else if byte >= 0x80 && byte <= 0xBF then (
    Buffer.add_char echo.pending (Char.chr byte);
    if Buffer.length echo.pending = echo.expected_width then
      flush_echo ~write ~display echo)
  else (
    flush_echo ~write ~display echo;
    echo_byte ~write ~display echo byte)

type editor_buffer = {
  limit : int;
  contents : Buffer.t;
  mutable limit_exceeded : bool;
}

let create_editor_buffer ?(limit = max_line_bytes) () =
  if limit < 1 then invalid_arg "editor buffer limit must be positive";
  { limit; contents = Buffer.create 256; limit_exceeded = false }

let editor_contents editor = Buffer.contents editor.contents

let replace_editor_contents editor value =
  if String.length value > editor.limit then
    invalid_arg "replacement exceeds editor buffer limit";
  Buffer.clear editor.contents;
  Buffer.add_string editor.contents value;
  editor.limit_exceeded <- false

let append_editor_byte editor byte =
  if Buffer.length editor.contents < editor.limit then (
    Buffer.add_char editor.contents (Char.chr byte);
    true)
  else (
    editor.limit_exceeded <- true;
    false)

let erase_editor_code_point editor =
  Buffer.truncate editor.contents (previous_utf8_boundary editor.contents);
  editor.limit_exceeded <- false

let editor_result editor =
  if editor.limit_exceeded then Line_too_long else Line (editor_contents editor)

let edit_terminal_line ?(output_limit = max_editor_output_bytes) history ~prompt
    ~display =
  let output_budget = create_output_budget ~limit:output_limit () in
  let editor_write = write_with_budget output_budget in
  editor_write (prompt_text prompt);
  let byte_buffer = Bytes.create 1 in
  let line = create_editor_buffer () in
  let echo = create_echo_state () in
  let navigation = create_navigation () in
  let line_ended = ref false in
  let current_line () = editor_contents line in
  let set_line = replace_editor_contents line in
  let refresh_line () =
    clear_echo echo;
    refresh ~write:editor_write ~prompt ~display (current_line ())
  in
  let append byte =
    if append_editor_byte line byte then
      echo_byte ~write:editor_write ~display echo byte
  in
  let rec discard_line () =
    match read_byte byte_buffer with
    | None | Some (0x0A | 0x0D) -> ()
    | Some _ -> discard_line ()
  in
  let rec read () =
    match read_byte byte_buffer with
    | None ->
        line_ended := true;
        flush_echo ~write:editor_write ~display echo;
        write "\n";
        if Buffer.length line.contents = 0 then End_of_input
        else editor_result line
    | Some (0x0A | 0x0D) ->
        line_ended := true;
        flush_echo ~write:editor_write ~display echo;
        write "\n";
        editor_result line
    | Some (0x08 | 0x7F) ->
        erase_editor_code_point line;
        refresh_line ();
        read ()
    | Some 0x03 -> raise Interrupt
    | Some 0x04 when Buffer.length line.contents = 0 ->
        write "\n";
        End_of_input
    | Some 0x0C ->
        refresh_line ();
        read ()
    | Some 0x15 ->
        set_line "";
        refresh_line ();
        read ()
    | Some 0x1B ->
        (match read_escape_key byte_buffer with
        | Older -> current_line () |> older history navigation |> set_line
        | Newer -> current_line () |> newer history navigation |> set_line
        | Delete -> erase_editor_code_point line
        | Ignore -> ());
        refresh_line ();
        read ()
    | Some 0x09 ->
        append 0x20;
        read ()
    | Some byte when byte >= 0x20 ->
        append byte;
        read ()
    | Some _ -> read ()
  in
  match read () with
  | result -> result
  | exception Display_budget_exceeded ->
      if not !line_ended then discard_line ();
      write "\n";
      Display_limit

let read_terminal_line ?(terminal_scope = with_raw_terminal) ?output_limit
    history ~prompt ~display =
  terminal_scope (fun () ->
      edit_terminal_line ?output_limit history ~prompt ~display)

let default_editing_reader history ~prompt ~display =
  read_terminal_line history ~prompt ~display

let read_line ?(editing_reader = default_editing_reader) history ~mode ~prompt
    ~display =
  let result =
    try
      match mode with
      | Piped -> read_plain_line stdin
      | Plain_terminal ->
          with_interrupt_handler (fun () ->
              write prompt;
              read_plain_line stdin)
      | Editing_terminal -> editing_reader history ~prompt ~display
    with
    | Interrupt ->
        write "\n";
        Interrupted
    | Display_budget_exceeded ->
        write "\n";
        Display_limit
  in
  remember_result history ~mode result;
  result
