# Related-work notes

Working notes for the paper's related-work section. Part A (PLAN 2.3): LLM + symbolic-solver
pipelines. Part B (PLAN 2.4, to append): natural logic and the TFL lineage.

Notes are from abstracts/landing pages (per PLAN "read abstracts in Phase 2"); numbers are
as the papers report them and should be re-checked against the full PDFs before they are
cited in the paper draft.

---

## Part A — LLM + solver pipelines (PLAN 2.3)

### Logic-LM (Pan et al., EMNLP 2023 Findings; arXiv:2305.12295)

- Three-stage pipeline: LLM translates the NL problem into a symbolic formulation → a
  deterministic symbolic solver (per task family: logic programming, FOL prover, CSP/SAT)
  performs the inference → a **self-refinement** module feeds solver error messages back to
  the LLM to revise the formalization.
- Benchmarks: ProofWriter, PrOntoQA, FOLIO, LogicalDeduction, AR-LSAT.
- Reported gains: **+39.2%** over the LLM with standard prompting and **+18.4%** over
  chain-of-thought, averaged across the five datasets.
- How TFL-Verify differs: Logic-LM's target languages (FOL, CSP) have no notion of a
  *fragment-membership signal* — a failed translation is just an error to be repaired by
  self-refinement. TFL-Verify makes parse failure a first-class **routing outcome**
  (`Outside_fragment`), and its target notation is variable-free and surface-close, which
  is the fidelity claim. Our v1 deliberately has no repair loop — the escalation signal is
  the product, not a nuisance.

### LINC (Olausson et al., EMNLP 2023; arXiv:2310.15164)

- LLM as a pure **semantic parser**: premises and conclusion are translated to first-order
  logic, then deduction is offloaded entirely to an external theorem prover (Prover9);
  results aggregated by majority vote over sampled translations.
- Benchmarks: FOLIO and ProofWriter, with StarCoder+ (15.5B), GPT-3.5, GPT-4.
- Reported: StarCoder+ with LINC beats GPT-3.5 and GPT-4 with chain-of-thought by an
  absolute **38%** and **10%** respectively on ProofWriter; with GPT-4, LINC scores **26%**
  higher than CoT on ProofWriter while performing comparably on FOLIO.
- Key error-analysis finding: the neurosymbolic and pure-LLM modes "succeed roughly
  equally often" on FOLIO but with **distinct and complementary failure modes**.
- How TFL-Verify differs: LINC is the closest architectural relative (translate → external
  symbolic check, no repair). But its FOL target forces variables and quantifier scoping —
  precisely the translation step where unfaithfulness hides — and it has no principled
  abstention route: a sentence FOL can't express well still gets translated to *something*.
  The complementary-failure-modes finding is direct motivation for our router claim:
  a mechanical signal for "this item belongs to the symbolic path / this one doesn't" is
  the missing piece, and TFL fragment membership provides exactly that.

### SymbCoT (Xu et al., ACL 2024; arXiv:2405.18357)

- **Fully LLM-based** symbolic reasoning: translate NL to a symbolic format, derive a
  step-by-step plan applying symbolic rules, then an LLM verifier checks the translation
  and the reasoning chain. No external solver anywhere.
- Benchmarks: five datasets spanning first-order logic and constraint-optimization
  expressions; reports consistent improvements over CoT and state-of-the-art results
  (exact figures in the full paper).
- How TFL-Verify differs: SymbCoT shows the symbolic *notation* helps even without a
  solver, but its checker is itself an LLM — the verification step has no soundness
  guarantee. TFL-Verify keeps checking symbolic and deterministic (the engine certifies
  validity); the LLM's only trusted role is translation, and even that is audited by
  deterministic back-rendering.

### FoVer (Pei et al., TACL 2025)

