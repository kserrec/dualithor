(* Loader for the gitignored [.env] at the repo root: [KEY=VALUE] lines, [#]
   comments, optional single or double quotes around the value. The process
   environment always wins, so an exported key is never shadowed by a stale
   file. *)

let unquote s =
  let n = String.length s in
  if
    n >= 2
    && ((s.[0] = '"' && s.[n - 1] = '"') || (s.[0] = '\'' && s.[n - 1] = '\''))
  then String.sub s 1 (n - 2)
  else s

let parse_line line =
  let line = String.trim line in
  if line = "" || line.[0] = '#' then None
  else
    match String.index_opt line '=' with
    | None -> None
    | Some i ->
        let key = String.trim (String.sub line 0 i) in
        let value =
          unquote
            (String.trim (String.sub line (i + 1) (String.length line - i - 1)))
        in
        if key = "" then None else Some (key, value)

(* Missing or unreadable file reads as no bindings, not an error: a machine
   with the key exported and no [.env] is a supported setup. *)
let load ?(path = ".env") () =
  match open_in path with
  | exception Sys_error _ -> []
  | ic ->
      Fun.protect
        ~finally:(fun () -> close_in_noerr ic)
        (fun () ->
          let rec go acc =
            match input_line ic with
            | exception End_of_file -> List.rev acc
            | line -> (
                match parse_line line with
                | Some kv -> go (kv :: acc)
                | None -> go acc)
          in
          go [])

let get ?(path = ".env") name =
  match Sys.getenv_opt name with
  | Some v -> Some v
  | None -> List.assoc_opt name (load ~path ())
