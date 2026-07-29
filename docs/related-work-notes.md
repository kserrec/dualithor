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

*(to be written in step 2.4: NatLog — MacCartney & Manning; NaturalLI — Angeli & Manning;
Sommers & Englebretsen's term logic; Castro-Manzano's TFL programming / Aristotelian
databases.)*
