(* AST for TFL's plus-minus notation, mirroring the JS reference engine
   (docs/port-spec.md §2). Signs are stored as a variant; the printer, not
   the AST, decides typographic vs ASCII spelling. *)

type sign = Plus | Minus | Wild

type term =
  | Atom of { name : string; singular : bool }
  | Neg of term
  | Compound of signed_term list (* 2+ elements when parser-built *)
  | Rel of { head : term; objects : signed_term list } (* 1+ objects *)
  | PropTerm of propterm_inner

and signed_term = { sign : sign; term : term; level : int }
(* level 0 = classical some/every; the printer omits it *)

and propterm_inner =
  | Inner_prop of prop
  | Inner_term of term (* a bare statement term: [p] *)

and prop = { subject : signed_term; predicate : signed_term }

(* Structural equality. The types contain no floats, functions or cycles, so
   OCaml's polymorphic equality is exactly the JS engine's termEq/stEq/propEq;
   these wrappers pin the types so a mismatched comparison can't typecheck. *)

let term_eq (a : term) (b : term) = a = b
let signed_term_eq (a : signed_term) (b : signed_term) = a = b
let prop_eq (a : prop) (b : prop) = a = b
