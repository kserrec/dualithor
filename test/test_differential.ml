(* 1.3 acceptance: differential agreement between the OCaml parser/printer and
   the frozen JS reference engine, on
   (a) every string literal in engine/tfl.test.js, fed to all three parse
       entry points — non-formula strings must fail identically on both sides;
   (b) 10k QCheck-generated ASTs: the JS printer must reproduce the OCaml
       printed form and the JS parser must recover the exact AST;
   (c) 10k random token strings: parse outcomes (AST or error position+text)
       must agree on all three entry points.

   Documented divergences are normalized here, in the harness — never in the
   engine: the OCaml quoting hint appended to unrecognized non-ASCII
   characters (LOG 2026-07-30) is stripped before message comparison. *)

open Tfl.Notation

(* Under `dune test` the cwd is _build/default/test (the deps put engine/
   one level up); under `dune exec` from the root it is the source tree. *)
let engine_dir =
  if Sys.file_exists "../engine/shim.js" then "../engine" else "engine"

let shim = Shim_client.start ~shim_path:(engine_dir ^ "/shim.js")

(* ── Outcome comparison ─────────────────────────────────────────────────── *)

type ocaml_outcome =
  | Parsed of Yojson.Safe.t * string (* AST as JS-shaped JSON, printed form *)
  | Failed of string * int (* full message, position *)

let ocaml_parse fn src : ocaml_outcome =
  try
    match fn with
    | "parseProposition" ->
        let p = parse_proposition src in
        Parsed (Ast_json.prop_to_json p, print_proposition p)
    | "parseTerm" ->
        let t = parse_term src in
        Parsed (Ast_json.term_to_json t, print_term t)
    | "parseSignedTerm" ->
        let s = parse_signed_term src in
        Parsed (Ast_json.st_to_json s, print_signed_term s)
    | _ -> assert false
  with Parse_error { message; pos } -> Failed (message, pos)

let print_fn_of = function
  | "parseProposition" -> "printProposition"
  | "parseTerm" -> "printTerm"
  | _ -> "printSignedTerm"

let advisory = " (quote the term to use non-ASCII names)"

(* Remove the first occurrence of [advisory] (the recorded §16.4 divergence). *)
let strip_advisory msg =
  let ml = String.length msg and al = String.length advisory in
  let rec find i =
    if i + al > ml then None
    else if String.sub msg i al = advisory then Some i
    else find (i + 1)
  in
  match find 0 with
  | None -> msg
  | Some i -> String.sub msg 0 i ^ String.sub msg (i + al) (ml - i - al)

