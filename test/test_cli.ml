(* The CLI process boundary (PLAN 11.4, pulled ahead).

   The threat this guards is specific to a line protocol: one crash does not
   lose one answer, it loses every request behind it — and the caller cannot
   tell that from a hang. `Tfl.Safe` already guarantees the engine never raises;
   this checks that the guarantee survives the process boundary, where the new
   failure modes are JSON that will not parse, fields of the wrong type, and
   commands that do not exist. Requests and replies are exchanged in lockstep,
   so a large reply cannot fill stdout while the caller is still filling stdin.

   So the batch below deliberately interleaves garbage with real work: if any
   line kills the process, the *later* good requests go missing and the reply
   count is short. Counting replies is the test. *)

let checks = ref 0

let check name b =
  incr checks;
  if not b then failwith ("test_cli: " ^ name)

(* `dune test` runs from _build/default/test/; `dune exec` runs from the repo
   root. Same resolution the shim client uses. *)
let exe =
  if Sys.file_exists "../bin/tfl_cli.exe" then "../bin/tfl_cli.exe"
  else "_build/default/bin/tfl_cli.exe"

let rec read_lines ic acc =
  match input_line ic with
  | line -> read_lines ic (line :: acc)
  | exception End_of_file -> List.rev acc

(* Send each nonblank request and read its reply before sending the next. *)
let run (lines : string list) : string list =
  (* cloexec matters: without it the child inherits copies of the parent's own
     pipe ends, so closing our write end never delivers EOF to the child's
     stdin and both sides block forever. This test hung until it was set. *)
  let out_r, out_w = Unix.pipe ~cloexec:true ()
  and in_r, in_w = Unix.pipe ~cloexec:true () in
  let pid = Unix.create_process exe [| exe |] in_r out_w Unix.stderr in
  Unix.close in_r;
  Unix.close out_w;
  let oc = Unix.out_channel_of_descr in_w
  and ic = Unix.in_channel_of_descr out_r in
  let rec exchange acc = function
    | [] -> List.rev acc
    | line :: rest -> (
        output_string oc (line ^ "\n");
        flush oc;
        if String.trim line = "" then exchange acc rest
        else
          match input_line ic with
          | reply -> exchange (reply :: acc) rest
          | exception End_of_file ->
              failwith "CLI closed stdout before replying to every request")
  in
  let replies = exchange [] lines in
  close_out oc;
  let unexpected_replies = read_lines ic [] in
  close_in ic;
  let _, status = Unix.waitpid [] pid in
  check "the process exits cleanly even after malformed input"
    (status = Unix.WEXITED 0);
  replies @ unexpected_replies

let run_help invoked_as =
  let out_r, out_w = Unix.pipe ~cloexec:true () in
  let pid =
    Unix.create_process exe [| invoked_as; "--help" |] Unix.stdin out_w
      Unix.stderr
  in
  Unix.close out_w;
  let ic = Unix.in_channel_of_descr out_r in
  let lines = read_lines ic [] in
  close_in ic;
  let _, status = Unix.waitpid [] pid in
  check "help exits cleanly" (status = Unix.WEXITED 0);
  lines

