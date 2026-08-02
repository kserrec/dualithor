# Sweep 3 — Description Logics & Structured Argumentation

Literature sweep for **TFL-Verify**. Two adjacent fields, both assessed as *potential upside*
rather than threat:

- **Part A** — Description logics as the industrial existence proof for decidable reasoning.
- **Part B** — Structured argumentation and contestability.

Every citation below was checked against Crossref, the arXiv API, a fetched publisher page, or
a fetched PDF of the paper itself. Numbers quoted are from the primary source unless explicitly
flagged. Anything that could not be corroborated is listed in **Verification caveats** at the end.
Search-engine summary prose was treated as an untrusted lead and discarded wherever it could not
be confirmed — one such conflation was caught and is recorded in the caveats.

---

# PART A — Description logics: the industrial existence proof

## A.1 EL++ / OWL 2 EL — the tractability envelope

### The founding result

> **Franz Baader, Sebastian Brandt, Carsten Lutz.** "Pushing the EL Envelope."
> *Proceedings of the 19th International Joint Conference on Artificial Intelligence (IJCAI-05)*,
> Edinburgh, 2005, pp. 364–369.
> Institute for Theoretical Computer Science, TU Dresden.
> PDF verified: https://www.ijcai.org/Proceedings/05/Papers/0372.pdf (full text read)

The paper's structure is exactly the shape of argument TFL-Verify is making about fragments, which
is why it is worth reading closely rather than merely citing.

**The positive half — Theorem 4** (verbatim from the PDF):

> "Let D₁, …, Dₙ be p-admissible concrete domains. Then subsumption in EL⁺⁺(D₁, …, Dₙ) w.r.t.
> CBoxes can be decided in polynomial time."

EL++ = conjunction (⊓) + existential restriction (∃r.C) + ⊤ + ⊥ (hence disjointness) + nominals
{a} + a restricted form of concrete domains + role inclusions r₁∘⋯∘r_k ⊑ r (hence transitivity and
the right-identity rule "required in medical applications"). The algorithm is a **completion / rule
saturation** procedure over a normalised CBox — a fixed set of rules applied to closure, which is
architecturally very close to what a TFL engine does.

`p-admissible` is defined in the paper as: (1) satisfiability and implication in D decidable in
polynomial time, and (2) **D is convex** — "if a conjunction of atoms of the form p(f₁,…,f_k)
implies a disjunction of such atoms, then it also implies one of its disjuncts."

**The negative half — the cliff edge.** The paper's own summary of its contribution:

> "we show that basically all other additions of typical DL constructors to EL with GCIs make
> subsumption intractable, and in most cases even ExpTime-complete."

Verified theorem-by-theorem from the PDF:

| Extension of EL (w/ general TBoxes) | Complexity of subsumption | Source |
|---|---|---|
| EL, EL++ with p-admissible concrete domains | **PTIME** | Thm 4 |
| EL⁽¬⁾ — even *atomic* negation | ExpTime-complete | Thm 6 |
| ELU — disjunction | ExpTime-complete | Thm 7 |
| EL^{≥2} — at-least restrictions (⩾ 2 r) | ExpTime-complete | Thm 8 |
| EL(D) for **any non-convex** concrete domain D | ExpTime-**hard** | Thm 9 |
| ELI — inverse roles | PSPACE-**hard** (exact complexity left open; best known upper bound ExpTime) | Thm 10 |
| EL^{≤1} — at-most restrictions / functional roles | (stated Thm 11; ExpTime upper bound noted in text) | Thm 11 |
| FL₀ (conjunction + value restriction) with GCIs | ExpTime-complete | Thm 12 |
| EL + arbitrary role-value maps | **undecidable** (cited to Baader 2003) | footnote 1 |

The paper also notes that similar reductions give ExpTime-completeness for EL extended with role
negation, role union, or transitive closure.

**Direct relevance to TFL-Verify.** Three transferable lessons:

1. **Convexity is the tractability frontier, not expressiveness per se.** Theorem 9 is the sharp
   one: p-admissibility is not just sufficient but *necessary* — the moment a concrete domain can
   force a genuine disjunction (non-convexity), you are ExpTime-hard. If TFL-Verify's defeasible
   or numeric layer ever admits a real case split, expect the same cliff. This is the same
   phenomenon as Horn-vs-non-Horn.
2. **Atomic negation alone costs everything** (Thm 6): ¬A for concept *names* only is already
   ExpTime-complete, because ¬C can be simulated by ¬A plus two GCIs. Any "just a little negation"
   concession is not little.
3. **Asymmetry beats symmetry.** EL (existential only) is PTIME with GCIs; FL₀ (value restriction
   only) is ExpTime-complete with GCIs. The historically "obvious" choice was the expensive one.
   A term logic making a deliberate, unusual syntactic commitment can land on the cheap side —
   which is the shape of TFL-Verify's own bet, and this is the canonical precedent for it.

### Standardisation — OWL 2 EL

> **W3C.** *OWL 2 Web Ontology Language Profiles (Second Edition)*.
> **W3C Recommendation, 11 December 2012.** https://www.w3.org/TR/owl2-profiles/ (fetched)

Verified from the spec: OWL 2 EL "is particularly useful in applications employing ontologies that
contain very large numbers of properties and/or classes"; "the basic reasoning problems can be
performed in time that is polynomial with respect to the size of the ontology"; the spec's own
complexity table gives **PTIME-complete** for ontology consistency, class expression satisfiability,
subsumption, and instance checking (taxonomic and data complexity). The "EL" name reflects "the
profile's basis in the EL family of description logics, logics that provide only Existential
quantification."

**This is the single most useful precedent for the project's framing.** A deliberately restricted,
polynomial-time-decidable logic fragment was carried all the way from a 2005 theory paper to a W3C
Recommendation in seven years, and from there into national health infrastructure. That trajectory
— *identify fragment → prove tractability → ship a reasoner → get standardised → get deployed* —
is precisely the arc TFL-Verify would need. It has been walked before, successfully.

---

## A.2 SNOMED CT — the deployment, with real numbers

### Scale

- **> 360,000 concepts.** Verified from SNOMED International's own page: "Released monthly, the
  SNOMED CT International Edition includes more than 360,000 concepts." (https://www.snomed.org/what-is-snomed-ct, fetched)
- **In use in more than eighty countries** — same page, verbatim: "Is in use in more than eighty
  countries."
- **53 member countries/territories.** Verified from https://www.snomed.org/members (fetched),
  verbatim: "Trading as SNOMED International, the organization has grown to 53 Members and has
  issued Affiliate Licenses to more than 50,000 individuals and organizations."
  Regional breakdown as listed: Americas 9 (Argentina, Belize, Canada, Chile, Costa Rica,
  El Salvador, Jamaica, United States, Uruguay); EMEA 33 (incl. Denmark, France, Germany, Ireland,
  Netherlands, Norway, Spain, Sweden, UK, Saudi Arabia, UAE, South Africa); Asia Pacific 12
  (incl. Australia, India, Indonesia, Malaysia, New Zealand, Republic of Korea, Singapore).
- **294,469 atomic concepts / 294,479 axioms** in the January 2012 international release, as
  measured for reasoner benchmarking (Kazakov et al., ORE 2012 — see A.3, Table 1 of that paper).

### What reasoning is actually run in production, and with which reasoner

**ELK is the default reasoner in SNOMED International's own production classification service.**
Verified from the README of the official IHTSDO repository
(https://github.com/IHTSDO/classification-service, fetched):

> "Configurable reasoner implementation – default `ELK`, switchable via REST parameter."

and the service itself:

> it "accepts RF2 delta change-sets, runs an embedded reasoner (ELK by default) and produces an
> RF2 delta of inferred relationship changes ready for import back into a terminology server such
> as **Snowstorm**."

The reasoning task in production is therefore **classification** — computing the inferred subsumption
(is-a) hierarchy from stated stated definitions — and the output is materialised back into the
distributed release as *inferred relationships*. This is genuinely load-bearing: the inferred
hierarchy is what downstream clinical systems query for subsumption ("is this code a kind of
diabetes?"), so a wrong entailment propagates into clinical decision support and reporting.

Snowstorm (https://github.com/IHTSDO/snowstorm) is SNOMED International's open-source terminology
server and provides the API for the Authoring Platform used to maintain the International Edition
and national editions.

### National mandate — the UK case

SNOMED CT is a **mandatory** NHS information standard, published under s.250 of the Health and
Social Care Act 2012. Verified from the NHS Standards Directory
(https://standards.nhs.uk/published-standards/snomed-ct, fetched):

- Reference: **SCCI0034 Amd 35/2016**
- Care settings: "Community health, Dentistry, GP / Primary care, Hospital, Maternity, Mental
  health, Pharmacy, Social care, Urgent and Emergency Care"
- Mandatory: SNOMED CT "is required to be used for communicating clinical content across health and
  care within the NHS standard contracts"
- Deadlines: General Practice **before 1 April 2018**; Secondary Care, Acute Care, Mental Health,
  Community Services, Dentistry, Optometry **before 1 April 2020**; all other health providers
  **by 1 April 2020**; legacy users to move to RF2 **no later than 1 October 2018**.

*(The NHS Digital SCCI0034 page at
https://digital.nhs.uk/data-and-information/information-standards/governance/latest-activity/standards-and-collections/scci0034-snomed-ct/
returned HTTP 403 to automated fetch; the Standards Directory page above was used instead.)*

### Assessment for the project

This is **strong evidence for the project's central bet**. A polynomial-time-decidable logic
fragment, chosen precisely *because* it was decidable and cheap, underpins a 360,000-concept
terminology deployed across 80+ countries and 53 member nations, with symbolic classification run
as a routine step in the release pipeline. Nobody in that pipeline argues about whether decidable
reasoning "delivers value at scale" — it is infrastructure. TFL-Verify can point to this without
hedging.

**But be precise about what it does and does not prove.** SNOMED CT's reasoning is *terminological
classification*, not *decision certification*, and the consumers of the entailments are terminology
authors and downstream software — not affected citizens. SNOMED shows decidable subsumption scales
and is trusted in production. It does **not** show that anyone has solved the explanation problem
for lay recipients. That gap is A.4, and it is where TFL-Verify's actual differentiation lives.

---

## A.3 Reasoners — performance evidence

### ELK

> **Yevgeny Kazakov, Markus Krötzsch, František Simančík.** "The Incredible ELK: From Polynomial
> Procedures to Efficient Reasoning with EL Ontologies." *Journal of Automated Reasoning*
> **53**(1): 1–61, 2014. DOI: 10.1007/s10817-013-9296-3
> *(verified via Crossref: title, all three authors, journal, vol 53, iss 1, pp 1–61, 2014.)*

> **Yevgeny Kazakov, Markus Krötzsch, František Simančík.** "ELK Reasoner: Architecture and
> Evaluation." *Proc. OWL Reasoner Evaluation Workshop (ORE 2012)*, CEUR-WS Vol-858, paper 10.
> PDF verified and read: https://ceur-ws.org/Vol-858/ore2012_paper10.pdf

> **Yevgeny Kazakov, Markus Krötzsch, František Simančík.** "ELK: A Reasoner for OWL EL Ontologies
> (Technical Report)." 2012. PDF verified and read:
> https://www.uni-ulm.de/fileadmin/website_uni_ulm/iui.inst.090/Publikationen/2012/KazKroSim12ELK_TR.pdf

**Hard benchmark numbers — verified by reading Tables 1 and 2 of the ORE 2012 paper.**

Hardware, verbatim from the paper: "All experiments were executed on a laptop (Intel Core i7-2630QM
2GHz quad core CPU; 6GB RAM; Java 1.6; Microsoft Windows 7). On this architecture, ELK defaults to
using 8 concurrent workers in the saturation phase; the other reasoners run in a single thread. We
set time-out to 30 minutes and allowed Java to use 4GB of heap space. All figures reported here were
obtained as the average over 5 runs."

Ontology metrics (Table 1): SNOMED CT — 294,469 atomic concepts, 62 atomic roles, 294,479 axioms.
GALEN (EL version) — 23,136 concepts, 950 roles, 36,489 axioms. FMA — 80,469 / 15 / 126,547.

**Classification times in seconds (Table 2), SNOMED CT row:**

| Reasoner | SNOMED CT | GALEN | GO2 | FMA |
|---|---|---|---|---|
| **ELK** | **6.2** | 1.3 | 1.0 | 0.9 |
| jcel | 1041.6 | 48.2 | 12.8 | 19.4 |
| Snorocket | 0* | 0* | 0* | 0* |
| FaCT++ | 408.9 | time-out | time-out | 5.8 |
| HermiT | **time-out** | mem-out | 41.0 | 19.6 |
| Pellet | **mem-out** | mem-out | 63.5 | 714.9 |

\* Snorocket's measured times were 0 because it classifies eagerly on load; the paper reports a
separate loading+classification table for a fair comparison, and states that on the larger
ontologies "ELK is 2–3 times faster than Snorocket."

Also verbatim from the paper: "ELK can load and classify SNOMED CT in under 15 seconds."

The 2012 technical report states ELK can classify SNOMED CT "in as little as 5 seconds on a common
laptop"; the ELK project page (https://www.korrekt.org/page/ELK_Reasoner, fetched) claims "less than
4 seconds on a modern laptop." Treat 4–15 s as the honest range depending on year, hardware, and
whether load time is included.

**The single most important number for TFL-Verify's argument is the HermiT/Pellet row.** On the same
ontology, on the same laptop:

- **EL reasoner (ELK): 6.2 seconds.**
- **General OWL 2 DL reasoners: 30-minute timeout, or out of memory.**

That is not a 2× constant-factor story. That is the fragment boundary showing up as the difference
between *works* and *does not run at all*. This is the empirical form of the argument TFL-Verify is
making about staying inside a decidable, cheap fragment, and it is available as a citable,
reproducible, published measurement rather than a hand-wave.

### Other reasoners

> **Andreas Steigmiller, Thorsten Liebig, Birte Glimm.** "Konclude: System description."
> *Journal of Web Semantics* **27–28**: 78–85, 2014. DOI: 10.1016/j.websem.2014.06.003
> *(verified via Crossref.)*

> **Birte Glimm, Ian Horrocks, Boris Motik, Giorgos Stoilos, Zhe Wang.** "HermiT: An OWL 2 Reasoner."
> *Journal of Automated Reasoning* **53**(3): 245–269, 2014. DOI: 10.1007/s10817-014-9305-1
> *(verified via Crossref.)*

> **Michael Lawley, Cyril Bousquet.** "Fast classification in Protégé: Snorocket as an OWL 2 EL
> reasoner." *Proc. 6th Australasian Ontology Workshop (AOW 2010)*, CRPIT vol. 122, pp. 45–49,
> Australian Computer Society. *(Not indexed in Crossref; citation taken from the reference list of
> the peer-reviewed ORE 2012 paper, ref [9]. See caveats.)*

> **Franz Baader, Carsten Lutz, Boontawee Suntisrivaraporn.** "CEL — A Polynomial-Time Reasoner for
> Life Science Ontologies." *Automated Reasoning (IJCAR 2006)*, LNCS, pp. 287–291.
> DOI: 10.1007/11814771_25 *(verified via Crossref.)*

### The competition evidence

> **Bijan Parsia, Nicolas Matentzoglu, Rafael Gonçalves, Birte Glimm, Andreas Steigmiller.**
> "The OWL Reasoner Evaluation (ORE) 2015 Competition Report." CEUR-WS Vol-1457, SSWS 2015.
> PDF verified and read: https://ceur-ws.org/Vol-1457/SSWS2015_paper1.pdf
> *(A journal version exists in J. Automated Reasoning; see caveats.)*

Verified verbatim from the PDF: "The 2015 competition was the third of its sort and had 14 reasoners
competing in 6 tracks comprising 3 tasks (consistency, classification, and realisation) over two
profiles (OWL 2 DL and EL)."

> "Out of the 6 competitions, 4 were won by the new hybrid reasoner Konclude, and two (EL-consistency
> and EL-classification) were won by ELK."

Konclude was "the winner of all three DL disciplines." The report also notes an interesting
crossover: "up to a point, Konclude is doing much (sometimes up to an order of magnitude) better
than ELK (the winner of the discipline), but towards the harder end, ELK overtakes Konclude" — i.e.
the specialised polynomial procedure wins exactly where it matters, on the hard tail.

Also verbatim: "The top slots in all tracks have been dominated by Konclude (and to a lesser extent
by ELK) for two years now."

### A fairness check, and a more recent data point

The ELK-vs-HermiT/Pellet table above is from 2012 on 2011-era hardware, so it should not be quoted
as if it were current. A 2023 independent re-evaluation is the honest supplement:

> **An Ngoc Lam, Brian Elvesæter, Francisco Martin-Recuerda** (SINTEF AS, Oslo).
> "A Performance Evaluation of OWL 2 DL Reasoners using ORE 2015 and Very Large Bio Ontologies."
> *DMKG 2023: 1st International Workshop on Data Management for Knowledge Graphs*, 28 May 2023,
> Hersonissos, Greece. CEUR Workshop Proceedings. PDF verified and read:
> https://dmkg-workshop.github.io/papers/paper2861.pdf

Six OWL 2 DL reasoners evaluated (Pellet, FaCT++, JFact, Openllet, HermiT, Konclude) on ORE 2015
and the 21 largest NCBO BioPortal ontologies. Verbatim from the abstract:

> "We observed that **the majority of the reasoners were unable to successfully perform over half of
> the reasoning tasks in the NCBO BioPortal dataset** which includes some very large ontologies.
> Despite of being a representative selection of the state-of-the-art OWL 2 DL reasoners, it came to
> our attention that **many of them are no longer being actively maintained.**"

Conclusion, verbatim: "Konclude and HermiT frequently ranking at the top for successful reasoning
tasks, while JFact had the most failures. In terms of reasoning time, Konclude demonstrated superior
performance."

**Two things follow.** First, the fragment argument is *not* an artefact of old benchmarks — eleven
years later, expressive OWL 2 DL reasoning still fails on more than half of tasks over very large
real ontologies, while the EL profile classifies SNOMED CT in seconds. Second, and worth noting
soberly for a project planning to ship an engine: the DL reasoner ecosystem has a maintenance
problem, with several tools unupdated for five-plus years. Long-term maintenance of a verification
engine is a real cost, and the adjacent field is visibly struggling with it.

---

## A.4 Explanation and justification in DL reasoning — **the competitor analysis**

This is the section that most directly bears on TFL-Verify's pitch, and the finding is favourable
but requires care to state honestly.

### The single best survey citation (recent)

> **Patrick Koopmann.** "Explaining Reasoning Results for Description Logic Ontologies (Invited
> Paper)." *Open Access Series in Informatics (OASIcs)*, Volume 138, Reasoning Web 2024/2025.
> Published 28 November 2025. DOI: **10.4230/OASIcs.RW.2024/2025.6**
> (fetched from drops.dagstuhl.de; abstract read verbatim)