- Verifies the *logical correctness of LLM reasoning text*: LLM translates the reasoning
  into executable FOL, then **Z3** validates each step. Evaluated on ProofWriter, FOLIO,
  and REVEAL (real-world LLM outputs); reports significant improvements over existing
  verification methods and demonstrates use for finding annotation errors in datasets.
- How TFL-Verify differs: same spirit — verify LLM output with a symbolic engine — but
  FoVer inherits FOL+SMT opacity: the formalization a Z3 query encodes is not something a
  non-logician can eyeball against the source sentence, and there is no
  membership/abstention signal. Our trace (plus-minus lines, each with a deterministic
  English gloss) targets exactly that auditability gap.

### Aside — NL→FOL translation quality (arXiv:2509.22338, 2025)

- Fine-tuning study of NL→FOL formalization: finds structural/logical translation robust
  but **predicate extraction is the main bottleneck**; supplying gold predicates boosts
  translation performance by 15–20%.
- Useful for the paper as independent evidence that the NL→FOL step is the fragile link —
  the exact step the fidelity claim says TFL's surface-close notation makes easier and
  easier to audit.

### Cross-cutting contrast for the paper

Every pipeline above targets FOL (or richer). None has: (1) a variable-free notation whose
form mirrors NL surface structure (fidelity/auditability), (2) deterministic back-rendering
of the formalization into English for a mechanical fidelity check, or (3) a mechanical
fragment-membership signal usable as a router/abstention mechanism. Those three are the
claims TFL-Verify exists to test.

---

## Part B — natural logic and the TFL lineage (PLAN 2.4)

### NatLog (MacCartney & Manning, 2007–2009)

- Natural logic for textual inference: entailment as a semantic *containment* relation
  (set-theoretic, over expressions of every type — words, phrases, sentences), refined in
  the extended model to seven basic entailment relations.
- Mechanism: decompose premise→hypothesis into a sequence of atomic edits; predict a
  lexical entailment relation per edit; project the relations upward through the semantic
  composition tree (monotonicity/projectivity); join the relations across the edit
  sequence. Implementation uses the Stanford parser, WordNet, and learned classifiers.
- Reported: ~70% accuracy / 89% precision on the FraCaS test suite.
- How TFL-Verify differs: NatLog *never leaves* natural language — inference is edits over
  surface forms, with no symbolic artifact anyone can re-check. TFL-Verify shares the
  conviction that inference should track NL surface structure (common Sommers ancestry),
  but produces a formal object (the plus-minus translation) with a decision procedure and
  an auditable proof trace. NatLog's monotonicity machinery also has no analogue of our
  mechanical fragment/router signal — it always produces *some* relation.

### NaturalLI (Angeli & Manning, EMNLP 2014)

- Natural logic inference for **common-sense fact recall**: infer "cats have tails"-style
  facts from a very large database of known facts, treating inference as search over
  lexical mutations with natural-logic semantics; the database is smoothed so any
  candidate fact has membership with some confidence.
- Reported: 74.2% accuracy predicting held-out facts, beating multiple baselines.
- How TFL-Verify differs: NaturalLI trades soundness for recall by design (soft
  membership, "likely true"); our engine certifies validity and treats everything short of
  proof as `Unknown`/`Invalid` — the opposite operating point. Useful contrast for the
  paper: natural-logic machinery scales to soft common sense, term-logic machinery
  certifies; the router is what lets a system be honest about which regime an input is in.

### Sommers & Englebretsen — the source system

- *An Invitation to Formal Reasoning: The Logic of Terms* (Ashgate, 2000) is the canonical
  book-level presentation of TFL (with Englebretsen 1996, *Something to Reckon With*, and
  Sommers 1982, *The Logic of Natural Language*, behind it). Propositions parse as two
  terms joined by plus-minus functors — a "logibra" (Sommers) with no individual
  variables or quantifiers; the syntax deliberately mirrors NL surface form, drawing on
  Aristotle, the Scholastics, Leibniz, and the 19th-century British algebraists.
