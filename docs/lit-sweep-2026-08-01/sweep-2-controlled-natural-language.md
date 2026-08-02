# Sweep 2 — Controlled Natural Languages vs. TFL-Verify's differentiator

**Date:** 2026-08-01
**Scope:** Adversarial existential check on TFL-Verify's central claim ("deterministic
back-rendering of a formal representation into English enables a non-logician to audit an
automated formalization") against the controlled-natural-language (CNL) tradition.

**Method note:** every PDF cited below was downloaded and text-extracted locally with
`pdftotext -layout`, and quotations are taken from that extracted text, not from a
summarising model. Bibliographic records were checked against Crossref, the arXiv API, or
the ACL Anthology. Where a search-result summariser made a claim I could not corroborate
from the source, that is recorded in "Verification caveats" and the claim is discarded.

---

## 0. Headline answers

**Q1 — Does ACE (or any CNL) already deliver deterministic formal→English back-rendering
good enough for a non-expert to audit an automated formalization?**

Partly, and this is the single biggest threat to the project's framing. ACE has shipped a
deterministic formal→English renderer since the 2000s: the Attempto Parsing Engine (APE)
generates ACE **paraphrases from the DRS** (the logical form), explicitly so the user can
"either accept the assigned interpretation … or … rephrase the input to obtain another
one" (Fuchs, Kaljurand & Kuhn 2008, §2.8). That is the same audit loop TFL-Verify
proposes. The OWL verbalizer (Kaljurand & Fuchs 2007) extends it to a *reversible*
OWL→ACE→OWL round trip. So "deterministic back-rendering" is **prior art, not novel**.

What is *not* established is the second half of the claim — that this actually enables
correct auditing by non-experts. The strongest human-subject evidence (Kuhn's ontograph
experiments, n=64) measures a **different task**: judging whether a statement is true of a
depicted situation, not whether a formalization matches a source sentence. ACE's own
principal author states in 2018 that the experiment testing whether "a reader of an ACE
text … understand[s] the ACE text as the writer intended" **was never run** ("For lack of
resources I did not do the experiment", Fuchs 2018 §3). The audit-task evaluation gap is
real and unclaimed.

**Q2 — What does TFL have that a CNL does not?**

Three things survive scrutiny, in descending order of strength:

1. **The input-side distinction is real and is recognised in the literature — as the CNL
   field's known weak point.** CNLs restrict what you may *write*; the standard remedy is a
   predictive/look-ahead editor, because (Kuhn 2012, arXiv:1211.3643) "CNLs are easy to
   read but hard to write." PENG's editor "dynamically enforces the grammatical
   restrictions of the CNL via lookahead information while a text is written" (Schwitter,
   COLING 2010). None of that applies when an **LLM**, not a human, produces the text —
   you cannot put a look-ahead editor around a model's output. TFL-Verify's
   "accept free English, refuse out-of-fragment input by parse failure" is the right shape
   for the LLM setting, and the CNL literature has no answer for it because the problem
   post-dates the design.
2. **Decidability.** ACE is undecidable, on the record: "This means that ACE is
   undecidable since already its first-order subset is larger than the above fragment"
   (Fuchs, CNL 2010 §6), and RACE therefore "terminates with a time-out." Caveat: ACE has
   decidable subsets — the OWL-mapped one — so this is an advantage over *full* ACE only.
3. **Surface-structure preservation in the rendering.** ACE's robust paraphrase mode
   *decomposes* the sentence (see §2.4); the mode that preserves relative-clause structure
   is flagged "experimental" with substantial coverage gaps. TFL's claim that the formula
   mirrors the sentence is a genuinely different (and stronger) property than ACE's
   normalising paraphrase — but it must be argued precisely, because ACE gets close.

What does **not** survive: "surface-close formal language readable by non-logicians" as a
novelty claim. Kuhn's survey already places 100 CNLs in that space, and rates ACE N4
("languages with natural sentences") — the second-highest naturalness class.

---

## 1. Tobias Kuhn's survey and the PENS scheme — the map of the field

**Citation (verified, Crossref + ACL Anthology + MIT Press):**
Tobias Kuhn. "A Survey and Classification of Controlled Natural Languages."
*Computational Linguistics* 40(1):121–170, 2014. DOI `10.1162/COLI_a_00168`.
ACL Anthology `J14-1005`. (Also arXiv:1507.01701.)

**Scope (verbatim from abstract):** "A comprehensive survey of existing English-based CNLs
is given, listing and describing **100 languages from 1930 until today**."

**PENS = Precision, Expressiveness, Naturalness, Simplicity**, each on a 1–5 scale, 625
classes total. The anchors: English is `P1 E5 N5 S1`; propositional logic is `P5 E1 N1 S5`.

Definitions that matter for us (verbatim, §3.1 and §3.3):

- **P4, "Deterministically interpretable languages":** "fully formal on the syntactic
  level … Each text in such a language can be deterministically parsed to a formal logic
  representation … but they may be underspecified in the sense that they require certain
  parameters, background axioms, external resources, or heuristics to enable sensible
  deductions."
- **P5, "Languages with fixed semantics":** "fully formal and fully specified on both the
  syntactic and semantic levels. Each text has exactly one meaning … without the help of
  heuristics or external resources."
- **N4, "Languages with natural sentences":** "sentences that can be considered valid
  natural sentences. Speakers of the respective natural language recognize the statements
  as sentences of their language and are able to correctly understand their essence
  **without instructions or training**. … While single sentences have a natural flow, this
  does not scale up to complete texts."
