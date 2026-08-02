# Sweep 6 — Novelty check (adversarial: try to refute)

Date run: 2026-08-01. Method: WebSearch for discovery, then WebFetch against a
primary or authority source (arXiv abs page, Crossref REST API, DOI resolution,
ACL Anthology, DBLP search API, IOS Press, NeurIPS proceedings) for every
citation kept. Search-engine summariser prose was used **only** to generate
candidate leads; nothing in the "Found" lists below rests on a summariser
snippet alone unless explicitly marked UNVERIFIED.

Verdict summary:

| Claim | Verdict |
|---|---|
| 1. No modal/temporal extension of the Pratt-Hartmann/Moss program | **PARTIAL** |
| 2. Complexity of deontic/temporal numerically definite relational syllogistic is open | **SURVIVES** |
| 3. No 2025–26 LLM-output verification system on natural/term logic | **REFUTED** (with a surviving residue) |
| 4. Nobody has combined an LLM with a defeasible logic engine | **REFUTED** |
| 5. Nobody has evaluated LLM fidelity on non-FOL / low-resource notation | **REFUTED** |

---

## Claim 1 — "No modal or temporal extension of the Pratt-Hartmann / Moss decidable-fragment program exists."

### Searches run

Sources: DBLP search API, Crossref REST API, arXiv, Springer, Project Euclid,
IEEE Xplore, ScienceDirect, PhilPapers, ACL Anthology (via general web search).

Verbatim queries:
1. `"temporal syllogistic" logic decidable fragment complexity` (web)
2. `"temporal syllogistic"` (web, exact-phrase)
3. `"deontic syllogistic" logic` (web)
4. `"dynamic syllogistic" OR "syllogistic with time" natural logic Moss` (web)
5. `"modal syllogistic" decidability complexity fragment Pratt-Hartmann Moss` (web)
6. `arXiv "syllogistic" temporal extension "natural logic" tense` (web)
7. `syllogistic logic modal extension complexity "Studia Logica" OR "Journal of Philosophical Logic" 2020..2026` (web)
8. `"modal fragments of natural language" decidable complexity` (web)
9. `"syllogistic" deontic obligation permission fragment decidable natural language reasoning complexity` (web)
10. `Pratt-Hartmann fragments of language temporal prepositions logic complexity` (web)
11. DBLP API: `https://dblp.org/search/publ/api?q=syllogistic%20modal&h=100&format=json`
12. DBLP API: `https://dblp.org/search/publ/api?q=syllogistic%20temporal&h=100&format=json`
13. DBLP API: `https://dblp.org/search/publ/api?q=syllogistic%20deontic&h=100&format=json`
14. DBLP: full publication list of Ian Pratt-Hartmann, `https://dblp.org/pid/60/4630.html`, filtered for temporal/modal/deontic/tense/epistemic/dynamic/time in title
15. Crossref: `query.bibliographic=temporal+syllogistic`, rows=20
16. Crossref: `query.bibliographic=deontic+syllogistic`, rows=20
17. Crossref: `query.bibliographic=modal+syllogistic+complexity+decidable`, rows=20

### Documented negatives

- **DBLP `syllogistic temporal` → 0 total hits.** (`"total":"0"`, `"sent":"0"`.)
- **DBLP `syllogistic deontic` → 0 total hits.**
- **DBLP Pratt-Hartmann author page**: no title on the fetched page contains
  temporal, modal, deontic, tense, epistemic, dynamic, or time.
- Crossref `deontic syllogistic` returns 2,293 items but the ranked top-20 are
  all either deontic-only or syllogistic-only; nothing joins the two.
- Crossref `modal syllogistic complexity decidable` top-20 is dominated by
  Malink's *Aristotle's Modal Syllogistic* (Harvard UP, 2013) chapter records —
  i.e. Aristotle exegesis, not complexity theory.

### Found — genuine prior work (all verified)

**A. Modal syllogistic inside the Sommers/Englebretsen term-logic tradition —
this is the most direct threat.**

- George Englebretsen, "Preliminary notes on a new modal syllogistic",
  *Notre Dame Journal of Formal Logic* 29(3), 1988.
  DOI `10.1305/ndjfl/1093637935` (resolved via Crossref; DOI redirects to
  Project Euclid with matching title).
