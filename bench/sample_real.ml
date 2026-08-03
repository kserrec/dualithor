(* PLAN 4.6 — the real-text sample.

   Implements `data/fidelity/real/PROTOCOL.md` exactly and nothing beyond it.
   Read that first: the procedure is pre-registered because the coverage number
   it feeds is trivially manipulable, and every filter here biases that number.

   Deterministic by construction — no randomness, no shuffling — so re-running
   against the same eCFR snapshot reproduces the sample byte for byte.

   Input:  data/raw/cfr-{title}-{part}.xml   (gitignored; US federal, public domain)
   Output: data/fidelity/real/sample.jsonl   (committed) *)

let sources =
  [ ("7", "273", "SNAP: certification of eligible households");
    ("20", "416", "SSI for the aged, blind, and disabled");
    ("24", "5", "HUD programs: general requirements") ]

let per_part = 20
let out_path = "data/fidelity/real/sample.jsonl"

let read_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

(* ── Extraction (PROTOCOL "Extraction" 1–3) ──────────────────────────────── *)

(* Contents of every <P> element. Headings, tables and citation-only elements
   are not <P> and so never enter the pool. *)
let paragraphs (xml : string) : string list =
  let out = ref [] and i = ref 0 in
  let n = String.length xml in
  let find_from pat from =
    let pl = String.length pat in
    let rec go j = if j + pl > n then None
      else if String.sub xml j pl = pat then Some j else go (j + 1)
    in
    go from
  in
  let continue_ = ref true in
  while !continue_ do
    match find_from "<P>" !i with
    | None -> continue_ := false
    | Some s -> (
        match find_from "</P>" (s + 3) with
        | None -> continue_ := false
        | Some e ->
            out := String.sub xml (s + 3) (e - s - 3) :: !out;
            i := e + 4)
  done;
  List.rev !out

(* Only <I> and <E> occur inside <P> in this corpus; drop any tag anyway. *)
let strip_tags (s : string) : string =
  let b = Buffer.create (String.length s) in
  let depth = ref 0 in
  String.iter
    (fun c ->
      if c = '<' then incr depth
      else if c = '>' then (if !depth > 0 then decr depth)
      else if !depth = 0 then Buffer.add_char b c)
    s;
  Buffer.contents b

let entities =
  [ ("&amp;", "&"); ("&lt;", "<"); ("&gt;", ">"); ("&quot;", "\"");
    ("&apos;", "'"); ("&#8212;", "\xe2\x80\x94"); ("&#8211;", "\xe2\x80\x93");
    ("&#8217;", "'"); ("&#8220;", "\""); ("&#8221;", "\""); ("&#167;", "\xc2\xa7");
    ("&nbsp;", " "); ("&#160;", " ") ]

let replace_all ~sub ~by s =
  let sl = String.length sub and n = String.length s in
  if sl = 0 then s
  else begin
    let b = Buffer.create n in
    let i = ref 0 in
    while !i < n do
      if !i + sl <= n && String.sub s !i sl = sub then (Buffer.add_string b by; i := !i + sl)
      else (Buffer.add_char b s.[!i]; incr i)
    done;
    Buffer.contents b
  end

