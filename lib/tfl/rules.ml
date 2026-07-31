(* The mediate rewrite rules (PLAN 1.5), ported from engine/tfl.js: term
   substitution at an occurrence path, DON (dictum de omni), Simp, and Add
   (port-spec §8). All results are canonical propositions. *)

open Ast

(* Replace the term at an occurrence position and canonicalize. A ± slot
   being substituted at (the path ends exactly there) is fixed to [fix_sign] —
   the wild resolution that produced the wanted net sign; under an odd number
   of governing minuses only the universal reading puts the occurrence at
   net + (the JS fuzz oracle caught a version that hard-coded +). canon_prop
   restores ± when the new term is itself a fixed reference. *)
let replace_at (p : prop) (side : Infer.side) (steps : Infer.occ_step list)
    (new_term : term) (fix_sign : sign) : prop =
  let rec sub t steps =
    match steps with
    | [] -> new_term
    | step :: more -> (
        match t with
        | Neg inner -> Neg (sub inner more)
        | Compound elements ->
            Compound
              (List.mapi
                 (fun i el ->
                   match step with
                   | Infer.Occ_at j when i = j ->
                       Infer.st el.sign (sub el.term more)
                   | _ -> el)
                 elements)
        | Rel { head; objects } ->
            Rel
              {
                head;
                objects =
                  List.mapi
                    (fun i o ->
                      match step with
                      | Infer.Occ_at j when i = j ->
                          Infer.st
                            (if o.sign = Wild && more = [] then fix_sign
                             else o.sign)
                            (sub o.term more)
                      | _ -> o)
                    objects;
              }
        | Atom _ | PropTerm _ -> Infer.engine_error "bad substitution path")
  in
  match side with
  | Infer.On_subject ->
      let sign =
        if steps = [] && p.subject.sign = Wild then fix_sign
        else p.subject.sign
      in
      Infer.canon_prop
        { subject = Infer.st sign (sub p.subject.term steps); predicate = p.predicate }
  | Infer.On_predicate ->
      Infer.canon_prop
        {
          subject = p.subject;
          predicate = Infer.st p.predicate.sign (sub p.predicate.term steps);
        }

(* ── DON ────────────────────────────────────────────────────────────────── *)

type donor_reading = { m : term; m_key : string; d : term }

(* Read a premise as a donor: −M+D donates D for M; −M−E donates (−E) (the
   obverse reading); a wild subject uses its universal reading. *)
let donor_readings (p : prop) : donor_reading list =
  if p.subject.sign = Plus then []
  else
    let m = p.subject.term in
    let d =
      if p.predicate.sign = Plus then p.predicate.term
      else Infer.canon_term (Neg p.predicate.term)
    in
    [ { m; m_key = Infer.term_key m; d } ]

(* All DON results of donor → host: substitute the donation for every
   net-+-capable occurrence of M in the host. *)
let apply_don (donor : prop) (host : prop) : prop list =
  List.concat_map
    (fun { m = _; m_key; d } ->
      let d_key = Infer.term_key d in
      if d_key = m_key then []
      else
        List.filter_map
          (fun (occ : Infer.occurrence) ->
            if
              Infer.can_be_plus occ && Infer.term_key occ.occ_term = m_key
            then
              Some
                (replace_at host occ.side occ.steps d
                   (if occ.occ_sign = 1 then Plus else Minus))
            else None)
          (Infer.occurrences host))
    (donor_readings donor)

(* ── Simp ───────────────────────────────────────────────────────────────── *)

(* Simp: at a net-+ occurrence of a compound, drop one conjunct; and from a
   particular, the subject (and a + predicate) yields its +T+T. *)
let apply_simp (p : prop) : prop list =
  let drops =
    List.concat_map
      (fun (occ : Infer.occurrence) ->
        match occ.occ_term with
        | Compound elements when Infer.can_be_plus occ ->
            List.mapi
              (fun i _ ->
                let rest = List.filteri (fun j _ -> j <> i) elements in
                let t =
                  match rest with
                  | [ { sign = Minus; term; _ } ] -> Neg term
                  | [ { term; _ } ] -> term
                  | rest -> Compound rest
                in
                replace_at p occ.side occ.steps t Plus)
              elements
        | _ -> [])
      (Infer.occurrences p)
  in
  if p.subject.sign = Plus || p.subject.sign = Wild then
    drops
    @ [
        Infer.canon_prop
          {
            subject = Infer.st Plus p.subject.term;
            predicate = Infer.st Plus p.subject.term;
          };
      ]
    @ (if p.predicate.sign = Plus then
         [
           Infer.canon_prop
             {
               subject = Infer.st Plus p.predicate.term;
               predicate = Infer.st Plus p.predicate.term;
             };
         ]
       else [])
  else drops

(* ── Add ────────────────────────────────────────────────────────────────── *)

(* Add: same-subject compound introduction — {−S+A, −S+B} ⊢ −S+(+A+B);
   {+S+A, −S+B} ⊢ +S+(+A+B). Both orders are tried; y (the reusable side)
   must be universal or wild. *)
let apply_add (a : prop) (b : prop) : prop list =
  List.filter_map
    (fun (x, y) ->
      if
        Infer.term_key x.subject.term = Infer.term_key y.subject.term
        && x.predicate.sign = Plus && y.predicate.sign = Plus
        && (y.subject.sign = Minus || y.subject.sign = Wild)
      then
        Some
          (Infer.canon_prop
             {
               subject = Infer.st x.subject.sign x.subject.term;
               predicate =
                 Infer.st Plus
                   (Compound
                      [
                        Infer.st Plus x.predicate.term;
                        Infer.st Plus y.predicate.term;
                      ]);
             })
      else None)
    [ (a, b); (b, a) ]
