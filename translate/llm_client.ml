(* OpenRouter chat-completions client (PLAN 2.2): one POST surface, three
   attempts with exponential backoff, a wall-clock timeout per attempt, and a
   usage ledger appended to data/usage.jsonl — tokens, cost and request id,
   never the key. *)

open Lwt.Syntax

type response = {
  content : string;
  prompt_tokens : int;
  completion_tokens : int;
  cost : float option; (* USD, as accounted by OpenRouter *)
}

exception Llm_error of string

(* Transient conditions worth another attempt: 429, 5xx, timeouts, network
   drops. Everything else (auth, malformed request) fails fast — retrying a
   401 three times just delays the real error. *)
exception Retryable of string

(* The run has spent its budget (PLAN 4.9). Never retried: another attempt
   costs the same money the ceiling just refused. *)
exception Cost_ceiling of string

let endpoint = Uri.of_string "https://openrouter.ai/api/v1/chat/completions"
let usage_path = "data/usage.jsonl"

(* ── Spend accounting (PLAN 4.9) ─────────────────────────────────────────── *)

(* Paid calls only: a cache hit never reaches this module, so this is real
   money for this process and nothing else. *)
let spent_usd = ref 0.

(* Replies OpenRouter priced at nothing at all — not zero, absent. They cannot
   be counted, so they are reported rather than assumed free. *)
let unpriced_calls = ref 0
let spent () = !spent_usd

(* Pure, so the ceiling can be tested without spending anything. *)
let ceiling_stop ~spent =
  if spent >= Config.cost_ceiling_usd then
    Some
      (Printf.sprintf
         "cost ceiling reached: $%.4f spent this run, ceiling $%.2f (raise \
          Config.cost_ceiling_usd if this is expected)"
         spent Config.cost_ceiling_usd)
  else None

let spend_report () =
  Printf.sprintf "spend this run: $%.4f of the $%.2f ceiling%s" !spent_usd
    Config.cost_ceiling_usd
    (if !unpriced_calls = 0 then ""
     else
       Printf.sprintf
         " — plus %d call(s) OpenRouter returned no cost for, so the total is \
          a lower bound"
         !unpriced_calls)

let api_key () =
  match Env.get "OPENROUTER_API_KEY" with
  | Some k when k <> "" -> k
  | _ ->
      raise
        (Llm_error
           "OPENROUTER_API_KEY not set (export it or put it in .env at the \
            repo root)")

let truncate_msg s =
  if String.length s <= 300 then s else String.sub s 0 300 ^ "…"

let log_usage ~model ~id ~prompt_tokens ~completion_tokens ~cost =
  let line =
    `Assoc
      [
        ("ts", `Float (Unix.time ()));
        ("model", `String model);
        ("id", `String id);
        ("prompt_tokens", `Int prompt_tokens);
        ("completion_tokens", `Int completion_tokens);
        ("cost", match cost with Some c -> `Float c | None -> `Null);
      ]
  in
  let oc = open_out_gen [ Open_append; Open_creat ] 0o644 usage_path in
  Fun.protect
    ~finally:(fun () -> close_out_noerr oc)
    (fun () -> output_string oc (Yojson.Safe.to_string line ^ "\n"))

(* What a response means, decided apart from the I/O so it is testable without
   a network. `Retry` is the only classification the retry loop acts on, which
   is why an empty body has to be decided *here* rather than downstream in
   parse_response — see below. *)
type disposition = Body of string | Retry of string | Fatal of string

let disposition_of ~code ~raw =
  if code >= 200 && code < 300 then
    (* An empty 200 is a dropped upstream connection wearing a success code:
       there is no error payload to read and nothing was generated. Classifying
       it as fatal is what lost 22 sentence-slots from the 2026-08-02 fidelity
       run — the parse failure landed outside the retry loop, the batch was
       abandoned, and the reported percentages still looked healthy because a
       missing sentence is invisible to a rate computed over attempts. *)
    if String.trim raw = "" then Retry "empty body on HTTP 200" else Body raw
  else
    let msg = Printf.sprintf "HTTP %d: %s" code (truncate_msg raw) in
    if code = 429 || code >= 500 then Retry msg else Fatal msg

let call_once ~key ~model ~system ~user ~max_tokens () =
  let body =
    `Assoc
      [
        ("model", `String model);
        ( "messages",
          `List
            [
              `Assoc [ ("role", `String "system"); ("content", `String system) ];
              `Assoc [ ("role", `String "user"); ("content", `String user) ];
            ] );
        ("max_tokens", `Int max_tokens);
        (* Asks OpenRouter to account cost in the response itself. *)
        ("usage", `Assoc [ ("include", `Bool true) ]);
      ]
    |> Yojson.Safe.to_string
  in
  let headers =
    Cohttp.Header.of_list
      [
        ("authorization", "Bearer " ^ key); ("content-type", "application/json");
      ]
  in
  let* resp, body_stream =
    Cohttp_lwt_unix.Client.post ~headers
      ~body:(Cohttp_lwt.Body.of_string body)
      endpoint
  in
  let* raw = Cohttp_lwt.Body.to_string body_stream in
  let code = Cohttp.Code.code_of_status (Cohttp.Response.status resp) in
  match disposition_of ~code ~raw with
  | Body b -> Lwt.return b
  | Retry msg -> Lwt.fail (Retryable msg)
  | Fatal msg -> Lwt.fail (Llm_error msg)