Abstract, verbatim: "The Web Ontology Language (OWL), grounded in description logics, enables
reasoning systems to infer implicit knowledge in a transparent manner. However, **the expressivity of
description logics and the complexity of large ontologies often results in reasoning outcomes that
are hard to understand without additional tool support.** … This chapter provides an overview of the
central explanation techniques… we consider both explanations for **positive entailments** (explaining
why something can be deduced), as well as **negative entailments** (why something cannot be deduced).
More specifically, we discuss **justifications, proofs and interpolation** as a means to explain
positive entailments, and **abduction** for explaining negative entailments…"

**This is the one citation to use if the paper needs a single anchor for "the DL world's explanation
state of the art."** It is recent, open-access, by one of the Evee/Evonne authors, and it concedes
the difficulty in its own abstract.

**It also surfaces a gap TFL-Verify should think about now rather than later: negative entailments.**
The DL community treats "why *can't* this be deduced?" as a separate and harder problem, addressed by
**abduction** rather than by proofs. For a contestability use case this is not a footnote — it is
arguably the *primary* case. A person denied a benefit is not asking "why did you derive that I am
ineligible?"; they are asking "why did you not derive that I am eligible?", and the useful answer is
abductive: *which additional fact, had it held, would have flipped the outcome?* That is the same
shape as a counterfactual explanation, and it is what a claimant needs in order to know what evidence
to go and get.

A proof trace answers the positive case beautifully and the negative case not at all. If TFL-Verify's
target is contestable eligibility decisions, it should decide explicitly whether it (a) covers
negative outcomes via some abductive/counterfactual mechanism, or (b) scopes itself to certifying
positive derivations and says so plainly in limitations. Silently shipping only the positive case
while claiming contestability would be the weakest point in the pitch, and this survey is the source
that shows the field takes the distinction seriously.

### What the OWL world actually ships

**Justifications** are the dominant explanation mechanism. A justification for an entailment η in an
ontology O is a **minimal subset J ⊆ O such that J ⊨ η**. Protégé ships justification-based
explanation as a standard feature. The canonical granularity refinement:

> **Matthew Horridge, Bijan Parsia, Ulrike Sattler.** "Laconic and Precise Justifications in OWL."
> *The Semantic Web — ISWC 2008*, LNCS 5318, pp. 323–338. DOI: 10.1007/978-3-540-88564-1_21
> *(verified via Crossref: title, three authors, ISWC 2008, pp. 323–338. Best paper award reported
> by secondary sources — see caveats.)*
> Laconic justifications contain only axiom "parts" that are actually needed; precise justifications
> go further in splitting axioms into their smallest relevant pieces.

> **Matthew Horridge, Bijan Parsia, Ulrike Sattler.** "Extracting Justifications from BioPortal
> Ontologies." *ISWC 2012*, LNCS, pp. 287–299. DOI: 10.1007/978-3-642-35173-0_19 *(Crossref verified.)*

**The crucial architectural limitation, stated by the authors themselves.** From Horridge's thesis
and echoed in the small-proofs literature: justifications are *premise sets*, not derivations. As
Alrabbaa et al. put it (verbatim from arXiv:2004.08311): "While justifications are a popular tool
for pinpointing the reasons for an entailment in an ontology, **they do not provide deeper
information on the reasoning behind the entailment.**"

In other words: a justification tells you *which axioms* did it. It does not tell you *how*.
**TFL-Verify's proof trace is the thing justifications are not.**

### Proofs — the newer, closer competitor

The DL community has moved toward actual proofs in the last five years, and this *is* a genuine
competitor to the proof-trace pitch. It must be engaged with, not ignored.

> **Christian Alrabbaa, Franz Baader, Stefan Borgwardt, Patrick Koopmann, Alisa Kovtunova.**
> "Finding Small Proofs for Description Logic Entailments: Theory and Practice."
> *EPiC Series in Computing* vol. 73 (LPAR-23), DOI: 10.29007/nhpp. Extended technical report:
> **arXiv:2004.08311** (verified via arXiv; PDF read).

> **Christian Alrabbaa, Franz Baader, Stefan Borgwardt, Patrick Koopmann, Alisa Kovtunova.**
> "Finding Good Proofs for Description Logic Entailments using Recursive Quality Measures."
> *CADE-28*, LNCS, pp. 291–308. DOI: 10.1007/978-3-030-79876-5_17 *(Crossref verified.)*

> **Christian Alrabbaa, Stefan Borgwardt, Tom Friese, Patrick Koopmann, Julián Méndez, Alexej
> Popovič.** "On the Eve of True Explainability for OWL Ontologies: Description Logic Proofs with
> Evee and Evonne." **arXiv:2206.07711**, 15 June 2022 (verified via arXiv, abstract read).
> Verbatim from the abstract: "the standard ontology editor Protégé offers two services to help:
> (black-box) justifications for OWL 2 DL ontologies, and (glass-box) proofs for lightweight OWL EL
> ontologies, where the latter exploits the proof facilities of reasoner ELK. **Since justifications
> are often insufficient in explaining inferences**, there is thus only little tool support for
> explaining inferences in more expressive DLs." They introduce EVEE-LIBS (Java library computing
> proofs for DLs up to ALCH), EVEE-PROTEGE (Protégé plugins) and EVONNE (standalone proof
> visualisation).

**Complexity of proof minimisation — directly actionable for TFL-Verify.** Verified from
arXiv:2004.08311:

> "for general proofs, the above decision problem is NP-complete even for polynomial derivers and
> unary coding of numbers. For exponential derivers, the complexity depends on the coding of the
> number n: it is NP-complete for unary coding, but NExpTime-complete for binary coding.
> **Interestingly, for tree-shaped proofs the complexity is considerably lower, which is due to the
> fact that we can use a Dijkstra-like greedy algorithm to compute minimal tree-shaped proofs.**"

The paper's Table 2 gives **P** for minimal tree-shaped proofs with polynomial derivers.
Also verified from the same paper: finding a *justification* of size ≤ n is already **NP-complete**
even for EL ontologies, and there may be exponentially many justifications, though finding *a*
single justification is polynomial.

**Design implication for TFL-Verify:** if the engine emits **tree-shaped** proof traces (each derived
fact used once, no DAG reuse), minimising them is in PTIME. If it emits DAG-shaped traces with
sharing, minimisation is NP-complete. Tree-shaped is also what users subjectively prefer (next
subsection). Both arguments point the same way. This is a cheap, well-founded design commitment to
make early and to state in the paper.

### Is it readable by non-experts? **The human-subject evidence says no.**

This is the decisive finding of Part A, and it is well supported.

#### Horridge's studies — all participants were experts, and they still failed

> **Matthew Horridge.** *Justification Based Explanation in Ontologies.* PhD thesis, University of
> Manchester, 2011. Full text verified and read:
> https://www.bcs.org/media/2146/dd-2012-matthew-horridge.pdf (BCS Distinguished Dissertation)

> **Matthew Horridge, Samantha Bail, Bijan Parsia, Ulrike Sattler.** "The Cognitive Complexity of
> OWL Justifications." *ISWC 2011*, LNCS, pp. 241–256. DOI: 10.1007/978-3-642-25073-6_16
> *(Crossref verified.)*

> **Matthew Horridge, Samantha Bail, Bijan Parsia, Uli Sattler.** "Toward cognitive support for OWL
> justifications." *Knowledge-Based Systems* **53**: 66–79, 2013. DOI: 10.1016/j.knosys.2013.08.021
> *(Crossref verified.)*

Verified participant populations, read directly from the thesis:

- **Experiment 7 (exploratory):** "The study comprised 12 volunteers who were staff and students from
  the School of Computer Science at the University of Manchester. The participants' experience with
  OWL ranged from less than 6 months to over 4 years… All participants were either confident or very
  confident that given a rendering of an OWL axiom they could explain the meaning of the axiom to
  another person."
- **Experiment 8 (pilot for the complexity model):** "Seven members of the School of Computer Science
  at the University of Manchester. Participants were either Academic, Research Staff, or PhD
  Students, with over 2 years of experience with ontologies and justifications."
- **Experiment 9:** "14 volunteers from a Computer Science MSc course on OWL ontology modelling."
- **Experiment 10:** "All participants were very experienced with OWL."

Verified results, verbatim from the thesis:

> "At both ends of the scale there were rankings for 'very easy to understand' and 'impossible to
> understand'. Moreover, **all participants bar one ranked one or more justifications as being
> impossible to understand.** … Overall, there were a significant number of 'difficult' to
> 'impossible' to understand justifications, which points to the fact that **justification
> understanding is a real problem.**"

> "it is worth noting that **all participants, including participants with a background in OWL and
> Description Logics made errors on the predicted hard justifications.**"

> "many of the participants (including participants with many years of experience with OWL, and even
> reasoner developers) did not realise, or neglected to see, that A ≡ ∀R.C, coupled with domain(R, A),
> entails ⊤ ⊑ A."

> "participants gave up trying to understand a justification very soon, perhaps because it simply
> seemed too complicated, or, after some effort they thought that they would never understand the
> justification."

**Not one of these studies recruited a layperson.** The population is Manchester CS staff, PhD
students, MSc students on an ontology course, and reasoner developers — and reasoner developers
failed items.

#### The proof-representation studies — laypeople were recruited, and it went badly

> **Christian Alrabbaa, Stefan Borgwardt, Anke Hirsch, Nina Knieriemen, Alisa Kovtunova,
> Anna Milena Rothermel, Frederik Wiehr.** "In the Head of the Beholder: Comparing Different Proof
> Representations." *Rules and Reasoning (RuleML+RR 2022)*, LNCS, pp. 211–226.
> DOI: 10.1007/978-3-031-21541-4_14 *(Crossref verified: title, all seven authors, pp. 211–226, 2022.)*
> PDF verified and read: https://lat.inf.tu-dresden.de/research/papers/2022/AlBoHiKnKoRoWi-RuleML22.pdf

This is a **four-study series** with **Prolific-recruited general-population participants** — exactly
the population TFL-Verify cares about. Verified from the PDF:

Framing, verbatim from the introduction — this sentence is worth quoting in the paper:

> "**Even methods that are 'explainable by design', such as logic-based ones, are not necessarily
> understandable by design when presenting them to laypersons.**"

Design: Studies I–IV compared tree-shaped vs. text-based proof presentations, varying length,
interactivity, and formula shape.

- **Study I** — 1-on-1 think-aloud interviews, ~90 min, €20. n = 16 (12 m / 4 f), mean age 23.0.
  **Screened**: "recruited from undergraduate and graduate university students with basic knowledge
  of logic… Screening criteria were familiarity with first-order logic (e.g. through a lecture)."
  Mean self-rated propositional-logic experience M = 3.25 (SD = 1.0) on 1–5.
- **Studies II–IV** — online surveys via Prolific. Footnote 4 of the paper, verbatim: "The
  participants were recruited using Prolific… **No restrictions on participant background were
  imposed.**" These are the genuinely lay samples. n = 101 (Study II, ~29 min, £5.20), **n = 173**
  (Study III, ~51 min, £8.75), n = 108 (Study IV, ~44 min, £6.25); mean ages 24.5 / 24.8 / 25.9.
  *(Per-study n derived from Table 2's male/female/non-binary columns; the n = 173 figure is
  independently confirmed in the text — "Rankings of all 173 participants" and "n = 173" — which
  validates the reading of the table.)*
- Self-reported logic experience in the lay samples was low: Study II M = 1.83 (SD = 1.18) with
  56.4% never having worked with propositional logic; Study III M = 1.76 (SD = 1) with 60.7% never
  having worked with it.

Later studies deliberately used nonsense domain terms
("Every woal is munted only with luxis that are kakes") to prevent prior domain knowledge from
substituting for reading the proof, and rendered DL syntax as natural-language sentences to widen
eligibility.

Verified results:

- Abstract, verbatim: "**We did not find evidence to support our main hypothesis that different user
  groups can understand different proof representations better.** Nevertheless, when participants
  directly compared proof representations, their subjective rankings showed some tendencies such as
  that most people prefer short tree-shaped proofs. **However, this did not impact the user's
  understanding of the proofs as measured by an objective performance measure.**"
- Limitations section, verbatim: "we did not pre-select participants according to their experience
  with logic or field of studies. **55.5% of the participants had no experience with propositional
  logic and 60.7% had never worked with it.** For many participants, even the ones with higher ICAR
  scores, **the proof tasks were very challenging, resulting in a mean score of M = 2.36 out of a
  total of 12.** 15 people commented about the high difficulty level in the end, and **only 3 said
  the proofs were easy to understand.**" *(This refers to Study III, n = 173, where the maximum
  attainable proof-comprehension score was 12 — i.e. lay participants scored ~20% on questions of
  the form "Which of the following would be a correct replacement for the deduction 'XYZ' in the
  proof?" and "Which parts of the following summary/reformulation of the proof are incorrect?")*
- Cognitive ability (ICAR-16) predicted proof performance in Studies II and III (χ²(3) = 17.16,
  p = .001, n = 173 for the ranking difference across ICAR groups) but not in Study IV.

There is a follow-up in the same group — Borgwardt, Hirsch, Knieriemen & Kovtunova, "In the heart of
the beholder: User-tailored explanations for description logics" (listed as a 2026 workshop paper on
Borgwardt's publication page) — **UNVERIFIED beyond the listing; see caveats.**

#### Related understandability work

> **Tu Anh T. Nguyen, Richard Power, Paul Piwek, Sandra Williams.** "Predicting the Understandability
> of OWL Inferences." *ESWC 2013 (The Semantic Web: Semantics and Big Data)*, LNCS, pp. 109–123.
> DOI: 10.1007/978-3-642-38288-8_8 *(Crossref verified.)*

> **Tobias Kuhn.** "The understandability of OWL statements in controlled English."
> *Semantic Web* **4**(1): 101–115, 2013. DOI: 10.3233/sw-2012-0063 *(Crossref verified.)*

### Verdict on the competitor question

**The OWL/DL world does NOT currently produce entailment explanations readable by non-experts.**
Characterised precisely:

| | Justifications | DL proofs (Evee/Evonne, ELK glass-box) |
|---|---|---|
| What it gives you | Minimal premise set | Full derivation, step by step |
| Shipped in Protégé | Yes, standard | Yes, for OWL EL (via ELK); Evee extends to ALCH |
| Explains *how*? | **No** — premises only | Yes |
| Minimisation complexity | Size-≤n justification: **NP-complete** (even EL) | Minimal proof: **NP-complete**; minimal *tree* proof: **P** |
| Human-subject evidence | Experts only; even experts fail hard items; most participants rated ≥1 justification "impossible to understand" | Laypeople tested; mean 2.36/12; only 3 of ~173 found proofs easy |
| Tested on laypeople? | **Never** | Yes — and results were poor |