- **N5, "Languages with natural texts":** natural text flow across whole documents.

Kuhn also fixes the CNL definition boundary at naturalness: "We will interpret this in
such a way that it only includes languages of naturalness N3 and higher. Thus, by this
definition, there are no CNLs with N1 or N2."

**Positions relevant to TFL-Verify (verbatim from Table 2 / §4.1):**

| Language | PENS | note |
|---|---|---|
| English | `P1 E5 N5 S1` | anchor |
| **ACE** | **`P4 E3 N4 S3`** | properties F W A (formal, written, academic) |
| PENG, PENG-D, PENG Light | `P5 E3 N4 S3` | *more* precise than ACE |
| Sydney OWL Syntax (SOS) | `P5 E2 N4 S3` | |
| OWL ACE | `P5 E2 N4 S3` | the decidable OWL-mapped ACE subset |
| E2V (Pratt-Hartmann) | `P5 E2 N4 S4` | two-variable fragment |
| **"Sowa's syllogisms"** | **`P5 E1 N4 S5`** | Aristotelian syllogistic in English |
| propositional logic | `P5 E1 N1 S5` | anchor |

**Why ACE is only P4:** "These expressions, however, are underspecified in the sense that
many deductions (e.g., when involving plurals or modal verbs) require external background
axioms that are not fixed by the ACE definition" (§4.1).

