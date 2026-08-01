# Scope and predictions

*Written 2026-08-01, before any benchmark has been run (project is at PLAN 3.x).
Research notes only — no PLAN step, nothing implemented on the basis of this.*

Two things are recorded here that would otherwise be lost: **pre-registered predictions**
about how the pipeline will perform, written down before any data exists, and the
**scope reasoning** about which text domains and which logical extensions are worth
pursuing. Companion document: `expressiveness-literature.md` (the citation-backed survey).

The predictions are recorded specifically so they can be checked against reality later.
Per the project's "honest results, always" principle, a prediction written *before* the
experiment is worth more than a post-hoc rationalisation — including, and especially, when
it turns out wrong.

---

## 1. Pre-registered predictions

Stated by Claude (Fable 5) on 2026-08-01, with no benchmark data in hand. Translator
models under test are frontier-tier (Claude Sonnet 5, GPT-5.6, Kimi K3).

### 1.1 End-task accuracy vs. direct answering — **expect a wash**

**Prediction: −2 to +5 points** on in-fragment items, i.e. plausibly within noise.

Reasoning. Logic-LM and LINC reported large gains over GPT-3.5-era models, and the
literature's consistent pattern is that augmentation gains shrink as base models improve.
Direct-answering baselines on clean in-fragment categorical items should land around
90–97%, leaving little headroom. More fundamentally, the pipeline does not eliminate
error — it **relocates** it from the reasoning step (now provably correct) to the
translation step (still an LLM). Both Logic-LM and LINC found translation, not solving, to
be the bottleneck.

### 1.2 Belief-bias items — **expect the clearest win**

**Prediction: +10–20 points on the bias-incongruent slice** (valid-but-unbelievable,
invalid-but-believable syllogisms).

Reasoning. LLMs inherit human-like content bias from training data; a symbolic checker is
structurally immune, because content words become uninterpreted term symbols before any
verdict is computed. NeuBAROCO's human-bias annotations make this slice directly
measurable (relevant to PLAN 6.3). If one headline positive result survives, this is it.

Residual exposure: translation is itself performed by an LLM and could carry bias into the
formalisation. Expected to be small relative to verdict-stage bias — but if it is *not*
small, that is itself a reportable finding, and the 7.2 fidelity audit is where it would
surface.

### 1.3 Fidelity claim — **expect a split verdict**

**Prediction: auditability advantage clearly demonstrated; raw NL→TFL parse rates possibly
no better than NL→FOL, plausibly worse, especially for the weakest model.**

Reasoning, in two directions that partly cancel. In TFL's favour: plus-minus notation
tracks English surface form, and the engine's deterministic `read_prop` gives a canonical
back-rendering that FOL simply does not have — verbalising `∀x(P(x) → ∃y R(x,y))` is a
judgment call, so FOL fidelity auditing is intrinsically mushier. Against: **FOL is
massively represented in pretraining data and TFL's notation is essentially absent.** The
models have seen enormous numbers of FOL formalisations and approximately zero plus-minus
ones. Few-shot prompting (PLAN 4.2) compensates partially, not fully. This is an
out-of-distribution headwind that FOL does not face.

### 1.4 Router claim — **expect good recall, diluted precision**

**Prediction: `Outside_fragment` recall high, precision meaningfully lower.**

Reasoning. Parse failure is a genuinely crisp mechanical signal, so genuinely
out-of-fragment sentences will reliably fail to parse (good recall). But parse failure
**conflates two distinct events**: the sentence really is outside the fragment (the signal
we want) and the model botched an in-fragment sentence (noise). Nothing distinguishes them
mechanically. PLAN 6.4's manual in/out tags are what make this measurable at all.

### 1.5 Coverage — **the constraint shaping every other number**

**Prediction:** near-total on the syllogism dataset; **20–40% on FOLIO**; high but
closed-world-confounded on ProofWriter; ~70% by construction on policybench (it is
authored that way).

Coverage composes multiplicatively with everything else:

```
certified-verdict rate ≈ coverage × parse rate × back-check pass rate × (1 − Unknown rate)
```

That last factor is known from the engine side but becomes an *empirical* statistic here:
outside the categorical fragment the derivation search is incomplete (and per
`expressiveness-literature.md` §1.1, provably must be), so some parsed, faithful
translations will still return `Unknown`.