**What this means for TFL-Verify — three points, in order of importance:**

1. **The competitor exists and is mature at the "produce a correct derivation" layer, and immature
   at the "a citizen can read it" layer.** Do not claim DL has no proof story — Evee/Evonne, ELK's
   glass-box proofs, and the small-proofs theory are real and good. Claim instead that the *last
   mile* is open, and cite Alrabbaa et al.'s own sentence that logic-based methods are not
   "understandable by design" for laypersons. That is a concession from inside the competing camp
   and is far stronger than an outside assertion.
2. **The bar is empirically low, which is opportunity and obligation both.** Nobody has demonstrated
   a lay-readable logical certificate. If TFL-Verify runs even a modest human-subject study on
   policy-text traces with non-expert participants, it would be, as far as this sweep found, close
   to the first such result in this lineage. It also means the project must not *assume* its traces
   are readable — the base rate for that assumption being wrong is high.
3. **Two concrete design commitments fall out, both cheap:** (a) emit **tree-shaped** traces
   (PTIME minimisation, and the subjectively preferred format); (b) render steps as natural-language
   sentences rather than symbolic notation — Alrabbaa et al. adopted exactly this to widen
   participation, and Nguyen et al. and Kuhn study it directly.

A caution worth recording: the Beholder studies found subjective preference for tree proofs but **no
objective performance difference**. Preference and comprehension came apart. If TFL-Verify runs a
study, it must measure comprehension objectively (can the participant answer a question the trace
determines, or correctly identify which premise to challenge?), not satisfaction.

---

## A.5 LLMs authoring or extending OWL ontologies, and how output is validated

### The systematic review

> **Jiayi Li, Daniel Garijo, María Poveda-Villalón.** "Large Language Models for Ontology
> Engineering: A Systematic Literature Review." *Semantic Web — Interoperability, Usability,
> Applicability*, vol. 17, iss. 4, 2026. DOI: 10.1177/22104968261465514
> *(Crossref verified: title, three authors, venue, vol/iss, 2026.)*
> Preprint PDF verified and read: https://www.semantic-web-journal.net/system/files/swj3864.pdf
> Ontology Engineering Group, Universidad Politécnica de Madrid.

Verified from the abstract: "We analyze 30 different papers to identify common tasks where LLMs have
been applied… Our findings indicate that LLMs serve primarily as ontology engineers, domain experts,
and evaluators, using models such as GPT, LLaMA, and T5… Our review also observed a **lack of
homogenization in task definitions, dataset selection, evaluation metrics, and experimental
workflows.** At the same time, **some papers do not release complete evaluation protocols or code,
making their results hard to reproduce and their methods insufficiently transparent.**"

*(Note: the abstract says 30 papers; §RQ3 of the same preprint says "Out of the 41 reviewed studies."
An internal inconsistency in the preprint version — flagged in caveats.)*

Verified from the body — **how validation is actually done**, and it is thin:

- "we found that **9 studies do not conduct any evaluation**" — either lacking experimental
  implementation entirely or presenting "basic demonstrations without comparative baselines or metric
  based analysis." Two more "describe evaluation strategies but do not report actual results."
- The evaluation that does happen is dominated by **surface-level NLP metrics**: precision/recall/F1
  against gold ontologies (OAEI datasets, LLMs4OL challenge), semantic similarity (SentenceBERT
  cosine), Tree Edit Distance, Insertion Rate at top-k, exact-match on SPARQL.
- Syntactic/structural checking appears via RDFLib parse errors and the **OOPS! (Ontology Pitfall
  Scanner)** API — a pitfall linter, not a reasoner.
- Human expert review is tracked as a separate dimension ("whether human involvement was required").

Verified from the conclusions:

> "Their reasoning remains shallow, often leading to **hallucinated facts and limited transparency.**
> … Evaluation practices are fragmented, as existing quantitative metrics fail to fully capture
> performance… and there is a **lack of common benchmarks**."

And the first-listed research challenge, verbatim:

> "**Hybrid Neuro-Symbolic Reasoning: Develop systems that combine LLM-generated suggestions with
> logic validation to enhance logical consistency and reduce hallucinations.**"

**That sentence is TFL-Verify's thesis, stated as an open challenge by a 2026 systematic review of an
adjacent field.** It is a citable, third-party endorsement of the project's premise — worth putting
in the paper's introduction.

**The headline gap: almost nobody runs the reasoner.** Across the reviewed corpus, validation is
overwhelmingly string-similarity-to-a-gold-ontology plus human review, with syntax linting. Symbolic
entailment checking of LLM output is the exception, not the norm. This is precisely the hole
TFL-Verify's approach fills, and the review says so independently.

### Individual systems worth citing

> **Anna Sofia Lippolis, Mohammad Javad Saeedizade, Robin Keskisärkkä, Sara Zuppiroli, Miguel
> Ceriani, Aldo Gangemi, Eva Blomqvist, Andrea Giovanni Nuzzolese.** "Ontology Generation using
> Large Language Models." **arXiv:2503.05388**, 7 March 2025 (verified via arXiv API).
> Two prompting techniques (Memoryless CQbyCQ, Ontogenia); benchmark of **ten ontologies, 100
> distinct competency questions, 29 user stories**; explicitly argues for "three structural criteria
> for ontology assessment, alongside expert qualitative evaluation, highlighting the need for a
> multi-dimensional evaluation."

> **Bohui Zhang, Valentina Anita Carriero, Katrin Schreiberhuber, Stefani Tsaneva, Lucía Sánchez
> González, Jongmo Kim, Jacopo de Berardinis.** "OntoChat: a Framework for Conversational Ontology
> Engineering using Language Models." **arXiv:2403.05921**, 9 March 2024, rev. 26 April 2024
> (verified via arXiv API). Comment field confirms: "ESWC 2024 Special Track on Large Language
> Models for Knowledge Engineering."

> **Justin Mücke, Ansgar Scherp.** "GLaMoR: Consistency Checking of OWL Ontologies using Graph
> Language Models." **arXiv:2504.19023**, 26 April 2025 (verified via arXiv API).
> Relevant as a *counter-position*: it proposes replacing the reasoner with a learned model for
> consistency checking. TFL-Verify's correctness bar (certify validity; a wrong verdict poisons
> everything) is the direct rebuttal — a 95%-accurate consistency checker is not a certifier.
> *(The "95% accuracy, 20× faster" figure appeared in a search summary; the abstract text retrieved
> from arXiv was truncated before those numbers — treat as UNVERIFIED, see caveats.)*

### The most directly relevant recent paper found in this sweep

> **Hui Yang, Jiaoyan Chen, Uli Sattler.** "Large Language Model for OWL Proofs."
> **arXiv:2601.12444**, 18 January 2026 (verified via arXiv API; abstract read).

Verbatim from the abstract: "The ability of Large Language Models (LLMs) to perform reasoning tasks
such as deduction has been widely investigated in recent years. Yet, **their capacity to generate
proofs — faithful, human-readable explanations of why conclusions follow — remains largely
underexplored.**" The framework covers three sequential tasks — Extraction, Simplification,
Explanation — plus assessment of Logic Completeness of the premise.

Verified findings:
1. "Some models achieve overall strong results but remain limited on complex cases."
2. "**Logical complexity, rather than representation format (formal logic language versus natural
   language), is the dominant factor shaping LLM performance.**"
3. "Noise and incompleteness in input data substantially diminish LLMs' performance."

**Finding (2) is important and slightly uncomfortable for one version of TFL's pitch.** If
representation format (symbolic vs. natural language) is *not* the dominant factor for LLM
performance, then arguing for TFL's plus-minus notation on the grounds that it is easier for an LLM
to emit is weakly supported — at least for proof tasks in the OWL setting. The defensible arguments
for the notation are elsewhere: decidability of the target fragment, checkability, and human
readability of the resulting certificate. Worth pre-empting this in the paper rather than being
asked about it.

Note also that this paper is by Uli Sattler's group — i.e. the DL explanation community is now
actively working the LLM-proof intersection. TFL-Verify is not alone in this space and should
position against it explicitly.

---

## A.6 The closest neighbour found in this sweep — flagged as important

> **Allen Daniel Sunny, Ido Sivan-Sevilla.** "A Neuro-Symbolic Framework for Accountability in
> Public-Sector AI." **arXiv:2512.12109** (v1 13 Dec 2025; v4 6 May 2026).
> arXiv comment field, verified: "**Accepted at FAccT 2026** (The 2026 ACM Conference on Fairness,
> Accountability, and Transparency), June 25–28, Montreal, Canada."

Abstract, verbatim (verified via arXiv API and the abstract page):

> "Automated eligibility systems increasingly determine access to essential public benefits, but the
> explanations they generate often fail to reflect the legal rules that authorize those decisions.
> This thesis develops a legally grounded explainability framework that links system-generated
> decision justifications to the statutory constraints of **CalFresh, California's Supplemental
> Nutrition Assistance Program**. The framework combines **a structured ontology of eligibility
> requirements** derived from the state's Manual of Policies and Procedures (MPP), **a rule
> extraction pipeline that expresses statutory logic in a verifiable formal representation**, and a
> **solver-based reasoning layer to evaluate whether the explanation aligns with governing law**.
> Case evaluations demonstrate the framework's ability to detect legally inconsistent explanations,
> highlight violated eligibility rules, and **support procedural accountability by making the basis
> of automated determinations traceable and contestable**."

**This is the nearest thing to TFL-Verify found anywhere in this sweep, and it should be treated as
required related work.** The pipeline shape — policy text → formal rules → symbolic checking of a
system's stated justification → contestability for the affected person — is the same pipeline, in
the same application domain (benefits eligibility), with the same stated societal motivation, landing
at a top venue in mid-2026.

Points of genuine differentiation still available to TFL-Verify, stated honestly:

- **Formalism and guarantees.** They use an unspecified "verifiable formal representation" plus a
  solver; TFL-Verify's claim is a *specific decidable fragment* with a *formally verified* engine and
  fragment-membership routing. Solver-based ≠ decidable-by-construction, and "solver said yes" is a
  different artefact from a checkable proof term.
- **The certificate itself.** Their contribution is *detecting* legally inconsistent explanations.
  TFL-Verify's is *emitting* a human-readable proof trace. Those are complementary, not identical.
- **Verification of the checker.** Nothing in the abstract claims the reasoning layer is itself
  verified; TFL-Verify's differential/oracle regime is a distinguishing engineering claim.

Caveat on my own reading: the abstract calls the work "this thesis," and no quantitative results
(rule-extraction accuracy, number of cases) are given in the abstract. The full PDF was not read in
this sweep — see caveats. Read it before writing the related-work section; do not characterise its
results from the abstract alone.

---

# PART B — Structured argumentation and contestability

*(Populated from two dedicated verification sweeps; see below.)*

### Cross-check anchors verified independently by the lead sweep

These two were verified directly against Crossref by the lead sweep, independently of the Part B
sub-sweeps, because they are the load-bearing facts for the ASPIC+/ABA vs. defeasible-logic
recommendation:

> **Michael J. Maher.** "Propositional defeasible logic has linear complexity."
> *Theory and Practice of Logic Programming* **1**(6): 691–711, 2001.
> DOI: 10.1017/s1471068401001168 *(Crossref verified.)*

> **Grigoris Antoniou, David Billington, Guido Governatori, Michael J. Maher.**
> "Representation results for defeasible logic." *ACM Transactions on Computational Logic*
> **2**(2): 255–287, 2001. *(Crossref verified.)*

Additional anchors verified directly by the lead sweep, for cross-checking the sub-sweeps:

| Citation | Verified record |
|---|---|
| Dung's foundational paper | Phan Minh Dung, "On the acceptability of arguments and its fundamental role in nonmonotonic reasoning, logic programming and n-person games", *Artificial Intelligence* **77**(2): 321–357, 1995. DOI: 10.1016/0004-3702(94)00041-x |
| 25-years-later retrospective | Pietro Baroni, Francesca Toni, Bart Verheij, "…: 25 years later", *Argument & Computation* **11**(1-2): 1–14, 2020. DOI: 10.3233/aac-200901 |
| ASPIC+ | Henry Prakken, "An abstract framework for argumentation with structured arguments", *Argument & Computation* **1**(2): 93–124, 2010. DOI: 10.1080/19462160903564592 |
| Rationality postulates | Martin Caminada, Leila Amgoud, "On the evaluation of argumentation formalisms", *Artificial Intelligence* **171**(5-6): 286–310, 2007. DOI: 10.1016/j.artint.2007.02.003 |
| ABA foundational | A. Bondarenko, P. M. Dung, R. A. Kowalski, F. Toni, "An abstract, argumentation-theoretic approach to default reasoning", *Artificial Intelligence* **93**(1-2): 63–101, 1997. DOI: 10.1016/s0004-3702(97)00015-5 |
| AF complexity (coherence/preferred) | Paul E. Dunne, T. J. M. Bench-Capon, "Coherence in finite argument systems", *Artificial Intelligence* **141**(1-2): 187–203, 2002. DOI: 10.1016/s0004-3702(02)00261-8 |
| AF complexity (semi-stable/stage) | Wolfgang Dvořák, Stefan Woltran, "Complexity of semi-stable and stage semantics in argumentation frameworks", *Information Processing Letters* **110**(11): 425–430, 2010. DOI: 10.1016/j.ipl.2010.04.005 |

### GDPR Article 22 — verified text, and a nuance that matters for the public-sector pitch

Verified independently by the lead sweep from https://gdpr-info.eu/art-22-gdpr/ (fetched):

- **Art 22(1)**, verbatim: "The data subject shall have the right not to be subject to a decision
  based solely on automated processing, including profiling, which produces legal effects concerning
  him or her or similarly significantly affects him or her."
- **Art 22(2)** carves out decisions that are (a) necessary for entering into/performing a contract,
  (b) **authorised by Union or Member State law** with suitable safeguards, or (c) based on explicit
  consent.
- **Art 22(3)**, verbatim: "**In the cases referred to in points (a) and (c) of paragraph 2**, the
  data controller shall implement suitable measures to safeguard the data subject's rights and
  freedoms and legitimate interests, at least the right to obtain human intervention on the part of
  the controller, **to express his or her point of view and to contest the decision**."
- **Art 22(4)** restricts such decisions based on Art 9(1) special categories.

**The nuance, and it cuts against a naive framing of the project's legal motivation.** The explicit
"contest the decision" right in Art 22(3) is scoped to points **(a) and (c)** — contract and explicit
consent. It does **not** textually attach to point **(b)**, decisions authorised by Union or Member
State law — which is exactly the basis on which most *government* eligibility and compliance
decisions are made. For those, Art 22(2)(b) requires that the authorising law "lays down suitable
measures to safeguard" the data subject, so the safeguards come from national law rather than from
Art 22(3) directly.

Practical consequence for TFL-Verify's positioning: **do not claim GDPR Art 22(3) gives benefit
claimants a direct right to contest a statutory automated eligibility decision.** The more accurate
and still-strong framing is that Art 22 establishes contestability as the governing norm for
automated decisions generally, that Member State law must supply equivalent safeguards in the
public-law case, and that administrative-law reason-giving duties (§ B.2.2) are the operative
requirement there. Getting this wrong in the paper would be an easy target for a reviewer with legal
training.

---

## B.1 Structured argumentation vs. defeasible logic — and the recommendation

*All citations in this section were verified directly against Crossref by the lead sweep. The
complexity tables were read out of a fetched PDF of the Handbook of Formal Argumentation complexity
chapter (see below), not from any search summary.*

### B.1.1 Dung's abstract argumentation frameworks and their complexity

> **Phan Minh Dung.** "On the acceptability of arguments and its fundamental role in nonmonotonic
> reasoning, logic programming and n-person games." *Artificial Intelligence* **77**(2): 321–357,
> 1995. DOI: 10.1016/0004-3702(94)00041-x *(Crossref verified.)*

An abstract argumentation framework (AF) is just a directed graph (A, R): arguments and an "attacks"
relation. All internal structure is abstracted away. Semantics (grounded, complete, stable,
preferred, semi-stable, stage, ideal) then select "acceptable" sets of arguments.

> **Wolfgang Dvořák, Paul E. Dunne.** "Computational Problems in Formal Argumentation and their
> Complexity." In *Handbook of Formal Argumentation*, College Publications, 2018, pp. 631–687
> (also *IfCoLog Journal of Logics and their Applications* **4**(8): 2557–2622).
> Updated PDF fetched and read: https://www.dbai.tuwien.ac.at/staff/dvorak/files/HOFA-complexity-updated-v1.pdf