- J.-Martín Castro-Manzano, "Un método de árboles para la lógica de términos
  modal", *Open Insight* 11(23), 2020, pp. 165–180. A tableaux method for
  Englebretsen's **modal term functor logic**, covering propositional logic,
  basic syllogistic, relational syllogistic, and modal syllogistic.
  *Partially verified*: title/volume/issue/pages corroborated by the Open
  Insight journal page and Redalyc/SciELO records surfaced in search; I did not
  fetch the article PDF itself. Note a citation discrepancy — Castro-Manzano's
  own 2022 *Computación y Sistemas* paper cites it as "Un método de árboles
  para la silogística modal, Open Insight, Vol. 58, pp. 209–237". One of the
  two records is wrong; I could not resolve which.
- Castro-Manzano & Reyes-Cárdenas, "Term Functor Logic Tableaux", *South
  American Journal of Logic* 4(1), 2018, pp. 1–22. **UNVERIFIED**: the PDF at
  `sa-logic.org/sajl-v4-i1/02-Castro-Manzano-Reyes-SAJL.pdf` is a scanned image
  PDF and WebFetch could not extract text. Title/venue/volume come from search
  listings only.
- Cross-reference confirming the modal-TFL line: J.-Martín Castro-Manzano,
  "Toward Relevance Term Logic", *Computación y Sistemas* 26(2), 2022 (SciELO
  page fetched) cites both Englebretsen 1988 and Castro-Manzano 2020 as prior
  modal term logic.

