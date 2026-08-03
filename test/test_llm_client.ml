(* The OpenRouter client's failure handling (PLAN 4.9). No network: the two
   decisions worth testing are both pure or thunk-driven, and a test that needs
   a live endpoint would never run.

   The threat is a specific one that already cost us a measurement. On
   2026-08-02 two Kimi batches came back as HTTP 200 with an empty body. The
   client classified that as fatal, the batch was abandoned, and 22 sentence
   slots vanished from the fidelity run — while the reported percentages still
   looked healthy, because a sentence that never arrived is invisible to a rate
   computed over attempts. A dropped call has to become another attempt, not a
   silent hole in the data. *)

module C = Translate.Llm_client

let checks = ref 0

let check name b =
  incr checks;
  if not b then failwith ("test_llm_client: " ^ name)

(* ── Classification ──────────────────────────────────────────────────────── *)

let is_retry = function C.Retry _ -> true | _ -> false
let is_fatal = function C.Fatal _ -> true | _ -> false
let is_body s = function C.Body b -> b = s | _ -> false

let () =
  (* The regression itself: under the old classification an empty 200 was a
     body, and failed downstream in parse_response — outside the retry loop. *)
  check "empty 200 body is retried" (is_retry (C.disposition_of ~code:200 ~raw:""));
  check "whitespace-only 200 body is retried"
    (is_retry (C.disposition_of ~code:200 ~raw:" \n\t "));
  check "a real 200 body is returned"
    (is_body {|{"choices":[]}|} (C.disposition_of ~code:200 ~raw:{|{"choices":[]}|}));
  check "204 with no body is retried" (is_retry (C.disposition_of ~code:204 ~raw:""));
  (* Unchanged behaviour, pinned so the split did not quietly move it. *)
  check "429 is retried" (is_retry (C.disposition_of ~code:429 ~raw:"slow down"));
  check "500 is retried" (is_retry (C.disposition_of ~code:500 ~raw:"boom"));
  check "503 is retried" (is_retry (C.disposition_of ~code:503 ~raw:"boom"));
  check "401 fails fast" (is_fatal (C.disposition_of ~code:401 ~raw:"bad key"));
  check "400 fails fast" (is_fatal (C.disposition_of ~code:400 ~raw:"bad request"));
  check "404 fails fast" (is_fatal (C.disposition_of ~code:404 ~raw:"no such model"))

(* ── The retry loop ──────────────────────────────────────────────────────── *)

(* Classifying a failure as retryable buys nothing unless the loop acts on it,
   which is the half the lost sentences actually needed. Zero delay: the
   backoff is not what is under test and three real sleeps would be 7s. *)

let attempts_of f =
  let n = ref 0 in
  let thunk () =
    incr n;
    f !n
  in
  let result =
    try Ok (Lwt_main.run (C.with_retries ~delay:0.0 ~max_attempts:3 thunk))
    with e -> Error e
  in
  (!n, result)

let () =
  let n, r = attempts_of (fun _ -> Lwt.fail (C.Retryable "empty body on HTTP 200")) in
  check "a retryable failure is attempted three times" (n = 3);
  check "and then reports the last error"
    (match r with Error (C.Llm_error m) -> m = "empty body on HTTP 200 (after 3 attempts)" | _ -> false);

  let n, r =
    attempts_of (fun i ->
        if i < 3 then Lwt.fail (C.Retryable "empty body on HTTP 200")
        else Lwt.return "recovered")
  in
  check "a call that recovers on the third attempt succeeds"
    (n = 3 && r = Ok "recovered");

  let n, r = attempts_of (fun _ -> Lwt.fail (C.Llm_error "HTTP 401: bad key")) in
  check "a fatal failure is not retried" (n = 1);
  check "and propagates unchanged"
    (match r with Error (C.Llm_error m) -> m = "HTTP 401: bad key" | _ -> false);

  (* An unexpected exception (a network drop surfacing as Unix_error, say) is
     transient by default — the old loop did this and it stays. *)
  let n, _ = attempts_of (fun _ -> Lwt.fail Exit) in
  check "an unclassified exception is retried" (n = 3);

  (* The ceiling must never be retried: another attempt costs the money the
     ceiling just refused. *)
  let n, r = attempts_of (fun _ -> Lwt.fail (C.Cost_ceiling "over")) in
  check "the cost ceiling is not retried" (n = 1);
  check "and propagates as itself"
    (match r with Error (C.Cost_ceiling _) -> true | _ -> false);

  (* A retryable failure must still be retried when it is raised synchronously
     rather than returned as a rejected promise. *)
  let n, _ = attempts_of (fun _ -> raise (C.Retryable "sync")) in
  check "a synchronously raised retryable is retried" (n = 3)

