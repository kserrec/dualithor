(* Engine result records serialized to the JS engine's exact JSON shapes
   (port-spec §17), for the differential harness: proofs, certificates,
   checkArgument results, passives, programs, queries, consistency, and
   equivalence decisions. Optional fields are emitted only when the JS object
   would carry the key. Also home to the §16.4 message normalization the
   error-carrying records need. *)

let advisory = " (quote the term to use non-ASCII names)"

(* Remove the first occurrence of [advisory] (the recorded §16.4 divergence:
   the OCaml engine appends a quoting hint the JS reference does not have). *)
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

(* ── Inference core (1.4) ───────────────────────────────────────────────── *)

let occ_to_json (o : Tfl.Infer.occurrence) : Yojson.Safe.t =
  let open Tfl.Infer in
  `Assoc
    [
      ("term", Ast_json.term_to_json o.occ_term);
      ( "path",
        `List
          (`String
             (match o.side with
             | On_subject -> "subject"
             | On_predicate -> "predicate")
          :: List.map
               (function Occ_neg -> `String "neg" | Occ_at i -> `Int i)
               o.steps) );
      ("sign", `Int o.occ_sign);
      ("ownWild", `Bool o.own_wild);
    ]

(* ── Proofs and verdicts (1.5/1.6/1.8) ──────────────────────────────────── *)

let line_to_json (l : Tfl.Derive.line) : Yojson.Safe.t =
  `Assoc
    [
      ("n", `Int l.n);
      ( "prop",
        match l.l_prop with Some p -> Ast_json.prop_to_json p | None -> `Null
      );
      ("text", `String l.text);
      ("rule", `String l.rule);
      ("parents", `List (List.map (fun i -> `Int i) l.parents));
    ]