**Table 1 of that chapter, transcribed** ("C-c" = complete for class C). This is the authoritative
complexity landscape, and it is the crux of the recommendation:

| Semantics σ | Credulous acceptance | Skeptical acceptance | Verification |
|---|---|---|---|
| conflict-free (cf) | in L | trivial | in L |
| naive (na) | in L | in L | in L |
| **grounded (gr)** | **P-complete** | **P-complete** | **P-complete** |
| stable (st) | NP-c | coNP-c | in L |
| admissible (ad) | NP-c | trivial | in L |
| complete (co) | NP-c | P-c | in L |
| ideal (id) | Θ₂ᴾ-c | Θ₂ᴾ-c | Θ₂ᴾ-c |
| **preferred (pr)** | NP-c | **Π₂ᴾ-complete** | coNP-c |
| semi-stable (sst) | Σ₂ᴾ-c | Π₂ᴾ-c | coNP-c |
| stage (stg) | Σ₂ᴾ-c | Π₂ᴾ-c | coNP-c |

Attributions given in the chapter's own text: grounded/trivial entries follow from Dung 1995; naive
from Coste-Marquis et al. 2005; stable/admissible/preferred from Dimopoulos & Torres 1996, "except
for the Π₂ᴾ-completeness of Skept_pr which is due to **Dunne and Bench-Capon [2002]**"; ideal due to
**Dunne [2009]**; semi-stable and stage due to Caminada et al. 2012 and **Dvořák and Woltran [2010]**.

Supporting primary sources, Crossref-verified:
- **Paul E. Dunne, T. J. M. Bench-Capon**, "Coherence in finite argument systems," *Artificial
  Intelligence* **141**(1-2): 187–203, 2002. DOI: 10.1016/s0004-3702(02)00261-8
- **Wolfgang Dvořák, Stefan Woltran**, "Complexity of semi-stable and stage semantics in
  argumentation frameworks," *Information Processing Letters* **110**(11): 425–430, 2010.
  DOI: 10.1016/j.ipl.2010.04.005
- **Paul E. Dunne, Michael Wooldridge**, "Complexity of Abstract Argumentation," in *Argumentation in
  Artificial Intelligence*, Springer, 2009, pp. 85–104. DOI: 10.1007/978-0-387-98197-0_5

**The single most important line in the table: grounded semantics is P-complete; everything
interesting above it is NP-hard, and skeptical preferred acceptance is Π₂ᴾ-complete** — the second
level of the polynomial hierarchy.

### B.1.2 ASPIC+

> **Henry Prakken.** "An abstract framework for argumentation with structured arguments."
> *Argument & Computation* **1**(2): 93–124, 2010. DOI: 10.1080/19462160903564592 *(Crossref verified.)*

> **Sanjay Modgil, Henry Prakken.** "A general account of argumentation with preferences."
> *Artificial Intelligence* **195**: 361–397, 2013. DOI: 10.1016/j.artint.2012.10.008
> *(Crossref verified.)* **Note the corrigendum:** Modgil & Prakken, "Corrigendum to 'A general
> account of argumentation with preferences' [Artif. Intell. 195 (2013) 361–397]," *Artificial
> Intelligence* **263**: 107–110, 2018. DOI: 10.1016/j.artint.2018.05.001. *Cite both — a paper that
> cites the 2013 result without the corrigendum looks careless.*

ASPIC+ components: a logical language with contrariness, **strict rules** (→) and **defeasible rules**
(⇒), a preference ordering over defeasible rules/premises, and three attack forms — **rebutting**
(attack a defeasible conclusion), **undercutting** (attack the applicability of a rule), and
**undermining** (attack an ordinary premise). Preferences turn attacks into **defeats**; the resulting
defeat graph is a Dung AF, and Dung semantics are then applied.

**Consequence: ASPIC+ inherits the Dung complexity table wholesale**, plus the cost of constructing
arguments from the rule base. It is a *framework for instantiating* Dung AFs, not an alternative to
them.

> **Martin Caminada, Leila Amgoud.** "On the evaluation of argumentation formalisms."
> *Artificial Intelligence* **171**(5-6): 286–310, 2007. DOI: 10.1016/j.artint.2007.02.003
> *(Crossref verified.)* — the **rationality postulates** (closure under strict rules, direct and
> indirect consistency) that ASPIC+ is designed to satisfy. These matter to TFL-Verify because they
> are exactly the kind of property a verified engine should be able to state and check.

### B.1.3 Assumption-Based Argumentation (ABA)

> **A. Bondarenko, P. M. Dung, R. A. Kowalski, F. Toni.** "An abstract, argumentation-theoretic
> approach to default reasoning." *Artificial Intelligence* **93**(1-2): 63–101, 1997.
> DOI: 10.1016/s0004-3702(97)00015-5 *(Crossref verified.)*

> **Francesca Toni.** "A tutorial on assumption-based argumentation." *Argument & Computation*
> **5**(1): 89–117, 2014. DOI: 10.1080/19462166.2013.869878 *(Crossref verified.)*

> **Robert Craven, Francesca Toni.** "Argument graphs and assumption-based argumentation."
> *Artificial Intelligence* **233**: 1–59, 2016. DOI: 10.1016/j.artint.2015.12.004 *(Crossref verified.)*

ABA represents everything as a deductive system (L, R) plus a designated set of **assumptions** and a
**contrary** mapping. Arguments are deductions from assumptions; attacks are deductions of a
contrary. Semantics are again Dung's, lifted to assumption sets.

**ABA complexity — Table 8 of the Dvořák & Dunne chapter, read from the fetched PDF.** Upper bounds
are parameterised by **C**, the complexity of deciding the ⊢ (derivability) relation. For **flat**
ABFs with polynomial derivability (C = P):

| σ | Credulous | Skeptical |
|---|---|---|
| stable (st) | NP | coNP |
| admissible (ad) | NP | trivial |
| preferred (pr) | NP | **coNP^NP = Π₂ᴾ** |
| ideal (id) | — | P^NP_∥ |

So ABA lands in the same place as ASPIC+: **Dung-level complexity, NP-hard and above for everything
except grounded/ideal-ish semantics.**

### ABA+ (ABA with preferences) — preferences cost a full level of the polynomial hierarchy

> **Tuomo Lehtonen, Johannes P. Wallner, Matti Järvisalo.** "Declarative Algorithms and Complexity
> Results for Assumption-Based Argumentation." *Journal of Artificial Intelligence Research* **71**:
> 265–318, 2021. DOI: **10.1613/jair.1.12479** *(Crossref verified; open access, PDF read by the
> sub-sweep.)*

> **Yannis Dimopoulos, Bernhard Nebel, Francesca Toni.** "On the computational complexity of
> assumption-based argumentation for default reasoning." *Artificial Intelligence* **141**(1-2):
> 57–78, 2002. DOI: 10.1016/s0004-3702(02)00245-x *(Crossref verified.)*

ABA+ (Čyras & Toni, KR 2016 short paper, pp. 553–556; extended preprint arXiv:1610.03024) adds
preferences to ABA. Lehtonen et al.'s Tables 2 and 3 for the logic-programming fragment:

| Semantics | ABA credulous | ABA skeptical | ABA+ credulous | ABA+ skeptical | ABA+ verification |
|---|---|---|---|---|---|
| admissible | NP-c | in P | **Σ₂ᴾ-c** | ? | coNP-c |
| complete | NP-c | in P | ? | ? | coNP-hard |
| preferred | NP-c | Π₂ᴾ-c | — | — | — |
| stable | NP-c | coNP-c | NP-c | coNP-c | in P |
| grounded | in P | in P | Δ₂ᴾ (FL-property) | Δ₂ᴾ (FL) | coNP-hard |
| ideal | in Θ₂ᴾ | in Θ₂ᴾ | — | — | — |

Their own gloss: "this result shows that reasoning under preferences in ABA+ faces **significantly
higher complexity** in the general case," and assuming the Weak Contraposition axiom "does not appear
to yield overall milder complexity" — the hardness results hold under WCP.

**This is directly decision-relevant.** TFL-Verify's defeasible layer is specified to have
**priorities**, and priorities are exactly what pushes ABA from NP up to Σ₂ᴾ and destroys the
polynomial grounded case (grounded goes from **in P** to **Δ₂ᴾ**). In defeasible logic, by contrast,
the superiority relation is part of the linear-time algorithm from the start. **The feature TFL-Verify
needs most is the feature that is cheapest in defeasible logic and most expensive in ABA.**

### B.1.4 Defeasible logic (Nute/Antoniou/Governatori/Maher lineage)

> **Michael J. Maher.** "Propositional defeasible logic has linear complexity."
> *Theory and Practice of Logic Programming* **1**(6): 691–711, 2001. DOI: 10.1017/s1471068401001168
> *(Crossref verified.)*

> **Grigoris Antoniou, David Billington, Guido Governatori, Michael J. Maher.** "Representation
> results for defeasible logic." *ACM Transactions on Computational Logic* **2**(2): 255–287, 2001.
> DOI: 10.1145/371316.371517 *(Crossref verified.)*

> **David Billington, Grigoris Antoniou, Guido Governatori, Michael Maher.** "An inclusion theorem
> for defeasible logics." *ACM Transactions on Computational Logic* **12**(1): 1–27, 2010.
> DOI: 10.1145/1838552.1838558 *(Crossref verified.)*

> **Grigoris Antoniou, David Billington, Guido Governatori, Michael J. Maher.** "Embedding defeasible
> logic into logic programming." *Theory and Practice of Logic Programming* **6**(6): 703–735, 2006.
> DOI: 10.1017/s1471068406002778 *(Crossref verified.)*

Implementation:
> **Ho-Pun Lam, Guido Governatori.** "The Making of SPINdle." *Rule Interchange and Applications
> (RuleML 2009)*, LNCS, pp. 315–322. DOI: 10.1007/978-3-642-04985-9_29 *(Crossref verified.)*

Defeasible logic is a rule-based, **proof-tag** formalism: strict rules, defeasible rules, defeaters,
and a superiority relation. Conclusions carry tags — **+Δp** (definitely provable), **−Δp**,
**+∂p** (defeasibly provable), **−∂p** — and each tag has an *inductive proof condition* that
constitutes its derivation.

**Maher's result is the decisive fact: propositional defeasible logic has LINEAR complexity.**
Not polynomial — linear. Verbatim, **Theorem 5** (verified by reading the full arXiv PDF, `cs/0405090`):

> "The consequences of a defeasible theory D can be computed in **O(N) time**, where N is the number
> of symbols in D."

The paper notes the algorithm "when restricted to positive definite conclusions, is similar to the
bottom-up linear algorithm for determining satisfiability of Horn clauses of Dowling and Gallier."

**Three scope limits the paper states about itself — all three matter, and citing the headline
without them would be overclaiming:**

1. **Propositional only.** Verbatim: "We have already established that **full first-order defeasible
   logic has a recursively enumerable inference problem**… In this paper we establish that inference
   in **propositional** defeasible logic has linear complexity."
2. **The variants are not covered by the theorem.** Verbatim: "We can expect that similar logics, such
   as the variants discussed in [2] and variants where strict rules are superior to defeasible rules,
   also have linear complexity and are amenable to the techniques used here, **although the details
   will require careful verification.**"
3. **Well-founded defeasible logic is expected to be quadratic, not linear.** Verbatim:
   "**well-founded defeasible logic can be expected to have quadratic complexity**, since it employs
   the well-founded semantics notion of failure, which has quadratic complexity."

**Consequence for TFL-Verify:** the linear-time claim is real and load-bearing, but it attaches to
*propositional* defeasible logic in the standard (ambiguity-blocking) formulation. If the defeasible
layer ends up first-order, or well-founded, or a variant, **the linear bound is not inherited
automatically** and would need its own argument. Since TFL-Verify already commits to a decidable
propositional-ish fragment, this is a natural fit rather than a problem — but the paper should state
which variant it implements and not cite "linear" unqualified.

Implementation of Maher's algorithm:
> **Michael J. Maher, Andrew Rock, Grigoris Antoniou, David Billington, Tristan Miller.**
> "Efficient Defeasible Reasoning Systems." *International Journal on Artificial Intelligence Tools*
> **10**(4): 483–501, 2001. DOI: 10.1142/s0218213001000623 *(Crossref verified.)* — the **Delores**
> system.

### B.1.5 The relationship — what is actually proven

> **G. Governatori, M. J. Maher, G. Antoniou, D. Billington.** "Argumentation Semantics for
> Defeasible Logics." *PRICAI 2000*, LNCS, pp. 27–37. DOI: 10.1007/3-540-44533-1_7
> *(Crossref verified.)*
> Journal version: **"Argumentation Semantics for Defeasible Logic,"** *Journal of Logic and
> Computation* **14**(5): 675–702, 2004. DOI: 10.1093/logcom/14.5.675 *(Crossref verified for
> title/venue/volume/pages/year; **Crossref's author metadata for the journal version lists only
> Governatori** — the four-author attribution is taken from the PRICAI version and standard citation
> practice. See caveats.)*

**This is the paper that settles the "is defeasible logic a special case?" question, and the answer
is: defeasible logic has been given an argumentation semantics — i.e. it can be characterised in
Dung-style argumentation terms — rather than defeasible logic being a mere syntactic sugar over
ASPIC+ or ABA.** The direction that is established is *defeasible logic → argumentation semantics*:
the proof-theoretic tags are shown to correspond to an argumentation-theoretic characterisation. The
"inclusion theorem" paper (Billington et al., TOCL 2010) then maps the internal lattice of defeasible
logic **variants** (ambiguity-blocking vs. ambiguity-propagating, with and without team defeat) onto
one another.

> **Bas van Gijzel, Henry Prakken.** "Relating Carneades with abstract argumentation via the ASPIC+
> framework for structured argumentation." *Argument & Computation* **3**(1): 21–47, 2012.
> *(Crossref verified.)*

This is the model of what a rigorous embedding paper looks like, and it is the template for how one
would relate TFL-Verify's defeasible layer to ASPIC+ if a reviewer demanded it.

### The paper that directly addresses DL vs. ASPIC+ — cited, but full text not obtained

> **Ho-Pun Lam, Guido Governatori, Régis Riveret.** "On ASPIC⁺ and Defeasible Logic."
> *Computational Models of Argument: Proceedings of COMMA 2016*, Frontiers in Artificial Intelligence
> and Applications vol. 287, IOS Press, pp. 359–370. DOI: **10.3233/978-1-61499-686-6-359**
> *(Crossref verified — authors Lam Ho-Pun, Governatori Guido, Riveret Régis, IOS Press, 2016. Note
> Crossref stores the title truncated as "On ASPIC" because the `+` is encoded as `<sup>+</sup>`
> markup; this is a metadata artefact, not a different paper.)*

From the abstract: the paper establishes connections between **an ASPIC+ instantiation and a DL
variant**, examining ambiguity propagating/blocking, team defeat, and strict rules for argumentation.

**Critical caveat — this is the single biggest gap in the sweep for this question.** The paper is
closed access (Unpaywall: `is_oa: false`, no repository copy; Semantic Scholar's abstract is elided by
the publisher). **The full text was not obtained, so the direction of the correspondence, which DL
variant, which ASPIC+ instantiation, and whether it is an equivalence or merely an inclusion are all
unknown.** The abstract says "a linkage between *an* instantiation of ASPIC+ and *a* DL variant" —
which is much weaker than a collapse. **Do not cite this as "DL is a special case of ASPIC+."**
Obtaining this paper should be the first action if the paper needs to make a claim here.

### The strongest *fully verified* embedding result is Carneades → defeasible logic

> **Guido Governatori.** "On the relationship between Carneades and Defeasible Logic."
> *Proceedings of the 13th International Conference on Artificial Intelligence and Law (ICAIL 2011)*,
> ACM, pp. 31–40. DOI: **10.1145/2018358.2018362** *(Crossref verified: sole author Governatori,
> ICAIL 2011, pp. 31–40.)*

Verbatim from the paper (full PDF read by the sub-sweep):

> **Theorem 7.** Let S be a Carneades Argument Evaluation Structure, and D = map(S), then
> 1. p is acceptable in S using proof standard *scintilla of evidence* iff D ⊢ +σ⁻p;
> 2. p is acceptable in S using proof standard ps ∈ {pe, ce, bd, dv} iff D ⊢ +∂*_ps p.

> **Corollary 8.** Acceptability of a proposition in Carneades can be computed in polynomial time.

The paper's own reading:

> "The results in Theorem 7 shows that the inference mechanism of Carneades, based on the current
> proof standards, **corresponds to a simple combination of defeasible logic theories** (sharing the
> same rules and facts but with different superiority relations) where the conclusions for each theory
> are computed using the **ambiguity blocking no team defeat variants of Defeasible Logic**."

