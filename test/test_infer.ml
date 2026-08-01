(* 1.4 acceptance: unit tests for inference core A, ported from the D2
   sections of engine/tfl.test.js that this layer covers — canonical equality
   (Com / Assoc / DN / wild quantity, incl. pairing-subscript noise), the
   immediate inferences (EN / IN / Contrap), and the validateProp engine
   guards. P/Z, rules, and derivation tests arrive with 1.5. *)

open Tfl.Notation
open Tfl.Infer
open Harness

let eq_up_to a b = prop_eq_up_to (p a) (p b)

let () =
  (* Canonical equality (Com / Assoc / DN / wild quantity) *)
  test "A-form does not convert" (fun () ->
      check (not (eq_up_to "−S+P" "−P+S")) "A converted");
  test "I-form converts" (fun () -> check (eq_up_to "+S+P" "+P+S") "I");
  test "E-form converts" (fun () -> check (eq_up_to "−S−P" "−P−S") "E");
  test "O-form does not convert" (fun () ->
      check (not (eq_up_to "+S−P" "+P−S")) "O converted");
  test "double negation strips" (fun () ->
      check (eq_up_to "−(−(−S))+P" "−(−(−(−(−S))))+P") "DN");
  test "compounds commute and associate" (fun () ->
      check (eq_up_to "−(+A+(+B+C))+D" "−(+C+(+B+A))+D") "Com/Assoc");
  test "singular quantity is wild in equality" (fun () ->
      check (eq_up_to "+Socrates*+Wise" "−Socrates*+Wise") "+ vs −";
      check (eq_up_to "±Socrates*+Wise" "+Socrates*+Wise") "± vs +");
  test "identity statements convert through the wild reading" (fun () ->
      check (eq_up_to "±Twain*+Clemens*" "±Clemens*+Twain*") "identity Com");
  test "the four forms stay distinct" (fun () ->
      let forms = [ "−S+P"; "−S−P"; "+S+P"; "+S−P" ] in
      List.iter
        (fun a ->
          List.iter
            (fun b ->
              check (eq_up_to a b = (a = b)) (Printf.sprintf "%s vs %s" a b))
            forms)
        forms);
  test "identity pairing subscripts are canonical noise" (fun () ->
      check (eq_up_to "−Dog+(Sees₁₂−Cat)" "−Dog+(Sees−Cat)") "identity roles";
      check
        (not (eq_up_to "−Dog+(Sees₂₁−Cat)" "−Dog+(Sees−Cat)"))
        "swapped roles");
  test "subscripted heads round-trip through the printer" (fun () ->
      let src = "+Student+(Teaches₂₁−Philosopher)" in
      check (print_proposition (p src) = src) "round-trip");

  (* EN / IN / Contrap *)
  test "contradictory flips both signs (EN)" (fun () ->
      check (prop_eq_up_to (contradictory (p "−S+P")) (p "+S−P")) "A → O";
      check (prop_eq_up_to (contradictory (p "+S+P")) (p "−S−P")) "I → E";
      check
        (prop_eq_up_to
           (contradictory (p "±Socrates*+Wise"))
           (p "±Socrates*−Wise"))
        "singular EN");
  test "obversion (IN) is an equivalence" (fun () ->
      check (prop_eq_up_to (obverse (p "−S+P")) (p "−S−(−P)")) "A obverse";
      check (prop_eq_up_to (obverse (p "−S−P")) (p "−S+(−P)")) "E obverse";
      (* Self-inverse up to canonical Com: obverting an A twice passes through
         an E-form, whose canonical order may hand back the contrapositive. *)
      let twice = obverse (obverse (p "−S+P")) in
      let contrap =
        match contrapositive (p "−S+P") with
        | Some q -> q
        | None -> failwith "contrapositive of A missing"
      in
      check
        (prop_eq_up_to twice (p "−S+P") || prop_eq_up_to twice contrap)
        "A twice";
      check (prop_eq_up_to (obverse (obverse (p "−S−P"))) (p "−S−P")) "E twice");
  test "contraposition of A and O; none for I and E" (fun () ->
      (match contrapositive (p "−S+P") with
      | Some q -> check (prop_eq_up_to q (p "−(−P)+(−S)")) "A contrap"
      | None -> failwith "A contrap missing");
      (match contrapositive (p "+S−P") with
      | Some q -> check (prop_eq_up_to q (p "+(−P)−(−S)")) "O contrap"
      | None -> failwith "O contrap missing");
      check (contrapositive (p "+S+P") = None) "I contrap";
      check (contrapositive (p "−S−P") = None) "E contrap");
  test "tautology is the safe A-form −T+T" (fun () ->
      check (prop_eq_up_to (tautology (parse_term "Dog")) (p "−Dog+Dog")) "It");

  (* Engine guards *)
  test "wild quantity requires a singular term" (fun () ->
      match validate_prop (p "±Dog+Pet") with
      | () -> failwith "should have raised Engine_error"
      | exception Engine_error _ -> ());
  test "wild predicates are rejected" (fun () ->
      match validate_prop (p "+Dog±Pet*") with
      | () -> failwith "should have raised Engine_error"
      | exception Engine_error _ -> ());

  finish "infer unit tests"