**B. Modal syllogistic with modern axiomatization/completeness (adjacent
program, not Pratt-Hartmann's).**

- Yipu Li & Yanjing Wang, "Epistemic Syllogistic: First Steps",
  *EPTCS* 379 (TARK 2023), pp. 392–406, DOI `10.4204/EPTCS.379.31`,
  arXiv:2307.05043 (abs page fetched). Explicitly frames modal syllogistic as
  "natural fragments of first-order modal logic"; gives axiomatizations and
  completeness proofs for epistemic apodeictic syllogistic and extensions.
  **This is the closest existing thing to "a modal stratum over a syllogistic
  fragment", and it postdates the prior sweep's claim of "four modal-syllogistic
  items total".**
- Steven K. Thomason, "Semantic analysis of the modal syllogistic",
  *J. Philos. Logic*, 1993, DOI `10.1007/BF01049258`; and "Relational Models for
  the Modal Syllogistic", *J. Philos. Logic*, 1997, DOI `10.1023/A:1004200616124`
  (both from DBLP API records).
- Domenico Cantone & Marianna Nicolosi Asmundo, "On the Satisfiability Problem
  for a 4-level Quantified Syllogistic and Some Applications to Modal Logic",
  *Fundamenta Informaticae*, 2013, DOI `10.3233/FI-2013-842` (DBLP record;
  extended version arXiv:1209.1943). Note the direction is *syllogistic set
  theory used to decide modal logic*, not modal syllogistic.
- Uckelman & Johnston, "A Simple Semantics for Aristotelian Apodeictic
  Syllogistics", *Advances in Modal Logic* 8, 2010 (DBLP record).
- Rini, "Is There a Modal Syllogistic?", *NDJFL*, 1998,
  DOI `10.1305/NDJFL/1039118870`; Willing, "Buridan's Divided Modal
  Syllogistic", *NDJFL*, 1991, DOI `10.1305/NDJFL/1093635752`; Thom, "Logic and
  Metaphysics in Avicenna's Modal Syllogistic", 2008,
  DOI `10.1007/978-1-4020-8405-8_13` (all DBLP records).

**C. Temporal syllogistic — exists, but as history of logic.**

- "Chapter 6: The Arabic Theory of Temporal Modal Syllogistic", *Studies in the
  History of Logic*, De Gruyter, 2006, pp. 55–90, DOI `10.1515/9783110326444.55`
  (verified via Crossref; Crossref metadata carries no author name). This is the
  only Crossref-indexed use of "temporal … syllogistic" found, and it is
  Avicenna scholarship, not a decidability/complexity result.

**D. A temporal fragment-of-English result by Pratt-Hartmann himself.**

- Ian Pratt-Hartmann, "Temporal prepositions and their logic",
  *Artificial Intelligence* 166, 2005, pp. 1–36, DOI `10.1016/j.artint.2005.04.003`
  (Crossref verified). Defines the fragment TPE and the interval temporal logic
  TPL; satisfiability NEXPTIME-complete.
- Extended abstract: TIME 2004, pp. 7–8, DOI `10.1109/time.2004.1314412`.
- Predecessor: Ian Pratt & Nissim Francez, "A Decidable Temporal Logic for
  Temporal Prepositions", *Advances in Temporal Logic* (Applied Logic Series),
  2000, pp. 255–278, DOI `10.1007/978-94-015-9586-5_13`.

**This is the sharpest correction to the claim as worded.** Pratt-Hartmann's
*fragments-of-language* program — the same program the numerically definite
syllogistic belongs to — already contains a temporal member with a tight
complexity result. It is not an extension *of the syllogistic* (TPE is built
from temporal prepositions and subordinating conjunctions, not from syllogistic
forms plus a temporal operator), but the sentence "no temporal extension of the
Pratt-Hartmann program exists" is false as stated.

**E. Adjacent counting+modality result.**

- Xiaoxuan Fu & Zhiguang Zhao, "Modal Logic with 'Most'", *Studia Logica*
  114(2), 2026, pp. 383–423, DOI `10.1007/s11225-024-10159-5` (Crossref
  verified). Modal operator "more φ-successors than ¬φ-successors";
  axiomatization over image-finite and all Kripke frames.

### Verdict: **PARTIAL**

The narrow complexity-theoretic claim holds (see Claim 2). The claim **as
worded** does not:
- Modal term functor logic in the exact Sommers/Englebretsen lineage exists
  (Englebretsen 1988) and has a mechanised proof method (Castro-Manzano 2020).
  A paper claiming to be first to put a modal layer on TFL would be wrong.
- A modern modal-syllogistic program with completeness results exists
  (Li & Wang 2023).
- A temporal fragment of English with a NEXPTIME-complete satisfiability
  problem exists inside Pratt-Hartmann's own program (2005).
- "Temporal syllogistic" as a phrase is occupied by Arabic history-of-logic
  scholarship.

**Recommended rewording for the paper**: not "no modal/temporal extension
exists", but "modal extensions of syllogistic and of term logic exist as
proof-theoretic/semantic studies (Englebretsen 1988; Thomason 1993, 1997;
Castro-Manzano 2020; Li & Wang 2023), and Pratt-Hartmann's program contains a
temporal fragment of English (2005); we are not aware of a complexity
classification for a deontic or temporal extension of the numerically definite
*relational* syllogistic specifically."

---

## Claim 2 — "The complexity of deontic or temporal extensions of the numerically definite relational syllogistic is open territory."

### Searches run

Verbatim queries (web + Crossref + DBLP, as listed under Claim 1 items 1–17, plus):
18. `"relational syllogistic" numerically definite complexity Pratt-Hartmann counting quantifiers`
19. `Pratt-Hartmann numerically definite relational syllogistic open problem extension modality complexity`
20. `deontic extension "two-variable fragment with counting" OR "numerically definite" complexity obligation decidable natural language fragment`

### Anchor (verified baseline, not a refutation)

- Ian Pratt-Hartmann, "On the Computational Complexity of the Numerically
  Definite Syllogistic and Related Logics", *Bulletin of Symbolic Logic* 14(1),
  2008, pp. 1–28 (DBLP record `journals/bsl/Pratt-Hartmann08`; Project Euclid
  `10.2178/bsl/1208358842`; preprint arXiv:cs/0701039). Numerically definite
  syllogistic: strongly NP-complete. Numerically definite *relational*
  syllogistic: NEXPTIME-complete.
- Ian Pratt-Hartmann & Lawrence S. Moss, "Logics for the Relational
  Syllogistic", *Review of Symbolic Logic* (Cambridge Core record located).

### Found

Nothing. No item in any of the searches above states a complexity result — or
even a decidability result — for a deontic-operator or temporal-operator
extension of the numerically definite relational syllogistic, or of C2 restricted
to that fragment. Crossref's `deontic syllogistic` and DBLP's `syllogistic
deontic` / `syllogistic temporal` queries return nothing joining the two
literatures at all.

The nearest neighbours found, none of which touch the target:
- deontic complexity work is about *Defeasible Logic* extensions, not counting
  fragments (see Claim 4);
- counting+modality work is Fu & Zhao 2026 ("Modal Logic with 'Most'"), which is
  a propositional modal logic with a majority operator, not a relational
  syllogistic;
- temporal complexity work in the same program is TPL/TPE (Pratt-Hartmann 2005),
  which has no numerical quantifiers.

### Verdict: **SURVIVES**

Stated honestly: *the searches above, run on DBLP (API), Crossref (API), arXiv,
Springer, Project Euclid, IEEE Xplore and general web search, returned nothing
on point.* This is a negative result over a moderately thorough sweep, not a
proof of absence. In particular I did not sweep JSTOR, ACM DL (403 on the one
fetch attempted), or the tables of contents of *JoLLI* / *NDJFL* / *RSL* issue
by issue.

---

## Claim 3 — "No 2025–2026 work builds an LLM-output verification system on natural logic or term logic."

### Searches run

Sources: DBLP search API, ACL Anthology, arXiv, NeurIPS proceedings, IOS Press,
general web.

Verbatim queries:
21. DBLP web search `syllogistic` (front page of hits, `https://dblp.org/search?q=syllogistic`)
22. `SemEval-2026 Task 11 syllogistic reasoning content effect task description`
23. `"SemEval-2026 Task 11" overview paper Valentino "content effect" syllogistic aclanthology`
24. `LLM "natural logic" monotonicity verification proof system 2025 neurosymbolic ACL`
25. `"term logic" OR "term functor logic" LLM translation verification Sommers Englebretsen computational`
26. `LLM verification pipeline "natural logic" NatLog MonaLog LangPro monotonicity 2025 2026 certify LLM output`
27. `NeSy 2025 workshop LLM symbolic verification natural logic syllogistic proof trace`
28. `LLM syllogism verification symbolic engine 2025 "proof" explainable pipeline translate natural language syllogistic validity check`

### Found — this refutes the claim

**A. SemEval-2026 Task 11, "Disentangling Content and Formal Reasoning in Large
Language Models" — an entire ACL shared task on LLM syllogistic validity, with
a large cohort of LLM→symbolic→deterministic-validator systems.**

DBLP's front page of `syllogistic` hits is now almost entirely this task.
Verified ACL Anthology IDs (all resolve under `aclanthology.org/2026.semeval-1.*`):

- `2026.semeval-1.17` — "Lakksh at SemEval-2026 Task 11: Neuro-Symbolic
  Decomposition to Mitigate Content Bias in Syllogistic Reasoning"
- `2026.semeval-1.73` — "dutirshlee at SemEval-2026 Task 11: Symbolic
  Augmentation for Content-Bias-Resistant Syllogistic Reasoning"
- `2026.semeval-1.229` — "AICOE-Tredence at SemEval-2026 Task 11: Mitigating
  Content Bias in Syllogisms via Symbolic Logic-Language Decoupling"
- `2026.semeval-1.315` — "AbstractReasoner at SemEval-2026 Task 11: Reducing
  Content Effects via Knowledge Distillation and Structured Reasoning Prompts"

Further DBLP-verified titles at SemEval@ACL 2026, all on the same task:
"Proofbusters … Neuro-Symbolic Syllogistic Reasoning via LLM-Guided Structure
Extraction and Deterministic Validation" (Ayman, Marzouk, Mashaly, Heriez);
"FregeLogic … A Hybrid Neuro-Symbolic Architecture for Content-Robust
Syllogistic Validity Prediction" (Akinfaderin, Diallo; arXiv:2604.18328);
"TUCNLP … Neuro-Symbolic Content Stripping for Debiased Syllogistic Reasoning";
"YNJTC … A Neuro-Symbolic Hybrid Pipeline for Content-Independent Syllogistic
Reasoning"; "pamaldi …"; "GigitAI … Hybrid Symbolic-Neural Approach for
Syllogistic Validity Classification"; "UFAL-CUNI …".

Method confirmation (arXiv abs page fetched): **Kartáč, Onderková, Bronec,
Kasner, Lango, Dušek, "UFAL-CUNI at SemEval-2026 Task 11: An Efficient Modular
Neuro-symbolic Method for Syllogistic Reasoning", arXiv:2605.04941** — "an
LLM-based parser that translates natural language syllogisms to a first-order
logic (FOL) representation" plus "an automated theorem prover" for deterministic
inference. That is architecturally the same shape as TFL-Verify.

Related, also DBLP-verified at ACL/EACL 2026: "Thinking in Schemas: Robust
Syllogistic Reasoning in LLMs" (Ranaldi, Ranaldi, Zanzotto, Cohen, ACL 2026);
"Can Activation Steering Generalize Across Languages? A Study on Syllogistic
Reasoning in Language Models" (Maraia, Ranaldi, Valentino, Zanzotto, EACL 2026).

**B. A deployed LLM-output verification service built on autoformalization.**

- Chenyang An, Sam Bayless, Stefano Buliani, Darion Cassel, Byron Cook, et al.,
  "A Neurosymbolic Approach to Natural Language Formalization and Verification",
  arXiv:2511.09008 (submitted 2025-11-12, revised 2026-07-13; abs page fetched).
  System **ARc** (Automated Reasoning checks): LLM formalizes natural-language
  policies; inference-time autoformalization validates the logical correctness
  of natural-language statements against those policies; redundant
  formalizations checked for semantic equivalence; reported >99% soundness and
  near-zero false-positive rate; produces auditable artifacts for regulated
  industries. This is precisely "verify LLM output with a formal engine and emit
  a human-inspectable artifact".

**C. Normative-reasoning benchmark for LLMs (adjacent).**

- Ozeki, Ando, Morishita, Abe, Mineshima, Okada, "Normative Reasoning in Large
  Language Models: A Comparative Benchmark from Logical and Modal Perspectives",
  arXiv:2510.26606, BlackboxNLP @ EMNLP 2025 (abs page fetched).

### Documented negative (the surviving residue)

Query 26 (`LLM verification pipeline "natural logic" NatLog MonaLog LangPro
monotonicity 2025 2026 certify LLM output`) returned only the 2017–2020
natural-logic literature — LangPro (Abzianidze, arXiv:1708.09417) and MonaLog
(Hu, Chen, et al., SCiL 2020, arXiv:1910.08772) — and nothing from 2025–2026
applying monotonicity calculus to certifying LLM output. Query 25 returned no
work combining LLMs with term functor logic; the only LLM×term-logic contact
found was a citation of Sommers/Englebretsen inside an ontology-engineering
paper (arXiv:2509.10249), not a system.

### Verdict: **REFUTED**

The claim is false as stated. 2026 has an entire ACL shared task whose leading
systems are LLM-parses-to-symbolic-form + deterministic validator over
syllogisms, plus a production-grade LLM-output verification service built on
autoformalization (ARc).

**What survives, and it is narrower than the project may have assumed:**
every such system found translates to **first-order logic** and discharges it
with a general-purpose solver (Z3, Prover9, an ATP). I found no system using
**term logic / plus-minus notation**, no system using **monotonicity calculus**,
and no system whose engine is a **formally verified fragment-specific decision
procedure with fragment-membership routing**. TFL-Verify's differentiators must
be relocated to (a) the notation, (b) the verified engine + proof trace, and
(c) fragment routing — not to "first to verify LLM output symbolically", and not
to "first to do this for syllogisms".

---

## Claim 4 (NEW) — "Has anyone combined an LLM with a defeasible logic engine?"

### Searches run

Verbatim queries:
29. `LLM "defeasible logic" formalization non-monotonic reasoning legal rules 2024 2025`
30. `large language model answer set programming regulatory compliance legal reasoning s(CASP) Gupta`
31. `LLM argumentation defeasible reasoning ASPIC ABA legal policy engine 2025 formalization system`
32. `Yang Ishay Lee "Answer Set Programs" large language models KR 2023 generate`

Sources: arXiv, ACL Anthology, IOS Press Ebooks, KR proceedings, general web.

### Found — this refutes the claim decisively

**A. LLM → Defeasible Deontic Logic (the exact target layer).**

- **Elias Horner, Cristinel Mateis, Guido Governatori, Agata Ciabattoni,
  "Toward Robust Legal Text Formalization into Defeasible Deontic Logic using
  LLMs", arXiv:2506.08899** (v1 2025-06-10, v3 2025-12-31; abs page fetched).
  Automated formalization of legal texts into Defeasible Deontic Logic;
  decomposes complex normative language into components and checks them for
  logical consistency; introduces refined evaluation metrics and a two-stage
  refinement pipeline; evaluated on Australian telecommunications regulations;
  reports LLM formalizations aligning closely with expert-crafted ones.
  Governatori is the author of Defeasible Deontic Logic itself. **This is the
  single most direct prior art for TFL-Verify's planned defeasible layer.**
  (Note: an alternate title string, "From Legal Texts to Defeasible Deontic
  Logic via LLMs: A Study in Automated Semantic Analysis", also appears for
  arXiv:2506.08899 — probably an earlier version's title.)

**B. LLM + formal argumentation for defeasible reasoning.**

- **Xiaotong Fang, Zhaoqun Li, Chen Chen, Beishui Liao, "LLM-ASPIC+: A
  Neuro-Symbolic Framework for Defeasible Reasoning", ECAI 2025**, Frontiers in
  Artificial Intelligence and Applications vol. 413, pp. 1567–1574,
  DOI `10.3233/FAIA250981` (IOS Press page fetched). Neural language
  understanding + formal ASPIC+ argumentation; new MineQA dataset for multi-step
  defeasible reasoning under strict and defeasible rules; 87.1% on BoardGameQA-2,
  82.6% on BoardGameQA-3.

**C. LLM + ASP (non-monotonic engine) for NL understanding and compliance.**

- Adam Ishay, Zhun Yang, Joohyung Lee, "Leveraging Large Language Models to
  Generate Answer Set Programs", **KR 2023**, `proceedings.kr.org/2023/37`,
  arXiv:2307.07699. LLM translates NL logic-puzzle descriptions into ASP;
  solver does the reasoning.
- Abhiramon Rajasekharan et al., "Reliable Natural Language Understanding with
  Large Language Models and Answer Set Programming", arXiv:2302.03780 (the
  STAR line; Gopal Gupta's group, s(CASP)).
- Coppolillo et al., "LLASP: Fine-tuning Large Language Models for Answer Set
  Programming", KR 2024, `proceedings.kr.org/2024/78`.

**D. Evaluation of defeasible reasoning in LLMs.**

- Emily Allaway & Kathleen McKeown, NAACL 2025 (Long Papers), pp. 10540–10558,
  anthology `2025.naacl-long.529`, DOI `10.18653/v1/2025.naacl-long.529`
  (Anthology page fetched). Title reported by the Anthology page as "Evaluating
  Defeasible Reasoning in LLMs with DEFREASING"; the abstract was not present in
  the fetched page, so the dataset name is single-sourced.

### Verdict: **REFUTED**

This is the most consequential finding of the sweep. The layer TFL-Verify plans
to build *first* is occupied, and by the strongest possible incumbents: the
author of Defeasible Deontic Logic (Governatori) with Ciabattoni's group, doing
LLM formalization of real regulatory text, one year ahead. Any claim of novelty
for "LLM + defeasible engine" must be dropped. A defensible residual claim would
have to be about the **substrate** (term logic with a verified decision
procedure and proof traces, rather than DDL over Prolog-style rules), not about
the combination.

---

## Claim 5 (NEW) — "Has anyone evaluated whether LLMs can produce a non-FOL formal notation faithfully?"

### Searches run

Verbatim queries:
33. `LLM autoformalization low-resource formal language Lean Isabelle Coq comparison performance gap`
34. `LLM code generation low-resource programming languages performance penalty MultiPL-E out-of-distribution`
35. `LLM translate natural language into unusual formal notation Alloy TLA+ Dafny evaluation faithfulness low resource specification language`
36. `"few-shot" prompting recovers performance unfamiliar formal language LLM grammar DSL measured penalty study`
37. `"OWL" OR "CLIF" OR "controlled natural language" LLM formalization notation choice accuracy comparison study measured`

### Found — refutes the claim; and the news is unfavourable to the project

**A. Direct measurement of the out-of-distribution notation penalty.**

- **Arslan Bisharat, Brian Ortiz, Eric Spencer, Khushboo Bhadauria, TaiNing
  Wang, George K. Thiruvathukal, Konstantin Laufer, Mohammed Abuhamad,
  "Can LLMs Write Correct TLA+ Specifications? Evaluating Natural-Language-to-TLA+
  Generation", arXiv:2606.05792** (2026-06-04; abs page fetched).
  205 TLA+ specifications; 2,600 runs across 25 open-weight models plus 130 runs
  across 5 proprietary models. **Up to 26.6% syntactic correctness, only 8.6%
  semantic correctness**, and successes exclusive to progressive prompting. The
  paper attributes this to corpus scarcity (a public TLA+ corpus of a few
  hundred modules vs. millions of C/Python/Java samples). It also reports that
  model size does not predict quality and that **code-specialized models
  underperform due to negative transfer from mainstream-language training**.
  This is the closest available proxy for TFL-Verify's risk: a
  mathematically-precise, low-corpus notation, measured end-to-end.

**B. Survey establishing the low-resource / DSL penalty as a known phenomenon.**

- **Sathvik Joel, Jie JW Wu, Fatemeh H. Fard, "A Survey on LLM-based Code
  Generation for Low-Resource and Domain-Specific Programming Languages",
  arXiv:2410.03981**, ACM TOSEM (2024-10-04, rev. 2025-09-26; abs page fetched).
  111 papers filtered from >27,000. Names data scarcity and syntax
  under-representation as the two obstacles; notes there is **no standard
  benchmark** for evaluating generation in LRPLs/DSLs.

**C. Evidence that notation choice measurably changes accuracy, and that a
compact non-NL logical language can be substituted without loss.**

- **Hanna Abi Akl, "Investigating Language Model Capabilities to Represent and
  Process Formal Knowledge: A Preliminary Study to Assist Ontology Engineering",
  arXiv:2509.10249**, RuleML+RR 2025 (abs page fetched). Explicitly studies
  "the impact of expressing logical problems with different grammars on the
  performance of SLMs on a predefined reasoning task", and concludes "it is
  possible to substitute Natural Language (NL) with a more compact logical
  language while maintaining a strong performance on reasoning tasks."
  *Caveat*: the abs page does not name the grammars compared; the claim that
  CLIF was the winning candidate came from a search summariser and is **not
  corroborated** — treat as UNVERIFIED until the PDF is read.

**D. Evidence on how much prompting recovers.**

- **Bailin Wang, Zi Wang, Xuezhi Wang, Yuan Cao, Rif A. Saurous, Yoon Kim,
  "Grammar Prompting for Domain-Specific Language Generation with Large Language
  Models", NeurIPS 36 (2023)** (proceedings.neurips.cc abstract page fetched).
  Premise stated directly: DSLs are "unlikely to have been encountered often
  enough during pretraining for the LLM to acquire its full syntax". Method:
  augment each few-shot demonstration with a minimally-sufficient BNF grammar;
  at test time predict a grammar, then generate under it. Evaluated on
  SMCalFlow, Overnight, GeoQuery, PDDL planning, and molecule generation.
  **This is the directly applicable mitigation for TFL-Verify: ship the
  plus-minus grammar in the prompt, not just examples.**

**E. Cross-proof-assistant transfer (partially verified).**

- "Multilingual Mathematical Autoformalization", arXiv:2311.03755 — surfaced in
  search with the finding that models fine-tuned on both Isabelle and Lean4
  outperform single-language fine-tunes (16% / 18% acceptable-with-minor-
  corrections vs. 6–11%), suggesting transfer across formal languages.
  **UNVERIFIED**: I did not fetch the abs page; these numbers come from a search
  summariser and must be re-checked before citation.
- "Knowledge Transfer from High-Resource to Low-Resource Programming Languages
  for Code LLMs", *Proc. ACM Program. Lang.*, DOI `10.1145/3689735`.
  **UNVERIFIED**: ACM DL returned HTTP 403 to WebFetch; title/venue/DOI from the
  search listing only.

### Verdict: **REFUTED**

Studies of exactly this kind exist and are numerous. More importantly for the
project, they supply a **calibrated prior, and it is a pessimistic one**: on
TLA+ — a precise, low-corpus notation with an active industrial user base —
the best measured semantic correctness is 8.6%. Plus-minus term-logic notation
has a far smaller corpus than TLA+.

Practical implications worth carrying into the plan:
1. The empirical risk is real and quantified elsewhere; the paper should
   pre-register a notation-fidelity measurement rather than assume recovery.
2. Grammar prompting (Wang et al., NeurIPS 2023) is the specific published
   mitigation and should be the baseline prompting strategy, not plain few-shot.
3. Abi Akl (RuleML+RR 2025) is direct evidence that a compact non-NL logical
   grammar *can* be substituted without accuracy loss on reasoning tasks —
   the one genuinely encouraging datapoint found.
4. An obvious and cheap experiment, apparently unrun in the literature: have the
   LLM emit **FOL** and mechanically transduce FOL→TFL, versus emitting TFL
   directly. The TLA+ paper's "negative transfer" finding suggests the indirect
   route may win.

---

## Verification caveats

1. **Unverified items, flagged inline.** Castro-Manzano & Reyes-Cárdenas, "Term
   Functor Logic Tableaux" (SAJL 4(1), 2018) — the hosted PDF is a scanned image
   and could not be text-extracted; bibliographic data is from search listings.
   "Multilingual Mathematical Autoformalization" (arXiv:2311.03755) numbers —
   summariser-sourced, abs page not fetched. "Knowledge Transfer from
   High-Resource to Low-Resource Programming Languages for Code LLMs"
   (DOI 10.1145/3689735) — ACM DL returned 403. The claim that CLIF was the
   winning grammar in Abi Akl (arXiv:2509.10249) — summariser-sourced, not in
   the fetched abstract. **None of these should be cited without re-checking.**
2. **Citation discrepancy unresolved.** Castro-Manzano's modal-term-logic
   tableaux paper appears under two incompatible records: *Open Insight* 11(23),
   2020, pp. 165–180, "Un método de árboles para la lógica de términos modal"
   (journal site / Redalyc / SciELO) versus *Open Insight* vol. 58, pp. 209–237,
   "Un método de árboles para la silogística modal" (the author's own 2022
   self-citation). Resolve before citing.
3. **Crossref metadata gap.** The De Gruyter chapter "The Arabic Theory of
   Temporal Modal Syllogistic" (DOI 10.1515/9783110326444.55) has no author in
   its Crossref record. The author must be established from the book itself
   before citation.
4. **Sources not swept.** JSTOR, PhilPapers full-text (only individual record
   pages were seen via search), ACM DL (403 on the one fetch attempted), IEEE
   Xplore beyond search listings, Semantic Scholar API, and issue-by-issue
   tables of contents for *JoLLI*, *NDJFL*, *RSL*, *Studia Logica*, *JPL*.
   Claim 2's negative is therefore reproducible over DBLP + Crossref + arXiv +
   web, but is not exhaustive.
5. **SemEval-2026 Task 11 overview paper.** I verified many individual system
   papers by anthology ID but did **not** fetch the task's own overview paper
   (cited in system papers as "Valentino et al., 2026b"). Its exact title,
   authors and anthology ID remain unconfirmed. The task's stated name,
   "Disentangling Content and Formal Reasoning in Large Language Models", comes
   from the UFAL-CUNI abstract, which is a reliable but single source.
6. **Recency.** Several verified items carry 2026 arXiv IDs (2604.*, 2605.*,
   2606.*) and ACL Anthology 2026 IDs. The field is moving fast enough that this
   sweep will be stale within months; the Claim 2 negative is the only one likely
   to hold.