(* None = both engines agree on [src] via [fn]; Some d = disagreement d. *)
let compare_on fn src : string option =
  match (ocaml_parse fn src, Shim_client.call shim fn [ `String src ]) with
  | Parsed (ast, printed), Ok js_ast ->
      if not (Ast_json.json_equal ast js_ast) then
        Some
          (Printf.sprintf "%s AST mismatch on %S: ocaml %s vs js %s" fn src
             (Yojson.Safe.to_string ast)
             (Yojson.Safe.to_string js_ast))
      else (
        (* Same AST — now the printers must emit the same string. The OCaml
           AST JSON goes through the JS printer, checking both printers and
           the serialization in one pass. *)
        match Shim_client.call shim (print_fn_of fn) [ ast ] with
        | Ok (`String js_printed) when js_printed = printed -> None
        | Ok (`String js_printed) ->
            Some
              (Printf.sprintf "%s print mismatch on %S: ocaml %S vs js %S" fn
                 src printed js_printed)
        | Ok other ->
            Some
              (Printf.sprintf "%s: js printer returned non-string %s" fn
                 (Yojson.Safe.to_string other))
        | Error e ->
            Some
              (Printf.sprintf "%s: js printer errored (%s) on ocaml AST for %S"
                 fn e.message src))
  | ( Failed (msg, pos),
      Error { name = "ParseError"; message = js_msg; pos = Some js_pos } ) ->
      if pos = js_pos && strip_advisory msg = js_msg then None
      else
        Some
          (Printf.sprintf
             "%s error mismatch on %S: ocaml (%S at %d) vs js (%S at %d)" fn
             src msg pos js_msg js_pos)
  | Parsed _, Error e ->
      Some
        (Printf.sprintf "%s: ocaml parsed but js errored (%s: %s) on %S" fn
           e.name e.message src)
  | Failed (msg, _), Ok _ ->
      Some
        (Printf.sprintf "%s: js parsed but ocaml errored (%s) on %S" fn msg src)
  | Failed _, Error { name; message; _ } ->
      Some
        (Printf.sprintf "%s: js raised %s (%s) on %S — expected ParseError" fn
           name message src)

let entry_points = [ "parseProposition"; "parseTerm"; "parseSignedTerm" ]

(* ── Corpus: every string literal in tfl.test.js ────────────────────────── *)

(* A small scanner for the frozen JS test file: skips // and slash-star
   comments and backtick template literals, extracts '…' and "…" literals
   decoding the standard escapes (unknown escapes keep the escaped char,
   as in JS). Good enough for the fixed file it reads. *)
let extract_js_strings (src : string) : string list =
  let n = String.length src in
  let out = ref [] in
  let i = ref 0 in
  while !i < n do
    let c = src.[!i] in
    if c = '/' && !i + 1 < n && src.[!i + 1] = '/' then
      while !i < n && src.[!i] <> '\n' do
        incr i
      done
    else if c = '/' && !i + 1 < n && src.[!i + 1] = '*' then (
      i := !i + 2;
      while !i + 1 < n && not (src.[!i] = '*' && src.[!i + 1] = '/') do
        incr i
      done;
      i := !i + 2)
    else if c = '\'' || c = '"' then (
      let quote = c in
      let b = Buffer.create 16 in
      incr i;
      let closed = ref false in
      while (not !closed) && !i < n do
        let d = src.[!i] in
        if d = '\\' && !i + 1 < n then (
          (match src.[!i + 1] with
          | 'n' -> Buffer.add_char b '\n'
          | 't' -> Buffer.add_char b '\t'
          | 'r' -> Buffer.add_char b '\r'
          | ch -> Buffer.add_char b ch);
          i := !i + 2)
        else if d = quote then (
          closed := true;
          incr i)
        else if d = '\n' then closed := true (* not valid JS; bail *)
        else (
          Buffer.add_char b d;
          incr i)
      done;
      out := Buffer.contents b :: !out)
    else if c = '`' then (
      incr i;
      let closed = ref false in
      while (not !closed) && !i < n do
        if src.[!i] = '\\' && !i + 1 < n then i := !i + 2
        else if src.[!i] = '`' then (
          closed := true;
          incr i)
        else incr i
      done)
    else incr i
  done;
  List.rev !out

let corpus_gate () =
  let src =
    In_channel.with_open_bin (engine_dir ^ "/tfl.test.js") In_channel.input_all
  in
  let strings = extract_js_strings src |> List.sort_uniq compare in
  let checks = ref 0 in
  let failures = ref 0 in
  List.iter
    (fun s ->
      List.iter
        (fun fn ->
          incr checks;
          match compare_on fn s with
          | None -> ()
          | Some d ->
              incr failures;
              Printf.eprintf "✗ corpus: %s\n" d)
        entry_points)
    strings;
  Printf.printf "corpus gate: %d distinct strings, %d checks, %d disagreements\n"
    (List.length strings) !checks !failures;
  !failures = 0

(* ── Random ASTs and random token strings ───────────────────────────────── *)

let diff_ast =
  QCheck2.Test.make ~count:10_000
    ~name:"differential: printers and parsers agree on generated ASTs"
    ~print:print_proposition Gen.prop_gen (fun p ->
      let ast = Ast_json.prop_to_json p in
      let printed = print_proposition p in
      (match Shim_client.call shim "printProposition" [ ast ] with
      | Ok (`String js_printed) -> js_printed = printed
      | _ -> false)
      &&
      match Shim_client.call shim "parseProposition" [ `String printed ] with
      | Ok js_ast -> Ast_json.json_equal ast js_ast
      | _ -> false)

(* Random concatenations of notation tokens: mostly ill-formed, some valid,
   exercising every tokenizer/parser error path on both engines at once. *)
let token_pool =
  [
    "+"; "-"; "−"; "±"; "+-"; "("; ")"; "["; "]"; "*"; "^"; "\""; "'"; "′";
    "″"; " "; "\n"; "S"; "P"; "Dog"; "Boy'"; "p"; "q"; "x1"; "_"; "2"; "²";
    "⁰"; "₁"; "7"; "head of a horse";
  ]

let token_string_gen : string QCheck2.Gen.t =
  let open QCheck2.Gen in
  let* n = int_bound 25 in
  let* parts = list_size (return n) (oneof_list token_pool) in
  return (String.concat "" parts)

let diff_strings =
  QCheck2.Test.make ~count:10_000
    ~name:"differential: parse outcomes agree on random token strings"
    ~print:String.escaped token_string_gen (fun s ->
      List.for_all (fun fn -> compare_on fn s = None) entry_points)

(* Harness self-test: a real divergence must be DETECTED, or a clean run means
   nothing. "+É+P" is the documented §16.4 case — the JS reference parses É as
   a bare name, the OCaml engine raises a lexical error. *)
let negative_control () =
  match compare_on "parseProposition" "+\u{00C9}+P" with
  | Some _ -> true
  | None ->
      prerr_endline
        "✗ negative control: harness failed to detect the §16.4 divergence";
      false

let () =
  let control_ok = negative_control () in
  let corpus_ok = corpus_gate () in
  let qcheck_failures =
    QCheck_base_runner.run_tests ~verbose:true [ diff_ast; diff_strings ]
  in
  Shim_client.stop shim;
  exit
    (if (not control_ok) || (not corpus_ok) || qcheck_failures <> 0 then 1
     else 0)
