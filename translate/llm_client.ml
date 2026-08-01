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

let endpoint = Uri.of_string "https://openrouter.ai/api/v1/chat/completions"
let usage_path = "data/usage.jsonl"

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
  if code >= 200 && code < 300 then Lwt.return raw
  else
    let msg = Printf.sprintf "HTTP %d: %s" code (truncate_msg raw) in
    if code = 429 || code >= 500 then Lwt.fail (Retryable msg)
    else Lwt.fail (Llm_error msg)

let with_timeout timeout_s thunk =
  Lwt.pick
    [
      thunk ();
      (let* () = Lwt_unix.sleep timeout_s in
       Lwt.fail (Retryable (Printf.sprintf "timeout after %.0fs" timeout_s)));
    ]

let parse_response raw =
  let open Yojson.Safe.Util in
  let fail why = raise (Llm_error (why ^ ": " ^ truncate_msg raw)) in
  let json =
    try Yojson.Safe.from_string raw with _ -> fail "unparseable response body"
  in
  (* OpenRouter can answer 200 with an {"error": …} payload. *)
  (match member "error" json with
  | `Null -> ()
  | e -> fail ("provider error " ^ Yojson.Safe.to_string e));
  try
    let content =
      json |> member "choices" |> index 0 |> member "message"
      |> member "content" |> to_string
    in
    let id = try json |> member "id" |> to_string with _ -> "" in
    let usage = member "usage" json in
    let tok name = match member name usage with `Int n -> n | _ -> 0 in
    let cost =
      match member "cost" usage with `Float c -> Some c | _ -> None
    in
    ( {
        content;
        prompt_tokens = tok "prompt_tokens";
        completion_tokens = tok "completion_tokens";
        cost;
      },
      id )
  with Type_error _ -> fail "unexpected response shape"

let complete ?(timeout_s = 120.) ~model ~system ~user ~max_tokens () =
  let key = api_key () in
  let rec go attempt delay =
    Lwt.catch
      (fun () ->
        with_timeout timeout_s (call_once ~key ~model ~system ~user ~max_tokens))
      (fun exn ->
        let retry msg =
          if attempt >= 3 then
            Lwt.fail (Llm_error (msg ^ " (after 3 attempts)"))
          else
            let* () = Lwt_unix.sleep delay in
            go (attempt + 1) (delay *. 2.)
        in
        match exn with
        | Retryable msg -> retry msg
        | Llm_error _ as e -> Lwt.fail e
        | exn -> retry (Printexc.to_string exn))
  in
  let* raw = go 1 1.0 in
  let r, id = parse_response raw in
  log_usage ~model ~id ~prompt_tokens:r.prompt_tokens
    ~completion_tokens:r.completion_tokens ~cost:r.cost;
  Lwt.return r