**On readability vs. expressiveness:** the survey does *not* assert a clean trade-off
curve. It reports the opposite structural finding — "the CNL classes form one single
cloud, from any perspective, and not two or more disconnected clouds" (§5.1) — and Kuhn
explicitly warns the dimensions are not a ranking: "In theory, more is better for each of
the PENS dimensions, but this does not necessarily [hold] … Having a high PENS score for
expressiveness, for example, just [means more can be expressed]" (§3, condensed). Note
also that PENS treats naturalness and expressiveness as *independent* dimensions ("There
are no strong dependencies between any two dimensions").

**Implication for TFL-Verify.** The survey supplies the coordinate system the paper should
position in. "Sowa's syllogisms" at `P5 E1 N4 S5` is the nearest neighbour to a term
logic: maximal precision, maximal simplicity, natural sentences, *minimal* expressiveness.
TFL's contribution has to be an expressiveness gain over `E1` while holding `P5 N4` — and
that must be argued against ACE at `E3`, not against propositional logic.

---

## 2. Attempto Controlled English (ACE) — the direct competitor

**Primary citation (verified, Crossref DOI `10.1007/978-3-540-85658-0_3`):**
Norbert E. Fuchs, Kaarel Kaljurand, Tobias Kuhn. "Attempto Controlled English for
Knowledge Representation." *Reasoning Web 2008*, LNCS 5224, Springer, pp. 104–124.

### 2.1 What ACE is

A subset of English with a deterministic translation into Discourse Representation
Structures (DRS), "a notational variant of first-order logic" (Kuhn 2014 §4.1). Features
per the survey: "complex noun phrases, plurals, anaphoric references, subordinated
clauses, modality, and questions." Example ACE sentences from the survey:

> A customer owns a card that is invalid or that is damaged.
> Every continent that is not Antarctica contains at least 2 countries.

The DRS can be re-targeted: "into the standard and the clausal forms of first-order logic,
into the TPTP notation, and – with some syntactic restrictions – into the semantic web
languages OWL and SWRL" (Fuchs, CNL 2010 §1).

### 2.2 How ACE handles ambiguity — the three-part mechanism

Verbatim, Fuchs/Kaljurand/Kuhn 2008 §2.8 ("Constraining Ambiguity"):

> To constrain the ambiguity of full natural language, ACE employs three simple means
> – some ambiguous constructs are not part of the language; unambiguous alternatives are
>   available in their place
> – all remaining ambiguous constructs are interpreted deterministically on the basis of a
>   small number of interpretation rules
> – **users can either accept the assigned interpretation — shown for example in the
>   paraphrase generated by APE — or they must rephrase the input to obtain another one**

That third bullet is TFL-Verify's audit loop, published in 2008.

### 2.3 The paraphraser — deterministic formal→English rendering, with examples

APE's output includes "different paraphrases of the input text **derived from its DRS**"
(§3.1). So the rendering is genuinely from the logical form, not a copy of the input.

Worked examples, verbatim from §2.9–§2.11:

*Disambiguating coordination.* Input `A customer inserts a card that is valid and opens an
account.` → paraphrase `A card is valid. A customer inserts the card. The customer opens
an account.` The alternative reading requires repeating the relative pronoun, and yields
`A card is valid. The card opens an account. A customer inserts the card.`

*Adverb attachment.* Input `The customer who inserts a card manually enters a code.` →
paraphrase `There is a customer. The customer enters a code. The customer inserts a card
manually.`

*Anaphora.* Input `A customer enters a card and a code. If the code is valid then
SimpleMat accepts the card. …` → paraphrase `There is a customer X1. The customer X1
enters a card X2 and a code X3. If the code X3 is valid then SimpleMat accepts the card
X2. **If it is false that** the code X3 is valid then SimpleMat rejects the card X2.`
"where the variables X1, X2, and X3 are introduced to clearly show the anaphoric
references."

### 2.4 The crack in it — the paraphrase is normalising, not surface-preserving

This is the most useful adversarial finding for TFL-Verify's positioning.

Look at what the paraphrases above actually do: they **shatter one input sentence into
several atomic sentences**, reorder the clauses, introduce **explicit variables `X1 X2
X3`**, and render negation as the formal-looking **"If it is false that …"**. The output is
a normal form of the DRS, not a mirror of the source sentence.

The APE webservice documentation confirms this is by design, and that the
surface-preserving mode is second-class (verbatim from `ape_webservice.html`):

- `cparaphrase1`: "Output a paraphrase that **uses full sentences instead of relative
  clauses**."
- `cparaphrase2`: "Output a paraphrase that **uses relative clauses instead of full
  sentences**. This paraphrase can currently handle if-then sentences that do not contain
  any modifiers, of-constructions, ditransitive verbs and noun phrase coordination.
  **Note: experimental**."
- `cparaphrase`: "a ``best-effort'' combination of paraphrase1 and paraphrase2."

**So: the robust ACE back-rendering destroys sentence structure; the structure-preserving
one is experimental and cannot handle modifiers, of-constructions, ditransitive verbs, or
NP coordination.** If TFL's rendering preserves the source sentence's shape across its
whole fragment, that is a defensible delta — but it is a delta in *degree of surface
correspondence*, not in the existence of deterministic back-rendering.

An auditor's task differs in the two cases: with ACE they must check a *decomposition*
against the source ("do these four atomic sentences together say what my one sentence
said?"); TFL's pitch is a *one-to-one* check. The former is plausibly the harder
cognitive task, and nobody has measured either.

### 2.5 RACE — the reasoner, and the decidability admission

**Citation (verified):** Norbert E. Fuchs. "First-Order Reasoning for Attempto Controlled
English." *CNL 2010*, LNCS 7175, Springer, pp. 81–94. DOI `10.1007/978-3-642-31175-8_5`.

From the abstract: "RACE is a first-order reasoner for Attempto Controlled English (ACE)
that can show the (in-)consistency of a set of ACE axioms, prove ACE theorems from ACE
axioms and answer ACE queries from ACE axioms. **In each case RACE gives a proof
justification in ACE and full English.**" And §2: "All input is in ACE, all output is in
ACE and full English."

That is a full English-in / English-out verification pipeline, shipped, with
English-language proof justifications. It is a closer competitor to TFL-Verify's product
shape than anything else found in this sweep.

**Decidability (verbatim, §6):**

> Pratt-Hartman and Third [5] investigated several fragments of natural language … and
> found that the fragment containing singular quantified nouns, predicative adjectives,
> copula with/without negation, relative clauses, transitive verbs and reflexive/non-reflexive
> pronouns as anaphors resolved by co-indexing is undecidable.
> **This means that ACE is undecidable** since already its first-order subset is larger
> than the above fragment. However, ACE contains some decidable – though less expressive –
> subsets, for instance the subset defined by its translation into OWL.

And: "Since ACE is not decidable, RACE would not terminate for axioms with an infinite
model. To prevent this, RACE is equipped with a time-out whose limit depends on the size of
the problem." An example set of axioms is stopped "after 10 s."

**Other RACE limits (verbatim §2):** "RACE covers the first-order subset of ACE, that is
all ACE constructs with the exception of imperative sentences, negation-as-failure and the
modal operators *may* and *should*. Currently RACE does not yet cover arithmetic, formulas
and operations on lists, sets and strings." Also: "The reasoner RACE does not have any
world knowledge"; some proofs "require domain-independent linguistic and mathematical
knowledge that cannot be expressed in ACE … To express this knowledge RACE uses auxiliary
first-order and Prolog axioms."

**Implication.** TFL-Verify's decidable-fragment-with-guaranteed-termination story is a
real advantage over full ACE/RACE, and it can be stated with a direct quotation from the
ACE authors. Do not overstate it: OWL-ACE is decidable, and the price ACE pays buys `E3`
expressiveness.

### 2.6 ACE ↔ OWL: the reversible verbalization

**Citation (verified, CEUR):** Kaarel Kaljurand and Norbert E. Fuchs. "Verbalizing OWL in
Attempto Controlled English." *OWLED 2007*, CEUR-WS Vol-258, paper 23.
Predecessor: Kaljurand & Fuchs, "Bidirectional mapping between OWL DL and Attempto
Controlled English," *PPSWR'06*, pp. 179–189 (cited as ref [10] in the OWLED paper;
I did not independently fetch the PPSWR paper — see caveats).

Verbatim from the abstract: "We describe a verbalization of the logical content of OWL
ontologies … in Attempto Controlled English (ACE). **Because ACE is a subset of English,
the verbalization makes OWL ontologies accessible to people with no training in formal
methods.** We conclude that OWL can be verbalized in concise and understandable English
**provided that a certain naming style is adopted** for OWL individuals, classes, and
properties."

Verbatim from §1 on reversibility: "This verbalization is **reversible**, i.e. the readers
of the resulting ACE text can edit it and then convert it back into the normative OWL
representation, and are thus able to communicate with OWL reasoners and other ontology
tools."

**Acknowledged failure modes (§5, "Problems") — verbatim:**

- Naming: "probably the most visible deficiency of the described verbalization is caused by
  the naming conventions used in OWL ontologies. Real-world OWL ontologies can contain
  class names like `FifteenMinutes`, `NAMEDArtery`, `Urgent`, `mirrorImaged` … Such names
  do not lend themselves well to any verbalization scheme."
- Blow-up on sugar: "ACE does not provide such short-hands and the verbalization will
  therefore unravel complex constructions. For instance, `DisjointUnion(person male
  female)` would be verbalized as: *No male is a female. No female is a male. Every person
  is a male or is a female. Everything that is a male or that is a female is a person.*"
  — one axiom becomes four sentences. Same normalisation problem as §2.4.

Implementation: the `owl-verbalizer` tool (github.com/Kaljurand/owl-verbalizer).

---

## 3. Human-subject evidence — what has actually been measured

This section is the one that decides Q1. Three studies exist; **none of them measures the
audit task**.

### 3.1 Kuhn's ontograph experiments (the strongest numbers in the field)

**Citations (both verified):**
- Tobias Kuhn. *Controlled English for Knowledge Representation.* Doctoral thesis, Faculty
  of Economics, Business Administration and IT, University of Zurich, 2010. (Chapter 5.)
- Tobias Kuhn. "The understandability of OWL statements in controlled English."
  *Semantic Web* 4(1):101–115, 2013. DOI `10.3233/sw-2012-0063` (Crossref-verified).
- Method paper: Tobias Kuhn. "How to Evaluate Controlled Natural Languages." *CNL 2009*,
  CEUR Vol-448. arXiv:0907.1251.

**The method.** An "ontograph" is a graphical, language-neutral depiction of a small
situation. Subjects see the ontograph plus statements in the language under test, and
classify each statement **true / false / don't know with respect to the depicted
situation**. This makes the test tool-independent and language-independent.

**Experiment 1** (thesis §5.3): n = 15, "mostly students and not experts in knowledge
representation." Result: "**Overall 83% of the statements have been classified
correctly**", rising to "almost 88%" excluding three statements Kuhn identifies as
borderline. Baseline is 50%.

**Experiment 2** (thesis §5.4), the main one: **n = 64** students/graduates "**with no
higher education in computer science or logic**", average age 22, 42% female / 58% male,
none of whom took part in earlier experiments. Within-subject design, ACE vs. **MLL**
("Manchester-like Language", a stand-in for Manchester OWL Syntax using "the same or very
similar keywords" and its colour codes). Results, verbatim:

- "**91.4% of the statements were classified correctly in the case of ACE and 86.3% in the
  case of MLL.** … This is a considerable and statistically significant difference … One
  also has to consider that these values are already close to the ceiling."
- Learning time: **ACE 13.72 min vs. MLL 18.42 min** — "**MLL required 29% more time to be
  learned**, compared to ACE."
- "only 23% had a perfect score in the main experiment" (vs. 44% in the pre-test run with
  laxer time limits).
- Honest negative result reported by Kuhn: ACE won in all four ontograph series but
  significantly in only one (series 2). "In the case of series 4, the reason is probably
  that Description Logic based languages like MLL can express these statements without
  variables whereas **ACE needs variables, which are somehow borderline cases in terms of
  naturalness**."

**Why this does not settle Q1.** The task is *statement ↔ depicted situation*. TFL-Verify's
audit task is *formalization ↔ source English sentence*. These recruit different
competences: the ontograph task never asks the subject to compare two linguistic objects,
and never exposes them to a formalization that is *subtly wrong in the way an LLM would get
it wrong*. Also note the coverage limit flagged by Fuchs (§3.3 below): Kuhn's statements
"use only a subset of ACE, namely those ACE constructs that can be mapped to … OWL."

### 3.2 Learning to *write* a CNL — the negative result

**Citation (verified, arXiv):** Sandra Williams, Richard Power, Allan Third. "How Easy is
it to Learn a Controlled Natural Language for Building a Knowledge Base?" arXiv:1406.2204
(2014-06-09).

Design: 2 OWL experts + 4 OWL novices learning **OWL Simplified English (OSE)**, observed
by eye-tracking and screen recording, encoding a **naturally occurring** source text
(harder and more realistic than previous studies, which used artificial texts or diagrams).

Verbatim conclusion (§6): "While OWL experts seemed to master OSE quickly and produced
small ontologies with ease. Clearly, **novices experienced difficulties and require more
guidance** such as examples of syntactically correct sentences." Abstract: "We have
identified a number of skills (competencies) required for this difficult task and key
problems that authors face."

**Implication.** This is the *write* direction, and it is where CNLs are weakest — which is
exactly the direction TFL-Verify sidesteps by having a machine, not a human, produce the
formalization, with parse failure as the fragment gate. n = 6 is small; cite it as
indicative, not decisive.

### 3.3 The ACE authors' own admission that the audit experiment was never run

**Citation (verified, Crossref DOI `10.3233/978-1-61499-904-1-75`):** Norbert E. Fuchs.
"Understanding Texts in Attempto Controlled English." *CNL 2018*, Frontiers in Artificial
Intelligence and Applications, IOS Press, pp. 75–84.

This is the most useful single source in the sweep. Fuchs opens by quoting the Attempto
project's own marketing claim and questioning it (verbatim §1):

> We, the authors of Attempto Controlled English (ACE), claim that "once written, ACE texts
> can be read and understood by anybody". **Is our claim really justified?**

He then draws exactly the distinction that matters for TFL-Verify (verbatim §2):

> The word "understanding" used by me in this paper has **another meaning** than the word
> "understanding" as used by Kuhn. While Kuhn addresses the understanding of **the language
> ACE itself**, I investigate **whether and to which extent a reader understands an ACE text
> written by somebody else**.

He designs an experiment for the second sense — author generates true ACE sentences from an
ontograph, reader must pick the matching ontograph from a set — and then (verbatim §3):

> **For lack of resources I did not do the experiment**, but – given the excellent results
> of Kuhn's two experiments – I am highly confident that it would show that the test persons
> can successfully relate a set of true ACE sentences to the correct ontograph.
>
> However, a positive outcome of the experiment should only be considered as a supportive
> argument, but not as a proof, that the reader of an ACE text will understand it in the way
> that the author intended. I have two reasons for this reservation. First and most
> importantly, **the ACE texts associated with ontographs consist only of individual,
> unrelated sentences, they do not constitute one coherent text.** Second, **Kuhn's texts use
> only a subset of ACE, namely those ACE constructs that can be mapped to the semantic web
> language OWL.** Some commonly occurring constructs are missing, for example explicit
> if-then sentences, anaphoric references interrelating sentences, intransitive and
> ditransitive verbs, modifiers of nouns and verbs.

His overall conclusion (abstract): "the correct understanding of an ACE text is possible,
but **requires contributions from both authors and readers**, quasi their cooperation" — he
models it on Grice/Clark conversational grounding.

**This is the citation to build the paper's evaluation section on.** The founder of the
most mature CNL says, in a peer-reviewed venue, that (a) intended-meaning transfer was never
empirically tested, (b) the existing evidence covers only the OWL-expressible subset and
only isolated sentences, and (c) he believes correct understanding needs author-reader
cooperation, which an LLM author cannot provide. TFL-Verify running that experiment — with
LLM-generated formalizations as the stimuli — would be a genuine contribution.

### 3.4 Evaluation methodology taxonomy (useful for designing our own study)

Schwitter, COLING 2010 (§ on evaluation), verbatim:

> **Paraphrase-based experiments** (for example, (Hart et al., 2008)) aim to evaluate the
> understandability of a CNL in a tool-independent way. Human subjects receive a statement
> in CNL and a choice of paraphrases in full natural language, and then have to select the
> correct paraphrase. These experiments scale well with the expressivity of the CNL but it
> is difficult to guarantee that the paraphrases are understood in the intended way.
>
> **Graph-based experiments** (for example, (Kuhn, 2010)) try to overcome the problems of
> paraphrase-based experiments. … a graph-based notation is used to describe a situation
> accompanied with statements in the language to be tested.

Kuhn's own framing (thesis / CNL 2009) splits CNL evaluation into **task-based** and
**paraphrase-based**. Note that neither category is "given a source sentence and a
machine-produced formalization, decide whether they agree" — the taxonomy itself has no slot
for the audit task.

---

## 4. PENG / PENG-ASP (Rolf Schwitter)

**Citations (verified):**
- Rolf Schwitter. "Controlled Natural Languages for Knowledge Representation."
  *COLING 2010: Posters*, pp. 1113–1121. ACL Anthology `C10-2128`.
- Stephen C. Guy and Rolf Schwitter. "The PENG ASP system: architecture, language and
  authoring tool." *Language Resources and Evaluation* 51(1):67–92. Crossref: issued
  2016-02-04, print issue 2017-03. DOI `10.1007/s10579-016-9338-7`.
- Rolf Schwitter. "Controlled Natural Language Processing as Answer Set Programming: an
  Experiment." arXiv:1408.2466. (Springer versions exist: DOI `10.1007/978-3-319-10223-8_2`
  and `10.1007/978-3-642-32612-7_3` for the related CNL/ASP papers.)

**PENS class:** PENG, PENG-D and PENG Light are all `P5 E3 N4 S3` in Kuhn's survey — i.e.
**more precise than ACE** (fixed semantics rather than underspecified DRS) at the same
expressiveness and naturalness.

**Mechanism (verbatim, Schwitter COLING 2010):** "The PENG system provides text- and
menu-based writing support that removes some of the burden of learning and remembering the
constraints of the CNL from the user and **generates a paraphrase that clarifies the
interpretation for each sentence that the user enters**. PENG's text editor **dynamically
enforces the grammatical restrictions of the CNL via lookahead information while a text is
written**. For each word form that the user enters into the editor, a list of options is
generated incrementally by the chart parser to inform the user about how the structure of
the current sentence can be continued."

The same paper describes Sydney OWL Syntax as being based on PENG and providing "a
syntactically bidirectional grammar."

**Relevance to TFL-Verify.** Two points.
1. PENG *also* shows the user a paraphrase clarifying the machine's interpretation. Same
   audit loop again. Back-rendering is a CNL-wide convention, not an ACE quirk.
2. PENG's second mechanism — the look-ahead editor — is the CNL field's answer to the
   "hard to write" problem, and it is **structurally inapplicable to LLM output**. This is
   the cleanest available articulation of why TFL-Verify's input-side story is not already
   solved: the entire CNL tradition assumes a *human at a keyboard who can be steered*.
   Use this in the related-work section.

**PENG-ASP** extends the approach to Answer Set Programming with a bidirectional grammar
(CNL→ASP and ASP→CNL). I verified the LRE bibliographic record via Crossref; **I could not
retrieve the LRE abstract or full text** (Springer paywall/redirect) — see caveats.

---

## 5. Grammatical Framework (Ranta)

**Citation (verified, Crossref):** Aarne Ranta. "Grammatical Framework." *Journal of
Functional Programming* 14(2):145–189, 2004. DOI `10.1017/s0956796803004738`.
(Also: Ranta, "Grammatical Framework: an Interlingual Grammar Formalism," FSMNLP 2019,
DOI `10.18653/v1/w19-3101`; and Ranta, *Type-Theoretical Grammar*, OUP 1995.)

**The relevant architecture:** GF separates an **abstract syntax** (a language-neutral,
type-theoretic representation of meaning) from multiple **concrete syntaxes** (each a
reversible mapping from abstract trees to surface strings in one language). Because
concrete syntaxes are declarative and reversible, GF gets **parsing and linearization from
the same grammar** — linearization *is* deterministic back-rendering, by construction, in
every language the grammar covers.

**Applied to ACE — verified, arXiv:1303.4293:** Kaarel Kaljurand and Tobias Kuhn. "A
Multilingual Semantic Wiki Based on Attempto Controlled English and Grammatical Framework."
Verbatim from the abstract: "We describe a semantic wiki system with an underlying
controlled natural language grammar implemented in Grammatical Framework (GF). The grammar
restricts the wiki content to a well-defined subset of Attempto Controlled English (ACE),
and facilitates a **precise bidirectional automatic translation** between ACE and language
fragments of a number of other natural languages … Additionally, our approach allows for
automatic translation into the Web Ontology Language (OWL), which enables automatic
reasoning over the wiki content."

**Implication — and this is the second-biggest threat.** GF makes "deterministic
formal→English rendering" a *generic, well-understood engineering property* of any grammar
written in the formalism, and generalises it to n languages for free. If TFL-Verify claims
back-rendering as an architectural novelty, a GF-literate reviewer will say: this is what
linearization from a reversible concrete syntax has always done. **The defensible claim is
therefore not "we can render back" but "the fragment we render back from is (a) reachable
from free English by an LLM, (b) decidable, and (c) mapped one-to-one onto the source
sentence's surface structure."** Frame the contribution as the *choice of fragment* and the
*audit evaluation*, not the rendering mechanism.

---

## 6. OWL verbalization more broadly

Beyond Kaljurand & Fuchs (§2.6), the Open University group is the main line.

**Citation (verified, ACL Anthology `C10-2116`):** Richard Power and Allan Third.
"Expressing OWL axioms by English sentences: dubious in theory, feasible in practice."
*COLING 2010: Posters*, pp. 1006–1013.

Verbatim from the abstract: "Current approaches to this task assume that axioms in OWL can
be mapped to sentences in English. We examine **three potential problems with this approach
(concerning logical sophistication, information structure, and size)**, and show that
although these could in theory lead to insuperable difficulties, **in practice they seldom
arise, because ontology developers use OWL in ways that favour a transparent mapping**. This
result is evidenced by an analysis of patterns from a corpus of **over 600,000 axioms in
about 200 ontologies**."

**This is a direct, quantified, adversarial hit on TFL-Verify's premise.** Its finding is
that the axiom↔sentence correspondence, *even for a formalism as un-English as description
logic*, is empirically transparent on real data. The title concedes the theory is "dubious"
— the theoretical worry is real and TFL's surface-closeness argument is the principled
answer to it — but the empirical result blunts the practical urgency.

**Other verified entries in this line:**
- Robert Stevens, James Malone, Sandra Williams, Richard Power, Allan Third. "Automating
  generation of textual class definitions from OWL to English." *Journal of Biomedical
  Semantics* 2(Suppl 2):S5, 2011. DOI `10.1186/2041-1480-2-s2-s5` (Crossref-verified).
- Sandra Williams, Allan Third, Richard Power. "Levels of organisation in ontology
  verbalisation." *ENLG 2011* (13th European Workshop on Natural Language Generation),
  Nancy. — **partially verified**, see caveats.
- Richard Power. "OWL Simplified English: a finite-state language for ontology editing."
  *CNL 2012*, LNCS, pp. 44–60. — verified via the reference list of arXiv:1406.2204 and the
  Springer listing (DOI `10.1007/978-3-642-32612-7_4`).
- Kuhn's survey also records the wider ecosystem: Rabbit (Ordnance Survey), CLOnE, SQUALL,
  Sydney OWL Syntax, DL-English, Lite Natural Language, Quelo, Gellish English.

**Pattern across this literature:** verbalization systems are *generation* systems (formal →
readable English) and are evaluated for **fluency, organisation, and comprehension** — never
for whether a reader can detect a *mismatch* between the verbalization and an original
natural-language source. There is no original source; the ontology is the ground truth. That
is structurally why the audit-task evaluation does not exist in this literature: **the audit
task only becomes meaningful once a machine translates *from* free English, which is
precisely the LLM setting.** This is the strongest single argument for TFL-Verify's
evaluation being novel, and it should be stated in exactly these terms.

---

## 7. LLMs × CNL, 2022–2026 — a near-empty intersection

I searched the arXiv API for `all:"Attempto Controlled English"` (16 hits, **none after
2020**), for `abs:"controlled natural language" AND abs:"autoformalization"` (**1 hit**),
and `all:"controlled natural language" AND all:"large language model"` (5 hits, mostly
irrelevant). Web and Semantic Scholar searches for LLM×ACE returned essentially nothing.

**Verified work at the intersection:**

- **Merlin Carl.** "Improving the Diproche CNL through Autoformalization via Large Language
  Models." arXiv:2303.17513 (v1 2023-03-12, v3 2024-04-10). Abstract verbatim: "The
  Diproche system is an automated proof checker for texts written in a controlled fragment
  of German, designed for didactical applications … The first version of the system used a
  controlled natural language for which a Prolog formalization routine was written. In this
  paper, we explore the possibility of **prompting large language models for
  autoformalization in the context of Diproche**, with encouraging first results." — This is
  the closest published analogue to TFL-Verify's architecture: LLM produces CNL, a
  deterministic checker consumes it. German, didactic, proof-checking; no back-rendering
  audit and no human study.
- **Grazia Garzo and Alessandro Palumbo.** "Human-in-the-Loop: Legal Knowledge Formalization
  in Attempto Controlled English." *2025 13th International Symposium on Digital Forensics
  and Security (ISDFS)*, 2025-04-24. DOI `10.1109/isdfs65363.2025.11011971`
  (Crossref-verified; IEEE Xplore doc 11011971). — Bibliographic record verified; **full
  text not retrieved** (HAL blocked by an Anubis challenge, IEEE paywalled), so no claims
  about its method or results are made here. See caveats.

**Adjacent (not CNL, but competing for the same problem):**

- **Bethel Hall, William Eiers.** "Neurosymbolic Auditing of Natural-Language Software
  Requirements." arXiv:2605.13817 (2026-05-13). Verified abstract: LLMs + SMT audit
  requirements; ambiguity is detected because "requirements that admit multiple plausible
  interpretations produce SMT-inequivalent formalizations, and **bidirectional SMT
  equivalence checking** turns this disagreement into a solver-checkable test"; SMT
  counterexamples raise verified accuracy "from 55.4% to 98.5%" on a hemodialysis QA
  benchmark. **This is a rival answer to the same question TFL-Verify asks — "is this
  formalization right?" — that removes the human from the loop entirely** by using
  stochastic self-disagreement plus a solver instead of human-readable rendering. It is the
  most serious non-CNL threat found. (See caveats: a search summariser attributed a
  round-trip *re-verbalization for human audit* to this paper; the abstract does not support
  that and the claim is discarded.)
- **Ha Thanh Nguyen et al.** "GDPR Auto-Formalization with AI Agents and Human
  Verification." arXiv:2604.14607 (2026-04-16). Verified abstract: multi-agent LLM
  formalization of GDPR provisions "coupled with independent verification modules which
  include **human reviewers' assessment of representational, logical, and legal
  correctness**." Concludes "structured verification and targeted human oversight are
  essential for reliable legal formalization." — Human-audit-of-formalization *as a
  process*, but no controlled measurement of whether non-experts can do it, and no
  deterministic back-rendering.
- **Ke Weng et al.** "Autoformalization in the Era of Large Language Models: A Survey."
  arXiv:2505.23486 (2025-05-29). The field-level survey to position against; it frames
  autoformalization as a route to "enhancing the verifiability of LLM-generated outputs."

**Reading of this gap.** Two interpretations, and the paper should address both:
(a) *opportunity* — nobody has connected mature CNL back-rendering to LLM formalization,
and TFL-Verify does; (b) *warning* — the CNL community has been quiet since ~2020 and the
autoformalization community went straight to Lean/SMT without passing through CNL, which
may mean the field judged human-readable intermediate representations to be the wrong bet.
Interpretation (b) is the reviewer objection to pre-empt: answer it with the auditability
argument (Lean and SMT formalizations are *not* auditable by the domain expert who owns the
source sentence) and with the §6 observation that the audit task only exists once you
translate from free English.

---

## 8. Consolidated comparison against TFL-Verify's pitch

| TFL-Verify claim | CNL status | Verdict |
|---|---|---|
| Deterministic formal→English rendering | ACE (APE paraphrases, since ≤2008), PENG, OWL verbalizers, GF linearization | **Not novel.** Drop or heavily qualify. |
| Rendering is faithful to the logical form | Yes — APE renders from the DRS, and OWL→ACE is reversible | **Not novel.** |
| Rendering mirrors the *source sentence's structure* | ACE's robust mode decomposes into atomic sentences + variables; the relative-clause-preserving mode is "experimental" with named coverage gaps | **Defensible delta**, if TFL preserves structure across its whole fragment. Must be demonstrated, not asserted. |
| Non-logician can audit the formalization | Never measured, for any CNL. Kuhn measured statement-vs-picture (n=64, ACE 91.4%); Fuchs 2018 explicitly did not run the intended-meaning experiment | **Genuine open gap. This is the contribution.** |
| Accepts free English; refuses out-of-fragment by parse failure | CNLs restrict the input instead, and rely on look-ahead editors — inapplicable to LLM output | **Real and defensible.** Best-supported differentiator after the evaluation gap. |
| Decidable fragment, guaranteed termination | ACE is undecidable (authors' own words); RACE times out. But OWL-ACE and E2V are decidable | **Real vs. full ACE**; not vs. all CNLs. |
| Surface-close term logic is unusual | Kuhn's survey already contains "Sowa's syllogisms" at `P5 E1 N4 S5` | Position TFL as *more expressive than E1 while holding P5/N4*. |

**Recommended framing shift.** Move the paper's weight from *"deterministic back-rendering
enables auditable formalization"* (prior art, ACE 2008) to *"the audit task has never been
measured, because until LLMs there was no free-English source to audit against — and here is
the first measurement, on a fragment chosen so that the rendering is one-to-one with the
source sentence and the verdict is decidable."* Every clause of that sentence is defensible
against the sources in this file.

**Related-work sections that must exist:** ACE + APE paraphraser; RACE; Kuhn's PENS survey
(as positioning); Kuhn's ontograph experiments (as the closest prior evaluation, with an
explicit statement of how our task differs); Fuchs 2018 (as the acknowledgment that the gap
is known); GF (as the general theory of reversible rendering); Power & Third 2010 (as the
empirical counterweight); Diproche (as the closest LLM×CNL system).

---

## Verification caveats

**Method.** WebFetch's PDF handling returned only FlateDecode stream noise for every PDF
tried, and its summariser produced confident but content-free answers from that noise. All
PDF evidence in this file was therefore obtained by `curl` + `pdftotext -layout` into
`/tmp/claude-1000/-home-serrecchia-Projects-tfl-verify/6e242743-c826-47dc-b12d-3a20997d2530/scratchpad/pdfs/`
and read directly. Bibliographic records were checked against the Crossref REST API, the
arXiv API, or ACL Anthology landing pages.

**Discarded summariser content (corroboration failed):**

1. A WebSearch summary stated that VERIMED (arXiv:2605.13817) "closes the loop using SMT
   equivalence between the original encoding and a re-formalization of the LLM's own
   informalization" and "re-verbalizes formal specifications back to natural language for
   human audit." **The paper's own abstract, fetched from the arXiv API, says no such
   thing** — it describes bidirectional SMT equivalence checking between *independently
   generated formalizations* of the same requirement, as an ambiguity signal. The
   round-trip-informalization claim is discarded; §7 states only what the abstract
   supports. I did not read the paper's full text.
2. A WebSearch summary attributed to Kuhn's ontograph work the finding that ACE "is more
   accepted by its users" and gave an aggregate framing of the two experiments. The
   participant counts, percentages, and times in §3.1 are instead taken verbatim from the
   extracted text of the thesis PDF. I did **not** verify that the *Semantic Web* 4(1)
   journal version reports identical figures — only that the journal article exists
   (Crossref DOI `10.3233/sw-2012-0063`). If a number is cited in the paper, cite the
   thesis, or re-check the journal version.
3. A WebSearch summary described the Garzo & Palumbo ACE paper as appearing at "the IADIS
   Conference on e-Society in Lisbon, March 2025." **Crossref shows ISDFS 2025
   (13th International Symposium on Digital Forensics and Security), 2025-04-24.** The
   IADIS attribution is discarded.

**UNVERIFIED items:**

- **UNVERIFIED: full text and findings of Garzo & Palumbo, "Human-in-the-Loop: Legal
  Knowledge Formalization in Attempto Controlled English" (ISDFS 2025).** Bibliographic
  record is Crossref-verified (DOI `10.1109/isdfs65363.2025.11011971`). Tried: direct
  `curl` of the HAL PDF (returned an HTML Anubis anti-bot challenge, not a PDF), WebFetch
  of `hal.science/hal-05021540v1` (Anubis access-denied page), IEEE Xplore (paywalled). No
  claim about its method or results is made in this file.
- **UNVERIFIED: abstract and contents of Guy & Schwitter, "The PENG ASP system" (LRE 51(1))**.
  Crossref confirms authors, journal, volume, issue, pages 67–92, DOI. Crossref carries no
  abstract; Springer redirects to an IdP authorization URL. PENG's paraphrase and look-ahead
  mechanisms in §4 are therefore sourced from Schwitter's COLING 2010 paper, which I did
  extract in full.
- **UNVERIFIED: Kaljurand & Fuchs, "Bidirectional mapping between OWL DL and Attempto
  Controlled English," PPSWR'06, pp. 179–189.** Known only from the reference list of the
  OWLED 2007 paper (ref [10]) and from that paper's in-text description. I did not fetch it
  or resolve a DOI.
- **PARTIALLY VERIFIED: Williams, Third & Power, "Levels of organisation in ontology
  verbalisation," ENLG 2011, Nancy.** Title, three authors, venue and year are consistent
  across a WebSearch result and the OU authors' publication records, but Crossref returned
  no match (the query collided with an unrelated 1981 book chapter) and I did not fetch an
  ACL Anthology page or PDF. Page numbers are not known. Re-verify before citing.
- **UNVERIFIED: exact page range of Fuchs, Kaljurand & Kuhn 2008** (given here as 104–124
  from secondary listings). The DOI `10.1007/978-3-540-85658-0_3` and the LNCS 5224 volume
  are Crossref-verified, and the PDF itself was extracted in full (internal page headers run
  from 111 to 117 in the passages quoted, consistent with that range).
- **UNVERIFIED: whether ACE's `cparaphrase*` modes behave as documented.** §2.4 relies on
  the Attempto webservice documentation page as fetched, not on running APE. If the
  "experimental / limited coverage" point becomes load-bearing in the paper, run APE on a
  test set and report measured behaviour.
- **Not attempted:** non-English CNLs, the CNL workshop series proceedings in full,
  SBVR Structured English, and the business-rules CNL lineage (RuleSpeak, SBVR-SE at
  `P3 E4 N4 S2`). These are lower-threat but would round out related work.

**Local artifacts:** extracted text for `kuhn2014cl`, `owled2007_verbalizing`, `cnl2010_race`,
`reasoningweb2008`, `kuhn_thesis`, `kuhn_howto_eval`, `fuchs2018`, `wpt2014`,
`power_third_coling2010`, `schwitter_coling2010` are in the `pdfs/` directory beside this
file, with the source PDFs, for re-checking any quotation.