(* Numeric character references, decimal (&#167;) and hex (&#xA7;), encoded as
   UTF-8. The named table above does not cover them and the corpus is full of
   both — section signs and em dashes especially. Without this the sampled text
   carries raw "&#xA7;" where regulation says "\xc2\xa7". *)
let utf8_of_code b cp =
  if cp < 0x80 then Buffer.add_char b (Char.chr cp)
  else if cp < 0x800 then (
    Buffer.add_char b (Char.chr (0xC0 lor (cp lsr 6)));
    Buffer.add_char b (Char.chr (0x80 lor (cp land 0x3F))))
  else if cp < 0x10000 then (
    Buffer.add_char b (Char.chr (0xE0 lor (cp lsr 12)));
    Buffer.add_char b (Char.chr (0x80 lor ((cp lsr 6) land 0x3F)));
    Buffer.add_char b (Char.chr (0x80 lor (cp land 0x3F))))
  else (
    Buffer.add_char b (Char.chr (0xF0 lor (cp lsr 18)));
    Buffer.add_char b (Char.chr (0x80 lor ((cp lsr 12) land 0x3F)));
    Buffer.add_char b (Char.chr (0x80 lor ((cp lsr 6) land 0x3F)));
    Buffer.add_char b (Char.chr (0x80 lor (cp land 0x3F))))

let decode_numeric (s : string) : string =
  let n = String.length s in
  let b = Buffer.create n in
  let i = ref 0 in
  while !i < n do
    if !i + 2 < n && s.[!i] = '&' && s.[!i + 1] = '#' then (
      match String.index_from_opt s !i ';' with
      | Some j when j - !i <= 10 ->
          let body = String.sub s (!i + 2) (j - !i - 2) in
          let parsed =
            try
              if String.length body > 1 && (body.[0] = 'x' || body.[0] = 'X') then
                Some (int_of_string ("0x" ^ String.sub body 1 (String.length body - 1)))
              else Some (int_of_string body)
            with _ -> None
          in
          (match parsed with
          | Some cp when cp > 0 && cp < 0x110000 -> utf8_of_code b cp; i := j + 1
          | _ -> Buffer.add_char b s.[!i]; incr i)
      | _ -> Buffer.add_char b s.[!i]; incr i)
    else (Buffer.add_char b s.[!i]; incr i)
  done;
  Buffer.contents b

let decode s =
  decode_numeric (List.fold_left (fun acc (a, b) -> replace_all ~sub:a ~by:b acc) s entities)

let squeeze (s : string) : string =
  let b = Buffer.create (String.length s) in
  let sp = ref true in
  String.iter
    (fun c ->
      let c = if c = '\n' || c = '\t' || c = '\r' then ' ' else c in
      if c = ' ' then (if not !sp then Buffer.add_char b ' '; sp := true)
      else (Buffer.add_char b c; sp := false))
    s;
  String.trim (Buffer.contents b)

(* Leading enumerated-paragraph markers: "(a)", "(a)(1)", "(iv)" — numbering,
   not sentence content. *)
let strip_markers (s : string) : string =
  let n = String.length s in
  let rec go i =
    if i < n && s.[i] = '(' then
      match String.index_from_opt s i ')' with
      | Some j when j - i <= 6 ->
          let k = ref (j + 1) in
          while !k < n && s.[!k] = ' ' do incr k done;
          go !k
      | _ -> i
    else i
  in
  let i = go 0 in
  String.sub s i (n - i)

(* ── Sentence splitting (PROTOCOL "Extraction" 4) ────────────────────────── *)

let protected_abbrevs =
  [ "U.S.C."; "C.F.R."; "Pub. L."; "No."; "Nos."; "Sec."; "Secs."; "e.g.";
    "i.e."; "etc."; "cf."; "Dr."; "Mr."; "Mrs."; "Ms."; "St."; "Jr."; "vs." ]

(* Does the text ending at [i] (inclusive of the period) finish an abbreviation
   we must not split on? Also protects a single capital letter + period, as in
   "J. Smith" and the lettered citations regulation is full of. *)
let ends_protected (s : string) (i : int) : bool =
  List.exists
    (fun a ->
      let al = String.length a in
      i + 1 >= al && String.sub s (i + 1 - al) al = a)
    protected_abbrevs
  || (i >= 1
      && (let c = s.[i - 1] in
          c >= 'A' && c <= 'Z')
      && (i = 1 || s.[i - 2] = ' ' || s.[i - 2] = '('))

let split_sentences (s : string) : string list =
  let n = String.length s in
  let out = ref [] and start = ref 0 in
  let i = ref 0 in
  while !i < n do
    let c = s.[!i] in
    if (c = '.' || c = '?' || c = ':') && not (ends_protected s !i) then begin
      (* boundary iff followed by whitespace then a capital *)
      let j = ref (!i + 1) in
      let saw_space = ref false in
      while !j < n && s.[!j] = ' ' do saw_space := true; incr j done;
      if !saw_space && !j < n && s.[!j] >= 'A' && s.[!j] <= 'Z' then begin
        out := String.sub s !start (!i + 1 - !start) :: !out;
        start := !j;
        i := !j
      end
      else incr i
    end
    else incr i
  done;
  if !start < n then out := String.sub s !start (n - !start) :: !out;
  List.rev_map String.trim !out |> List.rev

(* ── Candidate filter (PROTOCOL "Candidate filter") ──────────────────────── *)

let words s = List.filter (fun w -> w <> "") (String.split_on_char ' ' s)
let has_lower s = String.exists (fun c -> c >= 'a' && c <= 'z') s

let is_candidate (s : string) : bool =
  String.length s > 0
  && s.[String.length s - 1] = '.'
  && List.length (words s) >= 5
  && has_lower s
(* No upper length bound, deliberately — see the protocol. Dropping long
   sentences would delete the evidence for the very refusal reason §1B.1
   predicts will dominate, and would inflate coverage by exactly the amount
   that matters. *)

(* ── Sampling (PROTOCOL "Sample") ────────────────────────────────────────── *)

let take_every_kth (xs : 'a list) (want : int) : 'a list =
  let n = List.length xs in
  if n <= want then xs
  else
    let k = max 1 (n / want) in
    let picked =
      List.filteri (fun i _ -> i mod k = 0) xs
    in
    List.filteri (fun i _ -> i < want) picked

let json_escape s =
  let b = Buffer.create (String.length s + 8) in
  String.iter
    (fun c ->
      match c with
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | c when Char.code c < 0x20 -> Buffer.add_string b (Printf.sprintf "\\u%04x" (Char.code c))
      | c -> Buffer.add_char b c)
    s;
  Buffer.contents b

let () =
  let oc = open_out out_path in
  Fun.protect ~finally:(fun () -> close_out_noerr oc) @@ fun () ->
  let total = ref 0 in
  List.iter
    (fun (title, part, subject) ->
      let path = Printf.sprintf "data/raw/cfr-%s-%s.xml" title part in
      if not (Sys.file_exists path) then
        failwith (path ^ " missing — see data/fidelity/real/PROTOCOL.md for the fetch URL");
      let candidates =
        paragraphs (read_file path)
        |> List.map (fun p -> squeeze (decode (strip_tags p)))
        |> List.concat_map split_sentences
        |> List.map (fun s -> squeeze (strip_markers s))
        |> List.filter is_candidate
      in
      let picked = take_every_kth candidates per_part in
      Printf.printf "%-14s %5d paragraphs-worth of candidates, sampled %d\n%!"
        (Printf.sprintf "%s CFR %s" title part)
        (List.length candidates) (List.length picked);
      List.iteri
        (fun i s ->
          incr total;
          Printf.fprintf oc
            {|{"id": "r%02d", "source": "%s CFR %s", "subject": "%s", "n": %d, "nl": "%s"}|}
            !total title part subject i (json_escape s);
          output_char oc '\n')
        picked)
    sources;
  Printf.printf "\nwrote %d sentences to %s\n" !total out_path
