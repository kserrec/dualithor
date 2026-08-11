(* Scoring a translation against a gold formula (PLAN 4.5b).

   Exact string match is the wrong primary metric: term names are arbitrary, and
   the 4.3 smoke proved it — three models wrote three different stems for one
   verb and all three were right. What matters is whether the *structure* is the
   same under a consistent renaming of terms.

   But plain isomorphism is too generous in one specific and fatal way.
   `-Trustee+Fiduciary` and `-Fiduciary+Trustee` are isomorphic under the
   renaming that swaps the two names — so an illicit conversion of an A-form
   would score as correct. The renaming therefore has to be **anchored to the
   English**: a model's term may only correspond to a gold term whose name it
   plausibly shares a root with. Both sides draw their names from the same
   sentence, so this is a weak assumption, and it is what stops the metric from
   rewarding a wrong reading. *)

open Tfl.Ast

(* ── Name anchoring ────────────────────────────────────────────────────────
   Compare on letters and digits only, case-folded, so Work_for / workFor /
   "work for" all reduce alike. Abbreviation is the case that must survive,
   but an arbitrary subsequence is not a root: Cat occurs inside Educated and
   previously licensed a meaning-reversing A-form swap. Accept a prefix, one
   dropped character with the same endpoints (Wrk / Work), or four shared
   leading characters (Notifi / Notify). Below three characters these tests are
   nearly vacuous, so short names must match outright. *)

let normalise (s : string) : string =
  String.to_seq s
  |> Seq.filter_map (fun c ->
         if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') then Some c
         else if c >= 'A' && c <= 'Z' then Some (Char.lowercase_ascii c)
         else None)
  |> String.of_seq

let is_subsequence (short : string) (long : string) : bool =
  let n = String.length short and m = String.length long in
  let rec go i j = i >= n || (j < m && if short.[i] = long.[j] then go (i + 1) (j + 1) else go i (j + 1)) in
  go 0 0

let common_prefix (a : string) (b : string) : int =
  let n = min (String.length a) (String.length b) in
  let rec go i = if i < n && a.[i] = b.[i] then go (i + 1) else i in
  go 0

let is_prefix (short : string) (long : string) : bool =
  let n = String.length short in
  n <= String.length long && String.sub long 0 n = short

let drops_one_character (short : string) (long : string) : bool =
  let n = String.length short and m = String.length long in
  m = n + 1
  && short.[0] = long.[0]
  && short.[n - 1] = long.[m - 1]
  && is_subsequence short long

let names_compatible (a : string) (b : string) : bool =
  let a = normalise a and b = normalise b in
  if a = b then true
  else if String.length a < 3 || String.length b < 3 then false
  else
    let short, long =
      if String.length a <= String.length b then (a, b) else (b, a)
    in
    is_prefix short long
    || drops_one_character short long
    || common_prefix a b >= 4

(* ── Structural isomorphism ────────────────────────────────────────────────
   The binding is threaded functionally rather than mutated, because compound
   terms need backtracking: their elements are unordered, and canonical sorting
   cannot align them when the two sides use different names. *)

type env = { fwd : (string * string) list; rev : (string * string) list }

let empty_env = { fwd = []; rev = [] }

let bind env a b =
  match (List.assoc_opt a env.fwd, List.assoc_opt b env.rev) with
  (* already bound: must agree in both directions, keeping it a bijection *)
  | Some a', Some b' -> if a' = b && b' = a then Some env else None
  | None, None ->
      if names_compatible a b then
        Some { fwd = (a, b) :: env.fwd; rev = (b, a) :: env.rev }
      else None
  | _ -> None

let rec iso_term env (a : term) (b : term) : env option =
  match (a, b) with
  | Atom x, Atom y -> if x.singular = y.singular then bind env x.name y.name else None
  | Neg x, Neg y -> iso_term env x y
  (* Compound elements are unordered — match them as a bijection, with
     backtracking, since a greedy pass can bind a name pair that blocks a later
     element from matching. *)
  | Compound xs, Compound ys -> iso_unordered env xs ys
  | Rel x, Rel y ->
      if List.length x.objects <> List.length y.objects then None
      else
        Option.bind (iso_term env x.head y.head) (fun env ->
            (* object order is role order — ordered, never permuted *)
            iso_ordered env x.objects y.objects)
  | PropTerm (Inner_prop p), PropTerm (Inner_prop q) -> iso_prop env p q
  | PropTerm (Inner_term p), PropTerm (Inner_term q) -> iso_term env p q
  | _ -> None