### 1.6 The headline result — **selective trust, not accuracy uplift**

**Prediction: ~98%+ selective accuracy** (accuracy on items where the pipeline returns a
certified verdict), at whatever coverage the data yields, with a human-auditable trace per
item.

This is the claim expected to survive contact with data, and the reason is structural: the
engine is sound (the Phase 1 gates are the warrant), so a certified verdict can only be
wrong if the translation was unfaithful *and* the back-check missed it. **Selective
accuracy is bounded by translation fidelity alone.** That makes PLAN 7.2's human fidelity
audit the load-bearing measurement of the entire evaluation.

Framing consequence: the correct evaluation is *selective prediction* — report the pair
(coverage, accuracy-given-coverage), never a blended number that hides abstentions. Our
abstentions are unusually defensible because they are **structural** rather than a tacked-on
confidence threshold: `Outside_fragment`, `Translation_suspect`, and `Unknown` are distinct,
mechanically produced, and each means something specific. PLAN 7.1's abstention-aware
accuracy metric is where this lands.

### 1.7 Scorecard for later

| # | Prediction | Outcome |
|---|---|---|
| 1.1 | Flat accuracy −2 to +5 pts vs. direct | *not yet measured* |
| 1.2 | +10–20 pts on bias-incongruent slice | *not yet measured* |
| 1.3 | Auditability wins; parse rate may not | *not yet measured* |
| 1.4 | Router: good recall, diluted precision | *not yet measured* |
| 1.5 | FOLIO coverage 20–40% | *not yet measured* |
| 1.6 | Selective accuracy ≥98% | *not yet measured* |

---

## 2. Scope: which text domains fit

### 2.1 Policy / eligibility text — the sweet spot

"All employees with five years of service are eligible for sabbatical" is nearly a
categorical proposition already: compound subject term, predicate term, universal
affirmative. This is what policybench (PLAN 6.8–6.9) is authored around, and it is where
the fragment fits natively.

### 2.2 Legal text — partly in scope, and it is a *different* slice

Legal text shares the policy shape in places but adds five features, unequal in severity:

| Feature | Status | Note |
|---|---|---|
| **Defeasibility** ("unless", "notwithstanding", "except as provided in") | Out of fragment — **but addressable**, see below | The single biggest mismatch. Classical consequence is monotonic; legal rules are not. |
| **Deontic** ("shall", "may", "must", "is entitled to") | Out of fragment — **addressable** | Partial workaround available natively: term logic absorbs a lot into the *term*, so "is obligated to file" can simply be a predicate term. Loses deontic-specific inference, keeps subsumption. This works better in TFL than FOL because terms are first-class. |
| **Temporal** ("within 30 days", "prior to the effective date") | Out of fragment — **addressable** | See `expressiveness-literature.md` §2.3(g). |
| **Numerical thresholds** | **Split** | TFL⁺ handles counting quantifiers ("at least three directors are independent"). Arithmetic over amounts ("51% of outstanding shares", "damages exceeding $10,000") is calculation, not quantification — out. |
| **Vagueness** ("reasonable", "material", "good faith") | Permanently out | Not a gap in TFL. These are deliberate delegations to a human judgment-maker; no formal system resolves them. |

**What fits:** subsumption and eligibility determination — given stated rules and stated
facts, does this party fall under this defined category, and does this entitlement follow?
A small fraction of *jurisprudential* reasoning; a large fraction of *practical*
legal-adjacent work (compliance checking, benefits determination, contract condition
satisfaction).

**Underrated fit worth noting:** the engine's programs/queries layer (ported in PLAN 1.7 —
`parse_program`, `query_prop`, `check_program_consistency`) is shaped like a legal
definitions section. "'Qualified Person' means…" is a symbol table, and asking whether an
entity falls under a defined term is exactly `query_prop`.

**Correction to an earlier assumption.** The first three of the five rows above were
initially judged structurally out of reach, requiring escalation to a different engine.
That is wrong, and `expressiveness-literature.md` §2.3 documents why: defeasibility has a
**linear-time** treatment with native certificates (Maher 2001), deontic content has a
**coNP-complete** treatment that is paradox-free by construction (input/output logic), and
metric deadlines are **polynomial** with a human-readable failure certificate (Simple
Temporal Networks). The narrow-core-plus-escalation architecture still stands as a
principle; the specific placement of these three gaps was too pessimistic.

