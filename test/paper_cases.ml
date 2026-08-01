(* PLAN 1.13 — the curated paper-cases audit ("triple check").

   Every expectation in this file is written down from the *literature*, not
   read off the engine: the classical syllogistic (the 15 moods valid without
   existential import, the 9 subalternate moods that need it, the standard
   fallacies and immediate inferences), the relational inferences Sommers &
   Englebretsen use to motivate term logic, and Castro-Manzano, Lozano-Cobos &
   Reyes-Cárdenas 2018's worked numerical examples (Tables 10–13, plus the
   att-1/att-3 discriminator — see docs/port-spec.md §12, which records the
   mechanical check against that paper's Table 9).

   Each case was also hand-checked against the finite-model semantics of
   PLAN 1.10 — no existential import anywhere, the empty domain included.

   **If the engine disagrees with a case here, that goes to Kyle before
   anything changes.** A red case is evidence about the engine or about the
   case's sourcing; it is never a reason to edit the expectation.

   Two verdict conventions, both from port-spec §12:
   - Inside the atomic-categorical fragment the P/Z decision is *complete*, so
     an invalid argument must come back exactly `invalid`.
   - Outside it the derivation search is incomplete, so an argument the books
     call invalid may come back `unknown` (unknown ≠ invalid). What must never
     happen is a `valid`. Those cases use [expect_not_valid]. *)

open Harness

let expect_not_valid premises conclusion msg =
  let r = arg premises conclusion in
  check
    (verdict_name r <> "valid")
    (Printf.sprintf "%s: engine certified an argument the books call invalid (%s)"
       msg (verdict_name r))

let valid premises conclusion name =
  test name (fun () -> expect_verdict premises conclusion "valid" name)

let invalid premises conclusion name =
  test name (fun () -> expect_verdict premises conclusion "invalid" name)

let not_valid premises conclusion name =
  test name (fun () -> expect_not_valid premises conclusion name)

(* ── A. The 15 moods valid without existential import ────────────────────────
   Figures: 1 = M–P, S–M · 2 = P–M, S–M · 3 = M–P, M–S · 4 = P–M, M–S.
   A = −S+P · E = −S−P · I = +S+P · O = +S−P. *)

let () =
  valid [ "−M+P"; "−S+M" ] "−S+P" "Barbara (AAA-1)";
  valid [ "−M−P"; "−S+M" ] "−S−P" "Celarent (EAE-1)";
  valid [ "−M+P"; "+S+M" ] "+S+P" "Darii (AII-1)";
  valid [ "−M−P"; "+S+M" ] "+S−P" "Ferio (EIO-1)";
  valid [ "−P−M"; "−S+M" ] "−S−P" "Cesare (EAE-2)";
  valid [ "−P+M"; "−S−M" ] "−S−P" "Camestres (AEE-2)";
  valid [ "−P−M"; "+S+M" ] "+S−P" "Festino (EIO-2)";
  valid [ "−P+M"; "+S−M" ] "+S−P" "Baroco (AOO-2)";
  valid [ "−M+P"; "+M+S" ] "+S+P" "Datisi (AII-3)";
  valid [ "+M+P"; "−M+S" ] "+S+P" "Disamis (IAI-3)";
  valid [ "−M−P"; "+M+S" ] "+S−P" "Ferison (EIO-3)";
  valid [ "+M−P"; "−M+S" ] "+S−P" "Bocardo (OAO-3)";
  valid [ "−P+M"; "−M−S" ] "−S−P" "Calemes (AEE-4)";
  valid [ "+P+M"; "−M+S" ] "+S+P" "Dimatis (IAI-4)";
  valid [ "−P−M"; "+M+S" ] "+S−P" "Fresison (EIO-4)"

(* ── B. The 9 subalternate moods — valid only with existential import ────────
   The engine imports nothing (an A-form is true of an empty subject), so each
   of these must be *invalid*: the premises can all hold in a model where the
   minor term is empty, and every one of these conclusions is particular. *)

