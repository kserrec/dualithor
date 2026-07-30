(* Client for engine/shim.js: spawn the frozen JS reference engine behind a
   JSON-lines pipe and call its functions. One long-lived Node process per
   test run; requests are strictly sequential (write a line, read a line). *)

type t = { to_shim : out_channel; from_shim : in_channel }
type shim_error = { name : string; message : string; pos : int option }

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
