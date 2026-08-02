(* PLAN 4.1 — the translation contract.

   The one JSON shape a translator model is allowed to answer with:

   {"translations":  [{"nl": …, "tfl": …, "confidence": 0.0–1.0}],
    "untranslatable": [{"nl": …, "reason": …}]}

   Every sentence we send comes back in exactly one of the two arrays — the
   second is where the router claim lives, so a model declining a sentence is
   a first-class answer here, not an error.

   This module validates *shape only*. Whether the "tfl" string is a real
   proposition is the harness's question (4.3), where a parse failure is
   recorded with its 1.14 taxonomy class rather than discarded — so the
   translate library stays independent of the engine, and a malformed payload
   is never confused with an unparseable formula. *)

type translation = { nl : string; tfl : string; confidence : float }
type untranslatable = { nl : string; reason : string }

type payload = {
  translations : translation list;
  untranslatable : untranslatable list;
}

(* ── Validation ───────────────────────────────────────────────────────────
   Rejections carry the path to the offending value ("translations[2].tfl"),
   because these reasons are what we will read when a model's parse rate
   collapses and we need to know whether it was the formulas or the wrapper. *)

exception Bad of string

let bad fmt = Printf.ksprintf (fun s -> raise (Bad s)) fmt

(* Enough of the offending value to recognize it, never enough to bury the
   reason under a whole payload. *)
let abbrev (j : Yojson.Safe.t) =
  let s = Yojson.Safe.to_string j in
  if String.length s <= 60 then s else String.sub s 0 60 ^ "…"

let string_field ~where name (j : Yojson.Safe.t) =
  match Yojson.Safe.Util.member name j with
  | `String "" -> bad "%s.%s: must not be empty" where name
  | `String s -> s
  | `Null -> bad "%s.%s: missing" where name
  | other -> bad "%s.%s: expected a string, got %s" where name (abbrev other)

let confidence_field ~where (j : Yojson.Safe.t) =
  let v =
    match Yojson.Safe.Util.member "confidence" j with
    | `Float f -> f
    | `Int n -> float_of_int n
    | `Null -> bad "%s.confidence: missing" where
    | other ->
        bad "%s.confidence: expected a number in [0,1], got %s" where
          (abbrev other)
  in
  if Float.is_nan v || v < 0. || v > 1. then
    bad "%s.confidence: expected a number in [0,1], got %g" where v
  else v

let object_at ~where (j : Yojson.Safe.t) =
  match j with
  | `Assoc _ -> j
  | other -> bad "%s: expected an object, got %s" where (abbrev other)

(* An absent array means an empty one: a model with nothing to decline often
   omits "untranslatable" entirely, and rejecting the payload for that would
   throw away real translations and report a formatting habit as a translation
   failure. An absent *pair* of arrays is still a refusal — see [validate]. *)
let array_field name (j : Yojson.Safe.t) =
  match Yojson.Safe.Util.member name j with
  | `Null -> None
  | `List items -> Some items
  | other -> bad "%s: expected an array, got %s" name (abbrev other)

let validate (j : Yojson.Safe.t) : (payload, string) result =
  try
    ignore (object_at ~where:"payload" j);
    let ts = array_field "translations" j in
    let us = array_field "untranslatable" j in
    if ts = None && us = None then
      bad "payload: neither \"translations\" nor \"untranslatable\" is present";
    let translations =
      List.mapi
        (fun i item ->
          let where = Printf.sprintf "translations[%d]" i in
          let item = object_at ~where item in
          {
            nl = string_field ~where "nl" item;
            tfl = string_field ~where "tfl" item;
            confidence = confidence_field ~where item;
          })
        (Option.value ts ~default:[])
    in
    let untranslatable =
      List.mapi
        (fun i item ->
          let where = Printf.sprintf "untranslatable[%d]" i in
          let item = object_at ~where item in
          {
            nl = string_field ~where "nl" item;
            reason = string_field ~where "reason" item;
          })
        (Option.value us ~default:[])
    in
    Ok { translations; untranslatable }
  with Bad why -> Error why

(* Models fence JSON in markdown often enough that rejecting it would score a
   formatting habit as a translation failure. One leading ``` / ```json line
   and its closing fence come off; anything else passes through untouched. *)
let strip_fence (s : string) : string =
  let s = String.trim s in
  let starts_fenced = String.length s >= 3 && String.sub s 0 3 = "```" in
  if not starts_fenced then s
  else
    match String.index_opt s '\n' with
    | None -> s
    | Some nl ->
        let body =
          String.trim (String.sub s (nl + 1) (String.length s - nl - 1))
        in
        let n = String.length body in
        if n >= 3 && String.sub body (n - 3) 3 = "```" then
          String.trim (String.sub body 0 (n - 3))
        else body

let of_string (raw : string) : (payload, string) result =
  match Yojson.Safe.from_string (strip_fence raw) with
  | j -> validate j
  | exception Yojson.Json_error why -> Error ("not JSON: " ^ why)
  | exception e -> Error ("not JSON: " ^ Printexc.to_string e)
