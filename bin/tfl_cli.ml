(* The command-line surface (PLAN 11.4, pulled earlier per the 2026-08-02
   amendment: 4.6 and 6.1 both want it).

   JSON in, JSON out, one object per line on stdin and stdout. That shape is
   chosen so the pip-installable client at release is a thin wrapper around a
   long-lived process rather than a fresh exec per call — the engine has no
   startup state worth paying for repeatedly, and a line protocol is the one
   thing every language can speak without a binding.

   **This process never crashes and never exits non-zero on bad input.** Every
   failure — malformed JSON, unknown command, missing field, unparseable
   formula — comes back as a JSON object with an "error" field. That is the
   1.14 total-API discipline (`Tfl.Safe` returns a result and never raises)
   carried out to the process boundary, and it matters because the caller is a
   script that has to distinguish "the engine says no" from "the engine fell
   over". A non-zero exit is reserved for the process being unable to run at
   all. *)

let out (j : Yojson.Safe.t) =
  print_string (Yojson.Safe.to_string j);
  print_newline ();
  flush stdout

let error ?(fields = []) msg = `Assoc (("error", `String msg) :: fields)

let member name json =
  match Yojson.Safe.Util.member name json with `Null -> None | v -> Some v

let string_field name json =
  match member name json with
  | Some (`String s) -> Ok s
  | Some _ -> Error (Printf.sprintf "field %S must be a string" name)
  | None -> Error (Printf.sprintf "missing field %S" name)

let string_list_field name json =
  match member name json with
  | Some (`List items) ->
      let rec go acc = function
        | [] -> Ok (List.rev acc)
        | `String s :: rest -> go (s :: acc) rest
        | _ -> Error (Printf.sprintf "field %S must be a list of strings" name)
      in
      go [] items
  | Some _ -> Error (Printf.sprintf "field %S must be a list of strings" name)
  (* An argument with no premises is legal input — the conclusion alone decides
     it — so an absent list reads as empty rather than as an error. *)
  | None -> Ok []

(* A parse failure carries its 1.14 taxonomy class, which is the whole point of
   this command: `outside_fragment` is the router's escalation signal (5.1) and
   the coverage statistic 4.6 measures, and it has to be distinguishable from a
   typo by the caller. *)
let failure_json (f : Tfl.Safe.failure) =
  `Assoc
    [
      ("ok", `Bool false);
      ("class", `String (Tfl.Safe.kind_name f.kind));
      ("message", `String f.message);
      ("position", match f.pos with Some p -> `Int p | None -> `Null);
    ]

let cmd_check json =
  match (string_list_field "premises" json, string_field "conclusion" json) with
  | Error m, _ | _, Error m -> error m
  | Ok premises, Ok conclusion ->
      Tfl_verify.to_json (Tfl_verify.check ~premises ~conclusion)

let cmd_parse json =
  match string_field "tfl" json with
  | Error m -> error m
  | Ok src -> (
      match Tfl.Safe.parse src with
      | Error f -> failure_json f
      | Ok p ->
          `Assoc
            [
              ("ok", `Bool true);
              (* the canonical spelling, so a caller can normalize without
                 reimplementing the printer *)
              ("tfl", `String (Tfl.Notation.print_proposition p));
              ("english", `String (Tfl.Render.read_prop p));
            ])

let cmd_render json =
  match string_field "tfl" json with
  | Error m -> error m
  | Ok src -> (
      match Tfl.Safe.parse src with
      | Error f -> failure_json f
      | Ok p ->
          `Assoc [ ("ok", `Bool true); ("english", `String (Tfl.Render.read_prop p)) ])

let commands =
  [ ("check", cmd_check); ("parse", cmd_parse); ("render", cmd_render) ]

let handle (line : string) : Yojson.Safe.t =
  match Yojson.Safe.from_string line with
  | exception _ -> error "line is not valid JSON"
  | json -> (
      match string_field "cmd" json with
      | Error m ->
          error m
            ~fields:
              [ ("commands", `List (List.map (fun (n, _) -> `String n) commands)) ]
      | Ok name -> (
          match List.assoc_opt name commands with
          | Some f -> (
              (* Belt and braces over Tfl.Safe's own totality: an unexpected
                 exception here would kill the stream and take every queued
                 request with it, so it becomes one error line instead. *)
              try f json
              with e -> error ("internal: " ^ Printexc.to_string e))
          | None ->
              error
                (Printf.sprintf "unknown cmd %S" name)
                ~fields:
                  [
                    ( "commands",
                      `List (List.map (fun (n, _) -> `String n) commands) );
                  ]))

let usage =
  {|tfl_cli — JSON over stdio, one request per line.

  {"cmd":"check","premises":["-M+P","-S+M"],"conclusion":"-S+P"}
  {"cmd":"parse","tfl":"-Man+Mortal"}
  {"cmd":"render","tfl":"+Officer^1+(Sign+Contract)"}

Every reply is one JSON object. Failures carry an "error" field; a formula the
engine refuses carries "ok":false with its class (lexical | syntactic |
outside_fragment | internal), which is the fragment-membership signal.
|}

let () =
  if Array.length Sys.argv > 1 then (
    (* No flags, deliberately: the protocol is the interface. Anything on the
       command line is a request for help. *)
    print_string usage;
    exit (if Sys.argv.(1) = "--help" || Sys.argv.(1) = "-h" then 0 else 2));
  let rec loop () =
    match input_line stdin with
    | exception End_of_file -> ()
    | line ->
        if String.trim line <> "" then out (handle line);
        loop ()
  in
  loop ()
