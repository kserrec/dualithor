(* The anaphora resolution policy (PLAN 5.2).

   Why this test exists. Pratt-Hartmann's handbook chapter puts a knife-edge
   inside the fragment we occupy: `Sat(TV+Rel+RA)` — restricted anaphora, every
   pronoun bound to its *closest* permissible antecedent — is NEXPTIME-complete
   (Thm 15), while `Sat(TV+Rel+GA)` — general anaphora, free co-indexing — is
   **undecidable** (Thm 16), by a tiling encoding in six sentences. Same
   sentences, same syntax, only a different disambiguation policy. The paper
   claims our fragment is decidable where ACE is not; if our engine implemented
   GA that sentence would be false, and the router claim's substrate ("TFL is a
   small decidable fragment, so parse failure is a meaningful signal") would go
   with it.

   The answer, and it is a third option neither the plan nor the literature note
   anticipated: **the engine implements no anaphora resolution at all.** A
   primed name is a constant. It denotes a singleton and is related to nothing —
   not to the term it was primed from, not to any antecedent, not by proximity
   and not by co-indexing. The prime is a spelling convention that makes the
   atom a *fixed reference* (`Infer.is_fixed_ref`), exactly as `*` does for a
   singular term, and nothing more.

   That places us strictly below both RA and GA rather than between them, which
   is why the decidability claim survives. It is also a coverage cost, and the
   two are the same fact seen from either side: the ingredient the
   undecidability proof needs — a pronoun co-varying with a quantified
   antecedent — is inexpressible here, so we cannot write it and it cannot hurt
   us. See docs/engine-surface.md, "The anaphora resolution policy".

   Semantic claims below are decided by model enumeration (the 1.10 semantics,
   differential-verified against the frozen JS oracle), not by the engine's own
   verdicts: outside the categorical fragment the engine may answer `Unknown`
   or refuse an expensive search as `Resource_limit`, while the semantic truth
   is "invalid". Neither outcome can establish a negative. Each negative is
   therefore carried by an exhibited countermodel. *)

let p = Tfl.Notation.parse_proposition
let checks = ref 0

let check name b =
  incr checks;
  if not b then failwith ("test_anaphora: " ^ name)

(* Semantic entailment, by enumeration up to domain size 4. *)
let entails premises conclusion =
  Semantics.counter_model ~max_n:4 ~cap:2_000_000
    (List.map p premises) (p conclusion)
  = None

let verdict premises conclusion =
  (Tfl_verify.check ~premises ~conclusion).verdict

(* ── The prime makes a fixed reference, and that is all it does ──────────── *)

let () =
  check "a primed name is a proterm" (Tfl.Infer.is_proterm_name "Boy'");
  check "an unprimed name is not" (not (Tfl.Infer.is_proterm_name "Boy"));
  check "a proterm is a fixed reference"
    (Tfl.Infer.is_fixed_ref (Atom { name = "Boy'"; singular = false }));
  check "so is a singular, by the same predicate"
    (Tfl.Infer.is_fixed_ref (Atom { name = "Boy"; singular = true }));
  check "a general term is not"
    (not (Tfl.Infer.is_fixed_ref (Atom { name = "Boy"; singular = false })))

(* ── Fixed reference means singleton: some and every collapse ────────────── *)

let () =
  check "some-that-boy entails every-that-boy" (entails [ "+Boy'+Tall" ] "-Boy'+Tall");
  check "and back again" (entails [ "-Boy'+Tall" ] "+Boy'+Tall");
  (* The control that stops the above from being vacuous. *)
  check "a general term does not collapse"
    (not (entails [ "+Boy+Tall" ] "-Boy+Tall"));
  (* The engine agrees with the semantics here — this one is inside the
     categorical fragment, so its verdict is decisive rather than `Unknown`. *)
  check "the engine certifies the collapse" (verdict [ "+Boy'+Tall" ] "-Boy'+Tall" = Valid);
  check "and refuses it for a general term"
    (verdict [ "+Boy+Tall" ] "-Boy+Tall" = Invalid)

(* ── No antecedent resolution of any kind ────────────────────────────────── *)

(* This is the finding. If the engine resolved anaphora under *any* policy,
   `Boy'` would be linked to something. It is linked to nothing: not even to
   the term whose name it borrows. *)

let () =
  check "a proterm is not a member of the term it was primed from"
    (not (entails [] "±Boy'+Boy"));
  check "and inherits nothing from it"
    (not (entails [ "-Boy+Tall" ] "±Boy'+Tall"));
  (* The link has to be *asserted*, which is exactly why `pronominalize`
     records an explicit `±T'+T` anchor for every witness it introduces
     (port-spec §9). Nothing would need anchoring if resolution existed. *)
  check "with the anchor asserted, the inheritance goes through"
    (entails [ "-Boy+Tall"; "±Boy'+Boy" ] "±Boy'+Tall");
  check "and the engine certifies it"
    (verdict [ "-Boy+Tall"; "±Boy'+Boy" ] "±Boy'+Tall" = Valid);
  (* Two primings of one base name are two unrelated constants — there is no
     shared antecedent behind them. *)
  check "distinct primings are distinct individuals"
    (not (entails [ "±Boy'+Tall"; "±Boy''+Short" ] "+Boy'+Short"))

(* ── The GA ingredient is inexpressible: a proterm cannot co-vary ────────── *)

(* Pratt-Hartmann's undecidability witness is "Every artist who admires a
   beekeeper hates every carpenter who despises him", and the essential
   ingredient is the pronoun reaching back past an intervening quantifier to a
   quantified antecedent — so that the individual it denotes varies with the
   subject. A proterm cannot do that: it is one individual for the whole
   formula. The pair below is the discriminating test, and the second half is
   what makes the first half informative. *)

let () =
  check "a proterm object is the same individual for every subject"
    (entails
       [ "-Artist+(Admire+Beekeeper')"; "+Beekeeper'+Nice" ]
       "-Artist+(Admire+Nice)");
  check "a general-term object is not — this is the reading a pronoun would need"
    (not
       (entails
          [ "-Artist+(Admire+Beekeeper)"; "+Beekeeper+Nice" ]
          "-Artist+(Admire+Nice)"));
  (* And the engine does not claim otherwise on the negative. This exact
     candidate expansion exceeds the public inference budget, so the result is
     a classified refusal, never `Invalid` and never `Valid`. *)
  check "the expensive negative is a resource refusal, not a verdict"
    (match
       verdict
         [ "-Artist+(Admire+Beekeeper)"; "+Beekeeper+Nice" ]
         "-Artist+(Admire+Nice)"
     with
    | Error { error_class = Tfl_verify.Resource_limit; _ } -> true
    | _ -> false)

let () = Printf.printf "test_anaphora: %d checks passed\n" !checks
