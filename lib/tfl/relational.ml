(* The relational layer (PLAN 1.6), ported from engine/tfl.js: orientations,
   the passive transformation with the symmetry guard, and pronominalization
   (Skolemization for indirect proof) — port-spec §9. head_roles itself lives
   in Infer (canonical form needs it). *)

open Ast

(* Roles are carried by pairing subscripts, scope by subject position. The
   symmetry guard: participants whose relative scope order changes must share
   a quantity or have a fixed-reference member — ∀∀ and ∃∃ commute, fixed
   reference has no scope; a −/+ crossing is the ∀∃/∃∀ trap. *)
let slot_quantity (st : signed_term) : sign =
  if Infer.is_fixed_ref st.term then Wild else st.sign

let scope_commutes a b = a = b || a = Wild || b = Wild

(* A proposition and, for I- and E-forms (a fixed-reference wild counting as
   either), its converse — the two orientations conversion treats as the same
   statement. *)
let orientations (p : prop) : prop list =
  let s_sign = slot_quantity p.subject and q_sign = p.predicate.sign in
  let i_like = (s_sign = Plus || s_sign = Wild) && q_sign = Plus in
  let e_like = (s_sign = Minus || s_sign = Wild) && q_sign = Minus in
  (* I/E conversion is a level-0 equivalence. Rebuilding an orientation with
     [Infer.st] drops levels, and "most S is P" does not convert to "P is most
     S" in any case. *)
  if
    p.subject.level <> 0 || p.predicate.level <> 0
    || ((not i_like) && not e_like)
  then [ p ]
  else
    let base = if i_like then Plus else Minus in
    [
      p;
      {
        subject =
          Infer.st
            (if Infer.is_fixed_ref p.predicate.term then Wild else base)
            p.predicate.term;
        predicate = Infer.st base p.subject.term;
      };
    ]

(* ── The passive transformation ─────────────────────────────────────────── *)

type passive = { p_prop : prop; equivalent : bool; swapped : int }

(* All passives of a proposition (each object slot of a top-level relational
   predicate, in either orientation), tagged with the symmetry-guard verdict.
   Only equivalent:true results are inference-grade; the rest are the scope
   traps. Results dedupe by prop key across both orientations; the stored
   prop is the raw construction (saturate canonicalizes at use). *)
let passives (p : prop) : passive list =
  let out = ref [] in
  let seen : (string, unit) Hashtbl.t = Hashtbl.create 8 in
  List.iter
    (fun q ->
      match (q.predicate.sign, q.predicate.term) with
      | Plus, Rel { head = Atom { name; singular }; objects }
        when List.length objects + 1 <= 9 ->
          let n = List.length objects + 1 in
          let base, roles = Infer.head_roles name n in
          let parts =
            Array.of_list
              (slot_quantity q.subject :: List.map slot_quantity objects)
          in
          let objects = Array.of_list objects in
          for k = 1 to n - 1 do
            let equivalent = ref (scope_commutes parts.(0) parts.(k)) in
            let i = ref 1 in
            while !i < k && !equivalent do
              equivalent :=
                scope_commutes parts.(0) parts.(!i)
                && scope_commutes parts.(!i) parts.(k);
              incr i
            done;
            let objects' =
              Array.map (fun o -> Infer.st o.sign o.term) objects
            in
            let new_subject =
              Infer.st objects'.(k - 1).sign objects'.(k - 1).term
            in
            objects'.(k - 1) <- Infer.st q.subject.sign q.subject.term;
            let roles2 = Array.of_list roles in
            let tmp = roles2.(0) in
            roles2.(0) <- roles2.(k);
            roles2.(k) <- tmp;
            let head =
              Atom
                {
                  name = Infer.make_head_name base (Array.to_list roles2);
                  singular;
                }
            in
            let prop =
              {
                subject = new_subject;
                predicate =
                  Infer.st Plus (Rel { head; objects = Array.to_list objects' });
              }
            in
            let key = Infer.prop_key prop in
            if not (Hashtbl.mem seen key) then (
              Hashtbl.add seen key ();
              out :=
                { p_prop = prop; equivalent = !equivalent; swapped = k } :: !out)
          done
      | _ -> ())
    (orientations p);
  List.rev !out

(* ── Pronominalization (Skolemization; indirect proof only) ─────────────── *)

let collect_names (p : prop) (set : (string, unit) Hashtbl.t) : unit =
  let rec walk t =
    match t with
    | Atom { name; _ } -> Hashtbl.replace set name ()
    | Neg t -> walk t
    | Compound els -> List.iter (fun e -> walk e.term) els
    | Rel { head; objects } ->
        walk head;
        List.iter (fun o -> walk o.term) objects
    | PropTerm (Inner_prop q) ->
        walk q.subject.term;
        walk q.predicate.term
    | PropTerm (Inner_term t) -> walk t
  in
  walk p.subject.term;
  walk p.predicate.term

type pronominalization = { pr_prop : prop; anchors : prop list }

(* Rewrite a particular statement with fresh proterms fixing its witnesses,
   plus one anchor ±T′+T per witness. NOT an entailment (it introduces
   names); used only inside refute_set at setup. Both orientations are
   attempted; the one fixing the most witnesses wins (first on ties); its
   fresh names are added to [used]. Returns None for universal statements or
   when nothing needs introducing. *)
let pronominalize (p : prop) (used : (string, unit) Hashtbl.t) :
    pronominalization option =
  Infer.validate_prop p;
  collect_names p used;
  let attempt q =
    if q.subject.sign = Minus then None
    else
      let anchors = ref [] in
      let names = ref [] in
      let fresh base =
        let name = ref (base ^ "'") in
        while Hashtbl.mem used !name || List.mem !name !names do
          name := !name ^ "'"
        done;
        names := !names @ [ !name ];
        !name
      in
      let is_witness = function
        | Atom { name; singular } ->
            (not singular) && not (Infer.is_proterm_name name)
        | _ -> false
      in
      let mark t =
        let name =
          match t with Atom { name; _ } -> name | _ -> assert false
        in
        let pro = Atom { name = fresh name; singular = false } in
        anchors :=
          !anchors
          @ [ { subject = Infer.st Wild pro; predicate = Infer.st Plus t } ];
        pro
      in
      let rec walk_rel head objects =
        Rel
          {
            head;
            objects =
              List.map
                (fun o ->
                  if o.sign <> Plus || o.level <> 0 then o
                  else if is_witness o.term then Infer.st Wild (mark o.term)
                  else
                    match o.term with
                    | Rel { head; objects } ->
                        Infer.st Plus (walk_rel head objects)
                    | _ -> o)
                objects;
          }
      in
      let subject =
        if q.subject.sign = Plus && is_witness q.subject.term then
          Infer.st Wild (mark q.subject.term)
        else
          match (q.subject.sign, q.subject.term) with
          | Plus, Rel { head; objects } -> Infer.st Plus (walk_rel head objects)
          | _ -> q.subject
      in
      let predicate =
        match (q.predicate.sign, q.predicate.term) with
        | Plus, Rel { head; objects } -> Infer.st Plus (walk_rel head objects)
        | _ -> q.predicate
      in
      if !anchors = [] then None
      else Some ({ subject; predicate }, !anchors, !names)
  in
  let results = List.filter_map attempt (orientations p) in
  match results with
  | [] -> None
  | first :: rest ->
      let best_prop, best_anchors, best_names =
        List.fold_left
          (fun (bp, ba, bn) (cp, ca, cn) ->
            if List.length ca > List.length ba then (cp, ca, cn)
            else (bp, ba, bn))
          first rest
      in
      List.iter (fun n -> Hashtbl.replace used n ()) best_names;
      Some { pr_prop = best_prop; anchors = best_anchors }
