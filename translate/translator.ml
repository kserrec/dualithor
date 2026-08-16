(* PLAN 4.3 — the translator harness.

   One model, a list of sentences, one call: validate the payload (4.1), parse
   every returned formula through the engine's total API, and classify each
   input sentence into exactly one outcome.

   **A parse failure is data, not an error.** It comes back carrying its 1.14
   taxonomy class, because the whole router claim rests on the difference
   between "the notation cannot carry this sentence" and "the model wrote
   something malformed" — and we cannot measure that difference if the harness
   throws the failure away. Likewise a declined sentence is a first-class
   result: it is the model using the escape hatch the prompt gives it.

   [Absent] exists for the failure nobody notices otherwise: a model that
   silently drops a sentence would, without it, simply shrink the denominator
   and flatter every rate we report. *)

open Lwt.Syntax

type outcome =
  | Translated of { tfl : string; prop : Tfl.Ast.prop; confidence : float }
  | Unparseable of {
      tfl : string;
      failure : Tfl.Safe.failure; (* carries the Lexical/Syntactic/… class *)
      confidence : float;
    }
  | Declined of { reason : string }
  | Absent (* the model returned nothing for this sentence *)

type item = { nl : string; outcome : outcome }

type run = {
  model : string;
  items : item list; (* one per input sentence, in input order *)
  extra : string list; (* nl strings returned that we never sent *)
  from_cache : bool;
}

(* ── Matching replies to inputs ────────────────────────────────────────────
   The prompt asks for [nl] copied verbatim, and models mostly comply — but
   "mostly" is not a basis for attributing a formula to a sentence, and
   attributing one to the wrong sentence would corrupt the fidelity audit in a
   way no downstream check could catch. So matching is on a normalised key
   (case-folded, whitespace-collapsed) and nothing looser: a paraphrase does
   not match, and its sentence is reported [Absent] rather than paired with a
   formula that may be about something else. *)

let match_key (s : string) : string =
  let b = Buffer.create (String.length s) in
  let pending_space = ref false in
  String.iter
    (fun c ->
      match c with
      | ' ' | '\t' | '\n' | '\r' ->
          if Buffer.length b > 0 then pending_space := true
      | c ->
          if !pending_space then Buffer.add_char b ' ';
          pending_space := false;
          Buffer.add_char b (Char.lowercase_ascii c))
    s;
  Buffer.contents b

(* First occurrence wins: a model that repeats a sentence gets its first
   answer used, and the duplicate surfaces in [extra]. *)
let index_by_nl (nls : (string * 'a) list) : (string, 'a) Hashtbl.t =
  let t = Hashtbl.create 16 in
  List.iter
    (fun (nl, v) ->
      let k = match_key nl in
      if not (Hashtbl.mem t k) then Hashtbl.add t k v)
    nls;
  t

let classify (p : Schema.payload) (sentences : string list) :
    item list * string list =
  let translations =
    index_by_nl
      (List.map (fun (t : Schema.translation) -> (t.nl, t)) p.translations)
  in
  let declines =
    index_by_nl
      (List.map (fun (u : Schema.untranslatable) -> (u.nl, u)) p.untranslatable)
  in
  let claimed = Hashtbl.create 16 in
  let items =
    List.map
      (fun nl ->
        let k = match_key nl in
        match Hashtbl.find_opt translations k with
        | Some (t : Schema.translation) ->
            Hashtbl.replace claimed k ();
            let outcome =
              match Tfl.Safe.parse t.tfl with
              | Ok prop ->
                  Translated { tfl = t.tfl; prop; confidence = t.confidence }
              | Error failure ->
                  Unparseable
                    { tfl = t.tfl; failure; confidence = t.confidence }
            in
            { nl; outcome }
        | None -> (
            match Hashtbl.find_opt declines k with
            | Some (u : Schema.untranslatable) ->
                Hashtbl.replace claimed k ();
                { nl; outcome = Declined { reason = u.reason } }
            | None -> { nl; outcome = Absent }))
      sentences
  in
  (* Exactly one reply per claimed sentence is consumed here; a second reply
     for the same sentence is a repeat and must surface. A model answering one
     sentence twice, with different formulas, is disagreeing with itself and we
     picked one arbitrarily — silently discarding the other would hide that. *)
  let consumed = Hashtbl.create 16 in
  let extra =
    List.filter_map
      (fun nl ->
        let k = match_key nl in
        if Hashtbl.mem claimed k && not (Hashtbl.mem consumed k) then (
          Hashtbl.replace consumed k ();
          None)
        else Some nl)
      (List.map (fun (t : Schema.translation) -> t.nl) p.translations
      @ List.map (fun (u : Schema.untranslatable) -> u.nl) p.untranslatable)
  in
  (items, extra)

(* ── Rates ────────────────────────────────────────────────────────────────
   Reported as counts alongside every rate, because a rate over a handful of
   items reads as more solid than it is. [parse_rate] is deliberately over
   *attempted* translations only — a declined sentence is not a failed parse,
   and folding the two together would let a model improve its parse rate by
   declining everything hard. *)

type stats = {
  total : int;
  translated : int;
  unparseable : int;
  declined : int;
  absent : int;
}

let stats (items : item list) : stats =
  List.fold_left
    (fun s i ->
      match i.outcome with
      | Translated _ -> { s with translated = s.translated + 1 }
      | Unparseable _ -> { s with unparseable = s.unparseable + 1 }
      | Declined _ -> { s with declined = s.declined + 1 }
      | Absent -> { s with absent = s.absent + 1 })
    {
      total = List.length items;
      translated = 0;
      unparseable = 0;
      declined = 0;
      absent = 0;
    }
    items

let parse_rate (s : stats) : float option =
  let attempted = s.translated + s.unparseable in
  if attempted = 0 then None
  else Some (float_of_int s.translated /. float_of_int attempted)

(* ── The call ─────────────────────────────────────────────────────────────
   A malformed payload is returned as [Error], not raised and not partially
   salvaged: if the wrapper is wrong we have no trustworthy way to say which
   formula belongs to which sentence, and guessing is how a fidelity number
   becomes fiction. *)

let max_tokens = 4000

let translate ~(model : string) (sentences : string list) :
    (run, string) result Lwt.t =
  let system = Prompts.system in
  let user = Prompts.user sentences in
  let* raw, from_cache =
    match Cache.find ~model ~system ~user with
    | Some body -> Lwt.return (body, true)
    | None ->
        let+ (r : Llm_client.response) =
          Llm_client.complete ~model ~system ~user ~max_tokens ()
        in
        Cache.store ~model ~system ~user r.content;
        (r.content, false)
  in
  match Schema.of_string raw with
  | Error why -> Lwt.return (Error why)
  | Ok payload ->
      let items, extra = classify payload sentences in
      Lwt.return (Ok { model; items; extra; from_cache })