Direction and cost, both explicit: the map goes **Carneades → DL**, and "the mapping from a CAES to
the corresponding defeasible theory is, **in the worst case, quadratic** (linear for the dv proof
standard)," because superiority relations must be derived from pairwise argument-weight comparisons.
Corollary 8 composes that quadratic mapping with Maher's linear result.

**This is the cleanest proven statement in the whole area — a real argumentation formalism collapsing
*into* a DL variant, with the translation cost named. It runs in the opposite direction from the
"should we adopt argumentation instead?" intuition**, and it is a strong citation for the
recommendation in § B.1.7. It also means TFL-Verify could support Carneades-style **proof standards**
(§ B.1.6) *inside* a defeasible-logic engine, at quadratic translation cost, without adopting an
argumentation framework at all.

### ABA → ASPIC+ is proven (and only in that direction)

From **Modgil & Prakken**, the ASPIC+ tutorial (*Argument & Computation* **5**(1): 31–62, 2014), §5,
verbatim: "one can reconstruct assumption-based argumentation (ABA) in ASPIC⁺ … **this reconstruction
is formally shown in Prakken (2010)**." The reconstruction "will have **empty sets of defeasible rules
and axiom premises**, and consist of **ordinary premises and strict rules** (respectively
corresponding to the assumptions and rules in an ABA theory)," restricted to **flat** ABA theories,
and "**without the use of preference relation**, a correspondence can be shown between ABA and
ASPIC⁺." It requires the generalised contrary function, not plain negation. **The reverse direction is
not claimed.**

### What is honestly established vs. folklore — state this carefully:

- **Established:** defeasible logic admits an argumentation semantics (Governatori et al. 2004);
  defeasible logic embeds into logic programming (Antoniou et al., TPLP 2006); Carneades relates to
  Dung semantics via ASPIC+ (van Gijzel & Prakken 2012); the defeasible-logic variants are ordered by
  an inclusion theorem (Billington et al. 2010).
- **Established (added by the sub-sweep):** **Carneades → defeasible logic**, with a named quadratic
  translation cost and a polynomial-time corollary (Governatori, ICAIL 2011, Thm 7 / Cor 8);
  **ABA → ASPIC+** for flat theories without preferences (Prakken 2010, restated in Modgil &
  Prakken's 2014 tutorial §5); and *some* linkage between an ASPIC+ instantiation and a DL variant
  (Lam, Governatori & Riveret, COMMA 2016) whose strength is **unknown because the full text was not
  obtained**.
- **Folklore / not established by anything this sweep verified:** that defeasible logic "is just" a
  special case of ASPIC+, or that ASPIC+ with particular parameter choices collapses exactly to
  Nute-style defeasible logic. **No paper proving DL is (or is not) a special case of ASPIC+ or ABA in
  the strong sense was found.** The formalisms are **genuinely different in kind**: defeasible logic
  is *proof-theoretic* (tags with inductive proof conditions, computed bottom-up in linear time);
  ASPIC+/ABA are *semantic* (build all arguments, build the defeat graph, then apply an extension
  semantics). They agree on many outcomes; they are not the same object. Do not assert an exact
  collapse without a citation, because this sweep did not find one.
- **A hint pointing the other way, explicitly flagged as a hint and not a proof.** The Governatori et
  al. 2004 abstract claims "**we provide the first ambiguity blocking Dung-like argumentation
  system**" — i.e. DL's ambiguity-blocking behaviour was *not* available in existing Dung-style
  argumentation and had to be constructed. That suggests ambiguity-blocking DL is not a plain instance
  of standard Dung semantics. **It is an abstract claim about novelty, not a non-embeddability
  result**, and the paper body was not obtained. Do not present it as one.

Adjacent papers whose citations were verified but which did not settle the question:
**Phan Minh Dung**, "An axiomatic analysis of structured argumentation with priorities," *AIJ*
**231**: 107–150, 2016, DOI 10.1016/j.artint.2015.10.005; **Dung & Thang**, "Fundamental properties of
attack relations in structured argumentation with priorities," *AIJ* **255**: 1–42, 2018,
DOI 10.1016/j.artint.2017.11.002.

### B.1.6 Carneades and deployed legal argumentation

> **Thomas F. Gordon, Henry Prakken, Douglas Walton.** "The Carneades model of argument and burden of
> proof." *Artificial Intelligence* **171**(10-15): 875–896, 2007. DOI: 10.1016/j.artint.2007.04.010
> *(Crossref verified.)*

Carneades' distinctive contribution is **proof standards and burden of proof** — scintilla of
evidence, preponderance, beyond reasonable doubt — attached per-proposition. **This is directly
relevant to TFL-Verify's eligibility setting**, where a claimant and an agency demonstrably bear
different burdens, and where (per Robodebt, § B.2.5) reversing the evidentiary burden onto the
claimant was the central injustice. If the defeasible layer is going to model real policy, burden of
proof is a first-class concept, not an add-on. **Carneades is the formalism that took it seriously.**

Defeasible deontic logic / legal compliance tooling (Governatori lineage) is verified as existing:
- **Guido Governatori, Antonino Rotolo, Giovanni Sartor**, "Temporalised normative positions in
  defeasible logic," *ICAIL 2005*, pp. 25–34. DOI: 10.1145/1165485.1165490 *(Crossref verified.)*
- **Efstratios Kontopoulos, Nick Bassiliades, Guido Governatori, Grigoris Antoniou**, "Extending a
  Defeasible Reasoner with Modal and Deontic Logic Operators," *IEEE/WIC/ACM WI-IAT 2008*,
  pp. 626–629. DOI: 10.1109/wiiat.2008.164 *(Crossref verified.)*

### Deployed legal-reasoning and rules-as-code systems — the audit

Each system was chased to a primary source (operator's own site/repo, a government procurement
register, project README, GitHub API, Crossref). Vendor marketing and trade press are labelled as such
and were **not** treated as corroboration.

| System | Formalism | Verdict | Primary evidence |
|---|---|---|---|
| **Oracle Policy Automation / Intelligent Advisor** | Natural-language rules in **Word** + decision tables in **Excel** — not a logic notation | **Verified production use by named public bodies** — the only system here with independent third-party records | UK Find a Tender notice **2025/S 000-016576**: **Financial Ombudsman Service Ltd** renewing OPA "to maintain use of Navigator, Compass and the rulebase within the billing system", £167,898 ex VAT, 6 Apr 2025 – 5 Apr 2026. Contracts Finder **DDaT20003**: **UK Shared Business Services Ltd**, OPA training/support/integration, £180,000, 2020 |
| **OpenFisca** | Python microsimulation DSL (typed `Variable` classes over periods/entities) — not defeasible or deontic | **Verified production use in French state digital services**; actively maintained | `betagouv/aides-jeunes` README (the simulator behind mes-aides.1jeune1solution.beta.gouv.fr): "basé sur simulateur socio-fiscal libre OpenFisca"; repo last pushed 2026-07-31. Showcase lists **Mes droits sociaux**, **LexImpact** (French National Assembly); also **"Les meves ajudes"** (Barcelona) and a Japanese benefits service, per openfisca.org (fetched by lead sweep) |
| **DataLex** (AustLII) | `yscript` rules + `ylegis` preprocessor | **Live public platform, self-declared demonstration only** | AustLII's own wiki (page v89, last edited 23 Oct 2024): "**All of these apps are for demonstration purposes only.**" Runnable apps exist (Modern Slavery Act 2018, News Media Bargaining Code, s44 Constitution, FOI, Copyright); no external organisation runs one operationally |
| **Catala** | Literate DSL with **prioritised default logic** (base cases + exceptions), compiled to a total functional core | **Two proofs of concept + a signed institutional commitment — not yet production** | Inria's own page: "Two proofs of concept for government departments have already been produced" — CNAF (social benefits) and DGFiP (income tax). CNAF press release 08 Jun 2026: partnership convention with Inria; "Catala a été retenu comme une technologie structurante pour les **futurs** chantiers de la Cnaf". Release 1.2.1, 2026-07-06 |
| **Regorous** (Governatori / Data61 CSIRO) | **Defeasible Deontic Logic** (FCL) over BPMN, SPINdle engine | **Prototype + one unnamed trial; the government work was explicitly a proof of concept** | CSIRO's own page: "**prototype technology**" Data61 "previously developed"; sole field result: "A successful trial with an **ISP**…" (unnamed, undated). ABCB-hosted Data61 article (16 May 2017, via Wayback; live URL 404s): "Regulation as a platform is a **two-year proof-of-concept project**". `regorous.com` no longer resolves |
| **Blawx** (Jason Morris) | **s(CASP)** on SWI-Prolog behind a Blockly visual editor | **Experiment only; hosted service gone** | README: "it is **not production-quality software**… intended for **educational and experimental purposes**." CSPS "Rules as Code in Canada" (Feb 2024): prototype used with **Treasury Board Secretariat** to co-draft a "Definition of Salary" regulation; government states the encodings "should not be viewed as having equal legal status to the official rules". Last release v1.6.22-alpha (2023-10-18); **blawx.com now serves an unrelated gambling site** |
| **Carneades** (Gordon) | Carneades Argument Evaluation Structures (CAES), Go | **Research prototype; no deployment found; dormant since 2017** | GitHub API on `carneades/carneades-4`: newest release **v4.3, 2017-07-12**; commits since 2022 are docs/typos only. Project site names only EU research grants (ESTRELLA, IMPACT, MARKOS) and an ICCMA 2015 placing |

**The pattern is the finding, and it is uncomfortable for the argumentation camp.** The two systems
with genuine production footprints (**OPA**, **OpenFisca**) use the *least* logically expressive
formalisms — natural-language conditionals plus decision tables, and typed microsimulation formulas.
The systems with the richest logics (**defeasible deontic logic** in Regorous, **s(CASP)** in Blawx,
**CAES** in Carneades) have the weakest deployment records. Catala — prioritised default logic — sits
in between and is the only expressive-formalism system with a signed government commitment.

**Two readings, and TFL-Verify should decide which it is making.** Either (a) expressive logic is a
liability in deployment and the winners are deliberately dumb, or (b) nobody has yet paired an
expressive logic with the tooling, maintenance and institutional trust that OPA and OpenFisca enjoy.
The honest answer is that this sweep cannot distinguish them, and the paper should not pretend it can.
What can be said safely: **rules-as-code eligibility tooling demonstrably reaches production in
government**, which supports the application premise, while **structured argumentation demonstrably
has not**, which is a caution rather than an encouragement for the defeasible layer's ambitions.

### B.1.7 **Recommendation on the defeasible layer**

**Recommendation: keep the planned Nute-style defeasible logic. Do not switch the core to ASPIC+ or
ABA.** Reasons, in order of weight:

**1. Complexity — this is not close.**

| Formalism | Reasoning cost |
|---|---|
| **Propositional defeasible logic** | **Linear** (Maher, TPLP 2001) |
| ASPIC+ / ABA under grounded semantics | P-complete |
| ASPIC+ / ABA under stable | NP-c credulous / coNP-c skeptical |
| ASPIC+ / ABA under **preferred, skeptical** | **Π₂ᴾ-complete** |
| ASPIC+ / ABA under semi-stable, stage | Σ₂ᴾ-c / Π₂ᴾ-c |

TFL-Verify's whole thesis is fragment discipline and cheap decidable checking. Adopting a defeasible
layer whose natural semantics sits at the second level of the polynomial hierarchy would contradict
the project's own argument. Linear-time is not merely "faster" — it means the defeasible layer costs
asymptotically less than the parsing that precedes it, and it keeps the engine's cost story
uniformly simple.

*Honest qualification:* if one restricts ASPIC+/ABA to **grounded** semantics, it is polynomial, and
the complexity gap narrows to linear-vs-polynomial. But grounded semantics is also the most
sceptical and least expressive choice, which removes much of the reason to prefer ASPIC+ in the first
place. And the Nute lineage already offers a spectrum of variants (ambiguity-blocking vs.
propagating, team defeat) with the inclusion theorem relating them — the same expressiveness dial, at
linear cost.

**2. Readability of the certificate — also not close.**

- **Defeasible logic yields a certificate shaped like a legal argument.** A conclusion carries a tag
  (+∂p) whose proof condition unfolds into: *this rule applied; its antecedent held; every competing
  rule was either inapplicable, or defeated by a rule superior to it.* That reads, almost directly,
  as: *"You were found ineligible because rule R7 applied; the exception in R12 did not apply because
  you are not a full-time student; and R7 outranks R3."* Every element of that sentence is a
  proposition the claimant can deny — which is requirement (2) of § B.2.6.
- **ASPIC+/ABA yield a certificate shaped like a graph-theoretic claim.** "Argument A5 is in every
  preferred extension of the defeat graph" is not contestable by a layperson; it is barely
  contestable by a non-specialist lawyer. Rendering it requires either explaining extension semantics
  or discarding the semantics and showing only a dialogue — at which point you have re-derived
  something like a proof tag anyway.
- This matters more than usual for TFL-Verify because § A.4 and § B.2.4 both show the lay-readability
  bar is where systems actually fail. Choosing the formalism whose native artifact is *already* a
  reason-giving sentence is the single cheapest win available.

**3. Engineering fit with the existing project.** Defeasible logic's proof tags are an inductively
defined judgement over a rule set — exactly the shape that OCaml variants plus exhaustive `match`
handle well, and exactly the shape the existing oracle/differential test regime already knows how to
fuzz. ASPIC+ would require implementing argument construction, a defeat graph, and an extension
solver — effectively a second engine, with a second correctness surface, at NP-hard-and-above cost.
That is a large violation of the project's "lean; never over-engineer" principle.

**4. Deontic and burden-of-proof extensions exist in the same lineage.** Governatori's defeasible
deontic logic and the temporalised-normative-positions work sit directly on top of defeasible logic,
so the path to modelling obligations, permissions and violations does not require changing
formalisms later.

**What to take from ASPIC+/ABA/Carneades without adopting them:**

- **The rationality postulates** (Caminada & Amgoud 2007) — closure under strict rules, direct and
  indirect consistency. These are excellent properties for a *verified* engine to state and check,
  and they give the paper a principled correctness criterion beyond "the oracle is green."
- **Carneades' proof standards and burden of proof** — model who must show what. Given Robodebt, this
  is the most policy-relevant idea in the whole argumentation literature for this project.
- **ASPIC+'s three attack types** as a design checklist: does the defeasible layer let a claimant
  attack a *premise* (undermining), a *conclusion* (rebutting), and the *applicability of a rule*
  (undercutting)? All three are distinct real-world contest moves, and a layer that supports only
  rebutting is under-powered for contestation.
- **van Gijzel & Prakken (2012) as the template** if a reviewer asks how TFL's defeasible layer
  relates to mainstream structured argumentation. The honest answer is that it has an argumentation
  semantics (Governatori et al. 2004) and that a formal relating paper is future work — not that it
  is a special case.

---

## B.2 Contestability and explainable automated decision-making

*Sub-sweep findings. Five of this section's load-bearing citations (Lage et al., Poursabzi-Sangdeh
et al., Hirsch et al., Almada, Henin & Le Métayer) were independently re-verified against Crossref by
the lead sweep and matched exactly on title, authors, venue, pages and year.*

### B.2.1 The "right to explanation" debate — and how the CJEU largely settled it

The GDPR text is in the box above. The structural point: **Art 22(3) is a contestation right, not an
explanation right — the word "explanation" does not appear in Article 22.** It appears in **Recital
71**, which is non-binding interpretive guidance: safeguards "should include specific information to
the data subject and the right to obtain human intervention, to express his or her point of view, **to
obtain an explanation of the decision reached** after such assessment and to challenge the decision."
That gap is the entire academic fight.

| Position | Citation (verified) |
|---|---|
| No binding right to explanation exists | **Sandra Wachter, Brent Mittelstadt, Luciano Floridi**, "Why a Right to Explanation of Automated Decision-Making Does Not Exist in the General Data Protection Regulation," *International Data Privacy Law* **7**(2): 76–99 (2017). DOI: 10.1093/idpl/ipx005 |
| Rebuttal — read "meaningful" functionally | **Andrew D. Selbst, Julia Powles**, "Meaningful information and the right to explanation," *IDPL* **7**(4): 233–242 (2017). DOI: 10.1093/idpl/ipx022 |
| Reframe as "legibility" | **Gianclaudio Malgieri, Giovanni Comandé**, "Why a Right to Legibility of Automated Decision-Making Exists in the GDPR," *IDPL* **7**(4): 243–265 (2017). DOI: 10.1093/idpl/ipx019 |
| Right is the wrong remedy | **Lilian Edwards, Michael Veale**, "Slave to the Algorithm? Why a 'Right to an Explanation' Is Probably Not the Remedy You Are Looking For," *Duke Law & Technology Review* **16**(1): 18–84 (2017) |
| Synthesis — a broader accountability regime | **Margot E. Kaminski**, "The Right to Explanation, Explained," *Berkeley Technology Law Journal* **34**(1): 189–218 (2019). DOI: 10.15779/Z38TD9N83H |