let field name line =
  match Yojson.Safe.Util.member name (Yojson.Safe.from_string line) with
  | `String s -> s
  | `Bool b -> string_of_bool b
  | `Null -> "<absent>"
  | v -> Yojson.Safe.to_string v

let () =
  let help = run_help "horos" in
  check "help names the installed executable"
    (match help with
    | first_line :: _ ->
        first_line = "horos — JSON over stdio, one request per line."
    | [] -> false);

  let requests =
    [
      {|{"cmd":"check","premises":["-M+P","-S+M"],"conclusion":"-S+P"}|};
      (* garbage, sandwiched so anything it kills is visible downstream *)
      {|not json at all|};
      {|{"cmd":"nope"}|};
      {|{"cmd":"parse"}|};
      {|{"cmd":"parse","tfl":42}|};
      {|{"cmd":"check","premises":"not a list","conclusion":"-S+P"}|};
      {|{"cmd":"parse","tfl":"every man is mortal"}|};
      {|{"cmd":"parse","tfl":"-Man+Mortal"}|};
      (* the 5.3 abstention has to reach the caller as `unknown`, never
         `invalid` — this is the boundary the Python client will read *)
      {|{"cmd":"check","premises":["+S^2+P","+S^2+Q"],"conclusion":"+P+Q"}|};
      {|{"cmd":"render","tfl":"+Officer^1+(Sign+Contract)"}|};
      {|{"cmd":"compile","program":"-Man+Animal\n+-Socrates*+Man"}|};
      {|{"cmd":"compile","program":"-Man+Animal\n+oops("}|};
      {|{"cmd":"query","program":"+-Socrates*+Man\n-Man+Mortal","query":"+-Socrates*+Mortal"}|};
      {|{"cmd":"describe","program":"+-Socrates*+Man\n-Man+Animal\n-Man+Mortal","term":"Socrates*"}|};
      {|{"cmd":"consistency","program":"+-Socrates*+Man\n-Man+Mortal\n+-Socrates*-Mortal"}|};
      {|{"cmd":"equivalence","left":"-Dog+Mammal","right":"-(−Mammal)+(−Dog)"}|};
    ]
  in
  let replies = run requests in
  check "every request got exactly one reply — nothing was lost to a crash"
    (List.length replies = List.length requests);
  let r = Array.of_list replies in
  check "a valid syllogism is certified" (field "verdict" r.(0) = "valid");
  check "unparseable JSON is an error, not a crash"
    (field "error" r.(1) = "line is not valid JSON");
  check "an unknown command names the ones that exist"
    (field "error" r.(2) <> "<absent>"
    && Yojson.Safe.Util.member "commands" (Yojson.Safe.from_string r.(2))
       <> `Null);
  check "a missing field is reported by name"
    (field "error" r.(3) = {|missing field "tfl"|});
  check "a field of the wrong type is reported by name"
    (field "error" r.(4) = {|field "tfl" must be a string|});
  check "a premises field that is not a list is reported"
    (field "error" r.(5) = {|field "premises" must be a list of strings|});
  (* The taxonomy class is the router's escalation signal (5.1) and the
     coverage statistic 4.6 counts, so it has to survive serialization. *)
  check "a refused formula carries its taxonomy class"
    (field "ok" r.(6) = "false" && field "class" r.(6) = "syntactic");
  check "a parsed formula comes back canonical, with its English"
    (field "ok" r.(7) = "true"
    && field "english" r.(7) = "every man is mortal");
  check "the numerical abstention reaches the caller as unknown (5.3)"
    (field "verdict" r.(8) = "unknown" && field "method" r.(8) = "numerical");
  check "render speaks the quantity word on a relational predicate (5.0)"
    (field "english" r.(9) = "many officer sign some contract");
  check "compile returns stable statement records"
    (field "ok" r.(10) = "true"
    && field "schema" r.(10) = "horos-runtime-0.1"
    && List.length
         (Yojson.Safe.Util.to_list
            (Yojson.Safe.Util.member "statements"
               (Yojson.Safe.from_string r.(10))))
       = 2);
  let compile_errors =
    Yojson.Safe.Util.member "errors" (Yojson.Safe.from_string r.(11))
    |> Yojson.Safe.Util.to_list
  in
  check "a malformed program is refused as one complete unit"
    (field "ok" r.(11) = "false"
    && List.length compile_errors = 1
    && Yojson.Safe.Util.member "where" (List.hd compile_errors)
       = `String "line 2");
  let query_json = Yojson.Safe.from_string r.(12) in
  check "program query exposes support and explicit completeness"
    (field "verdict" r.(12) = "yes"
    && field "method" r.(12) = "PZ"
    && Yojson.Safe.Util.member "complete"
         (Yojson.Safe.Util.member "completeness" query_json)
       = `Bool true
    && Yojson.Safe.Util.member "support" query_json <> `Null);
  let describe_json = Yojson.Safe.from_string r.(13) in
  check "term descriptions carry proof support"
    (field "method" r.(13) = "bounded-saturation"
    && List.length
         (Yojson.Safe.Util.member "answers" describe_json
         |> Yojson.Safe.Util.to_list)
       = 3);
  let consistency_json = Yojson.Safe.from_string r.(14) in
  check "program consistency exposes its refutation evidence"
    (field "status" r.(14) = "inconsistent"
    && Yojson.Safe.Util.member "complete"
         (Yojson.Safe.Util.member "completeness" consistency_json)
       = `Bool true
    && Yojson.Safe.Util.member "evidence" consistency_json
       |> Yojson.Safe.Util.to_list |> List.length > 0);
  let equivalence_json = Yojson.Safe.from_string r.(15) in
  check "equivalence exposes its bounded rewrite witness"
    (field "equivalent" r.(15) = "true"
    && field "method" r.(15) = "rewrite"
    && Yojson.Safe.Util.member "complete"
         (Yojson.Safe.Util.member "completeness" equivalence_json)
       = `Bool false
    && Yojson.Safe.Util.member "evidence" equivalence_json
       |> Yojson.Safe.Util.to_list |> List.length = 1);

  (* A truth table near the public atom limit is much larger than an OS pipe.
     Reading it before sending the following request proves the documented
     lockstep protocol remains live in both directions. *)
  let replies =
    run
      [
        {|{"cmd":"equivalence","left":"-a+(+b+c+d+e+f+g+h+i+j+k+l+m+n+o)","right":"-a+(+b+c+d+e+f+g+h+i+j+k+l+m+n+o)"}|};
        {|{"cmd":"parse","tfl":"-Man+Mortal"}|};
      ]
    |> Array.of_list
  in
  check "a response larger than an OS pipe completes without deadlock"
    (Array.length replies = 2
    && String.length replies.(0) > 500_000
    && field "method" replies.(0) = "dnf");
  check "the request after a large response is still processed"
    (field "ok" replies.(1) = "true");

  (* An empty line is not a request and must not produce a reply, or the
     caller's reply-to-request pairing silently shifts by one. *)
  let replies = run [ ""; "   "; {|{"cmd":"parse","tfl":"-Man+Mortal"}|} ] in
  check "blank lines are skipped rather than answered"
    (List.length replies = 1);

  (* The limit has to apply while reading, before Yojson allocates a complete
     hostile line. Draining the rejected line is equally important: the valid
     request after it proves the long-lived process remains synchronized. *)
  let oversized = String.make (1_048_576 + 1) 'x' in
  let replies =
    run [ oversized; {|{"cmd":"parse","tfl":"-Man+Mortal"}|} ]
    |> Array.of_list
  in
  check "an oversized protocol line gets one structured refusal"
    (Array.length replies = 2
    && field "class" replies.(0) = "resource_limit");
  check "the request after an oversized line is still processed"
    (field "ok" replies.(1) = "true");

  (* Valid JSON is not necessarily a request object. Yojson's member helper
     raises on these shapes, so the object check must happen before lookup. *)
  let replies =
    run
      [
        "[]";
        {|"scalar"|};
        "null";
        "42";
        {|{"cmd":"parse","tfl":"-Man+Mortal"}|};
      ]
    |> Array.of_list
  in
  check "valid non-object JSON is refused without killing the stream"
    (Array.length replies = 5
    && Array.for_all
         (fun reply -> field "error" reply = "request must be a JSON object")
         (Array.sub replies 0 4));
  check "a request after non-object JSON is still processed"
    (field "ok" replies.(4) = "true");

  Printf.printf "cli boundary: %d checks passed\n" !checks