let proof_to_json (pr : Tfl.Derive.proof) : Yojson.Safe.t =
  `Assoc
    [
      ("found", `Bool pr.found);
      ("lines", `List (List.map line_to_json pr.lines));
    ]

let cancellation_to_json (c : Tfl.Decide.cancellation) : Yojson.Safe.t =
  `Assoc
    [
      ("particular", Ast_json.prop_to_json c.particular);
      ( "universals",
        `List
          (List.map
             (fun (p, times) ->
               `Assoc
                 [ ("prop", Ast_json.prop_to_json p); ("times", `Int times) ])
             c.universals) );
    ]

let certificate_to_json (c : Tfl.Decide.certificate) : Yojson.Safe.t =
  `Assoc
    [
      ("point", `List (List.map (fun k -> `String k) c.point));
      ( "clash",
        match c.clash with
        | Some (a, b) -> `List [ `String a; `String b ]
        | None -> `Null );
      ( "cancellation",
        match c.cancellation with
        | Some x -> cancellation_to_json x
        | None -> `Null );
    ]

let decision_record_to_json (d : Tfl.Decide.numerical_decision) :
    Yojson.Safe.t =
  `Assoc
    [
      ("valid", `Bool d.n_valid);
      ( "conditions",
        `Assoc
          [
            ("sum", `Bool d.sum);
            ("particular", `Bool d.n_particular);
            ("level", `Bool d.level_ok);
          ] );
      ("carriedLevel", `Int d.carried_level);
      ("conclusionLevel", `Int d.conclusion_level);
      ("particularPremises", `Int d.particular_premises);
      ("particularConclusions", `Int d.particular_conclusions);
    ]

let result_to_json (r : Tfl.Decide.result) : Yojson.Safe.t =
  `Assoc
    ([
       ( "verdict",
         `String
           (match r.verdict with
           | Valid -> "valid"
           | Invalid -> "invalid"
           | Contradicted -> "contradicted"
           | Unknown -> "unknown") );
       ( "method",
         `String
           (match r.meth with
           | PZ -> "PZ"
           | Derivation -> "derivation"
           | Indirect -> "indirect"
           | Numerical -> "numerical") );
     ]
    @ (match r.decision with
      | Some d -> [ ("decision", decision_record_to_json d) ]
      | None -> [])
    @ (match r.certificate with
      | Some c -> [ ("certificate", certificate_to_json c) ]
      | None -> [])
    @
    match r.proof with
    | Some pr -> [ ("proof", proof_to_json pr) ]
    | None -> [])

(* ── Relational layer (1.6) ─────────────────────────────────────────────── *)

let passive_to_json (r : Tfl.Relational.passive) : Yojson.Safe.t =
  `Assoc
    [
      ("prop", Ast_json.prop_to_json r.p_prop);
      ("equivalent", `Bool r.equivalent);
      ("swapped", `Int r.swapped);
    ]

(* ── Programs, queries, equivalence (1.7) ───────────────────────────────── *)

let program_to_json (r : Tfl.Program.parsed_program) : Yojson.Safe.t =
  `Assoc
    [
      ( "propositions",
        `List
          (List.map
             (fun (e : Tfl.Program.program_entry) ->
               `Assoc
                 [
                   ("prop", Ast_json.prop_to_json e.prop);
                   ("text", `String e.text);
                   ("line", `Int e.line);
                 ])
             r.propositions) );
      ( "errors",
        `List
          (List.map
             (fun (e : Tfl.Program.program_error) ->
               `Assoc
                 [
                   ("line", `Int e.err_line);
                   ("message", `String (strip_advisory e.err_message));
                   ("pos", `Int e.err_pos);
                 ])
             r.errors) );
    ]

let query_answers_to_json (answers : (Tfl.Ast.prop * string) list) :
    Yojson.Safe.t =
  `List
    (List.map
       (fun (p, text) ->
         `Assoc [ ("prop", Ast_json.prop_to_json p); ("text", `String text) ])
       answers)

let prop_query_to_json (r : Tfl.Program.prop_query) : Yojson.Safe.t =
  `Assoc
    (( "verdict",
       `String
         (match r.q_verdict with
         | Q_yes -> "yes"
         | Q_no -> "no"
         | Q_unknown -> "unknown") )
    ::
    (match r.support with
    | Some s -> [ ("support", result_to_json s) ]
    | None -> []))

let consistency_to_json (r : Tfl.Program.consistency) : Yojson.Safe.t =
  `Assoc
    ([ ("consistent", `Bool r.consistent); ("complete", `Bool r.complete) ]
    @ (if r.numerical then [ ("numerical", `Bool true) ] else [])
    @ (match r.certificate with
      | Some c ->
          [
            ("certificate", certificate_to_json c);
            ( "proof",
              match r.c_proof with Some p -> proof_to_json p | None -> `Null
            );
          ]
      | None -> (
          match r.c_proof with
          | Some p -> [ ("proof", proof_to_json p) ]
          | None -> [])))

let equivalents_to_json (es : Tfl.Program.equivalent_entry list) :
    Yojson.Safe.t =
  `List
    (List.map
       (fun (e : Tfl.Program.equivalent_entry) ->
         `Assoc
           [
             ("prop", Ast_json.prop_to_json e.eq_prop);
             ("text", `String e.eq_text);
             ("rule", `String e.eq_rule);
             ("reading", `String e.reading);
             ("path", `List (List.map (fun s -> `String s) e.path));
           ])
       es)

let decision_to_json (r : Tfl.Program.equivalence_decision) : Yojson.Safe.t =
  `Assoc
    ([
       ("equivalent", `Bool r.equivalent); ("method", `String r.e_method);
     ]
    @ (match r.atoms with
      | Some atoms ->
          [ ("atoms", `List (List.map (fun s -> `String s) atoms)) ]
      | None -> [])
    @ (match r.dnf with
      | Some rows -> [ ("dnf", `List (List.map (fun s -> `String s) rows)) ]
      | None -> [])
    @
    if r.e_method = "rewrite" then
      [
        ( "path",
          match r.e_path with
          | Some path -> `List (List.map (fun s -> `String s) path)
          | None -> `Null );
      ]
    else [])