### 2.3 Philosophical text — best logical fit, worst pipeline fit

**Why the logic fits.** Term logic's historical home is philosophy. Aristotle's
syllogistic, the scholastic tradition, and much of the early modern canon were composed in
an idiom that maps to plus-minus notation far more directly than to FOL. Sommers's entire
project was motivated by the claim that FOL *distorts* traditional philosophical argument.
If the fidelity claim holds anywhere, it holds most strongly here.

**Why the pipeline does not fit.** `Tfl_verify.check` takes `{premises, conclusion}` and
certifies the step between them. Philosophical prose almost never presents that structure:

- **Enthymemes are the norm** — suppressed premises mean the stated material is formally
  invalid even when the intended argument is valid.
- **Argument reconstruction has no ground truth** — two competent readers extract different
  premise sets from the same passage, and which reconstruction is correct is frequently the
  scholarly dispute itself. So the pipeline verifies the reconstructor's reading, not the
  text.

**The latent capability worth remembering.** The port spec's not-ported list (PLAN 0.3)
defers `suggestMissingPremise` among the Aristotelian extras. Missing-premise suggestion
**is** enthymeme completion — the exact operation philosophical reconstruction needs. A
tool that says "invalid as stated; valid if you grant *this* premise, rendered in English"
would be a real contribution to reading philosophy, and it is latent in the reference
engine we already ported around. Not scheduled; recorded so it is not forgotten.

**Where the value actually is:** teaching logic (the reference engine's `checkExpression`
grading path exists for this), formalising the historical canon, and checking one's own
reconstructions — *not* adjudicating live philosophical disputes, which turn on premise
truth and concept individuation rather than validity.

---

## 3. Why second-order logic is the wrong axis

Recorded because the question will recur.

**Second-order logic quantifies over properties rather than individuals** — "Socrates has
some quality Plato lacks", mathematical induction, the identity of indiscernibles. It
cannot be added as a feature, and more importantly it should not be wanted.

**It is not merely hard.** Under standard semantics, SOL has no sound, complete, and
effective proof system — this follows from Gödel, since SOL categorically characterises
arithmetic. Validity is **not even semi-decidable**: FOL at least lets you enumerate proofs
and eventually find one if it exists; SOL does not. The set of second-order validities is
not arithmetically definable. Two escape routes exist and both dissolve the request:
**Henkin (general) semantics** restores completeness but yields a system provably
equivalent to many-sorted first-order logic — full syntactic cost, first-order result;
**restricted fragments** (monadic SOL over strings or trees, per Büchi and Rabin) are
decidable only because the structures are fixed.

**The deeper reason: the properties destroyed are the value proposition.** TFL's worth here
rests on three legs, and second-order quantification attacks all three simultaneously:

1. **Variable-free surface proximity** — the basis of the fidelity claim, and the reason
   deterministic back-rendering is possible at all. Quantifying over predicate positions
   requires predicate *variables*, reintroducing exactly the binding machinery TFL exists
   to avoid.
2. **A decidable core** — the basis of the selective-accuracy promise. Gone by the theorems
   above; the engine would return `Unknown` on nearly everything interesting, and `Unknown`
   delivers no value.
3. **A crisp fragment boundary** — the basis of the router claim. If nearly everything
   parses, parse failure stops carrying information.

**The narrowness is the product.** A more expressive TFL would simply be a worse FOL.

**Three things that soften the loss.** (a) Term logic already absorbs much
apparently-second-order English — "she has all the qualities of a good leader" is often
term containment, not property quantification, and TFL is a logic of terms with compound
and relational term formation. (b) Genuinely second-order content is rare outside the
philosophy of mathematics; note that every canonical example (induction, indiscernibles,
Frege on number, categoricity) comes from that one area, and policy, legal eligibility and
ordinary argument essentially never quantify over properties. (c) **If more expressiveness
is ever wanted, the right axis is modality and defeasibility, not order** — those open up
legal text (§2.2), and crucially many modal logics are decidable, so leg 2 survives. See
`expressiveness-literature.md` §2.3 and §3 for what is safe and what silently is not.
