(* 1.9 acceptance: unit tests for NL rendering. The readProp tests are ported
   from the D5 section of engine/tfl.test.js and the D9 gloss test; the
   explainProof and readTerm expectations are probe-verified strings from the
   reference engine (its own explainProof tests run through the deferred
   answer() layer). Byte-exact — this is the back-translation contract. *)

open Tfl.Notation
open Tfl.Render

open Harness

let t = parse_term

let () =
  (* readProp: ported from tfl.test.js *)
  test "readProp: the four categorical forms" (fun () ->
      check_eq (read_prop (p "−Man+Mortal")) "every man is mortal";
      check_eq (read_prop (p "−Man−Mortal")) "no man is mortal";
      check_eq (read_prop (p "+Man+Wise")) "some man is wise";
      check_eq (read_prop (p "+Man−Wise")) "some man is not wise");
  test "readProp: singulars are named individuals with an article" (fun () ->
      check_eq (read_prop (p "±Socrates*+Man")) "Socrates is a man";
      check_eq (read_prop (p "±Socrates*−Man")) "Socrates is not a man";
      check_eq (read_prop (p "±Ada*+Animal")) "Ada is an animal");
  test "readProp orients a converted singular back to the individual"
    (fun () ->
      check_eq
        (read_prop (Tfl.Infer.canon_prop (p "±Socrates*+Man")))
        "Socrates is a man");
  test "readProp: proterms read as \"that X\"" (fun () ->
      check_eq (read_prop (p "±Boy'+Coward")) "that boy is a coward");
  test "readProp: many / most / few glosses" (fun () ->
      check_eq (read_prop (p "+V^1+C")) "many v is c";
      check_eq (read_prop (p "+V^2+C")) "most v is c";
      check_eq (read_prop (p "+C^3-H")) "few c is h";
      check_eq (read_prop (p "+C^3+H")) "few c is not h");

  (* readTerm/readProp: probe-verified reference strings *)
  test "readTerm: compounds, negations, relations, brackets" (fun () ->
      check_eq (read_term (t "(+White+Horse)")) "white and horse";
      check_eq (read_term (t "(−Smoker)")) "non-smoker";
      check_eq (read_term (t "(Lov+Woman)")) "lov some woman";
      check_eq (read_term (t "(Gave+Rose−Girl)")) "gave some rose every girl";
      check_eq (read_term (t "[+p+q]")) "\u{201C}some p is q\u{201D}");
  test "readProp: relational quantities and qualities" (fun () ->
      check_eq (read_prop (p "−Man+(Lov+Woman)")) "every man lov some woman";
      check_eq
        (read_prop (p "+Man−(Lov+Woman)"))
        "some man does not lov some woman";
      check_eq (read_prop (p "−Boy−(Lov+Coward)")) "no boy lov some coward");

  (* explainProof: probe-verified reference strings *)
  test "explainProof: direct derivation (Barbara)" (fun () ->
      let proof = Tfl.Derive.derive [ p "−M+P"; p "−S+M" ] (p "−S+P") in
      match explain_proof proof with
      | Some s -> check_eq s "Because every m is p, and every s is m, every s is p."
      | None -> failwith "no explanation");
  test "explainProof: indirect proof ends in the impossibility clause"
    (fun () ->
      let proof =
        Tfl.Derive.indirect_proof [ p "−A+B"; p "−B+C" ] (p "−A+C")
      in
      match explain_proof proof with
      | Some s ->
          check_eq s
            "Because every a is b, and every b is c, and some a is not c, it \
             would follow that some a is not c, yet every a is c \u{2014} \
             which is impossible."
      | None -> failwith "no explanation");
  test "explainProof: a failed proof explains nothing" (fun () ->
      match explain_proof { found = false; lines = [] } with
      | None -> ()
      | Some s -> failwith ("unexpected explanation: " ^ s));
  (* A proof record deserialized from JSON (PLAN 3.1) can claim found with no
     lines; reading its last line used to raise (bughunt 2026-08-01). *)
  test "explainProof: a found-but-empty proof explains nothing" (fun () ->
      match explain_proof { found = true; lines = [] } with
      | None -> ()
      | Some s -> failwith ("unexpected explanation: " ^ s));

  finish "render unit tests"