let () =
  invalid [ "−M+P"; "−S+M" ] "+S+P" "Barbari (AAI-1) needs existential import";
  invalid [ "−M−P"; "−S+M" ] "+S−P" "Celaront (EAO-1) needs existential import";
  invalid [ "−P−M"; "−S+M" ] "+S−P" "Cesaro (EAO-2) needs existential import";
  invalid [ "−P+M"; "−S−M" ] "+S−P" "Camestros (AEO-2) needs existential import";
  invalid [ "−M+P"; "−M+S" ] "+S+P" "Darapti (AAI-3) needs existential import";
  invalid [ "−M−P"; "−M+S" ] "+S−P" "Felapton (EAO-3) needs existential import";
  invalid [ "−P+M"; "−M+S" ] "+S+P" "Bramantip (AAI-4) needs existential import";
  invalid [ "−P−M"; "−M+S" ] "+S−P" "Fesapo (EAO-4) needs existential import";
  invalid [ "−P+M"; "−M−S" ] "+S−P" "Calemos (AEO-4) needs existential import"

(* ── C. Standard fallacies ─────────────────────────────────────────────────── *)

let () =
  invalid [ "−P+M"; "−S+M" ] "−S+P" "undistributed middle (AAA-2)";
  invalid [ "−M+P"; "−S−M" ] "−S−P" "illicit major (AEE-1)";
  invalid [ "+M+P"; "−S+M" ] "+S+P" "IAI-1 is invalid";
  invalid [ "−M+P"; "+S−M" ] "+S−P" "illicit process from a negative premise (AOO-1)"

(* ── D. Immediate inferences ────────────────────────────────────────────────
   Conversion is valid for I and E only; A converts only per accidens (which
   needs import, so not here) and O not at all. Obversion is valid on all four
   forms; contraposition on A and O only. Negative terms are written (−T). *)

let () =
  valid [ "+S+P" ] "+P+S" "I converts simply";
  valid [ "−S−P" ] "−P−S" "E converts simply";
  invalid [ "−S+P" ] "−P+S" "A does not convert simply";
  invalid [ "+S−P" ] "+P−S" "O does not convert";
  invalid [ "−S+P" ] "+P+S" "conversion per accidens needs existential import";
  valid [ "−S+P" ] "−S−(−P)" "obversion: A → E";
  valid [ "−S−P" ] "−S+(−P)" "obversion: E → A";
  valid [ "+S+P" ] "+S−(−P)" "obversion: I → O";
  valid [ "+S−P" ] "+S+(−P)" "obversion: O → I";
  valid [ "−S+P" ] "−(−P)+(−S)" "contraposition: A";
  valid [ "+S−P" ] "+(−P)−(−S)" "contraposition: O";
  invalid [ "−S−P" ] "−(−P)−(−S)" "E does not contrapose";
  invalid [ "+S+P" ] "+(−P)+(−S)" "I does not contrapose"

(* ── E. Relational arguments ────────────────────────────────────────────────
   The inferences term logic is advertised on: De Morgan's head-of-a-horse
   challenge (the case Sommers & Englebretsen use to show the syllogistic
   handles relationals once terms carry relational structure), the loves /
   admires family from the same material, and the scope trap that separates
   ∀∃ from ∃∀. *)

let () =
  valid [ "−Horse+Animal" ] "−(Head+Horse)+(Head+Animal)"
    "De Morgan: every head of a horse is a head of an animal";
  valid [ "−Man+(Lov+Woman)"; "−Woman+Human" ] "−Man+(Lov+Human)"
    "dictum inside a relational object";
  valid
    [ "−Boy+(Lov+Girl)"; "−Girl+(Adm−Teacher)" ]
    "−Boy+(Lov+(Adm−Teacher))" "chained relational complexes";
  valid
    [ "−Horse+(Faster+Dog)"; "−Dog+(Faster+Cat)" ]
    "−Horse+(Faster+(Faster+Cat))" "relational chaining without transitivity";
  valid [ "±John*+(Lov±Mary*)" ] "±Mary*+(Lov₂₁±John*)"
    "passive on two fixed references";
  valid [ "+Boy+(Lov+Girl)" ] "+Girl+(Lov₂₁+Boy)" "passive of a particular (∃∃)";
  not_valid [ "−Boy+(Lov+Girl)" ] "+Girl+(Lov₂₁−Boy)"
    "the ∀∃ / ∃∀ scope trap: every boy loves some girl ⊬ some girl is loved by \
     every boy";
  valid
    [ "−A−(R+B)"; "+C+(R+B)" ]
    "+C−A" "nothing A is R-related to a B; some C is ⊢ some C is not A";
  valid
    [ "+S+(Lov+Girl)"; "−Girl+Human" ]
    "+S+(Lov+Human)" "a particular subject carrying a relational object";
  valid
    [ "−Boy+(Lov+Girl)"; "+Boy+Tall" ]
    "+Tall+(Lov+Girl)" "a particular drawn out of a universal relational"