Selbst & Powles' move is the one that matters for us: **"meaningful" is pegged to whether the
information actually enables the data subject to exercise their rights — including the Art 22(3)
right to contest — rather than to any fixed technical disclosure format.** That is a functional
standard, and a proof trace can be argued to meet it.

**The CJEU has now largely resolved this in favour of contestability.**

> **Case C-634/21, *OQ v Land Hessen* (the "SCHUFA" ruling)**, CJEU, 7 December 2023,
> **ECLI:EU:C:2023:957** (CELEX 62021CJ0634). Operative part, verbatim from EUR-Lex: the automated
> establishment by a credit information agency of "a probability value… concerning his or her
> ability to meet payment commitments in the future constitutes 'automated individual
> decision-making' within the meaning of that provision, where a third party, to which that
> probability value is transmitted, draws strongly on that probability value to establish, implement
> or terminate a contractual relationship with that person."

The Court refused the "a human made the final call" defence where the human merely rubber-stamps a
score. The *score producer* is caught, not just the *decision announcer*.

> **Case C-203/22, *CK v Magistrat der Stadt Wien* (Dun & Bradstreet Austria)**, CJEU,
> 27 February 2025, **ECLI:EU:C:2025:117** (CELEX 62022CJ0203).

The controller must "explain, by means of relevant information and in a **concise, transparent,
intelligible and easily accessible form, the procedure and principles actually applied**," described
"in such a way that the data subject can understand **which of his or her personal data have been used
in what way**." Where trade secrets (Directive 2016/943) or third-party data are implicated, the
material goes to the supervisory authority or court, which balances and sets the scope of access.

**The doctrinal sentence that binds explanation to contestation:** if individuals "were not in a
position to understand the reasons which led to that decision **before expressing their point of view
or contesting the decision**, those rights would not satisfy in full their purpose."

**This is the most important legal finding in the whole sweep.** The required *content* of an
explanation is derived from **what contestation requires** — not from what the model happens to
expose. That is a legal standard a proof trace is unusually well suited to meet, and it is far
stronger ground than the older "right to explanation" literature.

> **EU AI Act, Art. 86 — "Right to explanation of individual decision-making."** Regulation (EU)
> 2024/1689 (13 June 2024; OJ 12 July 2024); **Art. 86 applies from 2 August 2026.** Affected persons
> subject to an Annex III high-risk decision with adverse impact have the right to obtain "clear and
> meaningful explanations of the role of the AI system in the decision-making procedure and the main
> elements of the decision taken." *(Scope note: this is an explanation of the system's **role** and
> the decision's **main elements** — not of model internals. See caveats: EUR-Lex direct fetch was
> blocked; text taken from two independently agreeing OJ mirrors.)*

### B.2.2 Administrative-law reason-giving

- **US — 5 U.S.C. § 555(e)** (verified verbatim, Cornell LII): "Except in affirming a prior denial or
  when the denial is self-explanatory, **the notice shall be accompanied by a brief statement of the
  grounds for denial**." Note the two carve-outs — "affirming a prior denial" and "self-explanatory"
  — which are exactly where automated eligibility systems hide.
- **US — *Motor Vehicle Mfrs. Ass'n v. State Farm Mutual Automobile Ins. Co.*, 463 U.S. 29 (1983)**
  (verified, Cornell LII): the agency "must examine the relevant data and articulate a satisfactory
  explanation for its action including a **'rational connection between the facts found and the choice
  made.'**" **This is the closest thing in US law to a demand for a trace** — facts found → connection
  → choice made is a structural requirement on the *shape* of the justification.
- **EU — Article 41 CFR, Right to good administration** (verified verbatim, fra.europa.eu). Art 41(2)
  is a three-part package: **(a)** the right to be heard *before* the adverse measure; **(b)** access
  to one's file, subject to confidentiality/trade-secret interests; **(c)** "**the obligation of the
  administration to give reasons for its decisions.**" This maps almost exactly onto Art 22(3) GDPR,
  and (b) already contains the trade-secret balancing that C-203/22 later applied.

Scholarship connecting reason-giving to automated systems, all verified:

| Citation | Note |
|---|---|
| **Danielle Keats Citron**, "Technological Due Process," *Washington University Law Review* **85**(6): 1249 (2008) | The foundational piece |
| **Danielle K. Citron, Frank Pasquale**, "The Scored Society: Due Process for Automated Predictions," *Washington Law Review* **89**: 1 (2014) | |
| **Kate Crawford, Jason Schultz**, "Big Data and Due Process: Toward a Framework to Redress Predictive Privacy Harms," *Boston College Law Review* **55**(1): 93–128 (2014) | Proposes "procedural data due process" |
| **Ignacio N. Cofone, Katherine J. Strandburg**, "Strategic Games and Algorithmic Secrecy," *McGill Law Journal* **64**(4): 623– (2019) | **The published rebuttal to the "people will game the rules if you disclose them" objection** — gaming requires loose proxies, subject-modifiable features, and cheap modification not reflecting genuine improvement. Cite this whenever rule-trace disclosure is challenged. |
| **Margot E. Kaminski, Jennifer M. Urban**, "The Right to Contest AI," *Columbia Law Review* **121**(7): 1957 (2021) | Four archetypes of contestation; grounds contestation in due-process tradition |

### B.2.3 Contestability as an HCI/design construct

| Citation (all Crossref-verified) | Contribution |
|---|---|
| **Tad Hirsch, Kritzia Merced, Shrikanth Narayanan, Zac E. Imel, David C. Atkins**, "Designing Contestability: Interaction Design, Machine Learning, and Mental Health," *DIS 2017*, pp. 95–99. DOI: 10.1145/3064663.3064703 | **Origin point** — identifies "contestability" as a new design principle for systems that evaluate human behaviour |
| **Marco Almada**, "Human intervention in automated decision-making: Toward the construction of contestable systems," *ICAIL 2019*, pp. 2–11. DOI: 10.1145/3322640.3326699 | **Contestability by design**; contestation is "not an afterthought, but instead a requirement at each stage of an AI system's lifecycle." Notes data subjects "might still lack the information they need to the concrete exercise of their right" |
| **Henrietta Lyons, Eduardo Velloso, Tim Miller**, "Conceptualising Contestability: Perspectives on Contesting Algorithmic Decisions," *PACM HCI* **5**(CSCW1), Art. 106, pp. 1–25 (2021). DOI: 10.1145/3449180 | Empirical analysis of submissions to Australia's AI Ethics Framework |
| **Kars Alfrink, Ianus Keller, Gerd Kortuem, Neelke Doorn**, "Contestable AI by Design: Towards a Framework," *Minds and Machines* **33**(4): 613–639 (2023; online 2022). DOI: 10.1007/s11023-022-09611-z | Framework synthesis |
| **Clément Henin, Daniel Le Métayer**, "Beyond explainability: justifiability and contestability of algorithmic decision systems," *AI & Society* **37**(4): 1397–1410 (2022). DOI: 10.1007/s00146-021-01251-8 | **The strongest theoretical hook for a proof-trace approach.** An *explanation* says how the system reached its output; a **justification** says why the output is *right*. Contestability requires the latter — and a proof trace is natively a justification, not merely an explanation |
| **Thomas Ploug, Søren Holm**, "The four dimensions of contestable AI diagnostics," *Artificial Intelligence in Medicine* **107**: 101901 (2020). DOI: 10.1016/j.artmed.2020.101901 | Contest the data / bias / performance / division of labour |
| **Mireia Yurrita, Himanshu Verma, Agathe Balayn, Kars Alfrink, Ujwal Gadiraju, Alessandro Bozzon**, "Identifying Algorithmic Decision Subjects' Needs for Meaningful Contestability," *PACM HCI* **9**(7), Art. CSCW234, pp. 1–29 (2025). DOI: 10.1145/3757415 | **Most recent and most on-point.** 21 semi-structured interviews with citizens of varying AI literacy, on a real public-sector system (Amsterdam illegal holiday-rental detection). Subjects need (1) **cooperation in sense-making**, (2) **support in contestation acts**, (3) **appropriate responsibility attribution**. Emphasises contestability's **collaborative** nature — an artifact-centric view of explanation is insufficient |

### B.2.4 The direct evidence question — do logical/rule traces help laypeople?

**There is no published human-subject study of formal logical proof traces presented to laypeople in
an eligibility-contestation setting.** That is a real novelty claim for TFL-Verify — and it means any
assertion that proof traces aid contestation is currently *unevidenced* and must be presented that
way.

**The nearest evidence is mildly to moderately discouraging, and it is aimed precisely at the
proof-trace form.**

> **Isaac Lage, Emily Chen, Jeffrey He, Menaka Narayanan, Been Kim, Samuel J. Gershman,
> Finale Doshi-Velez.** "Human Evaluation of Models Built for Interpretability."
> *Proc. AAAI Conf. on Human Computation and Crowdsourcing (HCOMP)* **7**(1): 59–67, 2019.
> DOI: 10.1609/hcomp.v7i1.5280 *(re-verified by lead sweep — exact match on all seven authors,
> venue, vol 7, pp. 59–67, 2019.)*

This is the closest existing study, because its object *is* a logic-based model — **decision sets** —
with Mechanical Turk laypeople, across simulation/verification/counterfactual questions in two
domains, manipulating model size, **cognitive chunks** (named intermediate concepts defined and
reused — structurally, *lemmas*), and repeated terms. Verbatim findings:

> "greater complexity generally results in longer response times; **adding cognitive chunks had the
> clearest impact**, while the effect of model size was less clear"

> "Introducing new cognitive chunks can result in overall increases in response time **on the order of
> 20 seconds**, whereas increases in length have effects on the order of 10 seconds."

> "participants had **significantly longer response times when new cognitive chunks were made explicit
> rather than implicitly embedded in a line**. This ran counter to our expectations"

> "the effect of different types of complexity on **accuracy was less clear. None of the effects were
> statistically significant.** … **counterfactual tasks had significantly lower accuracies than
> simulation tasks**."

> "the criteria we used to exclude participants who were not able to complete the tasks effectively
> at the beginning of the experiment **excluded over half of the participants**."

**A term-logic derivation is nothing but explicit intermediate steps — exactly the factor Lage et al.
measured as the most costly, and which cost *more* when made explicit than when left implicit.**

> **Forough Poursabzi-Sangdeh, Daniel G. Goldstein, Jake M. Hofman, Jennifer Wortman Vaughan,
> Hanna Wallach.** "Manipulating and Measuring Model Interpretability." *CHI 2021*, pp. 1–52.
> DOI: 10.1145/3411764.3445315 *(re-verified by lead sweep.)*

Abstract, verbatim: "We present a sequence of **pre-registered experiments (N = 3,800)**… Predictably,
participants who saw a clear model with few features could better simulate the model's predictions.
However, we did not find that participants more closely followed its predictions. Furthermore,
**showing participants a clear model meant that they were less able to detect and correct for the
model's sizable mistakes, seemingly due to information overload.** These counterintuitive findings
emphasize the importance of testing over intuition when developing interpretable models."

**This is the sharpest counter-evidence in the field: transparency improved simulation but degraded
error detection — and error detection is exactly what contestation requires.** A person who can
recite the rule but cannot spot that it was misapplied to them cannot contest.

Supporting evidence:

- **Tim Miller**, "Explanation in artificial intelligence: Insights from the social sciences,"
  *Artificial Intelligence* **267**: 1–38 (2019). DOI: 10.1016/j.artint.2018.07.007 — human
  explanation is **contrastive**, **selective**, and **social**. A complete derivation is
  anti-selective by construction.
- **Reuben Binns, Max Van Kleek, Michael Veale, Ulrik Lyngs, Jun Zhao, Nigel Shadbolt**,
  "'It's Reducing a Human Being to a Percentage': Perceptions of Justice in Algorithmic Decisions,"
  *CHI 2018*, pp. 1–14. DOI: 10.1145/3173574.3173951 — three experiments; "explanation styles
  primarily matter to justice perceptions only when subjects are exposed to multiple different
  styles"; "there may be **no 'best' approach** to explaining algorithmic decisions." Also found a
  **strong dislike of case-based explanations** despite their being the most faithful — faithfulness
  and acceptability come apart.
- **Sandra Wachter, Brent Mittelstadt, Chris Russell**, "Counterfactual Explanations Without Opening
  the Black Box: Automated Decisions and the GDPR," *Harvard Journal of Law & Technology* **31**(2):
  841–887 (2018). Verbatim: "We propose **three aims for explanations to assist data subjects: (1) to
  inform and help the subject understand why a particular decision was reached, (2) to provide grounds
  to contest adverse decisions, and (3) to understand what could be changed to receive a desired
  result in the future**… **none hinge on explaining the internal logic** of automated decision-making
  systems." **This last clause is a direct challenge to the proof-trace pitch and should be engaged
  head-on, not ignored.**

### B.2.5 Deployed eligibility systems that failed — and reason-giving was a named cause

**Australia — Robodebt.** *Report of the Royal Commission into the Robodebt Scheme*, Commissioner
**Catherine Holmes AC SC**, presented 7 July 2023 (corrected edition 11 July 2023), three volumes.
Income averaging of ATO annual data to raise social-security debts, reversing the evidentiary burden
onto recipients. Quoted in the Government Response (PMC, Nov 2023, ISBN 978-1-925365-36-8):

> "Robodebt was a crude and cruel mechanism, neither fair nor legal, and it made many people feel
> like criminals. In essence, people were traumatised on the off-chance they might owe money."
> (Report, p. xxix)

**Reason-giving was named as a cause, and Chapter 17's recommendations are the most directly
actionable design finding in this entire sweep.** Verbatim, Recommendation 17.1:

> "Where automated decision-making is implemented: • **there should be a clear path for those affected
> by decisions to seek review** • **departmental websites should contain information advising that
> automated decision-making is used and explaining in plain language how the process works**
> • **business rules and algorithms should be made available, to enable independent expert scrutiny.**"

Recommendation 17.2 calls for a body empowered "to monitor and audit automated decision-making
processes." **Note the two-tier structure of 17.1: plain-language explanation for the individual,
*plus* full rule/algorithm disclosure for expert scrutiny. The Commission did not treat either as a
substitute for the other.**

**Netherlands — SyRI.** Rechtbank Den Haag, 5 February 2020, *NJCM c.s. v. The Netherlands*,
C-09-550982, **ECLI:NL:RBDHA:2020:1878** (English version). The legislation enabling the *Systeem
Risico Indicatie* welfare-fraud risk system failed the Art 8(2) ECHR necessity/proportionality test
and was declared unlawful, the court emphasising lack of transparency and verifiability. The remedy
halted future use; it did **not** order disclosure of the models or destruction of data.
**Lesson: a system that cannot show its reasoning cannot be defended by the State either — opacity
is a litigation liability, not merely an individual-rights harm.**

**Netherlands — the childcare benefits scandal (*toeslagenaffaire*).** *Ongekend onrecht*
("Unprecedented injustice"), Childcare Allowance Parliamentary Inquiry Committee (chair C.J.L. van
Dam), Parliamentary document **35 510 no. 2**, 17 December 2020 (official English PDF read in full).
Verbatim: "basic principles of the rule of law were breached"; the "**all or nothing**" approach was
"a serious breach of the rule-of-law principle whereby a person's individual circumstances should be
taken into consideration"; parents were "**incorrectly branded as deliberate fraudsters**"; "**for
years, parents never had a chance**."

**The single most precise finding in the corpus on why reasons matter**, verbatim:

> "Many of the parents submitted objections to the Tax and Customs Administration/Benefits, but
> **because the Tax and Customs Administration/Benefits had not stated which documents were missing
> or were inaccurate, it was difficult for parents to state the reasons for their objections.**"

and, on stopping benefits for ~302 parents: "**No or insufficient reasons were stated on the order
form for stopping the benefits.**"

**The causal mechanism named is exactly the one a contestable-explanation system targets: an unstated
ground of decision makes the objection *unformulable* — not merely unpersuasive.** This is the
strongest single sentence in the sweep for motivating TFL-Verify's societal claim.

**US — Michigan MiDAS.** *Cahoo v. SAS Analytics Inc.*, **912 F.3d 887 (6th Cir. 2019)** (Nos.
18-1295/1296, decided 3 January 2019); related district-court opinions 322 F. Supp. 3d 772 and
377 F. Supp. 3d 769 (E.D. Mich.). Scholarly account: **Sonia M. Gipson Rankin**, "The MiDAS Touch:
Atuahene's 'Stategraft' and Unregulated Artificial Intelligence," **98 N.Y.U. L. Rev. Online 225
(2023)**. Verbatim from Gipson Rankin:

