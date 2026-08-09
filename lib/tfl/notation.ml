(* Tokenizer, parser, and printer for TFL's plus-minus notation, ported from
   engine/tfl.js (docs/port-spec.md §§1, 3, 4). The JS engine is the executable
   specification; deliberate divergences are the recorded port-language
   decisions (spec §16): bare-name letters are ASCII-only, and error positions
   count Unicode code points — equal to the JS reference's UTF-16 indices on
   all BMP input, which is all the differential corpus generates. *)

open Ast

(* ── Errors ─────────────────────────────────────────────────────────────── *)

exception Parse_error of { message : string; pos : int }
(* [pos] is a 0-based code-point index into the source. [message] carries the
   " (at position N)" suffix, mirroring the JS ParseError's .message. *)

let parse_error message pos =
  raise
    (Parse_error
       { message = Printf.sprintf "%s (at position %d)" message pos; pos })

(* ── Code points ────────────────────────────────────────────────────────── *)

(* The source is UTF-8; the tokenizer works over its code points so that the
   notation's fixed non-ASCII symbols (− ± ′ ″, sub/superscript digits) each
   occupy a single position, as in the JS reference. Malformed bytes decode to
   U+FFFD and fall through to "Unexpected character". *)
let decode (src : string) : int array =
  (* Count first, then decode into the exact-sized array. The former cons-list
     implementation retained one boxed list cell per code point and then
     copied the whole source into an array, making large hostile inputs much
     more expensive than their byte size suggested. *)
  let i = ref 0 in
  let n = String.length src in
  let count = ref 0 in
  while !i < n do
    let d = String.get_utf_8_uchar src !i in
    i := !i + Uchar.utf_decode_length d;
    incr count
  done;
  i := 0;
  Array.init !count (fun _ ->
      let d = String.get_utf_8_uchar src !i in
      i := !i + Uchar.utf_decode_length d;
      Uchar.to_int (Uchar.utf_decode_uchar d))

let cp_to_string (c : int) : string =
  let b = Buffer.create 4 in
  Buffer.add_utf_8_uchar b (Uchar.of_int c);
  Buffer.contents b

let is_ascii_letter c = (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)
let is_ascii_digit c = c >= 0x30 && c <= 0x39
let is_subscript_digit c = c >= 0x2080 && c <= 0x2089 (* ₀–₉ *)

(* Superscript digits are not one contiguous run: ¹ ² ³ are Latin-1. *)
let superscript_value c =
  match c with
  | 0x2070 -> Some 0 (* ⁰ *)
  | 0x00B9 -> Some 1 (* ¹ *)
  | 0x00B2 -> Some 2 (* ² *)
  | 0x00B3 -> Some 3 (* ³ *)
  | c when c >= 0x2074 && c <= 0x2079 -> Some (c - 0x2070) (* ⁴–⁹ *)
  | _ -> None

(* The JS reference skips /\s/: ASCII whitespace plus a fixed set of Unicode
   spaces (its test corpus exercises NBSP and thin space). *)
let is_whitespace c =
  match c with
  | 0x09 | 0x0A | 0x0B | 0x0C | 0x0D | 0x20 | 0x00A0 | 0x1680 -> true
  | c when c >= 0x2000 && c <= 0x200A -> true
  | 0x2028 | 0x2029 | 0x202F | 0x205F | 0x3000 | 0xFEFF -> true
  | _ -> false

(* Bare-name characters, narrowed to ASCII letters per the port-language
   decision (spec §16.4); quoted terms carry ordinary Unicode while refusing
   controls that can alter terminal or bidirectional display. *)
let is_name_start c = is_ascii_letter c

let is_name_char c =
  is_ascii_letter c || is_ascii_digit c || c = 0x5F (* _ *) || c = 0x27 (* ' *)
  || is_subscript_digit c

(* A printed name needs quotes unless it's a bare identifier. *)
let is_bare_name (name : string) : bool =
  let cps = decode name in
  Array.length cps > 0
  && is_name_start cps.(0)
  && Array.for_all is_name_char cps

(* ── Tokenizer ──────────────────────────────────────────────────────────── *)

type token_kind =
  | Tok_plus
  | Tok_minus
  | Tok_wild
  | Tok_lparen
  | Tok_rparen
  | Tok_lbracket
  | Tok_rbracket
  | Tok_name of { text : string; singular : bool }
  | Tok_level of int
  | Tok_eof

type token = { kind : token_kind; pos : int }

(* Validation caps meaningful levels at 3 (spec §5); absurd digit runs are
   out-of-contract (spec §16.3) — saturate rather than overflow. *)
let level_add v d = if v >= 1_000_000_000 then v else (v * 10) + d

(* Quoted names are eventually rendered in terminals as well as JSON. C0/C1
   controls can execute terminal protocols, while Unicode bidirectional
   controls can make a displayed formula appear to contain different text.
   They have no legitimate identifier role, so refuse them at the language
   boundary instead of relying on every future renderer to remember a
   context-specific escape pass. *)
let is_unsafe_quoted_name_char c =
  (c >= 0x00 && c <= 0x1F)
  || (c >= 0x7F && c <= 0x9F)
  || c = 0x061C || c = 0x200E || c = 0x200F
  || (c >= 0x202A && c <= 0x202E)
  || (c >= 0x2066 && c <= 0x2069)

(* Where the JS engine, admitting any Unicode letter, would start a name, the
   OCaml engine sees an unrecognized character; advise quoting (spec §16.4).
   Never interpolate a terminal or bidirectional control into the diagnostic:
   a future human CLI may print the message without JSON escaping. *)
let unexpected_char c =
  if is_unsafe_quoted_name_char c then
    Printf.sprintf "Unexpected unsafe character U+%04X" c
  else
    let base = Printf.sprintf "Unexpected character '%s'" (cp_to_string c) in
    if c >= 0x80 then base ^ " (quote the term to use non-ASCII names)" else base

let tokenize (src : string) : token array =
  let cps = decode src in
  let n = Array.length cps in
  let tokens = ref [] in
  let push kind pos = tokens := { kind; pos } :: !tokens in
  let i = ref 0 in
  while !i < n do
    let c = cps.(!i) in
    match c with
    | c when is_whitespace c -> incr i
    | 0x2B (* + *) ->
        (* ASCII alias: +- is the wild-quantity sign ± (a bare minus after +
           could never start a term — negative terms are parenthesized). *)
        if !i + 1 < n && (cps.(!i + 1) = 0x2D || cps.(!i + 1) = 0x2212) then (
          push Tok_wild !i;
          i := !i + 2)
        else (
          push Tok_plus !i;
          incr i)
    | 0x2D | 0x2212 (* - − *) ->
        push Tok_minus !i;
        incr i
    | 0x00B1 (* ± *) ->
        push Tok_wild !i;
        incr i
    | 0x28 ->
        push Tok_lparen !i;
        incr i
    | 0x29 ->
        push Tok_rparen !i;
        incr i
    | 0x5B ->
        push Tok_lbracket !i;
        incr i
    | 0x5D ->
        push Tok_rbracket !i;
        incr i
    | 0x22 (* double quote *) ->
        let j = ref (!i + 1) in
        while
          !j < n
          && cps.(!j) <> 0x22
          && not (is_unsafe_quoted_name_char cps.(!j))
        do
          incr j
        done;
        if !j < n && is_unsafe_quoted_name_char cps.(!j) then
          parse_error
            "Control and bidirectional formatting characters are not allowed \
             in quoted terms"
            !j;
        if !j >= n || cps.(!j) <> 0x22 then parse_error "Unclosed quote" !i;
        if !j = !i + 1 then parse_error "Empty quoted term" !i;
        let text =
          let b = Buffer.create (!j - !i) in
          for k = !i + 1 to !j - 1 do
            Buffer.add_utf_8_uchar b (Uchar.of_int cps.(k))
          done;
          Buffer.contents b
        in
        let singular = !j + 1 < n && cps.(!j + 1) = 0x2A in
        push (Tok_name { text; singular }) !i;
        i := !j + if singular then 2 else 1
    | 0x5E (* ^ *) ->
        let j = ref (!i + 1) in
        while !j < n && is_ascii_digit cps.(!j) do
          incr j
        done;
        if !j = !i + 1 then
          parse_error "Expected digits after '^' (quantity level)" !i;
        let v = ref 0 in
        for k = !i + 1 to !j - 1 do
          v := level_add !v (cps.(k) - 0x30)
        done;
        push (Tok_level !v) !i;
        i := !j
    | c when superscript_value c <> None ->
        let v = ref 0 in
        let j = ref !i in
        let scanning = ref true in
        while !scanning && !j < n do
          match superscript_value cps.(!j) with
          | Some d ->
              v := level_add !v d;
              incr j
          | None -> scanning := false
        done;
        push (Tok_level !v) !i;
        i := !j
    | c when is_name_start c ->
        let b = Buffer.create 8 in
        let j = ref !i in
        let scanning = ref true in
        while !scanning && !j < n do
          let d = cps.(!j) in
          if d = 0x2032 (* ′ *) then (
            Buffer.add_char b '\'';
            incr j)
          else if d = 0x2033 (* ″ *) then (
            Buffer.add_string b "''";
            incr j)
          else if d = 0x22 then (
            (* a double quote after name chars is a double prime, as in A″ —
               a quoted term can never directly follow a name *)
            Buffer.add_string b "''";
            incr j)
          else if is_name_char d then (
            Buffer.add_utf_8_uchar b (Uchar.of_int d);
            incr j)
          else scanning := false
        done;
        let singular = !j < n && cps.(!j) = 0x2A in
        push (Tok_name { text = Buffer.contents b; singular }) !i;
        i := !j + if singular then 1 else 0
    | c when is_ascii_digit c ->
        parse_error "Term names must start with a letter" !i
    | c -> parse_error (unexpected_char c) !i
  done;
  push Tok_eof n;
  Array.of_list (List.rev !tokens)

(* ── Parser ─────────────────────────────────────────────────────────────── *)
(* proposition := signed signed eof
   signed      := sign term level?
   sign        := '+' | '−' | '±'
   term        := name | '(' group ')' | '[' prop-or-name ']'
   group       := sign term                  → Neg (−) / the term itself (+)
                | sign term (sign term)+     → Compound
                | term                       → the term itself (plain parens)
                | term (sign term)+          → Rel (unsigned head) *)

type state = { tokens : token array; mutable i : int }

let peek st = st.tokens.(st.i)

let advance st =
  let t = st.tokens.(st.i) in
  st.i <- st.i + 1;
  t

let token_text t =
  match t.kind with
  | Tok_eof -> "end of input"
  | Tok_name { text; singular } ->
      Printf.sprintf "'%s%s'" text (if singular then "*" else "")
  | Tok_plus -> "'+'"
  | Tok_minus -> "'−'"
  | Tok_wild -> "'±'"
  | Tok_level v -> Printf.sprintf "level marker '^%d'" v
  | Tok_lparen -> "'('"
  | Tok_rparen -> "')'"
  | Tok_lbracket -> "'['"
  | Tok_rbracket -> "']'"

let fail_at st message tok : 'a =
  parse_error message (match tok with Some t -> t.pos | None -> (peek st).pos)

let is_sign t =
  match t.kind with Tok_plus | Tok_minus | Tok_wild -> true | _ -> false

let sign_of t =
  match t.kind with Tok_plus -> Plus | Tok_minus -> Minus | _ -> Wild

let rec parse_signed st =
  let t = peek st in
  if not (is_sign t) then
    fail_at st
      (Printf.sprintf "Expected a sign (+, − or ±), found %s" (token_text t))
      (Some t);
  let sign = sign_of (advance st) in
  let term = parse_term_inner st in
  let level =
    match (peek st).kind with
    | Tok_level v ->
        ignore (advance st);
        v
    | _ -> 0
  in
  { sign; term; level }

and parse_term_inner st =
  let t = peek st in
  match t.kind with
  | Tok_name { text; singular } ->
      ignore (advance st);
      Atom { name = text; singular }
  | Tok_lparen ->
      ignore (advance st);
      parse_group st t
  | Tok_lbracket -> (
      ignore (advance st);
      let inner =
        if is_sign (peek st) then
          let subject = parse_signed st in
          let predicate = parse_signed st in
          Inner_prop { subject; predicate }
        else
          match (peek st).kind with
          | Tok_name { text; singular } ->
              ignore (advance st);
              Inner_term (Atom { name = text; singular })
          | _ ->
              fail_at st
                (Printf.sprintf
                   "Expected a proposition or statement term inside [ ], found \
                    %s"
                   (token_text (peek st)))
                None
      in
      match (peek st).kind with
      | Tok_rbracket ->
          ignore (advance st);
          PropTerm inner
      | _ ->
          fail_at st
            (Printf.sprintf "Expected ']', found %s" (token_text (peek st)))
            None)
  | _ ->
      fail_at st
        (Printf.sprintf "Expected a term, found %s" (token_text t))
        (Some t)

and parse_group st open_tok =
  let close_paren () =
    match (peek st).kind with
    | Tok_rparen -> ignore (advance st)
    | _ ->
        fail_at st
          (Printf.sprintf "Expected ')', found %s" (token_text (peek st)))
          None
  in
  if is_sign (peek st) then (
    let elements = ref [ parse_signed st ] in
    while is_sign (peek st) do
      elements := parse_signed st :: !elements
    done;
    close_paren ();
    match List.rev !elements with
    | [ { sign; term; level } ] -> (
        if level <> 0 then
          fail_at st "A quantity level cannot attach inside a bare signed group"
            (Some open_tok);
        match sign with
        | Minus -> Neg term
        | Plus -> term (* (+T) is just T *)
        | Wild ->
            fail_at st
              "A wild sign (±) needs a proposition or relational-complex \
               context"
              (Some open_tok))
    | elements -> Compound elements)
  else
    (* Unsigned first element: relational complex, or plain grouping parens. *)
    let head = parse_term_inner st in
    match (peek st).kind with
    | Tok_rparen ->
        ignore (advance st);
        head (* (T) is just T *)
    | _ ->
        let objects = ref [] in
        while is_sign (peek st) do
          objects := parse_signed st :: !objects
        done;
        if !objects = [] then
          fail_at st
            (Printf.sprintf
               "Expected a signed object or ')' after the relation term, found \
                %s"
               (token_text (peek st)))
            None;
        close_paren ();
        Rel { head; objects = List.rev !objects }

let at_end st what =
  match (peek st).kind with
  | Tok_eof -> ()
  | _ ->
      fail_at st
        (Printf.sprintf "Expected end of input after the %s, found %s" what
           (token_text (peek st)))
        None

let make_state src = { tokens = tokenize src; i = 0 }
let state_of_tokens tokens = { tokens; i = 0 }

let parse_proposition_tokens tokens =
  let st = state_of_tokens tokens in
  let subject = parse_signed st in
  let predicate = parse_signed st in
  at_end st "proposition";
  { subject; predicate }

let parse_proposition src =
  parse_proposition_tokens (tokenize src)

let parse_term src =
  let st = make_state src in
  let t = parse_term_inner st in
  at_end st "term";
  t

let parse_signed_term src =
  let st = make_state src in
  let s = parse_signed st in
  at_end st "signed term";
  s

(* ── Printer ────────────────────────────────────────────────────────────── *)
(* Canonical concrete syntax: typographic − and ±, compact spacing,
   superscript levels with level 0 omitted. Round-trip contract:
   parse (print x) is structurally equal to x for every parser-producible x. *)

let print_sign = function Plus -> "+" | Minus -> "−" | Wild -> "±"

let superscripts = [| "⁰"; "¹"; "²"; "³"; "⁴"; "⁵"; "⁶"; "⁷"; "⁸"; "⁹" |]

let print_level n =
  if n = 0 then ""
  else
    String.to_seq (string_of_int n)
    |> Seq.map (fun d -> superscripts.(Char.code d - Char.code '0'))
    |> List.of_seq |> String.concat ""

let rec print_term = function
  | Atom { name; singular } ->
      let printed = if is_bare_name name then name else "\"" ^ name ^ "\"" in
      printed ^ if singular then "*" else ""
  | Neg t -> "(−" ^ print_term t ^ ")"
  | Compound elements ->
      "(" ^ String.concat "" (List.map print_signed_term elements) ^ ")"
  | Rel { head; objects } ->
      "(" ^ print_term head
      ^ String.concat "" (List.map print_signed_term objects)
      ^ ")"
  | PropTerm (Inner_prop p) -> "[" ^ print_proposition p ^ "]"
  | PropTerm (Inner_term t) -> "[" ^ print_term t ^ "]"

and print_signed_term st =
  print_sign st.sign ^ print_term st.term ^ print_level st.level

and print_proposition p =
  print_signed_term p.subject ^ print_signed_term p.predicate
