(* Finite-model semantics for the TFL fragment (PLAN 1.10), ported from
   engine/oracle.js. This is the *semantic* reference the engine's syntactic
   verdicts get checked against, so it lives with the tests: the shipped
   library certifies validity symbolically, and this module exists only to
   catch it being wrong.

   Semantics (no existential import anywhere): a model is a domain {0..n−1},
   a subset for every unary atom, an element for every singular atom and every
   proterm (fixed reference denotes), and a (k+1)-ary relation for every
   relation-head base with k objects. The empty domain is a model too, unless
   some singular or proterm occurs — names need a world, nothing else does.
   Term denotations: negation is complement, compounds intersect (a − element
   intersects the complement), a relational complex denotes the x's related by
   R to the objects (+ object = some T, − object = every T, quantifiers read
   left to right, pairing subscripts naming the slot each participant fills),
   and a propositional term [p] denotes the whole domain when p is true and ∅
   otherwise (the singleton-universe pun). In ±S+P quantity + = some, − =
   every, wild ± = some (equivalent to every on the singleton denotations ± is
   restricted to); quality − = "is not".

   Quantity levels (TFL⁺) are ignored, exactly as the JS oracle ignores them —
   the intermediate quantifiers have no semantics here.

   Two shapes the JS oracle does not model, and neither do we — both raise
   [Unmodeled]: a relational complex whose head is not an atom (oracle.js
   throws outright), and a propositional term over a bare term that is not a
   plain unary atom (oracle.js's vocabOf would record `undefined` and evaluate
   nonsense). *)

open Tfl.Ast

exception Unmodeled of string

(* ── Vocabulary ─────────────────────────────────────────────────────────── *)

type vocab = {
  unary : string list;
  singular : string list; (* singular atoms and proterms: fixed reference *)
  rels : (string * int) list; (* head base × arity (objects + subject) *)
}

let key_of base arity = base ^ "/" ^ string_of_int arity

let vocab_of (props : prop list) : vocab =
  let unary = ref [] and singular = ref [] and rels = ref [] in
  let add l x = if not (List.mem x !l) then l := !l @ [ x ] in
  let rec walk_term t ~as_head ~arity =
    match t with
    | Atom { name; singular = sg } ->
        if as_head then add rels (fst (Tfl.Infer.head_roles name arity), arity)
        else if sg || Tfl.Infer.is_proterm_name name then add singular name
        else add unary name
    | Neg t -> walk_term t ~as_head:false ~arity:0
    | Compound els ->
        List.iter (fun e -> walk_term e.term ~as_head:false ~arity:0) els
    | Rel { head; objects } ->
        (match head with
        | Atom _ -> ()
        | _ -> raise (Unmodeled "only atomic relation heads are modeled"));
        walk_term head ~as_head:true ~arity:(List.length objects + 1);
        List.iter (fun o -> walk_term o.term ~as_head:false ~arity:0) objects
    | PropTerm (Inner_prop p) -> walk_prop p
    | PropTerm (Inner_term (Atom { name; singular = false }))
      when not (Tfl.Infer.is_proterm_name name) ->
        add unary name
    | PropTerm (Inner_term _) ->
        raise
          (Unmodeled
             "a bare propositional term is modeled only over a plain unary atom")
  and walk_prop p =
    walk_term p.subject.term ~as_head:false ~arity:0;
    walk_term p.predicate.term ~as_head:false ~arity:0
  in
  List.iter walk_prop props;
  { unary = !unary; singular = !singular; rels = !rels }

(* ── Models ─────────────────────────────────────────────────────────────── *)

(* Unary denotations are bitmasks over the domain; a relation is the list of
   tuples it holds of. *)
type model = {
  n : int;
  full : int; (* (1 lsl n) - 1 *)
  singular : (string * int) list;
  unary : (string * int) list;
  rels : (string * int array list) list;
}

let lookup what assoc name =
  match List.assoc_opt name assoc with
  | Some v -> v
  | None ->
      raise (Unmodeled (Printf.sprintf "%s %s is not in the model" what name))

(* All arity-length tuples over {0..n−1}, last position varying fastest — the
   JS oracle's allTuples order, kept so tuple indices mean the same thing on
   both sides. *)