> "The Agency later recognized that in most cases from 2013 to 2015, **MiDAS ran from start to finish
> with no human review.**"

> "**The MiDAS fraud questionnaires did not provide adequate notice of the alleged misconduct to
> plaintiffs and prevented claimants from objecting to the possibility of fraud.**"

> "complaints and phone calls… were met with **the opaque diagnosis the MiDAS software regurgitated:
> 'overpayment,' with no further description given.**"

The Sixth Circuit affirmed denial of qualified immunity on the due-process claim because MiDAS
deprived plaintiffs of protected property interests "**without providing adequate pre-deprivation
notice**." **MiDAS is the case where "no reasons" is not background grievance but the constitutional
violation itself.** The bare string "overpayment" is the canonical example of an explanation that
satisfies a notice-was-sent checkbox while being useless for contestation.

### B.2.6 What an explanation must contain to be genuinely contestable

Six requirements converge across the legal and HCI strands. **Only the first two are about the
explanation as an artifact** — which is itself the headline finding.

1. **The specific grounds actually relied on in this case.** C-203/22's "procedure and principles
   *actually applied*"; *State Farm*'s "rational connection between the facts found and the choice
   made"; § 555(e)'s "grounds for denial"; and the *toeslagenaffaire* in negative form.
2. **Enough to locate an attackable proposition — an identified premise the person can deny.**
   Contestation is not comprehension; it is the ability to say *"that input is wrong"* or *"that step
   does not follow."* (Henin & Le Métayer; Wachter et al.'s aim (2).)
3. **Actionable difference-making information: what would have to change.** (Wachter et al. aim (3);
   Miller's contrastiveness.)
4. **Delivered before the deprivation, through a channel the person actually reads.** MiDAS produced
   an explanation and failed on both counts. Art 41(2)(a) CFR fixes the timing.
5. **A named, reachable, independent human with authority to change the outcome.** (Art 22(3);
   Yurrita et al.'s responsibility attribution; the *toeslagenaffaire* finding that objections were
   handled "not independently of the first assessor.")
6. **A parallel, deeper disclosure for expert/institutional scrutiny.** Robodebt Rec 17.1 makes this
   a *separate limb*; C-203/22 institutionalises it via supervisory-authority/court balancing.

**The honest synthesis for TFL-Verify.** The evidence does not say proof traces fail. It says the
**naive presentation of a proof trace to a layperson will very likely fail**, and it names the failure
mode precisely: explicit intermediate steps are the most costly element (Lage et al.), and more
visible reasoning has been shown to *reduce* error detection through information overload
(Poursabzi-Sangdeh et al.).

The convergent design implication — from Robodebt Rec 17.1, Yurrita et al., and C-203/22 alike — is a
**two-tier artifact**:

- **Tier 1, for the affected person:** short, selective, contrastive, premise-naming. Which premise
  *about you* is doing the work, and what would have to be different. The trace's value here is that
  it makes the *selection* faithful and the premises individually deniable.
- **Tier 2, for advocates, auditors, courts, and supervisory authorities:** the complete,
  machine-checkable derivation. Its value here is that it makes independent scrutiny cheap and the
  verdict falsifiable.

**If TFL-Verify runs a human-subject study, the pre-registered comparison this literature makes most
valuable — and that nobody has run — is: proof trace vs. counterfactual vs. feature attribution,
measured on the ability to correctly identify a genuinely erroneous premise.** Measure error
detection, not self-reported understanding or trust; those are known to diverge across this
literature, and error detection is the outcome that maps to contestability.

---

# ANSWERS TO THE THREE QUESTIONS

## Q1. Does the DL/OWL world already produce entailment explanations readable by non-experts?

**No. It produces correct derivations that non-experts cannot read.** The competitor is real at the
derivation layer and absent at the comprehension layer.

**What exists (mature, shipped):**
- **Justifications** — minimal premise subsets J ⊆ O with J ⊨ η. Standard in Protégé. Refined into
  *laconic* and *precise* justifications (Horridge, Parsia & Sattler, ISWC 2008). **Structurally
  cannot explain *how*** — they are premises, not derivations. Alrabbaa et al.: "they do not provide
  deeper information on the reasoning behind the entailment."
- **Proofs** — glass-box proofs from ELK for OWL EL, shipped in Protégé; **Evee** (Java library, DLs
  up to ALCH) and **Evonne** (interactive visualisation), arXiv:2206.07711. Backed by real theory:
  minimal proofs NP-complete, **minimal tree-shaped proofs in P** via a Dijkstra-like greedy
  algorithm (arXiv:2004.08311).
- **Survey**: Koopmann, "Explaining Reasoning Results for Description Logic Ontologies," OASIcs vol.
  138, 2025, DOI 10.4230/OASIcs.RW.2024/2025.6 — covers justifications, proofs, interpolation
  (positive entailments) and **abduction** (negative entailments).

**The human-subject evidence, which is the decisive part:**
- **Horridge's studies used only experts** — Manchester CS staff, PhD students, MSc ontology students,
  reasoner developers. Results: "**all participants bar one ranked one or more justifications as
  being impossible to understand**"; "**all participants, including participants with a background in
  OWL and Description Logics made errors on the predicted hard justifications**"; participants with
  "many years of experience with OWL, and even reasoner developers" missed a two-axiom inference.
  **Zero laypeople were ever tested.**
- **Alrabbaa et al. (RuleML+RR 2022) did test laypeople** — Prolific, no background restrictions,
  n = 101 / 173 / 108 across three online studies. Study III: **mean proof-comprehension score 2.36
  out of 12** (~20%); 60.7% had never worked with propositional logic; **only 3 participants said the
  proofs were easy to understand**. Subjective preference for short tree proofs, but **no objective
  performance difference**. Their own framing: "**Even methods that are 'explainable by design', such
  as logic-based ones, are not necessarily understandable by design when presenting them to
  laypersons.**"

**Implication for TFL-Verify:** the competitor is strongest exactly where TFL is not differentiated
(producing a correct derivation) and absent exactly where TFL claims to be (a citizen can read it).
Position against it with a concession from inside the DL camp rather than an outside dismissal. Two
free design commitments follow: **emit tree-shaped traces** (PTIME to minimise; subjectively
preferred) and **render steps as natural-language sentences, not symbols** (what Alrabbaa et al. did
to widen participation). And measure comprehension **objectively** if a study is run — preference and
comprehension demonstrably came apart in these studies.

**Also flagged: negative entailments.** The DL field treats "why was X *not* derived?" as a separate,
harder problem handled by **abduction**, not proofs. For eligibility contestation that is arguably
the *primary* case (a claimant denied a benefit). Decide explicitly whether TFL-Verify covers it or
scopes it out in limitations.

## Q2. Is there evidence that decidable subsumption reasoning delivers public value at scale?

**Yes, strong and citable.** This is solid evidence *for* the project's bet.

| Evidence | Verified figure | Source |
|---|---|---|
| SNOMED CT size | **> 360,000 concepts** | snomed.org/what-is-snomed-ct (verbatim) |
| Geographic reach | **"in use in more than eighty countries"** | same |
| Governance | **53 member countries/territories**; >50,000 affiliate licences | snomed.org/members (verbatim) |
| UK mandate | **Mandatory** NHS information standard SCCI0034 Amd 35/2016 under s.250 Health & Social Care Act 2012; GP **before 1 Apr 2018**, secondary/acute/mental health/community/dentistry/optometry **before 1 Apr 2020** | standards.nhs.uk (fetched) |
| Production reasoner | **ELK is the default reasoner** in SNOMED International's own classification service, feeding Snowstorm and the Authoring Platform | github.com/IHTSDO/classification-service README (verbatim) |
| Standardisation | OWL 2 EL is a **W3C Recommendation (11 Dec 2012)** with **PTIME-complete** consistency, satisfiability, subsumption, instance checking | w3.org/TR/owl2-profiles |
| Performance | SNOMED CT (294,469 concepts, 294,479 axioms): **ELK 6.2 s** vs. jcel 1041.6 s, FaCT++ 408.9 s, **HermiT time-out (30 min)**, **Pellet mem-out** — one 2011-era laptop | Kazakov et al., ORE 2012, Table 2 (PDF read) |
| Competition | ORE 2015: 14 reasoners, 6 tracks; Konclude won 4 (all DL disciplines), **ELK won both EL tracks**; ELK overtakes Konclude "towards the harder end" | ORE 2015 report (PDF read) |
| Still true in 2023 | Six OWL 2 DL reasoners: "**the majority of the reasoners were unable to successfully perform over half of the reasoning tasks**" on the 21 largest BioPortal ontologies | Lam, Elvesæter & Martin-Recuerda, DMKG 2023 (PDF read) |

**The strongest single argument:** on the same ontology, on the same laptop, the EL reasoner finishes
in 6.2 seconds while general OWL 2 DL reasoners time out or run out of memory. That is the fragment
boundary showing up as the difference between *works* and *does not run at all* — and the 2023
re-evaluation shows it is not an artefact of old benchmarks.

**The precedent to cite for the project's whole arc:** EL++ went from a 2005 IJCAI theory paper →
W3C Recommendation (2012) → mandatory national health infrastructure. *Identify fragment → prove
tractability → ship a reasoner → standardise → deploy* has been walked successfully.

**Two honest limits.** (a) SNOMED's reasoning is *terminological classification*, and its consumers
are terminology authors and downstream software, **not affected citizens** — it proves scale and
trust, not that anyone solved lay explanation. (b) The DL reasoner ecosystem has a visible
**maintenance problem** (2023 study: several reasoners unupdated for 5+ years) — relevant to a project
planning to ship and maintain an engine.

## Q3. Should the defeasible layer be ASPIC+/ABA rather than Nute-style defeasible logic?

**No. Keep Nute-style defeasible logic.** The recommendation is not close on either axis.

**Complexity:**

| Formalism | Cost |
|---|---|
| **Propositional defeasible logic** | **LINEAR** — O(N), N = symbols in the theory (Maher, *TPLP* 1(6):691–711, 2001, Thm 5) |
| ABA **+ preferences** (ABA+), admissible credulous | **Σ₂ᴾ-complete**; grounded rises from **in P** to **Δ₂ᴾ** (Lehtonen, Wallner & Järvisalo, *JAIR* 71:265–318, 2021) |
| ASPIC+/ABA, grounded semantics | P-complete |
| ASPIC+/ABA, stable | NP-c credulous / coNP-c skeptical |
| ASPIC+/ABA, **preferred, skeptical** | **Π₂ᴾ-complete** |
| ASPIC+/ABA, semi-stable / stage | Σ₂ᴾ-c / Π₂ᴾ-c |

(Dung-semantics figures from Dvořák & Dunne, *Handbook of Formal Argumentation* complexity chapter,
Table 1, PDF read. ABA figures from Table 8 of the same chapter: flat ABFs with polynomial
derivability give NP/coNP for stable, Π₂ᴾ for skeptical preferred.) ASPIC+ and ABA both *instantiate*
Dung AFs and therefore inherit this table wholesale. A project whose entire thesis is fragment
discipline should not bolt on a layer that natively sits at the second level of the polynomial
hierarchy.

**Readability of the certificate — the more important reason:**
- Defeasible logic's proof tag **+∂p** unfolds into a legal-sounding sentence: *rule R7 applied; its
  antecedent held; the exception in R12 did not apply because you are not a full-time student; and R7
  outranks R3.* **Every clause is a proposition the claimant can deny** — which is precisely
  requirement (2) of the contestability synthesis in § B.2.6.
- ASPIC+/ABA's native artifact is "argument A5 is in every preferred extension of the defeat graph."
  That is not contestable by a layperson. Rendering it readably means either teaching extension
  semantics or discarding them for a dialogue — re-deriving something proof-tag-shaped anyway.

**Engineering fit:** proof tags are an inductively defined judgement over a rule set — OCaml variants
plus exhaustive `match`, and the existing oracle/differential regime already fuzzes that shape.
ASPIC+ would mean argument construction + defeat graph + extension solver: a second engine with a
second correctness surface at NP-hard cost. A large "lean; never over-engineer" violation.

**Two findings that sharpen the recommendation (added after the sub-sweep):**

- **Priorities are the decisive feature, and they are cheapest in defeasible logic.** TFL-Verify's
  defeasible layer is specified to have priorities. Adding preferences to ABA (ABA+) pushes credulous
  admissible reasoning to **Σ₂ᴾ-complete** and lifts grounded from **in P** to **Δ₂ᴾ** (Lehtonen et
  al., *JAIR* 71, 2021; hardness holds even under Weak Contraposition). In defeasible logic the
  superiority relation is inside the linear-time algorithm from the start. *The feature the project
  needs most is the one that is free in DL and expensive in ABA.*
- **The one proven collapse runs Carneades → defeasible logic, not the reverse.** Governatori (ICAIL
  2011, Thm 7 / Cor 8) maps Carneades Argument Evaluation Structures into "the **ambiguity blocking no
  team defeat** variants of Defeasible Logic," at worst-case **quadratic** translation cost, yielding
  polynomial-time acceptability. So TFL-Verify can offer Carneades-style **proof standards and burden
  of proof** *inside* a defeasible-logic engine, without adopting an argumentation framework.

**Honest qualification on the linear-time headline.** Maher's theorem is stated for *propositional*
defeasible logic; the paper itself says full first-order DL "has a recursively enumerable inference
problem," that the variants "also have linear complexity… **although the details will require careful
verification**," and that **well-founded** defeasible logic "can be expected to have **quadratic**
complexity." State which variant the engine implements; do not cite "linear" unqualified.

**On the "is defeasible logic a special case?" question — be precise.** What is *proven* is that
defeasible logic **has an argumentation semantics** (Governatori, Maher, Antoniou & Billington,
*J. Logic and Computation* 14(5):675–702, 2004; PRICAI 2000 version DOI 10.1007/3-540-44533-1_7), that
it embeds into logic programming (Antoniou et al., *TPLP* 6(6):703–735, 2006), and that its variants
are ordered by an inclusion theorem (Billington et al., *ACM TOCL* 12(1):1–27, 2010). What is **not**
established by anything verified here is that defeasible logic "is just" ASPIC+ with particular
parameters. They are different in kind — defeasible logic is *proof-theoretic* (tags, bottom-up,
linear); ASPIC+/ABA are *semantic* (build all arguments, build the defeat graph, apply an extension
semantics). Do not assert a collapse.

**Take these three things from the argumentation literature without adopting the formalism:**
1. **Rationality postulates** (Caminada & Amgoud, *AIJ* 171(5-6):286–310, 2007) — closure under strict
   rules, direct and indirect consistency. Excellent stated-and-checked properties for a *verified*
   engine, and a principled correctness criterion beyond "the oracle is green."
2. **Carneades' proof standards and burden of proof** (Gordon, Prakken & Walton, *AIJ*
   171(10-15):875–896, 2007). Given that reversing the evidentiary burden onto claimants was the
   central injustice in Robodebt, this is the most policy-relevant idea in the whole literature for
   this project.
3. **ASPIC+'s three attack types as a design checklist** — can a claimant attack a premise
   (undermining), a conclusion (rebutting), and a rule's applicability (undercutting)? All three are
   real contest moves; a layer supporting only rebutting is under-powered.

**Caveat on the qualification:** restricted to *grounded* semantics, ASPIC+/ABA are polynomial and the
gap narrows to linear-vs-polynomial. But grounded is the most sceptical and least expressive choice,
which removes most of the reason to prefer ASPIC+ — and the Nute lineage already offers the same
expressiveness dial (ambiguity-blocking vs. propagating, team defeat, related by the inclusion
theorem) at linear cost.

---

# Cross-cutting implications for TFL-Verify

1. **Two-tier certificate, not one.** Robodebt Rec 17.1, Yurrita et al. (2025) and CJEU C-203/22 all
   converge on the same architecture: a short, selective, contrastive, premise-naming surface for the
   affected person, on top of a complete machine-checkable derivation for advocates, auditors, courts
   and supervisory authorities. Shipping only the full trace is the failure mode the evidence
   predicts.
2. **Tree-shaped traces, natural-language steps.** PTIME to minimise (Alrabbaa et al.), subjectively
   preferred, and the format that let the DL group widen study eligibility to non-logicians.
3. **Measure error detection, not understanding.** Poursabzi-Sangdeh et al. (N = 3,800, pre-registered)
   found transparency *improved simulation but degraded error detection*. Contestation is
   error detection. Self-report and objective performance came apart in both this and the Alrabbaa
   studies.