(* ── Reading the response body ───────────────────────────────────────────── *)

(* A body we cannot read is transient, not permanent: the provider answered 200
   and gave us nothing usable. This must raise `Retryable`, and parse_response
   must sit INSIDE the retry loop — it did not, and that cost the 2026-08-02
   fidelity re-run two Kimi batches (20 sentences) after 4.9 had already fixed
   the narrower empty-body case one layer down. A structured provider error is
   different in kind and still fails fast. *)

let raises_retryable f = match f () with _ -> false | exception C.Retryable _ -> true
let raises_fatal f = match f () with _ -> false | exception C.Llm_error _ -> true

let () =
  let parse s () = C.parse_response s in
  check "an unreadable body is retryable" (raises_retryable (parse ""));
  check "a truncated body is retryable" (raises_retryable (parse {|{"choices":|}));
  check "a non-object body is retryable" (raises_retryable (parse "[]"));
  check "a body with no choices is retryable" (raises_retryable (parse "{}"));
  check "an empty choices array is retryable"
    (raises_retryable (parse {|{"choices":[]}|}));
  check "a null content is retryable"
    (raises_retryable (parse {|{"choices":[{"message":{"content":null}}]}|}));
  (* The provider telling us something definite is not worth three attempts. *)
  check "a structured provider error fails fast"
    (raises_fatal (parse {|{"error":{"message":"no such model"}}|}));
  (* Every message carries the byte count, because the run that exposed this
     printed an empty payload and left nothing to diagnose from. *)
  check "failure messages name the body size"
    (match C.parse_response "{}" with
    | exception C.Retryable m ->
        (* "(2 bytes)" for "{}" *)
        let re = Str.regexp_string "(2 bytes)" in
        (try ignore (Str.search_forward re m 0); true with Not_found -> false)
    | _ -> false);
  let good =
    {|{"id":"gen-1","choices":[{"message":{"content":"hi"}}],"usage":{"prompt_tokens":3,"completion_tokens":1,"cost":0.5}}|}
  in
  (match C.parse_response good with
  | r, id ->
      check "a well-formed body parses" (r.content = "hi" && id = "gen-1");
      check "tokens and cost are read"
        (r.prompt_tokens = 3 && r.completion_tokens = 1 && r.cost = Some 0.5)
  | exception e -> check ("a well-formed body parses: " ^ Printexc.to_string e) false);
  (* A free call is JSON `0`, which yojson types as `Int`. *)
  (match C.parse_response {|{"choices":[{"message":{"content":"x"}}],"usage":{"cost":0}}|} with
  | r, _ -> check "a zero cost is counted, not filed as unpriced" (r.cost = Some 0.)
  | exception _ -> check "a zero cost is counted" false)

(* ── The cost ceiling ────────────────────────────────────────────────────── *)

let () =
  let ceiling = Translate.Config.cost_ceiling_usd in
  check "the ceiling is a real budget, not zero or unbounded"
    (ceiling > 0. && ceiling <= 100.);
  check "an unspent run may call" (C.ceiling_stop ~spent:0. = None);
  check "a run just under the ceiling may call"
    (C.ceiling_stop ~spent:(ceiling -. 0.01) = None);
  check "a run at the ceiling is stopped" (C.ceiling_stop ~spent:ceiling <> None);
  check "a run over the ceiling is stopped"
    (C.ceiling_stop ~spent:(ceiling *. 2.) <> None);
  check "nothing has been spent by this test" (C.spent () = 0.)

let () = Printf.printf "test_llm_client: %d checks passed\n" !checks