and iso_st env (x : signed_term) (y : signed_term) : env option =
  if x.sign <> y.sign || x.level <> y.level then None else iso_term env x.term y.term

and iso_ordered env xs ys =
  match (xs, ys) with
  | [], [] -> Some env
  | x :: xs, y :: ys -> Option.bind (iso_st env x y) (fun env -> iso_ordered env xs ys)
  | _ -> None

and iso_unordered env xs ys =
  match xs with
  | [] -> if ys = [] then Some env else None
  | x :: rest ->
      let rec try_each skipped = function
        | [] -> None
        | y :: more -> (
            match
              Option.bind (iso_st env x y) (fun env' ->
                  iso_unordered env' rest (List.rev_append skipped more))
            with
            | Some e -> Some e
            | None -> try_each (y :: skipped) more)
      in
      try_each [] ys

and iso_prop env (p : prop) (q : prop) : env option =
  Option.bind (iso_st env p.subject q.subject) (fun env ->
      iso_st env p.predicate q.predicate)

(* Compared on the raw trees, deliberately NOT on canonical forms.

   Two reasons, both discovered by the scorer's own tests rather than reasoned
   out in advance:

   1. [Infer.canon_prop] rebuilds signed terms through [Infer.st], which sets
      level 0 — canonical form discards quantity levels, because the numerical
      decision handles them separately. Comparing canonical forms therefore
      made the scorer blind to the difference between "most claimants are
      veterans" and "some claimants are veterans". A scorer that cannot see a
      dropped quantifier is not measuring fidelity.
   2. Canonicalisation also commutes I- and E-forms, which would score a
      converted formula as structurally identical. Conversion is truth-
      preserving, so it is not an error — but it moves the subject, and
      mirroring the sentence's surface order is the property TFL is being
      tested on. It belongs one grade down, under [Equivalent], which is where
      the mutual-entailment check puts it.

   Compound commutation, the one thing canonicalisation was genuinely wanted
   for, is handled directly by [iso_unordered]. *)
let structurally_equal (gold : prop) (got : prop) : bool =
  iso_prop empty_env gold got <> None

(* Literally the same formula as written, once the printer has normalised
   spelling (ASCII vs typographic signs, spacing, quoting). *)
let exactly_equal (gold : prop) (got : prop) : bool =
  match
    (Tfl.Notation.print_proposition gold, Tfl.Notation.print_proposition got)
  with
  | a, b -> a = b
  | exception _ -> false

(* ── Logical equivalence ───────────────────────────────────────────────────
   Mutual entailment through the verified decision procedure. Sound but
   incomplete outside the categorical fragment (an Unknown either way reads as
   "not shown equivalent"), so this only ever moves an item up a grade, never
   down. It catches formulas that are shaped differently but say the same
   thing — which a structural test by construction cannot. *)

let entails (premise : prop) (conclusion : prop) : bool =
  let p = Tfl.Notation.print_proposition premise in
  let c = Tfl.Notation.print_proposition conclusion in
  match (Tfl_verify.check ~premises:[ p ] ~conclusion:c).verdict with
  | Valid -> true
  | _ -> false

let logically_equivalent (gold : prop) (got : prop) : bool =
  entails gold got && entails got gold

(* ── The grade ─────────────────────────────────────────────────────────────
   Ordered weakest to strongest. [Structural] is the headline number;
   [Equivalent] is a genuine success too, just reached by a different route. *)

type grade =
  | Unparseable
  | Wrong (* parsed, but neither the same shape nor the same content *)
  | Equivalent (* different shape, provably the same claim *)
  | Structural (* same shape under an anchored renaming *)
  | Exact (* identical canonical form *)

let grade_name = function
  | Unparseable -> "unparseable"
  | Wrong -> "wrong"
  | Equivalent -> "equivalent"
  | Structural -> "structural"
  | Exact -> "exact"

(* Scored against the gold and every recorded alternate; the best grade wins,
   because an also_ok entry is by definition an equally faithful reading. *)
let grade_against (accepted : prop list) (got : prop) : grade =
  List.fold_left
    (fun best gold ->
      let g =
        if exactly_equal gold got then Exact
        else if structurally_equal gold got then Structural
        else if logically_equivalent gold got then Equivalent
        else Wrong
      in
      if g > best then g else best)
    Wrong accepted

let counts_as_correct = function
  | Exact | Structural | Equivalent -> true
  | Wrong | Unparseable -> false
