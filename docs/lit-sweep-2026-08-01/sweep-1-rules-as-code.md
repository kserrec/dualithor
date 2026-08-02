# Sweep 1 — Rules as Code, Legal Informatics, RegTech

Literature sweep for TFL-Verify. Every citation below was verified against Crossref, the
arXiv API, ACL Anthology, or the OASIS standards registry. Where I read the actual paper
text (via `pdftotext` on the publisher/arXiv PDF) I say so; where I only have the abstract,
I say that too. Anything I could not confirm is in **Verification caveats** at the end.

Method note: search-engine summaries were treated as *leads only*, never as content. Every
substantive claim here traces to either (a) a machine-readable metadata API, or (b) text I
extracted from the source PDF myself.

---

## 1. Catala — a programming language for the law

**Merigoux, D., Chataing, N., & Protzenko, J. (2021). Catala: a programming language for the
law. *Proceedings of the ACM on Programming Languages*, 5(ICFP), 1–29.**
DOI: [10.1145/3473582](https://doi.org/10.1145/3473582) · arXiv:2103.03198
*Verified: Crossref (title, authors, volume 5, issue ICFP, pages 1–29, 2021-08-19) + arXiv abstract page.*

**What it does.** A domain-specific language for statutory law, built on the observation
that statutes state general rules and then add exceptions. That pattern is captured as a
first-class **default expression** (a prioritised exception structure), which is the core
semantic contribution. Catala compiles to a generic lambda-calculus which can then be
translated to mainstream languages. From the verified abstract: "We have implemented a
compiler for Catala, and have proven the correctness of its core compilation steps using the
F* proof assistant."

**What it was evaluated on** (verified abstract): "several legal texts that are algorithms in
disguise, notably section 121 of the US federal income tax and the byzantine French family
benefits; in doing so, we uncover a bug in the official implementation."

**How programs are authored — the load-bearing question.**
**Human pair programming, not automation.** The methodology is a lawyer and a programmer
working side by side, in a *literate programming* style where the statutory text is
interleaved with the code that implements it. This is stated in the abstract ("Catala aims to
bring together lawyers and programmers through a shared medium, which together they can
understand, edit and evolve") and is the entire subject of the companion methodology paper:

**Huttner, L., & Merigoux, D. (2022). Catala: Moving towards the future of legal expert
systems. *Artificial Intelligence and Law*.**
DOI: [10.1007/s10506-022-09328-5](https://doi.org/10.1007/s10506-022-09328-5) (2022-08-25)
*Verified: Crossref (title, both authors, journal, date). Abstract NOT retrieved — Springer
requires auth and returned a 303 redirect to an IdP. HAL preprint exists at hal-02936606.*

**Deployment.** The 2021 paper's own evaluation covers US IRC §121 and French family
benefits. Reported French government engagement is with **DGFiP** (income tax) and **CNAF**
(family/social benefits). See caveat 1 — I could not fetch the Inria page (403, Anubis
bot-protection) and so cannot confirm the proof-of-concept vs. production distinction.

**Overlap / difference with TFL-Verify.**
- Both target statutory/policy rule text with exceptions. Catala's **default expression** is
  the closest existing analogue to TFL-Verify's planned defeasible layer (rules with
  exceptions and priorities) — worth reading closely before designing that layer.
- Catala's audit story is *literate programming*: a human reads statute-next-to-code. That
  presupposes the reader can read Catala. TFL-Verify's premise (a readable back-translation
  of the formal object) targets the reader who cannot.
- Catala is a compilation target with proven-correct compilation; TFL-Verify is a *verifier*
  that certifies validity and emits a proof trace. Different job.

---

## 2. Catala + LLMs — the one real NL→Catala automation result

**Lorenzo, G., Pietromatera, A., & Holzenberger, N. (2025). Translating Tax Law to Code with
LLMs: A Benchmark and Evaluation Framework. *Proceedings of the Natural Legal Language
Processing Workshop 2025* (NLLP 2025), pages 31–47.**
[aclanthology.org/2025.nllp-1.4](https://aclanthology.org/2025.nllp-1.4/)
*Verified: ACL Anthology landing page (title/authors/venue) + I extracted and read the full PDF text.*

**This is the direct answer to "is there any automated NL→Catala path?" — yes, as of 2025,
and this is it.**

**What they built.** A benchmark for generating Catala from French legal text (French housing
benefit / *aide personnalisée au logement* provisions), harvested from the published
open-source Catala corpus. Dataset: **416 training / 86 validation / 89 test samples**
(read from the paper text). Model input is the legal paragraph **plus hand-written metadata**
(the Catala scope/type declarations) — the model does not generate the metadata.

**Evaluation framework** — five metrics, all read from the paper: CodeBLEU, BERTScore, ChrF,
Tree Edit Distance (TED), and **Valid Syntax (VS)** ("checks if the generated code is
syntactically correct").

**Measured results** (read from Tables 1–3):
- GPT-4.1 few-shot, n=16: CodeBLEU 52.2 ± 6.0, VS 88.8 ± 5.6.
- GPT-4.1 zero-shot: CodeBLEU 2.3, VS 2.2 — i.e. the model has effectively never seen Catala.
- Best fine-tuned (QLoRA, 4-bit): Qwen2.5-Coder-14B-Instruct CodeBLEU 60.3 ± 5.1, VS 93.3 ± 4.4.
- LLaMA-3.3-70B-Instruct: CodeBLEU 48.5, VS 87.5.

**How the formalization is validated: it isn't, semantically.** This is the critical finding.
Every metric is either surface similarity to a reference or a parse check. There is **no
behavioural test, no execution against cases, and no human review step.** The authors say so
directly. From the Limitations section, verbatim: *"We do not claim that code generated by
LLMs can be used as-is."* And from the Conclusion, their own future work names the gap:
*"(3) include unit tests in the evaluation."*

**Overlap / difference with TFL-Verify.**
- **This is the closest published work to TFL-Verify's translation stage** and should be
  cited as the state of the art for LLM→legal-DSL.
- The gap it leaves open is exactly TFL-Verify's thesis: it produces a formalization with no
  mechanism for anyone — expert or not — to check that the formalization means what the
  source text meant. CodeBLEU 60 with no semantic check is not an audit.
- Note the shared author: Nils Holzenberger is also an author of SARA (§13) and DeonticBench
  (§13). He is the connective tissue of this subfield.

---

## 3. "Closing the Loop" — an unreviewed preprint extending Catala

**Heydari, A., & Leowald, T. (2026). Closing the Loop: Formally Verified Law as a Reward
Signal for Self-Improving Legal AI.** arXiv:2606.23913, submitted 2026-06-22. 14 pages.
*Verified: arXiv API (title, authors, date, "14 pages, no figures"). Abstract read via WebFetch.*

Proposes LLM-driven autoformalization into "a formal legal calculus extending Catala" plus a
verification kernel, using a deterministic verifier as an RL reward signal. Demonstrated on
German procedural deadlines, US Commerce Clause analysis, and cross-jurisdictional sanction
proportionality. **No quantitative benchmark results in the abstract.**

**Treat with caution.** No venue, no figures, two unknown authors, and a claim structure
("provable correctness", "self-improving legal AI") that is far broader than 14 pages can
support. I did not read the body. Flagging it for completeness, not endorsing it.

---

## 4. OpenFisca

**openfisca.org** (Python engine, AGPL; core repo github.com/openfisca/openfisca-core)
*Verified: I fetched openfisca.org/en/ directly. Country-adopter list below is from that page.*

**Architecture.** A modular Python rules engine. `OpenFisca-Core` is the shared engine; each
jurisdiction ships a **country package** of rules plus versioned **parameters** (rates,
thresholds, dated). Exposes a JSON Web API for application developers and a vectorised Python
API for microsimulation over large populations. It is microsimulation software with explicit
ties to legislation.

**How rules are authored.** **Entirely by hand, in Python.** Rules are Python classes
(`Variable` subclasses with a `formula`); parameters are YAML with validity dates. Authors are
policy experts, government staff, and developers. There is **no NL→OpenFisca automation** in
the project.

**Adopters** (quoted from openfisca.org/en/): Barcelona (*Les meves ajudes*, benefit
eligibility for citizens); the French Parliament (**LexImpact**, letting MPs estimate the
budget/tax/benefit impact of proposed reforms); Japan (*Support Estimate Hermit Crab*,
national and local benefit eligibility). See caveat 2 for the wider adopter list (New Zealand,
Australia, Tunisia, Mali, Côte d'Ivoire, Senegal, UAE) which I have from search summaries only.

**Overlap / difference with TFL-Verify.**
- OpenFisca is a *calculator*, not a verifier: it evaluates numeric formulas over a household,
  it does not certify entailment or detect that a rule set contradicts itself.
- LexImpact is the closest thing in the field to TFL-Verify's use case (b) "audit whether a
  rule set is self-consistent" — but it does so by *simulating budget impact*, not by symbolic
  consistency checking.
- Its arbitrary Python formulas mean it has no decidable fragment and no proof trace. This is
  a clean contrast to draw in the paper.

---

## 5. LegalRuleML (OASIS standard)

**Palmirani, M., Governatori, G., Athan, T., Boley, H., Paschke, A., & Wyner, A. (eds.) (2021).
*LegalRuleML Core Specification Version 1.0*. OASIS Standard, 30 August 2021.**
[docs.oasis-open.org/legalruleml/legalruleml-core-spec/v1.0/os/legalruleml-core-spec-v1.0.html](https://docs.oasis-open.org/legalruleml/legalruleml-core-spec/v1.0/os/legalruleml-core-spec-v1.0.html)
*Verified: I fetched the OASIS standards registry page and read the official "Cite as" block,
editor list, and approval date verbatim.*

An XML markup standard (XML Schema + Relax NG, built on Consumer RuleML 1.02) for representing
the semantic and logical content of legal normative rules — deontic operators, defeasibility,
temporal parameters, and the provenance/attribution metadata that legal rules need (who
asserted this rule, under what authority, effective when). Approved as a Committee
Specification 2018-05-08 and as a full **OASIS Standard on 2021-08-30**.

**How rules are authored.** By hand, by knowledge engineers, typically with a legal expert.
LegalRuleML is an interchange *serialisation*, not a reasoner — it is consumed by engines such
as SPINdle (§7).

**Overlap / difference.** LegalRuleML's metadata layer (jurisdiction, temporal validity,
authority, defeasibility annotations) is a well-designed target that TFL-Verify's defeasible
layer could borrow from rather than reinvent. Its weakness for this project: XML at that level
of verbosity is unreadable by a non-expert, which is precisely the reader TFL-Verify targets.

---

## 6. DAPRECO knowledge base

**Robaldo, L., Bartolini, C., Palmirani, M., Rossi, A., Martoni, M., & Lenzini, G. (2019/2020).
Formalizing GDPR Provisions in Reified I/O Logic: The DAPRECO Knowledge Base. *Journal of
Logic, Language and Information*, 29(4), 401–449.**
DOI: [10.1007/s10849-019-09309-z](https://doi.org/10.1007/s10849-019-09309-z)
*Verified: Crossref — full six-author list, journal, volume 29, issue 4, pages 401–449, issued 2019-11-19.*

Companion LREC paper: **Robaldo, Bartolini, Lenzini et al., "The DAPRECO Knowledge Base:
Representing the GDPR in LegalRuleML," LREC 2020**, [aclanthology.org/2020.lrec-1.698](https://aclanthology.org/2020.lrec-1.698/).
*Verified: ACL Anthology URL resolves; I did not read the full text.*

**What it is.** A repository of rules encoding GDPR provisions, layered on the **PrOnto**
privacy ontology. Rules are if-then statements in **reified Input/Output logic** (a deontic
logic where obligations are outputs of a normative system given inputs), serialised in
LegalRuleML. Described as the largest freely available LegalRuleML knowledge base.

**How rules are authored.** Hand-crafted by the project's legal and logic researchers. No
automation.

**Overlap / difference.** DAPRECO is a static formalization artifact, not a pipeline. It
matters to TFL-Verify as (a) proof that hand-formalizing one regulation is a multi-year
funded project — the cost argument for automation — and (b) a possible source of
already-formalized rules to test a TFL translation against.

---

## 7. Regorous, SPINdle, and the Governatori defeasible-logic line

**Governatori, G., & Shek, S. (2013). Regorous: a business process compliance checker.
*ICAIL '13: Proceedings of the Fourteenth International Conference on Artificial Intelligence
and Law*.** DOI: [10.1145/2514601.2514638](https://doi.org/10.1145/2514601.2514638)
*Verified: Crossref (title, both authors, venue, 2013-06-10). Abstract elided by publisher; full text closed.*

**Governatori, G. (2015). The Regorous Approach to Process Compliance. *2015 IEEE 19th
International Enterprise Distributed Object Computing Workshop* (EDOCW), pp. 33–40.**
DOI: [10.1109/EDOCW.2015.28](https://doi.org/10.1109/EDOCW.2015.28)
*Verified: Crossref + Semantic Scholar (DBLP key conf/edoc/Governatori15). Abstract elided; paper is closed access — I did NOT read it.*

**Lam, H.-P., & Governatori, G. (2009). The Making of SPINdle. In *Rule Interchange and
Applications* (RuleML 2009), LNCS, pp. 315–322.**
DOI: [10.1007/978-3-642-04985-9_29](https://doi.org/10.1007/978-3-642-04985-9_29)
*Verified: Crossref.*

**Governatori, G., Hashmi, M., Lam, H.-P., Villata, S., & Palmirani, M. (2016). Semantic
Business Process Regulatory Compliance Checking Using LegalRuleML. In *Knowledge Engineering
and Knowledge Management* (EKAW), LNCS, pp. 746–761.**
DOI: [10.1007/978-3-319-49004-5_48](https://doi.org/10.1007/978-3-319-49004-5_48)
*Verified: Crossref.*

**What the stack is.** SPINdle is an open-source Java defeasible-logic reasoner (scales to
theories with over a million rules). Regorous is a *compliance-by-design* checker: business
processes are modelled in BPMN and annotated with the effects of each task; normative
requirements are formalized in **FCL / PCL** (Formal Contract Logic / Process Compliance
Logic — defeasible logic plus a deontic logic of violations, giving obligations, permissions,
prohibitions, and compensatory obligations); SPINdle then computes which obligations are in
force at each point in the process, and Regorous reports where the process violates them.

**What was actually deployed and measured.** Corroborated from an independent systematic
review that I read in full (López & Hildebrandt, §7a): a compliance analysis was performed on
**six business processes for consumer complaint management against Section 8 of the Australian
Telecommunications Consumers Protection Code 2012 using the Regorous compliance framework**,
in the context of a study of the complaint handling process of a land and property management
authority (LPMA) in New South Wales, Australia. I could not obtain per-rule accuracy or
runtime numbers — see caveat 3.

### 7a. The systematic review that quantifies the authoring bottleneck

**López, H. A., & Hildebrandt, T. T. (2024). Three Decades of Formal Methods in Business
Process Compliance: A Systematic Literature Review.** arXiv:2410.10906, 2024-10-13.
Self-described as "UNPUBLISHED MANUSCRIPT."
*Verified: arXiv PDF downloaded and read in full.*

46 primary studies selected from 5,018 retrieved, spanning 1981 to GDPR. **This paper is the
single best citation for TFL-Verify's motivating claim.** Verbatim findings I read:

- *"From the set of primary studies, 41 (resp. 89,13%) works considered the formalization of
  regulatory texts an activity requiring manual effort."*
- *"A total of 26 studies (56,52% of the total) did not exhibit evidence of an actual use of
  the compliance framework proposed."*
- On maturity: *"63,04% of frameworks are at levels A-D of the technology readiness levels,
  which means conceptual solutions with artificial examples… only 13,4% of the studies
  providing evidence on the application of the frameworks in operational settings, with none
  of them providing long-term analysis of their impact."*
- Under a heading literally titled **"Where are the lawyers?"**: *"A marked absence of evidence
  of the use of existing compliance frameworks by compliance specialists (lawyers,
  consultants, etc). This might be because most of the existing compliance frameworks require
  compliance officers to know a type of mathematical logic, which is far from their
  background, and whose training takes time."*
- They also name the missing benchmark: *"We lack a benchmark dataset that can be used for
  comparison among different compliance frameworks."*

**Overlap / difference with TFL-Verify.** This review states TFL-Verify's problem statement in
the field's own words, with numbers, from an independent source. It is a *supporting* citation,
not a competing system. The 89.13%-manual figure and the "Where are the lawyers?" finding
should both appear in the paper's introduction.

---

## 8. Dragoni et al. — the pre-LLM NL→rules baseline

**Dragoni, M., Villata, S., Rizzi, W., & Governatori, G. (2018). Combining Natural Language
Processing Approaches for Rule Extraction from Legal Documents. In *AI Approaches to the
Complexity of Legal Systems* (AICOL), LNCS, pp. 287–300.**
DOI: [10.1007/978-3-030-00178-0_19](https://doi.org/10.1007/978-3-030-00178-0_19)
*Verified: Crossref (four authors, 2018). Note: widely cited as 2017 (workshop year); Crossref records 2018 for the LNCS volume.*

Classical NLP pipeline (Stanford Parser syntax patterns + Boxer logic-based extraction +
WordNet) extracting rules from the **Australian Telecommunications Consumer Protections Code**.
Reported precision 83.05%, recall 90.78%, F-measure 86.74% on term identification.

**Important correction, read directly from Horner et al. (§9):** those published numbers are
internally inconsistent. Horner et al. recompute from Dragoni's own reported counts (65 gold
atoms, 59 extracted, 49 correct) and get **recall 75.38%** (not 90.78%) and **F1 79.03%** (not
86.74%). They further re-count the gold standard themselves and find 69 atoms, giving recall
71.01% and F1 0.772. If TFL-Verify cites the Dragoni baseline, cite the corrected figures and
the correction.

---

## 9. Horner et al. — LLMs → Defeasible Deontic Logic (the strongest LLM-formalization result)

**Horner, E., Mateis, C., Governatori, G., & Ciabattoni, A. (2025). Toward Robust Legal Text
Formalization into Defeasible Deontic Logic using LLMs.** arXiv:2506.08899, submitted
2025-06-10, v3 2025-12-31 ("extended version with additional results and discussion").
Affiliations: TU Wien; AIT Austrian Institute of Technology; Central Queensland University;
Charles Sturt University.
*Verified: arXiv API + I downloaded and read the full PDF.*

**Pipeline.** Segment legal text into "law snippets" (using DeepSeek-R1) → extract deontic
atoms → generate DDL rules → optional **refinement stage** (Claude Sonnet 4) that reprocesses
all snippets and rules jointly. Corpus: the **Australian Telecommunications Consumer
Protections Code** (same corpus as Dragoni, enabling direct comparison).

**Models evaluated** (read from the paper): GPT-4.1, GPT-4o, GPT-4o mini, DeepSeek-V3 (0324
and original), Claude Sonnet 4 (with extended thinking), Llama 4 Maverick, OpenAI o3, o1,
o4-mini, o3-mini, DeepSeek-R1 (0528 and original). Plus QLoRA-style fine-tuning of GPT-4o and
GPT-4.1.

**How the formalization is validated — and this is the key point.** Six hand-graded dimensions
against an **expert-crafted gold standard**, with a short-circuiting scheme (fail Qi ⇒ all Qj,
j>i fail): Q1 completeness (as a *percentage* of gold rules attempted), Q2 syntactic validity,
Q3 semantic correctness, Q4 deontic modality accuracy, Q5 precondition appropriateness, Q6
atom-name meaningfulness/reuse. **Grading is manual and requires someone who can read DDL and
knows the gold standard.** There is no lay-auditable artifact anywhere in the loop.

**Results I read.** Deontic annotation precision 100% across all their experiments (vs 95.92%
for Dragoni). Term identification precision/recall/F1 in the 60–86% band across configurations
(e.g. 85.51% and 84.06% appear repeatedly in the results tables); highest precision overall
still belongs to Dragoni et al., with GPT-4o single-step second-best; highest recall from the
refinement-stage pipeline seeded by GPT-4.1; highest F1 from the refinement pipeline seeded by
DeepSeek-R1 (0528).

**Their own stated limitation, which TFL-Verify should quote.** Section 4.5.5 argues the
gold-standard metric is itself unsound: LLMs are penalised for producing extra rules that are
*"arguably justified by the legal text"* but absent from the gold standard, so *"the metric
fails to distinguish between semantically valid additions and hallucinated additions,
undermining its reliability in assessing true model performance."* That is a direct argument
that gold-standard matching is the wrong validation instrument for legal formalization — which
is an argument for something like a readable trace instead.

**Overlap / difference with TFL-Verify.**
- DDL with defeasibility and priorities is the target representation TFL-Verify's planned
  defeasible layer is heading toward. Governatori is a co-author here and the author of
  SPINdle/Regorous — this is the same lineage.
- The distinguishing gap is identical to the Catala case: expert-only validation, no
  mechanism for a non-expert to see what the rules say.

---

## 10. The Rules as Code movement — position papers and critiques

**Mohun, J., & Roberts, A. (2020). Cracking the code: Rulemaking for humans and machines.
*OECD Working Papers on Public Governance*, No. 42. OECD Publishing, Paris.**
DOI: [10.1787/3afe6ba5-en](https://doi.org/10.1787/3afe6ba5-en), issued 2020-10-12.
*Verified: Crossref (title "Cracking the code", OECD Working Papers on Public Governance,
2020-10-12). Crossref returns an empty author array — authors James Mohun and Alex Roberts are
confirmed from the OECD publication page and from Morris's citation of it in the Blawx paper,
which I read. Case studies from New Zealand, France, and Canada: see caveat 4.*

The canonical position paper. Proposes that governments produce an official machine-consumable
version of rules alongside the natural-language version.

**Critiques and drafter's-eye views:**

**Kennedy, R. (2024). Rules as code and the rule of law: ensuring effective judicial review of
administration by software. *Law, Innovation and Technology*, 16(1), 170–193.**
DOI: [10.1080/17579961.2024.2313801](https://doi.org/10.1080/17579961.2024.2313801)
*Verified: Crossref (single author Rónán Kennedy, journal, volume 16, pages 170–193, 2024-01-02).
I did NOT read the body — I have the framing (benefits vs. substantial risks; ossification,
mis-translation of rules, separation-of-powers problems) from search summaries only. See caveat 5.*

**Waddington, M. — "Rules as Code" (research note) and "Rules As Code: Drawing Out the Logic of
Legislation for Drafters and Computers," SSRN abstract 4299375.**
*Partially verified: the SSRN abstract ID resolves in search results. I did not fetch SSRN or
Crossref-verify a DOI. Waddington is a legislative drafter (Jersey) arguing RaC does not
trespass on interpretive functions. See caveat 6.*

**Barraclough, T. et al.** — New Zealand Law Foundation-funded "legislation as code" research.
*UNVERIFIED as a formal citation; see caveat 7.*

**Relevance to TFL-Verify.** The mis-translation critique — that encoding law into code
silently makes interpretive choices — is the strongest external motivation for the project's
audit story, and is now empirically demonstrated by Vernie & Grabmair (§11a).

---

## 11. Recent (2023–2026) LLM → executable/logical legal representation

Listed roughly by relevance to TFL-Verify.

### 11a. **Vernie, J., & Grabmair, M. (2026). By Their Fruits You Will Know Them: Comparing Formalizations of Law by the Decisions They Encode.** arXiv:2605.25186, 2026-05-24. 23 pages, 17 figures, submitted to EMNLP 2026.
*Verified: arXiv API (abstract verbatim) + I downloaded and read the PDF body.*

**THE CLOSEST PRIOR ART TO TFL-VERIFY'S AUDIT THESIS.**

Method (read from the paper): instruct **9 frontier LLMs** to formalize each of **10 EU
provisions** — spanning GDPR (Arts. 6, 9, 17, 22), the AI Act, the DMA, and consumer-law
directives (UCTD, UCPD) — as a **tree whose leaves are input variables, internal nodes are
logical operators, and the root is the legal consequence**, i.e. a Boolean function
representing "the decision schema a legal expert would follow." Then: match trees at the node
level, derive a shared interface per pair, and use **Z3** to enumerate prime implicants / edge
cases on which any two formalizations disagree. Selected edge cases are then **verbalized by an
LLM into concrete factual scenarios** for review.

Findings (verified abstract): *"behavioral divergence between formalizations is essentially
uncorrelated with their structural agreement"* and the verbalized cases *"reveal qualitatively
distinct types of disagreement, including divergences that mirror genuine controversies in the
legal commentary."*

**Why it is close but not the same.** Four differences I confirmed in the body:
1. It is **differential, not absolute** — it needs ≥2 formalizations and tells you *that they
   disagree*, never that either matches the source text.
2. The reviewer is explicitly a **legal expert**: *"verbalize selected edge cases into concrete
   factual scenarios in natural language that a legal expert can evaluate."* They cite
   accessibility to non-experts as a *"recognized concern in adjacent fields"* — an open
   problem they gesture at, not one they solve.
3. The human reads *scenarios*, never the formal object. The Boolean tree stays opaque.
4. Their own limitation: *"verbalization hides several layers of complexity. The verbalization
   itself is generated by an [LLM]"* — an unverified NL artifact in the audit path.

### 11b. **Amrollahi, D., Lopez, J., & Barrett, C. (2026). Faithful Autoformalization via Roundtrip Verification and Repair.** arXiv:2604.25031, 2026-04-27.
*Verified: arXiv API, abstract verbatim.*

**The most direct threat to a "readable back-translation" novelty claim.** Verbatim: *"formalize
a statement, translate the result back to natural language, re-formalize, and use a formal tool
to check logical equivalence. When the two formalizations agree, this provides evidence of a
faithful formalization."* Failure triggers stage-level diagnosis and scoped repair. Evaluated on
two statutory domains (**Texas Transportation Code**, **Texas Parks and Wildlife Code**) with
Claude Opus 4.6 and GPT-5.2. Result: rules failing the equivalence check show **1.4x–2.5x more
NLI drift** than rules that pass.

**Difference.** The round trip here is a *machine* consistency check with no human in it — the
back-translated NL is an intermediate artifact, discarded after re-formalization. It is not
offered to a person to read. Clark Barrett's group is a formal-methods lab; this is autoformalization
methodology, not legal-informatics UX. TFL-Verify's claim must be about the *human-facing*
readable rendering, not about round-tripping per se, which is now taken.

### 11c. **Nguyen, H. T., Fungwacharakorn, W., Wehnert, S., Zin, M. M., Kong, Y., Xue, J., Araszkiewicz, M., Goebel, R., & Satoh, K. (2026). GDPR Auto-Formalization with AI Agents and Human Verification.** arXiv:2604.14607, 2026-04-16. **Accepted at ICAIL 2026.**
*Verified: arXiv API, abstract verbatim.*

Multi-agent LLM workflow generating legal scenarios, formal rules, and atomic facts, coupled
with *"independent verification modules which include human reviewers' assessment of
representational, logical, and legal correctness."* Conclusion: *"structured verification and
targeted human oversight are essential for reliable legal formalization."* **The reviewers are
expert human reviewers.** This is the peer-reviewed statement that human verification is
necessary — and it is done the expensive way.

### 11d. **Zin, M.-M., Wehnert, S., Kong, Y., Nguyen, H.-T., Fungwacharakorn, W., Xue, J., Araszkiewicz, M., Goebel, R., Satoh, K., & Nguyen, L.-M. (2026). Can Legislation Be Made Machine-Readable in PROLEG?** arXiv:2601.01477, 2026-01-04.
*Verified: arXiv API, abstract verbatim.*

A single LLM prompt simultaneously produces if-then rules and a PROLEG encoding of **GDPR
Article 6**; these are *"validated and refined by legal domain experts"*; the executable PROLEG
program *"can produce human-readable explanations for instances of GDPR decisions."*
Same team as 11c. Note the two-artifact design (if-then rules as the human-facing layer, PROLEG
as the executable layer) — architecturally similar to what TFL-Verify does with a readable gloss,
but the human-facing layer is validated by experts, and the explanations are of *decisions*,
not of the *encoding*.

### 11e. **Yadamsuren, B., Platt, S. K., & Diaz, M. (2025). LLM-Assisted Formalization Enables Deterministic Detection of Statutory Inconsistency in the Internal Revenue Code.** arXiv:2511.11954, 2025-11-15. 29 pages; code at github.com/borchuluun/section121-inconsistency-detection.
*Verified: arXiv API, abstract verbatim.*

**Directly occupies TFL-Verify's use case (b): auditing a rule set for self-consistency.**
GPT-4o translates **IRC Section 121** (the same section Catala evaluated on) into Prolog rules,
refined in SWISH; GPT-5 guides further refinement; the Prolog model then detects an
"inconsistency zone" deterministically. Measured: GPT-4o with either NL-only or Prolog-augmented
prompting detected the inconsistency in **only one of three strategies (33% accuracy)**;
NL prompting achieved **100% rule coverage** vs **66%** for Prolog-augmented. The hybrid Prolog
model produced deterministic, reproducible results where prompting did not.

**Difference.** Formalization is hand-refined by the authors in SWISH; no lay-audit mechanism;
n=1 statute section. But the framing — LLM formalization + symbolic engine → deterministic
inconsistency detection — is TFL-Verify's use case (b) almost exactly. Cite it and differentiate
on the audit layer and on scale.

### 11f. **Sadowski, A., & Chudziak, J. A. (2025). On Verifiable Legal Reasoning: A Multi-Agent Framework with Formalized Knowledge Representations.** CIKM '25, pp. 2535–2545. arXiv:2509.00710, 2025-08-31.
*Verified: arXiv API including journal_ref (CIKM '25 proceedings, pages 2535–2545).*

Modular multi-agent framework: an ontology schema formalizes statutory concepts into verifiable
intermediate representations supporting symbolic inference. On statutory tax calculation:
**76.4%** with the modular framework vs **18.8%** for end-to-end baselines with foundational models.
*(Numbers from the abstract via WebFetch; I did not read the body.)*

### 11g. **Wang, O. P., Wong-Toropainen, S., Amrollahi, D., Bai, R., Bansal, T., Garg, A., & Gilpin, L. H. (2026). Know Your Limits: On the Faithfulness of LLMs as Solvers and Autoformalizers in Legal Reasoning.** arXiv:2606.16118, 2026-06-15. Submitted to COLM 2026 (under review); accepted at the AI4Law and AI4Math workshops at ICML.
*Verified: arXiv API including the comment field.*

Names three failure modes of LLM legal autoformalization: **scope laundering** (reporting
conclusions inconsistent with the formal solver without executing the logic), **implicit
constraint blindness**, and **program synthesis failures**. Concludes there is *"a fundamental
gap between benchmark accuracy and logical faithfulness"* and that scope laundering persists
across all models. *(Content via WebFetch of the abs page; I did not read the body.)*
**This is TFL-Verify's threat model, published.** Strong motivating citation for why the
symbolic engine must be the authority and the LLM only the translator.

### 11h. **Janatian, S., Westermann, H., Tan, J., Savelka, J., & Benyekhlef, K. (2023). From Text to Structure: Using Large Language Models to Support the Development of Legal Expert Systems.** JURIX 2023. arXiv:2311.04911, 2023-11-01.
*Verified: arXiv API, abstract verbatim.*

GPT-4 generates JusticeBot-methodology "pathways" from legislation. Evaluation: **60% of
generated pathways rated equivalent to or better than manually created ones in a blind
comparison.** The evaluation is a blind expert comparison against hand-built pathways — again,
expert-mediated, no lay audit.

### 11i. **Khoja, A., Kölbl, M., Leue, S., & Wilhelmi (2025). Automated Consistency Analysis for Legal Contracts.** arXiv:2504.18422, 2025-04-25. **Accepted for publication in *Artificial Intelligence and Law*.** Tool: ContractCheck (github.com/sen-uni-kn/ContractCheck).
*Verified: arXiv API including the acceptance comment.*

SMT-based consistency checking of Share Purchase Agreements: an SPA ontology, clause
preconditions and constraints encoded in **decidable fragments of first-order logic**,
contracts converted into "blocks," then Z3-style SMT solving to find conflicting clauses.
**Encoding into blocks is manual — no LLM in the loop** (the abstract does not mention LLMs).
Relevant to TFL-Verify twice over: it is use case (b) in the contract domain, and its
"decidable fragment of FOL" framing parallels TFL-Verify's fragment-membership routing.

### 11j. **Kennan, A., Singh, L., Garcia Guevara, A., Ahmed, M., & Goodman, J. (2025). AI-Powered Rules as Code: Experiments with Public Benefits Policy.** Beeck Center for Social Impact + Innovation (Georgetown University) and the Digital Benefits Network. Published 2025-03-24.
*Verified: I fetched the Digital Government Hub publication page.*

Four experiments using **GPT-4o (API), ChatGPT (web), and Gemini 1.5 Flash (web)** on **SNAP and
Medicaid** eligibility policy across California, Georgia, Michigan, Pennsylvania, Texas (both
programs), Alaska (SNAP), Oklahoma (Medicaid). Targets: natural-language eligibility summaries,
machine-readable JSON pseudocode, and executable eligibility code.

Findings from the page: LLMs were less effective asked to identify *all* eligibility criteria at
once than criterion-by-criterion; RAG improved accuracy with "mixed results for relevance and
completeness"; simple prompts produced "unusable code" and detailed prompts "partially correct"
results; and *"Accuracy and equity considerations must outweigh efficiency."* The report
recommends human oversight but supplies **no verification methodology a non-expert could apply.**

**This is the practitioner-side statement of exactly the gap TFL-Verify targets, from a
government-innovation lab rather than an academic venue.** Excellent framing citation.

---

## 12. Blawx — the non-expert-facing end of the field (and it has no LLM)

**Morris, J. (2022). Blawx: Web-based user-friendly Rules as Code. *GDE'ASP 2022: Workshop on
Goal-Directed Execution of Answer Set Programs*, 1 August 2022, Haifa, Israel. CEUR Workshop
Proceedings Vol-3193, paper 4.** Lexpedite Legal Technology Ltd., Sherwood Park, Alberta.
[ceur-ws.org/Vol-3193/paper4GDE.pdf](https://ceur-ws.org/Vol-3193/paper4GDE.pdf) · github.com/lexpedite/blawx
*Verified: I downloaded the CEUR PDF and read it in full.*

**What it is.** A web tool for encoding legal rules using **Google Blockly** drag-and-drop
blocks, backed by **s(CASP)** (goal-directed answer set programming; migrated from Flora-2 in
December 2021). Morris's stated requirements, quoted from the paper, include *"easy for subject
matter experts to use, to facilitate adoption and avoid the knowledge acquisition bottleneck"*
and *"natural language explanations for conclusions linked to legislative source material, to
earn trust of experts, developers, and users."* He claims Blawx is *"to my knowledge the only
offering with all of them."*

**The explanation feature — closest thing in the field to TFL-Verify's proof trace.** Read from
the paper: results display *"one or more 'explanations', which are a collapsible tree view of…
the natural language justification provided by the s(CASP) reasoner. When the defeasibility
elements of the encoding refer to sections of the source law, those sections are highlighted in
the text of the explanation. Hovering over the highlighted text display the text of the
legislative section to which they refer."* Each test also auto-generates three web API endpoints;
a demo expert-system chatbot ("BlawxBot") consumes them.

**Institutional backing.** Since late 2021, development *"has been guided primarily by the needs
of the Rules as Code Programme at the Canada School of Public Service, which is supporting
departments across the Government of Canada."* Acknowledgments name Service Canada's Benefits
Delivery Modernization Programme and the SMU Centre for Computational Law.

**How rules are authored — decisive.** By a human subject-matter expert, dragging blocks. I
grepped the full text for `llm|gpt|language model|machine learning|natural language process` —
**zero matches.** Blawx has no automated NL→rules path of any kind.

**Overlap / difference with TFL-Verify.**
- Blawx and TFL-Verify agree on the goal — a formal legal encoding a non-programmer can work
  with and whose conclusions come with a source-linked natural-language justification.
- They differ on both halves: Blawx is **100% hand-authored** (no LLM), and its readability
  comes from a *visual block editor* rather than from a notation that reads as prose.
- Blawx is the strongest evidence that the "lay-accessible" half of TFL-Verify's thesis is a
  recognised goal with real government uptake — and that nobody has combined it with automated
  formalization.

---

## 13. Legal NLP benchmarks usable as evaluation data

All verified against the arXiv API (titles, author lists, dates, comment fields).

| Benchmark | Citation | Size / content | Fit for TFL-Verify |
|---|---|---|---|
| **SARA** | Holzenberger, N., Blair-Stanek, A., & Van Durme, B. (2020). *A Dataset for Statutory Reasoning in Tax Law Entailment and Question Answering.* arXiv:2005.05257, 2020-05-11. NLLP@KDD 2020. | US tax code sections + cases; entailment and numeric QA | **Best fit.** Statutory rules + fact patterns + ground-truth entailment. Directly exercises "verify a claim against rules." |
| **DeonticBench** | Dou, G., Brena, L., Deo, A., Jurayj, W., Zhang, J., Holzenberger, N., & Van Durme, B. (2026). *DeonticBench: A Benchmark for Reasoning over Rules.* arXiv:2604.04443, 2026-04-06. | **6,232 tasks** across US federal taxes, airline baggage policies, US immigration administration, US state housing law. **Reference Prolog programs released for all instances.** Optional solver-based workflow where models translate statutes and facts to executable Prolog with an explicit program trace. Best hard-subset performance: **44.4% on SARA Numeric, 46.6 macro-F1 on Housing.** | **Extremely strong fit and a partial novelty threat.** Deontic (obligations/permissions/prohibitions), real rule domains, and it already pairs an NL benchmark with a symbolic target plus traces. Read this one first. |
| **LegalBench** | Guha, N., Nyarko, J., Ho, D. E., Ré, C., Chilton, A., et al. (40 authors) (2023). *LegalBench: A Collaboratively Built Benchmark for Measuring Legal Reasoning in Large Language Models.* arXiv:2308.11462, 2023-08-20. 143 pages. NeurIPS 2023 Datasets & Benchmarks. | 162 hand-crafted tasks, six reasoning types | Partial. Mostly classification, not rule-application with a formal target. The rule-application/rule-conclusion subsets are the usable slice. |
| **CUAD** | Hendrycks, D., Burns, C., Chen, A., & Ball, S. (2021). *CUAD: An Expert-Annotated NLP Dataset for Legal Contract Review.* arXiv:2103.06268. **NeurIPS 2021.** | 13,000+ expert annotations; clause span highlighting | Weak fit. Extraction/highlighting, not entailment. |
| **LexGLUE** | Chalkidis, I., Jana, A., Hartung, D., Bommarito, M., Androutsopoulos, I., Katz, D. M., & Aletras, N. (2021). *LexGLUE: A Benchmark Dataset for Legal Language Understanding in English.* arXiv:2110.00976. **ACL 2022.** | Multi-dataset NLU suite | Weak fit. Classification/NLU, no rule formalization. |
| **OpenExempt** | Servantez, S., Lawsky, S. B., Jain, R., Linna, D. W., & Hammond, K. (2026). *OpenExempt: A Diagnostic Benchmark for Legal Reasoning and a Framework for Creating Custom Benchmarks on Demand.* arXiv:2601.13183, 2026-01-19. | Diagnostic benchmark + on-demand custom benchmark generation | Promising; Sarah Lawsky's involvement means real statutory-logic grounding. I did not read the body. |
| **CitizenQuery-UK** | Majithia, N., Shinde, R., Chapman, Z., Trital, P., Decker, J., Maskey, M., Simperl, E., & Shadbolt, N. (2026). *The CitizenQuery Benchmark.* arXiv:2602.04064, 2026-02-03. | 22k synthetic query/response pairs from gov.uk; FActScore-based factuality benchmarking of 11 models | Adjacent, not core. Factuality of NL answers, no formal representation. Useful as motivation (benefits/tax/immigration queries where errors are "severe, negative, likely invisible"). |

**Benefits/eligibility data specifically:** DeonticBench (housing, immigration, taxes) and the
Beeck Center SNAP/Medicaid experiments (§11j) are the two real sources. I found **no public,
labelled benefits-eligibility dataset with ground-truth formalizations** — that gap is itself
worth reporting.

---

## 14. THE QUESTION THAT MATTERS MOST

> Is there an existing system that (1) automatically formalizes rule text with an LLM AND
> (2) gives a human a way to audit that formalization without expert training?

**No. As of this sweep, no system does both.** The field splits cleanly, and nothing bridges it.

**The field is NOT uniformly hand-authored** — that would have been the answer in 2023, but it
is no longer true. LLM formalization of legal text is now an active, publishing subfield with
at least eight distinct 2025–2026 efforts (§2, §9, §11a–11h, §11j). So the honest finding is
sharper than "uniformly hand-authored":

**Split A — systems that automatically formalize with an LLM.** Lorenzo/Pietromatera/Holzenberger
(Catala), Horner et al. (DDL), Vernie & Grabmair (Boolean trees), Amrollahi/Lopez/Barrett
(roundtrip), Nguyen et al. and Zin et al. (PROLEG), Yadamsuren et al. (Prolog), Sadowski &
Chudziak (ontology IR), Janatian et al. (JusticeBot pathways), Beeck Center (JSON/code).
**Every one of them validates the formalization by one of exactly three means, and all three
require expertise:**
1. **Surface similarity to an expert-authored gold standard** — Lorenzo et al. (CodeBLEU/ChrF/
   TED/BERTScore + a parse check), Horner et al. (six hand-graded dimensions vs. an expert DDL
   gold standard), Janatian et al. (blind expert comparison).
2. **Expert human review in the loop** — Nguyen et al. (ICAIL 2026), Zin et al., Beeck Center.
   All say expert oversight is *essential*; none reduce the expertise required.
3. **Machine-to-machine formal checks with no human at all** — Amrollahi et al. (roundtrip
   logical equivalence via a formal tool), Yadamsuren et al. (deterministic Prolog).

**Split B — systems a non-expert can audit.** Exactly one is genuinely designed for this:
**Blawx** (Morris 2022) — Blockly blocks plus s(CASP) natural-language justifications
hyperlinked to the legislative source text, backed by the Canada School of Public Service.
**Blawx contains no LLM and no automated formalization whatsoever** (verified by grepping the
full paper text: zero matches for LLM/GPT/language model/machine learning/NLP). Catala's
literate programming and OpenFisca's readable parameters are weaker members of this split, and
both are hand-authored too.

**The closest thing to a bridge, named precisely:**

**Vernie, J., & Grabmair, M. (2026), "By Their Fruits You Will Know Them" (arXiv:2605.25186).**
It is the only system where an LLM formalizes law *and* a human is shown a natural-language
artifact to judge the formalization by. But it falls short of the target on four counts I
confirmed in the text: it is **differential** (needs ≥2 formalizations; can never say a single
formalization is faithful to the source), the reviewer is explicitly **"a legal expert"**, the
human **never sees the formal object** (only verbalized edge-case scenarios), and the
verbalization is itself an unverified LLM artifact — which the authors flag as a limitation.
They cite accessibility to non-experts as a *"recognized concern in adjacent fields"*, i.e. they
name the gap as open.

**Runner-up:** Amrollahi, Lopez & Barrett (arXiv:2604.25031) formalize → back-translate to
natural language → re-formalize → check logical equivalence. The back-translation exists but is
**consumed by a machine, never shown to a person.**

**The unoccupied position, stated precisely:** *automated LLM formalization + an absolute
(not differential) faithfulness check + a rendering of the formal object itself that an
untrained reader can compare against the source text.* That is TFL-Verify's slot, and it is
currently empty. The independent evidence that it matters: López & Hildebrandt's systematic
review found **89.13% of compliance frameworks treat formalization as manual effort**, and asks
**"Where are the lawyers?"** — answering that frameworks *"require compliance officers to know a
type of mathematical logic, which is far from their background, and whose training takes time."*

---

## 15. Novelty threats, ranked

1. **Vernie & Grabmair 2026 (arXiv:2605.25186)** — occupies "audit LLM-generated legal
   formalizations via verbalized cases a human judges." Published ~10 weeks before this sweep.
   TFL-Verify must differentiate on *absolute vs. differential* checking and on *rendering the
   formal object* vs. rendering scenarios. **Must-cite; must-differentiate.**
2. **Amrollahi, Lopez & Barrett 2026 (arXiv:2604.25031)** — occupies "back-translate the
   formalization to natural language and check equivalence." This directly threatens any
   novelty claim framed around round-tripping or readable back-translation *as a mechanism*.
   TFL-Verify's claim must be pinned to the human-facing rendering, not the round trip.
   **Highest threat to the PLAN 3.4 readable-orientation/gloss work specifically.**
3. **DeonticBench 2026 (arXiv:2604.04443)** — 6,232 rule-reasoning tasks with **released
   reference Prolog programs** and an explicit program-trace workflow. It largely pre-empts
   "we built the first benchmark pairing rule text with symbolic targets and traces." Better
   used as evaluation data than competed with.
4. **Lorenzo, Pietromatera & Holzenberger 2025 (NLLP)** — occupies "benchmark for LLM
   translation of law into a legal DSL." TFL-Verify's translation stage is no longer novel in
   kind; the differentiator is what happens *after* translation.
5. **Yadamsuren, Platt & Diaz 2025 (arXiv:2511.11954)** — occupies use case (b),
   LLM-formalization-driven statutory inconsistency detection, on IRC §121. Small (n=1
   section), hand-refined, no audit layer — but it is a prior claim on the idea.
6. **Blawx (Morris 2022)** — occupies "non-programmer works with a formal legal encoding and
   reads source-linked natural-language justifications." No LLM, so not a competitor on
   translation, but it means "readable proof trace linked to statute text" is not novel on its
   own.
7. **Horner et al. 2025 (arXiv:2506.08899)** — occupies "LLM → defeasible deontic logic with
   priorities." Directly overlaps the planned defeasible layer. Governatori is a co-author,
   linking it to SPINdle/Regorous/LegalRuleML.
8. **Sadowski & Chudziak 2025 (CIKM)** — occupies "verifiable legal reasoning via formalized
   intermediate representations," peer-reviewed at a strong venue, with numbers (76.4% vs 18.8%).

None of these individually kills the project. The combination means the paper's contribution
must be stated as the *conjunction* — automated formalization **plus** an absolute faithfulness
check **plus** a lay-readable rendering of the formal object — and each conjunct must be
explicitly differentiated from the work above.

---

## 16. Verification caveats

Everything below is something I could not confirm from a primary source. Nothing in this list
should be repeated as fact without further checking.

1. **UNVERIFIED: Catala's deployment status with DGFiP and CNAF.** I attempted
   `inria.fr/en/catala-software-dgfip-cnaf` (HTTP 403, Anubis bot-protection) and
   `catala-lang.org` (returned only the page title, no body). Search summaries describe
   "two proofs of concept" — one for CNAF, one for DGFiP — but **I did not read that on an
   Inria/DGFiP/CNAF page myself.** The proof-of-concept vs. production-deployment distinction
   is unconfirmed. What IS verified: the ICFP 2021 abstract's own claim to have evaluated on
   US IRC §121 and French family benefits and found a bug in the official implementation.

2. **UNVERIFIED: the full OpenFisca adopter list.** Verified from openfisca.org/en/: Barcelona,
   the French Parliament (LexImpact), Japan. **Not verified:** New Zealand, Australia, Tunisia,
   Mali, Côte d'Ivoire, Senegal, UAE — these came from a search summary of an OECD-OPSI PDF and
   the OpenFisca docs, neither of which I fetched. Do not cite them without checking.

3. **UNVERIFIED: Regorous's measured results.** Both Regorous papers (ICAIL 2013, EDOCW 2015)
   are closed access; Semantic Scholar reports their abstracts as *elided by the publisher*.
   I have their metadata from Crossref but **have not read either paper.** The deployment claim
   in §7 (six complaint-management processes vs. Section 8 of the Australian Telecommunications
   Consumers Protection Code 2012, in an LPMA NSW study) is corroborated only by López &
   Hildebrandt's systematic review, which I did read. **No per-rule accuracy, runtime, or
   rule-count figures for Regorous were obtained.** A search summary asserting "Regorous was
   empirically evaluated against the 2012 Australian Telecommunications Customers Protection Code
   with successful results" was **discarded** — I could not corroborate "successful results"
   from any source I read.

4. **PARTIALLY VERIFIED: OECD "Cracking the code."** Crossref confirms the title, the series
   (OECD Working Papers on Public Governance), and the date (2020-10-12), but **returns an empty
   author array**. Authors James Mohun and Alex Roberts, working paper number 42, and the DOI
   10.1787/3afe6ba5-en are confirmed by Jason Morris's own footnote citation in the Blawx paper,
   which I read verbatim. **The New Zealand / France / Canada case studies are UNVERIFIED** —
   from a search summary only; I did not fetch the OECD PDF.

5. **UNVERIFIED CONTENT: Kennedy (2024), *Law, Innovation and Technology* 16(1):170–193.**
   Citation fully verified via Crossref. **I did not read the paper.** The characterisation
   (ossification, mis-translation, separation of powers) is from a search summary and should be
   read before being quoted.

6. **PARTIALLY VERIFIED: Waddington.** SSRN abstract 4299375 for "Rules As Code: Drawing Out the
   Logic of Legislation for Drafters and Computers" appears in search results; I did not fetch
   SSRN and found no DOI. The separate "Research Note Rules as Code" exists on Academia.edu,
   which I do not treat as a citable source. **Author affiliation and publication venue for both
   are unconfirmed.**

7. **UNVERIFIED: Tom Barraclough / New Zealand Law Foundation "legislation as code" project.**
   Only a Medium post and passing references surfaced. **No formal citation obtained.** If the
   paper needs the New Zealand strand of Rules as Code, this needs a dedicated pass.

8. **UNVERIFIED: Dragoni et al. publication year.** Crossref records the LNCS volume as **2018**;
   the work is widely cited (including by Horner et al., whom I read) as **2017**, presumably
   the AICOL workshop year. Both are defensible; cite consistently and note the discrepancy.

9. **NOT READ (abstract only):** Sadowski & Chudziak (§11f, numbers 76.4%/18.8% are from the
   abstract via WebFetch, not from the body); Wang et al. "Know Your Limits" (§11g); Khoja et al.
   ContractCheck (§11i); OpenExempt (§13); CitizenQuery (§13); LegalBench, CUAD, LexGLUE, SARA
   (metadata and abstracts verified via arXiv API; bodies not read); the DAPRECO LREC 2020 paper
   (§6); Huttner & Merigoux 2022 (§1 — Springer 303-redirected to an auth IdP; **its abstract was
   NOT retrieved**, and the characterisation of its methodology in §1 comes from search summaries
   plus the verified ICFP abstract, not from the paper itself).

10. **FLAGGED AS LOW-CONFIDENCE SOURCE:** "Closing the Loop" (arXiv:2606.23913, §3) — no venue,
    two unknown authors, 14 pages, no figures, very broad claims. Metadata verified via arXiv API;
    abstract via WebFetch; body not read. **Do not cite as evidence of anything.**

11. **DISCARDED SEARCH-SUMMARY CONTENT.** Per the sweep's discipline, I discarded: (a) a claim
    that "the SARA numeric dataset from LegalBench contains 96 cases" — SARA is a separate 2020
    dataset by Holzenberger et al., not a LegalBench original, and I did not verify any case
    count; (b) the "Regorous… successful results" claim in caveat 3; (c) a summary claim that
    "LLMs correctly translated three out of four rules" in a UK Highway Code / Logical English
    pipeline — I never identified or verified that paper.

12. **PDF-summariser failures, noted for transparency.** WebFetch's summariser could not parse
    the raw PDFs for the Blawx CEUR paper and the NLLP Catala paper (returned "binary content I
    cannot reliably parse"). Rather than accept a lossy summary, I downloaded both with `curl`
    and extracted text with `pdftotext`, then read the text directly. All quoted material from
    Blawx, the NLLP Catala paper, Horner et al., the López & Hildebrandt survey, and Vernie &
    Grabmair comes from that extracted text, not from a summariser.