let with_timeout timeout_s thunk =
  Lwt.pick
    [
      thunk ();
      (let* () = Lwt_unix.sleep timeout_s in
       Lwt.fail (Retryable (Printf.sprintf "timeout after %.0fs" timeout_s)));
    ]

(* A body we cannot read is a **transient** condition, not a permanent one: the
   provider answered 200 and handed us nothing usable, which is exactly what a
   dropped or truncated response looks like from here. So it raises `Retryable`
   and the loop gets another go.

   This function used to run *outside* the retry loop, and every failure in it
   was fatal. That is what lost two Kimi batches — 20 sentences — from the
   2026-08-02 fidelity re-run, after 4.9 had already fixed the narrower
   empty-body case one layer down. A structured provider error is different in
   kind: that is the provider telling us something definite, so it still fails
   fast rather than burning three attempts on a bad model slug.

   Every message now carries the body's byte count and its first 300 bytes. The
   run that exposed this printed an empty payload and left nothing to diagnose
   from, which is its own defect. *)
let parse_response raw =
  let open Yojson.Safe.Util in
  let detail why =
    Printf.sprintf "%s (%d bytes): %S" why (String.length raw)
      (truncate_msg raw)
  in
  let bad why = raise (Retryable (detail why)) in
  let fatal why = raise (Llm_error (detail why)) in
  let json =
    try Yojson.Safe.from_string raw with _ -> bad "unparseable response body"
  in
  (* A non-object body would make every `member` below raise Type_error outside
     any handler, which escapes as an uncaught exception rather than an error. *)
  (match json with `Assoc _ -> () | _ -> bad "response body is not a JSON object");
  (* OpenRouter can answer 200 with an {"error": …} payload. *)
  (match member "error" json with
  | `Null -> ()
  | e -> fatal ("provider error " ^ Yojson.Safe.to_string e));
  try
    let content =
      json |> member "choices" |> index 0 |> member "message"
      |> member "content" |> to_string
    in
    let id = try json |> member "id" |> to_string with _ -> "" in
    let usage = member "usage" json in
    let tok name = match member name usage with `Int n -> n | _ -> 0 in
    let cost =
      (* A genuinely free call comes back as JSON `0`, which yojson types as
         `Int` — reading only `Float` would file it as unpriced. *)
      match member "cost" usage with
      | `Float c -> Some c
      | `Int n -> Some (float_of_int n)
      | _ -> None
    in
    ( {
        content;
        prompt_tokens = tok "prompt_tokens";
        completion_tokens = tok "completion_tokens";
        cost;
      },
      id )
  (* Both, and the distinction is not academic: `member` on a wrong-typed field
     raises Type_error, but `index 0` on an *empty* array raises Undefined —
     which used to escape this function uncaught and kill the process rather
     than produce an error. Found by the test below, not in the wild. *)
  with Type_error _ | Undefined _ -> bad "unexpected response shape"

(* The retry loop, generic over the attempt so it can be exercised without a
   network. Anything not classified `Retryable` — or refused by the ceiling —
   fails on the spot. *)
let rec with_retries ?(attempt = 1) ?(delay = 1.0) ~max_attempts f =
  Lwt.catch f (fun exn ->
      let retry msg =
        if attempt >= max_attempts then
          Lwt.fail
            (Llm_error
               (Printf.sprintf "%s (after %d attempts)" msg max_attempts))
        else
          let* () = Lwt_unix.sleep delay in
          with_retries ~attempt:(attempt + 1) ~delay:(delay *. 2.) ~max_attempts
            f
      in
      match exn with
      | Retryable msg -> retry msg
      | (Llm_error _ | Cost_ceiling _) as e -> Lwt.fail e
      | exn -> retry (Printexc.to_string exn))

let complete ?(timeout_s = 120.) ~model ~system ~user ~max_tokens () =
  match ceiling_stop ~spent:!spent_usd with
  | Some why -> Lwt.fail (Cost_ceiling why)
  | None ->
      let key = api_key () in
      (* parse_response is INSIDE the loop: a body-shape failure is retryable
         and only becomes fatal once the attempts are spent. *)
      let* r, id =
        with_retries ~max_attempts:3 (fun () ->
            let* raw =
              with_timeout timeout_s
                (call_once ~key ~model ~system ~user ~max_tokens)
            in
            match parse_response raw with
            | v -> Lwt.return v
            | exception e -> Lwt.fail e)
      in
      (match r.cost with
      | Some c -> spent_usd := !spent_usd +. c
      | None -> incr unpriced_calls);
      log_usage ~model ~id ~prompt_tokens:r.prompt_tokens
        ~completion_tokens:r.completion_tokens ~cost:r.cost;
      Lwt.return r