4. **Legal framing: lead with CJEU C-203/22, not the 2017 "right to explanation" debate.** The Court's
   holding — that the required content of an explanation is derived from *what contestation requires*
   — is a functional standard a proof trace is well suited to meet. And **do not claim Art 22(3) gives
   a direct contest right for statutory public-sector decisions**; its safeguards are scoped to
   Art 22(2)(a) and (c), while government eligibility decisions typically rest on (b).
5. **Engage two direct challenges head-on rather than ignoring them.** Wachter, Mittelstadt & Russell:
   the three aims of explanation "none hinge on explaining the internal logic." Yang, Chen & Sattler
   (arXiv:2601.12444): "logical complexity, rather than representation format… is the dominant factor
   shaping LLM performance" — which weakens any argument for TFL notation grounded in LLM ergonomics.
   The defensible grounds for the notation are decidability, checkability, and human readability of
   the certificate.
6. **A 2026 systematic review independently states the project's thesis as an open challenge.**
   Li, Garijo & Poveda-Villalón: "Hybrid Neuro-Symbolic Reasoning: Develop systems that combine
   LLM-generated suggestions with logic validation to enhance logical consistency and reduce
   hallucinations." Across their reviewed corpus, validation of LLM-authored ontologies is
   overwhelmingly string similarity + human review + syntax linting; **almost nobody runs the
   reasoner.** That is the hole TFL-Verify fills, said by a third party.
7. **Read arXiv:2512.12109 (FAccT 2026) before writing related work.** Sunny & Sivan-Sevilla's
   CalFresh accountability framework is the nearest neighbour found anywhere in this sweep — same
   pipeline, same domain, same motivation. Differentiation is available (decidable fragment vs.
   unspecified solver; emitting a certificate vs. detecting inconsistency; a *verified* checker) but
   it must be argued, not assumed.

---

# Verification caveats

Every citation above was checked against Crossref, the arXiv API, a fetched publisher page, or a
fetched PDF of the work itself. Search-engine summary prose was treated as an untrusted lead
throughout. The exceptions and residual uncertainties are listed here.

## Errors caught in summariser output during this sweep

- **A search summary asserted that arXiv:2206.07711 was "In the Head of the Beholder: Comparing
  Different Proof Representations."** It is not. Fetching the arXiv page showed 2206.07711 is
  "On the Eve of True Explainability for OWL Ontologies: Description Logic Proofs with Evee and
  Evonne" by Alrabbaa, Borgwardt, Friese, Koopmann, Méndez & Popovič. The Beholder paper was then
  verified separately via Crossref (DOI 10.1007/978-3-031-21541-4_14) and its PDF read directly.
  **Both papers are real; the summariser conflated their identifiers.** This is exactly the failure
  mode the previous sweep on this project caught, and it recurred here.
- **A search summary gave SNOMED International's membership as "51 member countries/territories as of
  2025" and SNOMED CT as "more than 350,000 active concepts."** The organisation's own pages say
  **53 Members** and **"more than 360,000 concepts."** The summariser figures were discarded.
- **GLaMoR "95% accuracy, 20× faster than classical reasoners"** appeared only in a search summary;
  the arXiv abstract text retrieved was truncated before those figures. **Reported as UNVERIFIED.**
  The paper itself (arXiv:2504.19023, Mücke & Scherp) is verified as existing.

## Part A — unverified or partially verified

1. **ELK JAR (2014) experimental numbers.** The *Journal of Automated Reasoning* paper's metadata is
   Crossref-verified (53(1):1–61). Its open PDF at `elk.semanticweb.org` returned HTML, and the
   Springer page 303-redirects to an auth endpoint. **All ELK performance figures reported here come
   from the ORE 2012 workshop paper and the 2012 technical report, whose PDFs were read in full** —
   not from the journal article. The "4–15 second" range spans the TR ("as little as 5 seconds"), the
   ORE paper ("6.2 s" classification / "under 15 seconds" load+classify) and the project page ("less
   than 4 seconds on a modern laptop"); the last is a project-website claim, not peer-reviewed.
2. **Snorocket citation.** Lawley & Bousquet, AOW 2010, CRPIT vol. 122, pp. 45–49 is **not indexed in
   Crossref**. It was taken from reference [9] of the peer-reviewed ORE 2012 paper. Reliable, but
   secondary.
3. **"Laconic and Precise Justifications in OWL" best-paper award at ISWC 2008** — reported by
   secondary sources only; **not verified**. The citation itself is Crossref-verified.
4. **NHS Digital SCCI0034 page** returned HTTP 403 to automated fetch. The mandate details were taken
   from the **NHS Standards Directory** page instead, which was fetched successfully. The two should
   agree, but only one was read.
5. **SNOMED CT Logic Profile / OWL 2 EL conformance.** `confluence.ihtsdotools.org` refused the
   connection (ECONNREFUSED). The claim that SNOMED CT's logic profile is a **subset of OWL 2 EL**
   appeared only in a search summary and is therefore **UNVERIFIED here**. It is strongly implied by
   ELK (an OWL EL reasoner) being SNOMED International's production default, but that is inference,
   not a read source. Check before asserting.
6. **ORE 2015 journal version.** The CEUR/SSWS 2015 PDF was read in full and all figures come from it.
   A *Journal of Automated Reasoning* version is referred to in secondary sources but was **not
   located or verified**.
7. **Minimal-tree-proof complexity table (Table 2 of arXiv:2004.08311).** The table's cell alignment
   was garbled by `pdftotext`, so individual cells are reported with low confidence. The **introduction's
   prose statement is unambiguous and is what is quoted**: general minimal proofs are NP-complete even
   for polynomial derivers with unary coding; NExpTime-complete for exponential derivers with binary
   coding; "for tree-shaped proofs the complexity is considerably lower… a Dijkstra-like greedy
   algorithm to compute minimal tree-shaped proofs."
8. **Beholder per-study participant counts.** n = 173 for Study III is stated in the paper's text
   twice and is solid. The other counts (16 / 101 / 108) were **derived by summing Table 2's
   male/female/non-binary columns**, since the table's "# participants" header spans those columns.
   The Study III sum (102 + 71 = 173) matches the text, which validates the reading — but treat the
   others as derived, not quoted.
9. **arXiv:2512.12109 (Sunny & Sivan-Sevilla).** Only the **abstract** was read; the full PDF was not.
   No quantitative results are stated in the abstract, and the abstract refers to the work as "this
   thesis." **Do not characterise its results from this document.**
10. **Li/Garijo/Poveda-Villalón systematic review — internal inconsistency.** The abstract of the
    preprint says "**We analyze 30 different papers**"; § RQ3 of the same preprint says "**Out of the 41
    reviewed studies**." Both figures are quoted verbatim from the same document. Likely a
    version/edit mismatch between the preprint and the published SAGE version (DOI
    10.1177/22104968261465514, vol. 17 iss. 4, 2026). **Resolve against the published version before
    citing a paper count.**
11. **"Pushing the EL Envelope" Theorem 11** (EL^{≤1}, at-most restrictions). The theorem statement
    line was located but its complexity class was cut off at a page break in the extracted text; the
    surrounding prose establishes an ExpTime upper bound. Reported as "stated Thm 11" without a
    committed class.

## Part B — unverified or partially verified

12. **EU AI Act Article 86 text.** EUR-Lex direct fetch failed in every attempted form. The quoted
    text comes from **two independent OJ mirrors that agree verbatim** (artificialintelligenceact.eu,
    ai-act-law.eu), with a third agreeing in substance. The Regulation's title, adoption date
    (13 June 2024) and OJ publication date (12 July 2024) *were* verified on EUR-Lex. High confidence,
    but not EUR-Lex-confirmed.
13. **SyRI judgment.** `uitspraken.rechtspraak.nl` returned only a JavaScript shell. Court, date
    (5 Feb 2020), case number (C-09-550982), ECLI **NL:RBDHA:2020:1878** (English version) and the
    Art 8 ECHR holding were verified via the ESCR-Net case-law database, corroborated by the JuLIA
    database and *Human Rights Law Review* 22(2) ngac010. **No verbatim quotation from the judgment is
    given anywhere in this document.** The Dutch-original identifier commonly cited as
    ECLI:NL:RBDHA:2020:865 was **not verified** and is not relied on.
14. **Robodebt Royal Commission Report.** The live host refused all automated requests. Title,
    Commissioner, presentation date (7 July 2023), three-volume structure, the 11 July 2023 corrected
    edition, and the **verbatim text of Recommendations 10.1, 17.1 and 17.2** were verified from an
    **Internet Archive snapshot of the Commission's own page**, and independently corroborated by the
    Government Response PDF (pmc.gov.au, ISBN 978-1-925365-36-8), which was downloaded and read and
    which quotes the Report at pp. xxvii and xxix. **The Report PDF itself was not opened.**
    **Discrepancy flagged:** the Commission's page lists **57 recommendations**; the Government
    Response says **56**. Unresolved. Do not cite a recommendation count without checking the Report.
15. **Michigan MiDAS "93% erroneous."** Verified only to Gipson Rankin, 98 N.Y.U. L. Rev. Online 225
    (2023), whose footnote for that figure is to press coverage. **The Michigan Office of the Auditor
    General report itself was not obtained.** The commonly repeated "22,000 determinations reviewed,
    93% not fraud" framing comes from press coverage and is **not** reported here as verified.
16. **Cahoo v. SAS Analytics.** Case name, court, docket (18-1295/1296), date (3 Jan 2019), reporter
    cite (912 F.3d 887) and panel verified via **CourtListener**. Justia and other hosts returned 403.
    The due-process holding is quoted from **Gipson Rankin's characterisation, not the slip opinion**.
17. **Governatori et al., "Argumentation Semantics for Defeasible Logic," *J. Logic and Computation*
    14(5):675–702 (2004).** Crossref verifies title, venue, volume, pages and year, but its **author
    metadata lists only Governatori**. The four-author attribution (Governatori, Maher, Antoniou,
    Billington) is carried over from the Crossref-verified PRICAI 2000 version
    (DOI 10.1007/3-540-44533-1_7) and standard citation practice. **Confirm the author list against
    the published article before citing.**
18. **Dung-semantics complexity table.** Transcribed from a fetched PDF whose column alignment
    `pdftotext` partially garbled in the ideal/preferred/semi-stable/stage block. The values reported
    (Skept_pr = Π₂ᴾ-c; Cred_sst = Cred_stg = Σ₂ᴾ-c; Skept_sst = Skept_stg = Π₂ᴾ-c; ideal = Θ₂ᴾ-c) are
    the standard values in the literature and are consistent with the chapter's own attribution text,
    but the **individual cell reading should be confirmed against the published chapter** before the
    table is reproduced in a paper.
19. **Deployed legal argumentation / rules-as-code systems.** The audit table in § B.1.6 rests on
    primary sources (procurement registers, project READMEs, GitHub API, operators' own pages), and
    each row's verdict should be read with its evidence. Specific items that could **NOT** be
    verified and must not be repeated:
    - **HMRC's CEST / Employment Status Indicator being built on OPA** — widely repeated (Wikipedia,
      consultancies), but HMRC's own CEST IT test-plan PDF was downloaded and grepped: **zero hits**
      for "Oracle", "OPA", "Policy Automation", "rulebase". **Unverified.**
    - **US IRS, Australian DIAC, and CNAF as OPA customers** — no `.gov` / `.gov.au` / CNAF primary
      source; only consultancy marketing. **Unverified.**
    - Oracle's "hundreds of millions of people" and "halve the rate of queries and appeals" — vendor
      datasheet, no methodology. **Not independently verifiable.**
    - **OpenFisca in production in Senegal** — traced only to a 2016 OGP hackathon and a country-model
      repo. **Unverified.**
    - **OpenFisca NZ Rates Rebate as "first service in production outside Europe"** — *contradicted*
      by the NZ government's own Service Innovation Lab page, which says progress "awaits a decision…
      whether to move this into BAU."
    - **Mlang actually replacing DGFiP's production M compiler** — Inria's 2021 page states intent and
      a two-year expectation; no confirmation found.
    - The **Regorous/ABCB** material is quoted from an Internet Archive snapshot (2021-03-28); the
      live URL 404s.
20. **Lam, Governatori & Riveret, "On ASPIC⁺ and Defeasible Logic" (COMMA 2016) — full text NOT
    obtained. This is the single biggest gap for the "is DL a special case of ASPIC+?" question.**
    Closed access at IOS Press; Unpaywall reports no repository copy; Semantic Scholar's abstract is
    elided by the publisher; three plausible filenames probed on governatori.net all 404'd. **Only the
    abstract is verified**, and it says "a linkage between *an* instantiation of ASPIC⁺ and *a* DL
    variant" — direction, variant, and whether it is equivalence or inclusion are all **unknown**.
    Obtain this paper before making any claim about the DL/ASPIC+ relationship.
21. **Governatori et al., JLC 2004, full text not obtained.** Unpaywall reports it OA at an OUP URL,
    but OUP returns an HTML interstitial to non-browser clients. Abstract verified twice (Huddersfield
    research portal; OUP abstract page). The "first ambiguity blocking Dung-like argumentation system"
    line is from the **abstract**, and is reported above explicitly as a hint, not a proof.
22. **Author order for Governatori et al., JLC 2004.** Crossref lists only "G. Governatori".
    Governatori's own page orders it Governatori, Maher, **Billington, Antoniou**; OUP's article page
    and dblp/Semantic Scholar give Governatori, Maher, **Antoniou, Billington**. The latter is used
    (two independent sources, one the publisher). **Confirm before citing.**
23. **`governatori.net` presents an untrusted TLS certificate**, so WebFetch refuses it and the
    sub-sweep used `curl -sk` — those page contents are **unauthenticated in transit**. The two claims
    taken from it are independently corroborated by Crossref.
24. **ABA+ open cells.** The Lehtonen et al. table reproduced above contains genuine "?" entries
    (ABA+ skeptical admissible and complete, ABA+ credulous complete) — these are **open in the source
    paper**, not gaps in this sweep. Do not fill them in.
25. **Čyras & Toni ABA+ (KR 2016, pp. 553–556)** is a 4-page short paper; the extended preprint
    arXiv:1610.03024 states on its own abs page that it is "a preprint of a manuscript under review."
    The **complexity results** cited above are from Lehtonen et al. (JAIR 2021), which is verified
    open access — not from the ABA+ paper itself.
26. **ABA+ (Čyras & Toni).** The lead sweep's own Crossref searches failed to surface the canonical
    ABA+ paper; the sub-sweep located it as a **4-page KR 2016 short paper (pp. 553–556, dblp
    `conf/kr/CyrasT16`)**, which explains why bibliographic search was unreliable. **Resolved — see
    caveats 24 and 25 for the residual limits.** The complexity figures used above come from Lehtonen
    et al. (JAIR 2021), not from the ABA+ paper.
27. **Legal and HCI papers verified at metadata level only.** For the Part B.2 corpus, bibliographic
    details were verified against Crossref and/or publisher/repository pages, but the *arguments* as
    characterised come from verified abstracts and publisher summaries, not full-text reading. The
    works read in full or substantial part — and therefore quoted verbatim with confidence — are:
    **Lage et al. (HCOMP 2019)**, **Poursabzi-Sangdeh et al. (CHI 2021)**, **Wachter/Mittelstadt/
    Russell (Harvard JOLT 2018)**, the **Dutch parliamentary inquiry report**, and the **Australian
    Government Response**. Five of the Part B.2 citations (Lage, Poursabzi-Sangdeh, Hirsch, Almada,
    Henin & Le Métayer) were **independently re-verified against Crossref by the lead sweep** and
    matched exactly on title, authors, venue, pages and year.
28. **Minor page-range gaps.** Kaminski & Urban end page (2047 vs. 2048 — sources differ) unverified;
    cite as "121 Colum. L. Rev. 1957 (2021)." Cofone & Strandburg end page not shown; cite as
    "64 McGill L.J. 623 (2019)." Crossref's stored title for Sarra (2020) is truncated mid-phrase.
29. **Secondary XAI format-comparison studies** (arXiv:2408.17401, arXiv:2204.10152, arXiv:2309.08438,
    a FAccT 2024 counterfactual-type study) surfaced as leads and were confirmed to exist, but their
    authors, venues and findings were **not** verified. None of their results are reported as
    established anywhere above.

## Scope limits of this sweep

- Part A's LLM-and-ontology section is a **snapshot, not a systematic review** — that field is moving
  fast and the sweep leaned on one 2026 systematic review plus four individually verified papers.
- No **quantitative** claim about SNOMED CT's clinical or economic benefit was sought or verified;
  the Q2 evidence is about scale, mandate, and reasoning performance, not health outcomes.
- The recommendation in Q3 rests on complexity and certificate-readability. It does **not** rest on
  any empirical comparison of defeasible logic vs. ASPIC+ certificates with human subjects, because
  **no such study was found** — consistent with the broader finding that no one has tested logical
  proof traces on laypeople in a contestation setting.
