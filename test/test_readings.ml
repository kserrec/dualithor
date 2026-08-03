(* The approved English readings (PLAN 5.0).

   This file exists because the differential harness cannot answer the question
   that matters here. A comparison against the frozen JS reference can only say
   "this matches the old thing", and on English rendering the old thing has no
   authority: it is one earlier draft of an English generator, and two of its
   readings are provably wrong. Only a person can say "this reading is *right*",
   so the readings are written out here in full, in the order a reader would want
   them, for Kyle to read and approve — the same footing as the 3.3 trace samples.

   The rendering is the audit surface. In the Phase 9 study the participant never
   sees TFL at all: they see a source sentence and the English on the right-hand
   column below, and are asked whether the two say the same thing. A wrong reading
   here would mean the study measures our renderer instead of our idea.

   Two constructions changed in 5.0, and both were back-check false positives —
   the *only* two remaining (LOG 2026-08-02: "true false-positive rate against a
   correct renderer: 0/88"). Everything else in this file is unchanged behaviour,
   pinned so the fix cannot have moved it. *)

open Tfl.Notation
open Tfl.Render
open Harness

let t = parse_term
let reads formula english = check_eq (read_prop (p formula)) english
let reads_term formula english = check_eq (read_term (t formula)) english

(* ── Fix 1: the quantity word is spoken on a relational predicate ────────── *)

(* The bug (i06): `render.ml` gated the quantity word on the predicate *not*
   being a relational complex, so "Many officers sign a contract" —
   +Officer^1+(Sign+Contract) — read "some officer sign some contract", byte
   for byte identical to level 0. A reader auditing the formula was shown
   "some" where it says "many", and the back-check was blind there. *)

let () =
  test "the quantity word survives a relational predicate" (fun () ->
      reads "+Officer+(Sign+Contract)" "some officer sign some contract";
      reads "+Officer^1+(Sign+Contract)" "many officer sign some contract";
      reads "+Officer^2+(Sign+Contract)" "most officer sign some contract");

  (* Level 3 marks the predominant *complement*, so "few" inverts the English
     polarity — the rule that cost us the 4.5b re-run when the gold had it
     backwards. It applies to relational predicates exactly as it does to plain
     ones; "does not" is where the inversion surfaces. *)
  test "level 3 inverts polarity on a relation, as it does on a plain term"
    (fun () ->
      reads "+Officer^3+(Sign+Contract)" "few officer does not sign some contract";
      reads "+Officer^3-(Sign+Contract)" "few officer sign some contract");

  test "the object quantities inside the relation are untouched" (fun () ->
      reads "+Officer^1+(Sign-Contract)" "many officer sign every contract";
      reads "+Officer^1+(Sign+Contract+Clause)"
        "many officer sign some contract some clause");

  (* The categorical readings this branch already produced. If the fix had
     reached further than intended, these are what would move. *)
  test "the plain-term level readings are unchanged" (fun () ->
      reads "+Volunteer^1+Employee" "many volunteer is employee";
      reads "+Volunteer^2+Employee" "most volunteer is employee";
      reads "+Volunteer^3+Employee" "few volunteer is not employee";
      reads "+Volunteer^3-Employee" "few volunteer is employee");

  (* A fixed-reference subject takes a different branch entirely and never
     reaches the quantity word — level 0 and the singular reading both stand. *)
  test "a fixed-reference subject is unaffected" (fun () ->
      reads "±Alice*+(Sign+Contract)" "Alice sign some contract";
      reads "±Boy'+(Sign+Contract)" "that boy sign some contract")

(* ── Fix 2: a compound term is one term, not a list of them ──────────────── *)

(* The bug (d03): "Every registered voter is a citizen" —
   -(+Registered+Voter)+Citizen — read "every registered and voter is citizen".
   "and" in English joins two separate things ("Alice and Bob"); a compound is
   an intersection, which English writes by juxtaposition. *)

let () =
  test "a compound reads as a noun phrase" (fun () ->
      reads_term "(+Registered+Voter)" "registered voter";
      reads_term "(+Tall+Boy+Athlete)" "tall boy athlete";
      reads "-(+Registered+Voter)+Citizen" "every registered voter is citizen";
      reads "+(+Registered+Voter)+Citizen" "some registered voter is citizen";
      reads "-Citizen+(+Registered+Voter)" "every citizen is registered voter");

  test "a negative element keeps its non- prefix" (fun () ->
      reads_term "(+Registered-Voter)" "registered non-voter";
      reads_term "(-Registered+Voter)" "non-registered voter";
      reads_term "(+Rich-Happy)" "rich non-happy";
      reads "-(-Registered+Voter)+Citizen"
        "every non-registered voter is citizen");

  (* A one-element compound is not affected by the joiner at all: both the old
     " and " and the new " " collapse to the element itself. This is why the
     differential exempts only compounds of two or more. *)
  test "a one-element compound is untouched" (fun () ->
      reads_term "(+Voter)" "voter";
      reads_term "(-Voter)" "non-voter");

  test "compounds nested inside relations and brackets" (fun () ->
      reads "-Judge+(Sign+(+Long+Contract))"
        "every judge sign some long contract";
      reads "+Judge^2+(Sign+(+Long+Contract))"
        "most judge sign some long contract";
      reads "±[-(+Registered+Voter)+Citizen]+True"
        "some \u{201C}every registered voter is citizen\u{201D} is true")

(* ── Fix 3: a comma marks an otherwise invisible subject/predicate seam ──── *)

(* A relational subject reading trails off with no closing word ("head some
   horse"), and an affirmative relational predicate opens with no word either,
   so the two run together and a reader cannot see where the subject ends:
   "every head some horse head some animal". Carried from 3.3/3.4 as having no
   readable form; conversion cannot rescue it because A-forms do not convert.

   A comma is chosen over inserting "is" because it requires no knowledge of
   English words. "is" reads correctly when the relation is noun-like ("every
   head some horse is head some animal") and wrongly when it is verb-like
   ("every lov some woman is lov some girl"), and a deterministic renderer
   cannot tell those apart. The comma is neutral to the distinction. *)

let () =
  test "a comma marks the seam between two relational complexes" (fun () ->
      reads "-(Head+Horse)+(Head+Animal)"
        "every head some horse, head some animal";
      reads "-(Head+Horse)-(Head+Animal)" "no head some horse, head some animal";
      reads "+(Head+Horse)+(Head+Animal)"
        "some head some horse, head some animal";
      reads "+(Head+Horse)^1+(Head+Animal)"
        "many head some horse, head some animal";
      reads "-(Lov+Woman)+(Lov+Girl)" "every lov some woman, lov some girl");

  (* Where the predicate already opens with a word, that word is the marker and
     the comma would be redundant — "some head some horse, does not head some
     animal" is worse English than the space it would replace. *)
  test "no comma when \"does not\" already marks the seam" (fun () ->
      reads "+(Head+Horse)-(Head+Animal)"
        "some head some horse does not head some animal";
      reads "+(Head+Horse)^3+(Head+Animal)"
        "few head some horse does not head some animal");

  (* The seam is only invisible when a relational reading ends the subject. A
     negated or compound subject can still end in one, so both take the comma. *)
  test "negated and compound subjects that end in a relation take it too"
    (fun () ->
      reads "-(-(Head+Horse))+(Head+Animal)"
        "every non-head some horse, head some animal";
      reads "-(+Tall+(Head+Horse))+(Head+Animal)"
        "every tall head some horse, head some animal");

  test "no comma where a word already separates the two" (fun () ->
      (* plain predicate: "is" marks it *)
      reads "-(Head+Horse)+Animal" "every head some horse is animal";
      reads "-(Head+Horse)-Animal" "no head some horse is animal";
      (* plain subject: nothing to run together *)
      reads "-Man+(Lov+Woman)" "every man lov some woman";
      reads "-Boy-(Lov+Coward)" "no boy lov some coward";
      reads "±Alice*+(Sign+Contract)" "Alice sign some contract";
      reads "+Officer^1+(Sign+Contract)" "many officer sign some contract")

(* ── Untouched: everything the fix must not have reached ─────────────────── *)

(* The four categorical forms, singulars, proterms and plain relationals are the
   bulk of what a Phase 9 participant reads. None of them involve a compound or
   a levelled relational predicate, so none of them may have moved. *)

let () =
  test "the four categorical forms" (fun () ->
      reads "-Man+Mortal" "every man is mortal";
      reads "-Man-Mortal" "no man is mortal";
      reads "+Man+Wise" "some man is wise";
      reads "+Man-Wise" "some man is not wise");

  test "named individuals and proterms" (fun () ->
      reads "±Socrates*+Man" "Socrates is a man";
      reads "±Socrates*-Man" "Socrates is not a man";
      reads "±Ada*+Animal" "Ada is an animal";
      reads "±Boy'+Coward" "that boy is a coward");

  test "plain relational readings" (fun () ->
      reads "-Man+(Lov+Woman)" "every man lov some woman";
      reads "+Man-(Lov+Woman)" "some man does not lov some woman";
      reads "-Boy-(Lov+Coward)" "no boy lov some coward";
      reads_term "(Gave+Rose-Girl)" "gave some rose every girl");

  (* The E-form sign flip the 4.4 back-check catches (c02/c06). It is here
     because the two must keep reading differently: if a meaning-inverting
     formula ever rendered the same as the correct one, the back-check could
     not catch it and the Phase 9 item would have no right answer. *)
  test "the c02 sign flip still reads as its own, wrong, sentence" (fun () ->
      reads "-(-Member)-Eligible" "no non-member is eligible";
      reads "-(-Member)+Eligible" "every non-member is eligible")

(* ── Known-imperfect readings, recorded rather than pinned as good ───────── *)

(* These are pinned because they are the current behaviour and a change to them
   should be deliberate — NOT because they are good English. Each is out of
   5.0's scope, which is the two proven bugs; they are listed here so the
   approval covers what is still wrong as well as what was fixed. *)

let () =
  test "OPEN: a compound predicate on a named individual takes no article"
    (fun () ->
      (* "Alice is a registered voter" is the English. The article rule fires
         only for a plain-noun predicate, so a compound gets none. Newly
         visible: it used to read "Alice is registered and voter", which was
         wrong in a way that hid this. *)
      reads "±Alice*+(+Registered+Voter)" "Alice is registered voter");

  test "OPEN: negating a compound is indistinguishable from negating its head"
    (fun () ->
      (* Pre-existing and unchanged by 5.0 — both spellings collided under
         " and " too. The back-check cannot see the difference either. *)
      check_eq
        (read_term (Tfl.Ast.Neg (t "(+Registered+Voter)")))
        "non-registered voter";
      reads_term "(-Registered+Voter)" "non-registered voter");

  test "OPEN: no verb agreement on a relational predicate" (fun () ->
      (* "signs", not "sign". Carried from 1.9; the reference has the same
         gap, and fixing it needs morphology we do not have. *)
      reads "-Officer+(Sign+Contract)" "every officer sign some contract");

  test "OPEN: a relational reading still has no \"of\"" (fun () ->
      (* "head of some horse" is the English. The renderer cannot supply the
         preposition: the object's sign carries the *quantity* ("some"), while
         the preposition is a lexical property of the relation and the slot —
         Head takes "of", Lov takes nothing, Gave takes "to" on its second
         object. Emitting a guess would assert a relationship the formula never
         states, on the audit surface, where the back-check could not see it.
         The available lever is term naming, which is the translation prompt's
         job: a quoted head `"head of"` reads correctly, and reaches the first
         object slot only. Kyle's call, 2026-08-02: live with it. *)
      reads "-(Head+Horse)+(Head+Animal)"
        "every head some horse, head some animal")

let () = finish "approved readings (PLAN 5.0)"
