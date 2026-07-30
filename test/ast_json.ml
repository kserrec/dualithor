(* Serialize OCaml ASTs into the JS engine's exact JSON shape (port-spec §17):
   {type:'atom', name, singular} · {sign, term, level} with ASCII signs ·
   {type:'prop', subject, predicate}. The differential harness compares both
   engines' structures through this encoding. *)

open Tfl.Ast

let sign_to_string = function Plus -> "+" | Minus -> "-" | Wild -> "±"

let rec term_to_json (t : term) : Yojson.Safe.t =
  match t with
  | Atom { name; singular } ->
      `Assoc
        [
          ("type", `String "atom");
          ("name", `String name);
          ("singular", `Bool singular);
        ]
  | Neg t -> `Assoc [ ("type", `String "neg"); ("term", term_to_json t) ]
  | Compound elements ->
      `Assoc
        [
          ("type", `String "compound");
          ("elements", `List (List.map st_to_json elements));
        ]
  | Rel { head; objects } ->
      `Assoc
        [
          ("type", `String "rel");
          ("head", term_to_json head);
          ("objects", `List (List.map st_to_json objects));
        ]
  | PropTerm (Inner_prop p) ->
      `Assoc [ ("type", `String "propterm"); ("inner", prop_to_json p) ]
  | PropTerm (Inner_term t) ->
      `Assoc [ ("type", `String "propterm"); ("inner", term_to_json t) ]

and st_to_json (st : signed_term) : Yojson.Safe.t =
  `Assoc
    [
      ("sign", `String (sign_to_string st.sign));
      ("term", term_to_json st.term);
      ("level", `Int st.level);
    ]

and prop_to_json (p : prop) : Yojson.Safe.t =
  `Assoc
    [
      ("type", `String "prop");
      ("subject", st_to_json p.subject);
      ("predicate", st_to_json p.predicate);
    ]

(* Structural JSON equality up to object-key order (JSON.stringify emits keys
   in insertion order; Yojson's polymorphic equality on Assoc is
   order-sensitive) and up to int/float representation of whole numbers. *)
let rec json_equal (a : Yojson.Safe.t) (b : Yojson.Safe.t) : bool =
  match (a, b) with
  | `Assoc xs, `Assoc ys ->
      let sort = List.sort (fun (k1, _) (k2, _) -> compare k1 k2) in
      let xs = sort xs and ys = sort ys in
      List.length xs = List.length ys
      && List.for_all2 (fun (k1, v1) (k2, v2) -> k1 = k2 && json_equal v1 v2) xs ys
  | `List xs, `List ys ->
      List.length xs = List.length ys && List.for_all2 json_equal xs ys
  | `Int i, `Float f | `Float f, `Int i -> float_of_int i = f
  | a, b -> a = b