- The algebra gives a sound, complete, simple decision method for syllogistic: a
  conclusion follows iff (i) the premises sum algebraically to the conclusion and (ii) the
  number of particular conclusions equals the number of particular premises
  (Englebretsen 1996, p. 167). Singulars, relationals, and compound (propositional) terms
  are all represented in the same two-term shape — the wild-quantity treatment of
  singulars is what lets "Socrates" reason like a term.
- This is the system our vendored engine implements (with the no-existential-import
  discipline and the P/Z test as the categorical decision); the book is the ground truth
  for the 1.13 paper-cases audit.
- Chapter 5, §3, pp. 118–122 also publishes algebraic enthymeme completion: introduce
  one or more unknown premises, write the validity equation, and solve for the omitted
  signed expressions. This establishes priority over TFL-Verify's former closed-form
  missing-premise proposal; see `missing-premise-priority-audit-2026-08-08.md`.
- For the paper's fidelity claim: the book's own selling point — the notation tracks how
  people actually phrase arguments — is exactly the property we are testing empirically
  via LLM translation fidelity vs FOL.

### Castro-Manzano et al. — TFL⁺, TFL programming, Aristotelian databases

Primary: Castro-Manzano, Lozano-Cobos & Reyes-Cárdenas, "Programming with Term Logic,"
*BRAIN* 9(3), 2018 (read in full — the paper our engine's comments cite).

- **TFL⁺**: TFL extended with Peterson (1979) / Thompson (1982) intermediate quantifiers —
  "many" (k/g), "most" (t/d), "few/predominant" (p/b) — carried as superscript quantity
  levels 0–3 on terms (their Table 8). The modified decision method adds condition
  (iii): the conclusion's quantification level must not exceed the premises' (their
  wording: "lesser or equal than the maximum level of quantification of the premises").
  Their Proposition 1 (reliability): an inference is SYLL⁺-valid iff TFL⁺-valid.
  **Engine note:** our vendored engine implements the *term-matched* strengthening of
  (iii) — the conclusion's level must be licensed by a premise quantifying the same
  subject term — which agrees with their validity tables (10–13) while closing the
  loophole the loose phrasing leaves open (a level riding the middle term); documented in
  port-spec §12. Numerical term logic traces further to Murphree (1998).
- **Aristotelian databases** (Mozes 1989): a database is Aristotelian when it (1) explains
  deductions in natural language, (2) volunteers a stronger/weaker answer than asked, (3)
  points out unproven but likely possibilities, (4) suggests "missing rules" that would
  make a query provable, and (5) suggests openings for analogy/induction. Mozes built this
  over Prolog-style syntax; deduction is syllogistic; negation-as-failure included.
- **TFLPL**: their logic-programming language after TFL⁺ (implemented in C): a program is
  a sequence of two-term propositions; the fact/rule distinction disappears (as the
  singular/universal distinction does in TFL); no variables, no unification — inference is
  DON-driven. Named future work at time of writing: a relational module, a numerical
  reasoning module, a probabilistic interpretation (Thompson 1986).
- How TFL-Verify relates: the OCaml engine implements the relational layer, TFL⁺
  numerical validity checks, programs and queries, and deterministic English readings.
  Missing-premise suggestion exists only in the frozen JavaScript reference as bounded
  search and is not part of the OCaml release surface. The former regulatory-router
  product is discontinued; the remaining research question is a matched human comparison
  of deterministic TFL- and FOL-derived English.

### Cross-cutting contrast for the paper (Part B)

The natural-logic line (NatLog, NaturalLI) validates surface-faithful inference but never
produces a checkable symbolic artifact; the term-logic line (Sommers & Englebretsen,
Castro-Manzano) built exactly such an artifact — an algebra with decision procedures — but
was never connected to machine translation from free NL at scale. TFL-Verify is the splice:
LLMs supply the NL→TFL step the term-logic line lacked, and TFL supplies the certifying,
auditable checker the LLM+FOL line (Part A) lacks a human-readable version of.

---

## Part C — adjacent prior art (extended sweep, 2026-07-29)

Five families beyond the PLAN's six named items, each earning its place in the related-work
section for a different reason.

### C1. Syllogistic-fragment theory — Moss, Pratt-Hartmann

- Pratt-Hartmann & Moss, "Logics for the Relational Syllogistic" (*Review of Symbolic
  Logic*, 2009; arXiv:0808.0521): a family of syllogistic fragments parametrized by which
  constructors are allowed (noun-level negation, relative clauses, relational terms), with
  **completeness theorems and complexity results for each fragment** — including results
  on when a rule-based syllogistic proof system exists at all and when *reductio ad
  absurdum* is indispensable. Kruckman & Moss ("Exploring the Landscape of Relational
  Syllogistic Logics," 2018) extend the map.
- Pratt-Hartmann, "On the Computational Complexity of the Numerically Definite
  Syllogistic" (*BSL*): complexity of syllogistic with numerical quantifiers — the
  theoretical neighborhood of TFL⁺'s intermediate quantifiers.
- Why it matters for us: this line is the **theoretical grounding for the router claim** —
  fragment membership is a real, well-studied boundary with known proof-theoretic and
  complexity properties, not an ad-hoc engineering cutoff. It also gives principled
  context for our engine's shape: a complete decision on the categorical fragment, and
  indirect proof (reductio) becoming necessary exactly where their results say rule-based
  systems stop sufficing. We do not need their theorems for the system, but the paper
  should cite them when arguing the fragment boundary is natural.

### C2. Monotonicity NLI systems — MonaLog (Hu, Moss et al., SCiL 2020)

- A deliberately lightweight NLI system: token-level polarity (arrow) tagging plus a small
  set of monotonicity rules over surface forms; generates entailments/contradictions
  directly from the input sentence. Competitive with heavier logic-based NLI models on
  SICK; also used to generate training data for BERT (hybrid MonaLog+BERT improves SICK
  accuracy).
- Why it matters: the strongest modern evidence that *surface-level* symbolic methods
  remain competitive on the fragments they cover — the same bet TFL makes — while still
  producing no translation artifact or membership signal. A close cousin, one step short
  of a certifying checker.

### C3. LLM syllogistic-reasoning benchmarks — NeuBAROCO and kin

- NeuBAROCO (Ozeki et al.; arXiv:2306.12567, follow-up 2408.04403): 95 multiple-choice +
  790 NLI syllogism problems in English and Japanese, annotated for the classic human
  biases (belief bias, conversion errors, atmosphere effect). Findings: models are far
  from error-free on syllogisms; GPT-4's failures concentrate in the **reasoning step
  rather than interpretation** (their Translate-and-Explain analysis), and human-like
  biases persist.
- Why it matters: direct evidence that LLMs mis-reason on exactly the fragment our engine
  decides *completely* — the cleanest possible motivation for offloading that fragment to
  a symbolic checker. Also a candidate dataset for PLAN 6.3 (syllogism-focused loader)
  alongside SylloBase/Avicenna, with the bias annotations enabling a nice analysis cut
  (does the pipeline neutralize belief bias?).

### C4. LLM + Prolog pipelines

- "Reliable Reasoning Beyond Natural Language" (Borazjanizadeh & Piantadosi, 2024;
  arXiv:2407.11373): LLM translates problem statements into Prolog; SWI-Prolog executes;
  reasoning becomes "infer the facts, encode as logic code." LoRP (2025, *Knowledge-Based
  Systems*) is the same architecture hardened with validation and voting. A 2025 study
  (arXiv:2506.04575) probes whether LLMs are *stable* formal-logic translators under
  linguistic variation — finding translation consistency, not solving, is the weak link.
- Why it matters: same translate-then-execute architecture with Horn-clause Prolog as
  target; the field's own conclusion ("reliability … mainly depends on the translation
  step") is our fidelity claim's premise stated from the FOL/Prolog side. Also the
  concrete systems our `router/escalate.ml` stub (PLAN 5.1) names as the future
  escalation hook — and the contrast to TFLPL (Part B), which programs in terms with no
  unification at all.

### C5. Autoformalization — Wu et al. (NeurIPS 2022; arXiv:2205.12615)

- Few-shot LLM translation of competition mathematics into Isabelle/HOL: 25.3% of
  problems translated perfectly; training a neural prover on autoformalized theorems
  lifted MiniF2F proof rate 29.6% → 35.2%. A now-large successor literature (Lean-targeted
  ProofBridge, StepFun-Formalizer, etc.).
- Why it matters: the maximal-ambition end of the same program — LLM as NL→formal
  translator — where "perfect translation rate" plays the role our parse rate +
  back-check play. Shows the translation bottleneck is not an artifact of logic
  benchmarks; it appears at every scale of formality. Our niche is the opposite corner:
  a deliberately small target language where translation can be *audited by reading*.

### C6. SatLM (Ye, Chen, Dillig & Durrett, NeurIPS 2023; arXiv:2305.09656)

- Declarative prompting: the LLM parses the NL problem into a **set of logical
  constraints** (not an imperative program), and an off-the-shelf SAT solver derives the
  answer. Fixes the planning-error failure mode of program-aided LMs (which manipulate
  equations imperatively and err mid-derivation). New state of the art on LSAT,
  BoardgameQA, and StructuredRegex at publication.
- Why it matters: completes Part A's pipeline taxonomy — imperative programs (PAL),
  FOL provers (LINC), mixed solvers (Logic-LM), SAT constraints (SatLM). The
  declarative-specification framing is the closest of the four to ours (a TFL translation
  is also a declarative artifact, not a procedure); the difference remains auditability
  of the artifact and the membership signal.

### C7. Grammar-constrained decoding (Geng et al., EMNLP 2023, arXiv:2305.13971;
Synchromesh, Poesia et al. 2022; XGrammar and successors)

- Constrains generation token-by-token with a per-token validity mask so the output is
  **guaranteed to conform to a grammar** — no fine-tuning, works for JSON, code, formal
  languages. Mature tooling exists (Synchromesh → XGrammar and the JSON-schema
  ecosystem).
- Why it matters — **design-relevant, not just citation-relevant**: GCD could force every
  translation to parse, trivially zeroing our `Lexical`/`Syntactic` failure classes. The
  paper must address "why not just constrain decoding?" head-on: forcing well-formed TFL
  does not make translation *faithful* — it would transmute out-of-fragment content into
  syntactically valid but wrong TFL, silently destroying both the router signal (parse
  failure is the abstention mechanism) and the honesty of the fidelity audit. Deliberate
  unconstrained generation is a feature: we *want* the model able to fail loudly.
  Possible future ablation arm: GCD-constrained translation vs free translation,
  measuring what happens to back-check fidelity when parse failure is impossible.

### C8. Abstention / selective prediction

- "Know Your Limits: A Survey of Abstention in Large Language Models" (TACL 2025) and
  "The Art of Refusal" (arXiv:2407.18418) survey the field: abstention framed from the
  query/model/values perspectives; selective-prediction methods rely on **uncertainty
  estimates** (confidence thresholds, calibration) to decide when to withhold an answer.
  Cascade work (e.g., early-abstention routing to cheaper/stronger models) is the
  systems-side cousin.
- Why it matters: the router *is* an abstention mechanism, but with a mechanically
  checkable trigger — fragment membership — rather than a confidence estimate. That's the
  vocabulary the paper should use to position `Outside_fragment`: abstention literature
  keeps searching for reliable abstention signals inside the model; TFL provides one
  *outside* the model, deterministic and inspectable. One or two of these citations
  situate the claim.