let rec all_tuples n arity =
  if arity = 0 then [ [||] ]
  else
    List.concat_map
      (fun t -> List.init n (fun e -> Array.append t [| e |]))
      (all_tuples n (arity - 1))

let subset tuples mask =
  List.filteri (fun i _ -> mask land (1 lsl i) <> 0) tuples

(* ── Evaluation ─────────────────────────────────────────────────────────── *)

let rec eval_term (t : term) (m : model) : int =
  match t with
  | Atom { name; singular } ->
      if singular || Tfl.Infer.is_proterm_name name then
        1 lsl lookup "singular" m.singular name
      else lookup "unary term" m.unary name
  | Neg t -> m.full land lnot (eval_term t m)
  | Compound elements ->
      List.fold_left
        (fun mask el ->
          let d = eval_term el.term m in
          mask land if el.sign = Minus then m.full land lnot d else d)
        m.full elements
  | Rel { head; objects } -> eval_rel head objects m
  | PropTerm (Inner_prop p) -> if eval_prop p m then m.full else 0
  | PropTerm (Inner_term t) -> if eval_term t m <> 0 then m.full else 0

and eval_rel head objects m =
  let name =
    match head with
    | Atom { name; _ } -> name
    | _ -> raise (Unmodeled "only atomic relation heads are modeled")
  in
  let arity = List.length objects + 1 in
  let base, roles = Tfl.Infer.head_roles name arity in
  let roles = Array.of_list roles in
  let rel = lookup "relation" m.rels (key_of base arity) in
  let objects = Array.of_list objects in
  (* Participant i (subject = 0, then objects) fills slot roles.(i); the
     quantifiers still read left to right — roles never change scope. *)
  let rec check i tuple =
    if i = Array.length objects then List.exists (fun t -> t = tuple) rel
    else
      let o = objects.(i) in
      let den = eval_term o.term m in
      let every = o.sign = Minus in
      let rec witness y =
        if y >= m.n then every (* ∀ over the empty denotation holds; ∃ fails *)
        else if den land (1 lsl y) = 0 then witness (y + 1)
        else
          let next = Array.copy tuple in
          next.(roles.(i + 1) - 1) <- y;
          let hit = check (i + 1) next in
          if every && not hit then false
          else if (not every) && hit then true
          else witness (y + 1)
      in
      witness 0
  in
  let mask = ref 0 in
  for x = 0 to m.n - 1 do
    let tuple = Array.make arity 0 in
    tuple.(roles.(0) - 1) <- x;
    if check 0 tuple then mask := !mask lor (1 lsl x)
  done;
  !mask

and eval_prop (p : prop) (m : model) : bool =
  let s = eval_term p.subject.term m in
  let q = eval_term p.predicate.term m in
  let test x =
    if p.predicate.sign = Minus then q land (1 lsl x) = 0
    else q land (1 lsl x) <> 0
  in
  let every = p.subject.sign = Minus in
  let rec scan x =
    if x >= m.n then every (* no import: universals hold vacuously *)
    else if s land (1 lsl x) = 0 then scan (x + 1)
    else
      let hit = test x in
      if every && not hit then false
      else if (not every) && hit then true
      else scan (x + 1)
  in
  scan 0

(* ── Model enumeration ──────────────────────────────────────────────────── *)

(* How many models of size [n] the vocabulary admits, in floats — the count
   overflows any int long before it stops being interesting, and the JS oracle
   compares it against the cap in floats too. *)
let model_count (v : vocab) (n : int) : float =
  let fn = float_of_int n in
  (fn ** float_of_int (List.length v.singular))
  *. (2. ** float_of_int (List.length v.unary * n))
  *. List.fold_left
       (fun acc (_, arity) -> acc *. (2. ** fn ** float_of_int arity))
       1. v.rels

let exhaustive_upto (v : vocab) ~max_n ~cap : bool =
  let rec go n =
    n > max_n || (model_count v n <= float_of_int cap && go (n + 1))
  in
  go 0