(* ── F. Indirect proofs ─────────────────────────────────────────────────────
   The worked proofs of the Course 2/3 relational material: arguments a direct
   derivation cannot reach, because a witness has to be named before the
   premises can interact. The method is asserted, not just the verdict —
   routing through the counterclaim is the point of these cases. *)

let meth_name (r : Tfl.Decide.result) =
  match r.meth with
  | PZ -> "PZ"
  | Derivation -> "derivation"
  | Indirect -> "indirect"
  | Numerical -> "numerical"

let indirect premises conclusion name =
  test name (fun () ->
      let r = arg premises conclusion in
      check
        (verdict_name r = "valid")
        (Printf.sprintf "%s: expected valid, got %s" name (verdict_name r));
      check
        (meth_name r = "indirect")
        (Printf.sprintf "%s: expected the indirect route, got %s" name
           (meth_name r)))

let () =
  (* Some boy loves some girl; no boy loves a coward ⊢ some girl is not a
     coward. The witness girl has to be named before the second premise can
     touch her. *)
  indirect
    [ "+Boy+(Lov+Girl)"; "−Boy−(Lov+Coward)" ]
    "+Girl−Coward" "the worked proof: boys, girls, cowards";
  (* Some boy loves every girl; some girl is a rebel ⊢ some boy loves a rebel.
     Universal-object instantiation: reachable only around a fixed witness. *)
  indirect
    [ "+Boy+(Lov−Girl)"; "+Girl+Rebel" ]
    "+Boy+(Lov+Rebel)" "some boy loves every girl; some girl is a rebel";
  (* The same premises do not give the coward *positively* — the books call it
     invalid, and the engine, outside its complete fragment, must at least not
     certify it. *)
  not_valid
    [ "+Boy+(Lov+Girl)"; "−Boy−(Lov+Coward)" ]
    "+Girl+Coward" "indirect proof does not overclaim";
  (* Course 3's quick-check: the categorical moods fall to the indirect route
     as well, though checkArgument decides them by P/Z long before. *)
  test "Barbara is reachable indirectly too (Course 3 quick-check)" (fun () ->
      let proof =
        Tfl.Derive.indirect_proof
          (List.map Tfl.Notation.parse_proposition [ "−A+B"; "−B+C" ])
          (Tfl.Notation.parse_proposition "−A+C")
      in
      check proof.found
        "the indirect search should refute the counterclaim of Barbara")

(* ── G. Numerical quantifiers (TFL⁺) ────────────────────────────────────────
   Castro-Manzano, Lozano-Cobos & Reyes-Cárdenas 2018 (BRAIN 9(3)), Tables
   10–13, plus the att-1 / att-3 pair that fixes the term-matched reading of
   condition (iii) (port-spec §12). Levels: ^1 many, ^2 most, ^3 few. *)

let () =
  invalid [ "+H^1+I"; "−g+H" ] "−g+I" "Table 10 — kaa-1 is invalid";
  invalid [ "−C+F"; "+M^1+C" ] "+M^2+F"
    "Table 11 — akt-4 is invalid on the level condition";
  valid [ "+C^3−H"; "−C+E" ] "+E−H" "Table 12 — bao-3 is valid";
  valid [ "−F−C"; "+V^2+C" ] "+V^1−F" "Table 13 — ekg-2 is valid";
  valid [ "−M+P"; "+S^2+M" ] "+S^2+P"
    "att-1: a most-premise on the conclusion's own subject licenses a \
     most-conclusion";
  invalid [ "−M+P"; "+M^2+S" ] "+S^2+P"
    "att-3: a most-premise on the middle term licenses nothing";
  valid [ "+V^2+C" ] "+V+C" "most descends to some"

let () = finish "paper cases"
