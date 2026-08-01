(* Client for engine/shim.js: spawn the frozen JS reference engine behind a
   JSON-lines pipe and call its functions. One long-lived Node process per
   test run; requests are strictly sequential (write a line, read a line). *)

type t = { to_shim : out_channel; from_shim : in_channel }
type shim_error = { name : string; message : string; pos : int option }

(* Under `dune test` the cwd is _build/default/test (the deps put engine/ one
   level up); under `dune exec` from the root it is the source tree. *)
let default_path () =
  if Sys.file_exists "../engine/shim.js" then "../engine/shim.js"
  else "engine/shim.js"

let start ~shim_path =
  let from_shim, to_shim =
    Unix.open_process ("node " ^ Filename.quote shim_path)
  in
  { to_shim; from_shim }

let stop t = ignore (Unix.close_process (t.from_shim, t.to_shim))

let call t (fn : string) (args : Yojson.Safe.t list) :
    (Yojson.Safe.t, shim_error) result =
  let req = `Assoc [ ("fn", `String fn); ("args", `List args) ] in
  output_string t.to_shim (Yojson.Safe.to_string req);
  output_char t.to_shim '\n';
  flush t.to_shim;
  let line =
    try input_line t.from_shim
    with End_of_file -> failwith ("shim died during call to " ^ fn)
  in
  match Yojson.Safe.from_string line with
  | `Assoc [ ("ok", v) ] -> Ok v
  | `Assoc [ ("error", `Assoc fields) ] ->
      let str k =
        match List.assoc_opt k fields with Some (`String s) -> s | _ -> ""
      in
      let pos =
        match List.assoc_opt "pos" fields with
        | Some (`Int n) -> Some n
        | _ -> None
      in
      Error { name = str "name"; message = str "message"; pos }
  | other -> failwith ("shim: unexpected response " ^ Yojson.Safe.to_string other)

(* Compare an OCaml-side value against the reference's answer for the same
   call: None when they agree, Some description when they do not. The
   differential suites are built out of this. *)
let expect_json t (fn : string) (args : Yojson.Safe.t list)
    (expected : Yojson.Safe.t) : string option =
  match call t fn args with
  | Ok js when Ast_json.json_equal expected js -> None
  | Ok js ->
      Some
        (Printf.sprintf "%s mismatch: ocaml %s vs js %s" fn
           (Yojson.Safe.to_string expected)
           (Yojson.Safe.to_string js))
  | Error e ->
      Some (Printf.sprintf "%s: js errored %s (%s)" fn e.name e.message)
