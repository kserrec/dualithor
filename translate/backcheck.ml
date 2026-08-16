(* PLAN 4.4 — the back-translation fidelity check.

   Render the model's own formula back into English with the engine's
   deterministic renderer (1.9), then ask a judge whether that reading makes the
   same claim as the source sentence. A disagreement means the formula does not
   say what the sentence said, whatever else is true of it.

   **Why this and not a prompt patch.** A targeted few-shot example fixes the one
   error you already found and generalises to nothing; you can only patch bugs
   you have discovered. This check is *blind to which bug it is catching* — it
   compares meanings, so it flags error classes nobody anticipated. Prompt
   patching buys coverage; this buys correctness, and the two must not be
   confused (decided 2026-08-01).

   It is also the one step here with no FOL counterpart. Verbalising an
   arbitrary first-order formula is a judgment call, so there is no canonical
   English reading to audit against. Determinism is what makes the comparison
   mean something.

   **The judge never sees the formula.** It gets the source sentence and the
   rendering, nothing else. Showing it the TFL would let it reconstruct the
   intended reading and rate the formula it can see rather than the English it
   produced — which is exactly the failure being tested for. *)

open Lwt.Syntax

type judgement = {
  nl : string;
  rendering : string;
  score : int; (* 0 disagrees · 1 partial · 2 agrees *)
  note : string; (* what differs; empty when the pair agrees *)
}

(* [Partial] is deliberately not folded into either side. A partial reading is
   the case a human should look at, and collapsing it into "agrees" would hide
   exactly the near-misses this check exists to surface. *)
type outcome = Agrees | Partial | Disagrees

let outcome_of j =
  match j.score with 2 -> Agrees | 1 -> Partial | _ -> Disagrees

let outcome_name = function
  | Agrees -> "agrees"
  | Partial -> "partial"
  | Disagrees -> "disagrees"

(* ── Rendering ────────────────────────────────────────────────────────────
   Through the 3.4 readable orientation, so a relational subject reads
   subject-first ("some boy lov some girl") rather than word-for-word. The
   formal object is never rewritten — only its English reading. *)

let render (p : Tfl.Ast.prop) : string =
  Tfl.Render.read_prop (Tfl_verify.readable_orientation p)

(* ── The judge ────────────────────────────────────────────────────────────
   The prompt spends most of its length on one instruction: awkwardness is not
   disagreement. The renderer is deterministic and stilted by design, and a
   judge that penalises stiltedness would flag faithful translations — which
   costs coverage while catching nothing. Pre-registered expectation (1B.3):
   5–20% false positives, and above ~20% the check costs more than it buys. *)

let system =
  {|You compare two statements and decide whether they make the same claim.

The first is a sentence written by a person. The second is a mechanical reading
produced by a logic engine — it is deterministic, terse, and often ungrammatical.

**Awkward wording is NOT a disagreement.** The machine reading drops articles,
abbreviates verbs to stems, and repeats nouns instead of using pronouns. "every
man lov some woman" is a perfectly good reading of "Every man loves some woman."
Judge only whether the two make the same claim about the same things.

What IS a disagreement:
- the quantity changed (every ↔ some ↔ most)
- the quality changed (is ↔ is not; a claim became its opposite)
- subject and predicate swapped in a way that changes what is asserted
- a term was dropped, added, or replaced by something that means something else
- the scope of a relation changed (loves some girl ↔ loves every girl)

Score each pair:
  2 — the same claim
  1 — nearly the same, but something is missing, added, or weakened
  0 — a different claim, including one that asserts the opposite

Answer with one JSON object and nothing else — no prose, no markdown fence:

{"judgements": [{"n": 1, "score": 2, "note": ""}]}

`n` is the pair number as given. `note` says what differs, in a few words, and
is empty when the score is 2.|}

let user (pairs : (string * string) list) : string =
  let block i (nl, rendering) =
    Printf.sprintf "%d.\n  person:  %s\n  machine: %s" (i + 1) nl rendering
  in
  Printf.sprintf
    "Judge each of these %d pairs. Return the JSON object described above and \
     nothing else.\n\n\
     %s"
    (List.length pairs)
    (String.concat "\n\n" (List.mapi block pairs))

(* ── Reading the judge's reply ────────────────────────────────────────────
   Shape-only validation, same discipline as 4.1: a malformed reply is an
   [Error], never a silently-dropped judgement. A missing judgement would
   otherwise read as "no disagreement found", which is the wrong default for a
   safety check. *)

let parse_reply (n : int) (raw : string) :
    ((int * int * string) list, string) result =
  let open Yojson.Safe.Util in
  match Yojson.Safe.from_string (Schema.strip_fence raw) with
  | exception _ -> Error "judge reply is not JSON"
  | j -> (
      match member "judgements" j with
      | `List items -> (
          try
            let parsed =
              List.map
                (fun it ->
                  let idx = it |> member "n" |> to_int in
                  let score = it |> member "score" |> to_int in
                  let note =
                    match member "note" it with `String s -> s | _ -> ""
                  in
                  if idx < 1 || idx > n then
                    failwith "judgement index out of range";
                  if score < 0 || score > 2 then failwith "score outside 0..2";
                  (idx, score, note))
                items
            in
            Ok parsed
          with
          | Type_error (m, _) -> Error m
          | Failure m -> Error m)
      | _ -> Error "judge reply has no \"judgements\" array")

(* ── The call ─────────────────────────────────────────────────────────────
   A pair the judge never scored comes back as [Disagrees] with a note saying
   so: for a check whose job is catching bad translations, silence must fail
   closed, never open. *)

let max_tokens = 4000

let check ~(model : string) (pairs : (string * Tfl.Ast.prop) list) :
    (judgement list, string) result Lwt.t =
  let rendered = List.map (fun (nl, p) -> (nl, render p)) pairs in
  let user = user rendered in
  let* raw, _from_cache =
    match Cache.find ~model ~system ~user with
    | Some body -> Lwt.return (body, true)
    | None ->
        let+ (r : Llm_client.response) =
          Llm_client.complete ~model ~system ~user ~max_tokens ()
        in
        Cache.store ~model ~system ~user r.content;
        (r.content, false)
  in
  match parse_reply (List.length rendered) raw with
  | Error why -> Lwt.return (Error why)
  | Ok scored ->
      let find i = List.find_opt (fun (idx, _, _) -> idx = i) scored in
      Lwt.return
        (Ok
           (List.mapi
              (fun i (nl, rendering) ->
                match find (i + 1) with
                | Some (_, score, note) -> { nl; rendering; score; note }
                | None ->
                    {
                      nl;
                      rendering;
                      score = 0;
                      note = "the judge returned no verdict";
                    })
              rendered))