(* Sampling for vocabularies too big to enumerate. The stream deliberately
   does NOT reproduce the JS oracle's LCG (whose state is shared with its
   formula generation), so sampled runs are sound-but-incomplete on both sides
   without being comparable — [exhaustive_upto] is what the differential gate
   filters on. *)
let seed = ref 20260704

let rand k =
  seed := ((!seed * 1103515245) + 12345) land 0x7fffffff;
  (!seed lsr 16) mod k

let random_model (v : vocab) (n : int) : model =
  let full = (1 lsl n) - 1 in
  {
    n;
    full;
    singular = List.map (fun s -> (s, rand n)) v.singular;
    unary = List.map (fun u -> (u, rand (full + 1))) v.unary;
    rels =
      List.map
        (fun (base, arity) ->
          ( key_of base arity,
            List.filter (fun _ -> rand 2 = 1) (all_tuples n arity) ))
        v.rels;
  }

(* [iter_models v n ~cap f] calls [f] on each model of size [n], stopping at
   the first one for which it returns true (which [iter_models] then returns).
   Beyond [cap] models the enumeration degrades to [cap] random samples. *)
let iter_models (v : vocab) (n : int) ~(cap : int) (f : model -> bool) : bool =
  let full = (1 lsl n) - 1 in
  if model_count v n > float_of_int cap then
    let rec go k = k < cap && (f (random_model v n) || go (k + 1)) in
    go 0
  else
    (* n = 0 with a name in the vocabulary yields nothing: names need a world. *)
    let rec fill_sing rest sing =
      match rest with
      | [] -> fill_unary v.unary sing []
      | name :: rest ->
          let rec pick e =
            e < n && (fill_sing rest ((name, e) :: sing) || pick (e + 1))
          in
          pick 0
    and fill_unary rest sing un =
      match rest with
      | [] -> fill_rels v.rels sing un []
      | name :: rest ->
          let rec pick mask =
            mask <= full
            && (fill_unary rest sing ((name, mask) :: un) || pick (mask + 1))
          in
          pick 0
    and fill_rels rest sing un rels =
      match rest with
      | [] -> f { n; full; singular = sing; unary = un; rels }
      | (base, arity) :: rest ->
          let tuples = all_tuples n arity in
          let key = key_of base arity in
          let limit = 1 lsl List.length tuples in
          let rec pick mask =
            mask < limit
            && (fill_rels rest sing un ((key, subset tuples mask) :: rels)
               || pick (mask + 1))
          in
          pick 0
    in
    fill_sing v.singular []

(* ── Entailment ─────────────────────────────────────────────────────────── *)

(* A model making every premise true and the conclusion false, or None if
   there is none up to size [max_n] (exhaustive within [cap] models per size). *)
let counter_model ~max_n ~cap (premises : prop list) (conclusion : prop) :
    model option =
  let v = vocab_of (premises @ [ conclusion ]) in
  let found = ref None in
  let rec size n =
    if n > max_n then None
    else if
      iter_models v n ~cap (fun m ->
          if
            List.for_all (fun p -> eval_prop p m) premises
            && not (eval_prop conclusion m)
          then (
            found := Some m;
            true)
          else false)
    then !found
    else size (n + 1)
  in
  size 0

let entails ~max_n ~cap premises conclusion =
  counter_model ~max_n ~cap premises conclusion = None

(* ── Reporting ──────────────────────────────────────────────────────────── *)

let show_model (m : model) : string =
  let pairs label l =
    if l = [] then []
    else
      [
        label ^ ": "
        ^ String.concat ", "
            (List.map (fun (k, v) -> Printf.sprintf "%s=%d" k v) l);
      ]
  in
  let rels =
    if m.rels = [] then []
    else
      [
        "rels: "
        ^ String.concat ", "
            (List.map
               (fun (k, tuples) ->
                 Printf.sprintf "%s={%s}" k
                   (String.concat " "
                      (List.map
                         (fun t ->
                           String.concat ","
                             (Array.to_list (Array.map string_of_int t)))
                         tuples)))
               m.rels);
      ]
  in
  String.concat "; "
    ((Printf.sprintf "n=%d" m.n :: pairs "singular" m.singular)
    @ pairs "unary" m.unary @ rels)
