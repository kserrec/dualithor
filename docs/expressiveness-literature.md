# Expressiveness literature: what could be added to TFL without escalating

*Written 2026-08-01. Research notes only — no PLAN step, no code implications acted on.*

This document records a literature survey on the expressiveness TFL currently lacks
(defeasibility, deontic content, tense/metric time, modality, comparatives, proportional
quantifiers) and on how far a decidable term/syllogistic logic can be pushed before it
breaks. It exists because the findings would otherwise be lost; **nothing here is a
proposal, and none of it is scheduled work.**

Three sections matter more than the rest:

- **§1** — findings that bear on the engine *as it exists today*, including one live
  correctness threat (§1.2) and one live design question (§1.3).
- **§3** — four ways to silently lose decidability. Read before any design conversation
  about extensions; none of them announces itself in the notation.
- **§5** — verification caveats. Some citations below are flagged as unconfirmed and must
  not be cited in the paper without being checked first.

**Provenance and confidence.** Compiled from five parallel literature sweeps, each
instructed to verify every citation against Crossref, arXiv, ACL Anthology, or a fetched
publisher page, and to flag anything unconfirmed. Several sweeps read primary PDFs in
full (Pratt-Hartmann's handbook chapter, Pratt-Hartmann & Moss 2009, Kruckman & Moss 2021,
Icard & Moss 2014, MacCartney & Manning 2009, Angeli & Manning 2014, Johnson 1989,
Hodkinson–Wolter–Zakharyaschev 2000, Hampson & Kurucz 2015). Two sweeps reported
discarding fabricated content returned by automated PDF summarisers and re-deriving the
material from extracted text; that is why §5 exists and why it should be taken seriously.

---

## 1. Findings about the engine we already have

### 1.1 Our incompleteness outside the categorical fragment is theoretically forced

Our derivation search is incomplete outside the categorical fragment — it can return
`Unknown` on arguments that are in fact valid. **This is not an engineering shortcoming.
It is provably unavoidable for the fragment we occupy.**

> **Pratt-Hartmann, I. & Moss, L. S. (2009). "Logics for the Relational Syllogistic."
> *The Review of Symbolic Logic* 2(4):647–683.** arXiv:0808.0521.

They classify six fragments, in a variable-free term notation structurally close to TFL:

| Fragment | Contents | Strongest possible proof system |
|---|---|---|
| `S` | traditional syllogistic | direct, sound + **complete** |
| `S†` | `S` + negated nouns | direct, sound + **complete** |
| `R` | `S` + transitive verbs | direct, **refutation-complete only** (Thm 4.1) |
| `R*` | `R` + relative clauses in subject NPs | indirect, sound + complete |
| `R†` | `S` + verbs **and** negated nouns | **no sound+complete system exists at all** (Thm 6.12) |
| `R*†` | `R*` + negated nouns | **no sound+complete system exists at all** (Thm 6.12) |

Sequent-validity complexity: `S`, `S†`, `R` are NLOGSPACE-complete; `R*` is co-NP-complete;
`R†` and `R*†` are **EXPTIME-complete** (Thm 6.3, by reduction from modal K with a
universal modality). Corollary 6.4: since PTIME ≠ EXPTIME, no finite rule set for `R†` or
`R*†` is even sound and *refutation*-complete.

**TFL has negative terms natively — the minus sign is the whole notation — and relational
terms. We are at or above the `R†` line.** Theorem 6.12 is therefore a direct statement
about our engine, and it says no finite set of syllogism-like rules can be complete here
*even with unrestricted reductio ad absurdum*.

For the paper: "our derivation search is incomplete outside the categorical fragment"
becomes "the fragment is provably not finitely axiomatizable in syllogistic style;
incompleteness is the theoretically correct posture (Pratt-Hartmann & Moss 2009, Thm 6.12)."

**Related asymmetry worth stating explicitly:** complexity and syllogistic axiomatizability
are independent axes. `TV` (syllogistic + transitive verbs) is NLOGSPACE-complete — as
cheap as the plain syllogistic — yet already admits no finite sound-and-complete syllogistic
rule set, only refutation-completeness. Cheap to decide does not imply finitely
axiomatizable.

### 1.2 Live correctness threat: the TFL⁺ numerical layer

> **Pratt-Hartmann, I. (2008). "On the Computational Complexity of the Numerically Definite
> Syllogistic and Related Logics." *Bulletin of Symbolic Logic* 14(1):1–28.** arXiv:cs/0701039.

Establishes: numerically definite syllogistic is **strongly NP-complete**; numerically
definite *relational* syllogistic is **NEXPTIME-complete**. And — the part that matters to
us — **demonstrates the incompleteness of previously proposed proof systems** for the
numerically definite syllogistic. Published rule sets in this space have been wrong.

Strengthened twice:

> **Pratt-Hartmann, I. (2009). "No Syllogisms for the Numerical Syllogistic." In
> *Languages: From Formal to Natural* (Francez Festschrift), LNCS 5533, Springer,
> pp. 192–203.** Thm 1: no finite set of syllogistic rules whose *indirect* derivation
> relation is sound and complete for N†. Thm 2: same for N.
>
> **Pratt-Hartmann, I. (2013). "The syllogistic with unity." *Journal of Philosophical
> Logic* 42(2):391–407.** No finite rule set is sound and *refutation*-complete for
> `Syl+Num`; for k>0, none is sound and refutation-complete as a direct system for
> `Syl+Num_k`.

**Two consequences.**

1. *Design.* `Sat(Syl+Num)` is only NP-complete — the decision problem is easy. Decide it
   algorithmically (integer / Presburger-style reasoning). Do not search for syllogisms;
   the finite rule set provably does not exist.
2. *Audit.* Our TFL⁺ layer implements Sommers/Englebretsen-derived numerical rules, and we
   have **already found one error of exactly this genus** — the documented Murphree
   condition-(iii) correction (term-matched numerical condition) recorded in the port spec.
   That is one instance of the phenomenon Pratt-Hartmann proves is general. Before the
   paper claims soundness for the numerical layer, our `numerical_decision` should be
   checked against his incompleteness results.

*No bug in our implementation has been demonstrated.* The claim here is narrower: the
literature contains proofs that rule systems of the lineage ours descends from have been
incomplete in this exact fragment, and we have independently hit one such error already.

### 1.3 Live design question: pronoun resolution policy

From Pratt-Hartmann's handbook chapter (full citation in §2.1):

- `Sat(TV+Rel+RA)` is **NEXPTIME-complete** (Thm 15) — RA = *restricted* anaphora, every
  pronoun bound to its **closest** binding-theory-allowed antecedent.
- `Sat(TV+Rel+GA)` is **UNDECIDABLE** (Thm 16) — GA = *general* anaphora, free co-indexing
  subject only to binding theory.

Same sentences, same syntax, **only a different disambiguation policy.** The undecidability
proof is a grid/tiling encoding in six sentences; the essential ingredient is a co-indexed
pronoun reaching back *past an intervening quantifier*, which RA forbids and GA permits.
Witness sentence: "Every artist who admires a beekeeper hates every carpenter who despises
him."

Worse at arity 3: `Sat(DTV+Rel+RA)` is **undecidable even under the restricted policy**
(Thm 17; Pratt-Hartmann & Third 2006). The RA/GA knife-edge exists only for binary verbs.

**Our engine has pronominalization.** What resolution policy does it implement, and is it
pinned? This is a question about existing code, not a hypothetical. It has not been
checked; this document does not answer it.

### 1.4 Where our engine sits on the map

Satisfiability complexity, from the handbook chapter. Fragment tags: `Syl` = classical
syllogistic (no existential import); `TV` = + transitive verbs; `DTV` = + ditransitive
verbs; `+Rel` = + relative clauses; `+Non` = + noun-level negation; `+Num` = + numerical
determiners; `+RA`/`+GA` = restricted / general anaphora.

| Fragment | Satisfiability | Thm |
|---|---|---|
| `Syl` | NLOGSPACE-complete | 3 |
| `TV` | **NLOGSPACE-complete** — *free* | 4 |
| `DTV` | PTIME-complete | 5 |
| `Syl+Non` | NLOGSPACE-complete | 9 |
| `Syl+Rel` | NP-complete | 6 |
| `Syl+Num`, `Syl+Num_k` (all k>0) | NP-complete (translates into C¹) | 12 |
| `TV+Non` | **EXPTIME-complete** | 10 |
| `TV+Rel` | EXPTIME-complete | 7 |
| `TV+Num` | NEXPTIME-complete (translates into C²) | 13 |
| `DTV+Rel` | NEXPTIME-complete | 8 |
| `DTV+Non` | NEXPTIME-complete | 11 |
| `TV+Rel+RA` | NEXPTIME-complete | 15 |
| `TV+Rel+GA` | **UNDECIDABLE** | 16 |
| `DTV+Rel+RA` | **UNDECIDABLE** | 17 |

**Our engine ≈ `TV+Num` with negative terms ≈ the numerically definite relational
syllogistic ≈ NEXPTIME-complete, sitting inside C²** (two-variable first-order logic with
counting). That placement is what makes §3.1 lethal for us specifically.

Two quotable results:

- **Thm 4 — transitive verbs are complexity-free.** Pratt-Hartmann's own gloss: relational
  principles "do not, from a complexity-theoretic point of view, make inference more
  difficult. The apparently greater difficulty of arguments such as (2) as compared to (1)
  is purely psychological." Proof technique: unsatisfiable `TV` sets have a refutation
  using at most two left-branching Barbara chains plus fixed extra steps, so the problem
  reduces to directed-graph reachability. (`Sat(Syl)` reduces to Krom/2-literal-clause SAT;
  `Sat(DTV)` to Horn SAT.)
- **Negated nouns cost exactly as much as relative clauses.** `Syl+Non` is NLOGSPACE but
  `TV+Non` is EXPTIME-complete, matching `TV+Rel`. His phrasing: "the non-construction is,
  in complexity theoretic terms, as harmful as relative clauses." The hardness proof
  reduces from K^U *without* relative clauses, using noun negation to simulate them. **TFL's
  minus sign is not free once relations are in play.**

Open problems he states: tight bounds for `TV+Num_k`, `DTV+Num`, `DTV+Num_k` are unknown;
it is not even known whether `DTV+Num_k` is **decidable** for k>0. Note also that `TV+Num`
has the finite model property (Pratt-Hartmann 2008, Lemma 5) whereas C² does not, so
`TV+Num` is strictly weaker than C² despite matching its complexity.

Ambient bounds: **FO²** is NEXPTIME-complete (Grädel, Kolaitis & Vardi, *BSL* 3(1):53–69,
1997); **C²** is decidable (Grädel, Otto & Rosen, LICS 1997) and NEXPTIME-complete
(Pratt-Hartmann, *JoLLI* 14(3):369–395, 2005).

---

## 2. What could be added without escalating

Ranked by value per unit of effort.

### 2.1 Primary sources for §1 and this section

> **Pratt-Hartmann, I. "Semantic Complexity in Natural Language." Chapter 14 of *The
> Handbook of Contemporary Semantic Theory*, 2nd ed., eds. S. Lappin & C. Fox,
> Wiley-Blackwell.** (Draft dated 19 October 2015; read in full.)
> <https://personalpages.manchester.ac.uk/staff/ian.pratt/papers/nat_lang/hst.pdf>
>
> **Pratt-Hartmann, I. (2004). "Fragments of Language." *Journal of Logic, Language and
> Information* 13:207–223.** DOI 10.1023/B:JLLI.0000024735.97006.5a. Founding paper of the
> program.
>
> **Pratt-Hartmann, I. (2003). "A Two-Variable Fragment of English." *JoLLI* 12(1):13–45.**
> The controlled language E2V; expressive power equal to FO²; NEXPTIME-complete. Source of
> Thms 15/16.
>
> **Pratt-Hartmann, I. & Third, A. (2006). "More Fragments of Language." *Notre Dame
> Journal of Formal Logic* 47(2):151–177.** Ditransitive verbs; source of Thm 17.
> *(Note: Pratt-Hartmann's own bibliography cites this as "Fragments of language: the case
> of ditransitive verbs"; the published title on Project Euclid is "More Fragments of
> Language." Use the published title.)*

### 2.2 Tier 1 — cheap, complete, certificate-producing

**(a) An independent oracle for our own categorical fragment.** `S†` (syllogistic +
negated nouns) has a finite, sound, **complete**, *direct* proof system — no reductio —
at NLOGSPACE (PHM 2009). That is a published, independently derived axiomatization of
approximately the fragment our P/Z conditions decide, from outside the Sommers tradition
entirely.

Given the project's correctness bar, this may be the highest-value item in the survey: we
currently have **one** oracle lineage (the JS reference and the finite-model semantics we
ported from it). `S†` would be a second, independent one. Cheaper still, the decision
procedures behind the complexity bounds are directly implementable as differential oracles:
`Sat(Syl)` → Krom (2-literal clause) satisfiability; `Sat(TV)` → directed-graph
reachability; `Sat(DTV)` → Horn satisfiability.

**(b) Kruckman & Moss's `L₁` — three rules, PTIME, complete.**

> **Kruckman, A. & Moss, L. S. (2021). "Exploring the Landscape of Relational Syllogistic
> Logics." *The Review of Symbolic Logic* 14:728–765.** arXiv:1809.00656.

Parametrizes 2³ = 8 systems by three independent features over a base `L₁`. Syntax:
`terms ::= p | r all x | r some x | x̄`; `sentences ::= all x y | some x y`. Terms nest,
unlike PHM 2009.

| Language | Term formers | Sentence formers | Complexity of consequence |
|---|---|---|---|
| `L₁` | `r all x` | `all x y` | **PTIME** |
| `L₂` | `r all x` | `all`, `some` | PTIME |
| `L₃` | `r all x`, `r some x` | `all x y` | co-NP-complete |
| `L₃.₅` | `r all x`, `r some x` | `all`, `some` | co-NP-complete |
| `L₄` | `r all x`, `x̄` | `all x y` | co-NP-hard (exact class **open**) |
| `L₄.₅` | `r all x`, `x̄` | `all`, `some` | EXPTIME (upper bound only) |
| `L₅` | all three | `all x y` | EXPTIME-complete |
| `L₅.₅` | all three | `all`, `some` | EXPTIME-complete (≈ `R*†`) |

`L₁`'s complete rule set is three rules: `(ax): all x x`; `(barbara): all x y, all y z ⟹
all x z`; `(anti): all x y ⟹ all (r all y) (r all x)`.

**Bounded completeness** (Def. 1.3, Thm 1.5) is the implementation concept: a system is
boundedly complete if there is a PTIME-computable `f` such that Γ ⊨ φ implies Γ ⊢ φ using
only sentences from `f(Γ ∪ {φ})`. Bounded completeness implies completeness *and* PTIME
decidability, and the decision procedure is forward-chaining saturation over that finite
set to fixpoint (≤ 1+|A| rounds) — an OCaml worklist in roughly 150 lines.

Their definition of *syllogistic proof system* is restrictive and worth adopting for
precision: rules may not discharge assumptions (no reductio, no proof by cases), and
premises must be a fixed finite set of templates, not a schema. **Every negative result in
this literature is relative to that definition.**

Open problems they state: exact complexity of `L₄`, `L₄.₅`; proof systems of any kind for
`L₄`, `L₄.₅`, `L₅` in their original syntax.

**(c) Implicative verbs — a finite lexicon lookup, zero logical cost.**

> **Nairn, R., Condoravdi, C. & Karttunen, L. (2006). "Computing relative polarity for
> textual inference." *Proceedings of ICoS-5*, Buxton.** ACL `W06-3907`. *(No page numbers
> available; ICoS-5 is not indexed by dblp. Cite without pages.)*
>
> **Karttunen, L. (2012). "Simple and Phrasal Implicatives." *\*SEM 2012*, pp. 124–131.**
> ACL `S12-1020`. Earlier: **Karttunen, L. (1971). "Implicative verbs." *Language*
> 47(2):340–358.** DOI 10.2307/412084.

Nine implication signatures, with the relation generated by deleting and by inserting the
operator (table from MacCartney & Manning 2009 §6; relation symbols per §2.4 below):

| Class | Signature | DEL | INS | Example |
|---|---|---|---|---|
| implicative (UP) | +/− | ≡ | ≡ | he managed to escape ≡ he escaped |
| | +/∘ | ⊏ | ⊐ | he was forced to sell ⊏ he sold |
| | ∘/− | ⊐ | ⊏ | he was permitted to live ⊐ he lived |
| implicative (DOWN) | −/+ | ^ | ^ | he forgot to pay ^ he paid |
| | −/∘ | \| | \| | he refused to fight \| he fought |
| | ∘/+ | ⌣ | ⌣ | he hesitated to ask ⌣ he asked |
| factive (NON) | +/+ | ⊏ | ⊐ | he admitted that he knew ⊏ he knew |
| | −/− | \| | \| | he pretended he was sick \| he was sick |
| | ∘/∘ | # | # | he wanted to fly # he flew |

Adds no expressive machinery and no decision-procedure cost.

**Factives break, and MacCartney says why** (verbatim, §6): "a fully satisfactory treatment
of the factives (signatures +/+, −/−, and ∘/∘) would require an extension to our present
theory. For example, deleting signature +/+ generates ⊏; yet under negation, this is
projected not as ⊐, but as | (*he didn't admit that he knew* | *he didn't know*). **The
problem arises because the implication carried by a factive is not an entailment, but a
presupposition.**" (Citing van der Sandt, R. A. (1992), "Presupposition Projection as
Anaphora Resolution," *Journal of Semantics* 9(4):333–377.) NatLog treats factives as ⊏
anyway "since in practice this leads to correct predictions more often than not" — an
engineering hack the authors label as such, and **not one a certifying engine should copy.**

Empirical caution: de Marneffe, Manning & Potts, "Did It Happen? The Pragmatic Complexity
of Veridicality Assessment," *Computational Linguistics* 38(2):301–333, find that context
and world knowledge, not lexical signature alone, determine veridicality — the signature
model is systematically incomplete on naturally occurring text.

**(d) Comparative adjectives — with a sharp constraint.**

> **Moss, L. S. (2011). "Syllogistic Logic with Comparative Adjectives." *JoLLI*
> 20(3):397–417.** DOI 10.1007/s10849-011-9137-x.

Comparatives as primitive binary relations, transitive and irreflexive, **no degree scale
and no measure function**; sound and complete axiomatization.

**The constraint, from Moss's own lecture slides:** *"Transitivity should not be treated as
a meaning postulate, since this renders the logic undecidable. Instead, it is a proof
rule."* Reinforced from the other direction — see §3.4.

Adjacent: **Moss, "Intersecting Adjectives in Syllogistic Logic,"** *MoL 11*/LNCS
pp. 223–237 (intersective adjectives, the easy case). Still open everywhere: vagueness, the
positive form ("tall" with no comparison class), degree modification, cross-scale
comparison — Moss's own "more to do" list names vagueness as unaddressed.

*Not* a fit despite appearances: Haruta, Mineshima & Bekki, "Logical Inferences with
Comparatives and Generalized Quantifiers," *ACL 2020 SRW* (arXiv:2005.07954) — CCG →
higher-order degree semantics → Coq. Variables, not surface-close, undecidable with
timeouts. The opposite of our design constraints.

### 2.3 Tier 2 — the legal-text gaps, which turn out to be addressable

These three are the substantive correction to the earlier assumption that defeasibility,
deontic content, and deadlines all require routing to a different engine. They do not.

**(e) Defeasibility — linear time, certificates native.**

> **Maher, M. J. (2001). "Propositional defeasible logic has linear complexity." *Theory
> and Practice of Logic Programming* 1(6):691–711.** **Theorem 5 (verbatim):** "The
> consequences of a defeasible theory D can be computed in O(N) time, where N is the number
> of symbols in D." This includes theories **with** defeaters and a superiority (priority)
> relation, because the transformation to basic form is itself linear (Thm 4).

Lineage: Donald Nute's defeasible logic, in the Antoniou / Billington / Governatori / Maher
formulation. A derivation is literally a finite sequence of tagged literals — `+Δq`, `−Δq`,
`+∂q`, `−∂q` — each licensed by a named inference rule applied to earlier elements. **The
audit trail is free, because the formalism is proof-theoretic by construction.**

Architecturally it is a *control layer over literals*: it decides which conclusions survive
conflict and delegates "does this actually follow?" downward. That composes with our engine
rather than replacing it.

Why the alternatives are worse for us: KLM preferential logics (Kraus, Lehmann & Magidor
1990) give exponential tableau branches with negative minimality checks; rational closure
(Lehmann & Magidor) gives a ranking plus an opaque classical entailment test; mainstream
ASP gives no derivation at all. Defeasible logic is the only one whose native output *is*
the certificate.

Implementations on real statutes: **SPINdle** (Lam & Governatori, RuleML 2009, LNCS
pp. 315–322) and **Regorous** (Governatori & Shek, ICAIL 2013, pp. 245–246). ASP
implementation: Governatori, *KI* 38(1–2):79–88, 2024.

**(f) Deontic content — use input/output logic; do NOT use Standard Deontic Logic.**

SDL is modal **KD** and is decidable — PSPACE-hard for every logic between K and S4
(Ladner, *SIAM J. Comput.* 6(3):467–480, 1977), PSPACE-complete. But it is **not safe on
legal text**:

| Paradox | Origin | The inference | Why it breaks legal text |
|---|---|---|---|
| **Ross's** | Ross, A., "Imperatives and Logic," *Theoria* 7:53–71, 1941 | `Om ⊢ O(m ∨ b)` | A filing duty entails an obligation with a prohibited disjunct |
| **Good Samaritan** | Prior, A. N., "Escapism," 1958 *(see §5)* | `O(h ∧ r) ⊢ Or` | "Must assist a person who has been injured" makes the injury obligatory |
| **Chisholm / CTD** | Chisholm, R., "Contrary-to-Duty Imperatives and Deontic Logic," *Analysis* 24(2):33–36, 1963 | Four sentences, consistent in English, **inconsistent in SDL** | Every penalty/remedy/waiver clause is contrary-to-duty |

Chisholm is fatal for us: "if you fail to file, you must pay a late fee" cannot be
represented in SDL without inconsistency or premise dependence. An engine deriving
`O(file ∨ commit_fraud)` from a filing duty produces exactly the class of wrong verdict
the correctness bar forbids. Overview: Prakken & Sergot, "Contrary-to-duty obligations,"
*Studia Logica* 57(1):91–115, 1996. Variant: Forrester, "Gentle Murder, or the Adverbial
Samaritan," *J. Philosophy* 81(4):193–197, 1984.

**The alternative — input/output logic.** Norms are represented as *pairs*, not
object-language formulas, so the paradoxes are never inherited.

> **Makinson, D. & van der Torre, L. (2000). "Input/Output Logics." *Journal of
> Philosophical Logic* 29(4):383–408**; and (2001) "Constraints for Input/Output Logics,"
> 30(2):155–185.
>
> **Ciabattoni, A. & Rozplokhas, D. (2023). "Streamlining Input/Output Logics with Sequent
> Calculi."** Closes the complexity gap: **coNP-complete for all eight I/O logics**, with a
> polynomial reduction to propositional (un)satisfiability. Completing Sun, X. & Robaldo,
> L. (2017), "On the complexity of input/output logic," *J. Applied Logic* 25:69–88
> (coNP-completeness for OUT₁, OUT₂, OUT₄).

So: one SAT call, sequent derivations as proofs, our engine deciding the atomic TFL
entailments underneath. Ross's paradox is blocked by design (no output weakening in
OUT₁/OUT₃); contrary-to-duty is handled via constrained output.

Other routes, weaker for us: dyadic deontic logic (Hansson, *Noûs* 3(4):373–398, 1969;
Åqvist systems E/F/G) handles CTD but **no decidability/complexity theorem was found** —
see §5. Benzmüller, Farjami & Parent (2021) embed it in Isabelle/HOL, so proofs are
auditable but the host logic is only semi-decidable. Libal & Steen's NAI Suite (JURIX 2019)
uses a *first-order* deontic logic and is likewise semi-decidable.

**(g) Metric time — polynomial, with a human-readable failure certificate.**

> **Dechter, R., Meiri, I. & Pearl, J. (1991). "Temporal constraint networks."
> *Artificial Intelligence* 49:61–95.**

A **Simple Temporal Network (STN)** has time-point variables and constraints of the form
`a ≤ t_j − t_i ≤ b`. Consistency is **polynomial** — negative-cycle detection on the
distance graph (Floyd–Warshall O(n³), or Bellman–Ford; Shostak 1981 for the negative-cycle
criterion). Every deadline phrase is one edge:

- "within 30 days of X" → `0 ≤ t_Y − t_X ≤ 30`
- "prior to the effective date" → `t_X − t_eff ≤ 0`
- "for a period of not less than twelve months" → `t_end − t_start ≥ 12`

**The certificate is free and legible:** a negative cycle *is* a chain of deadlines that
provably cannot all be met. Every SMT solver ships a difference-logic theory solver.

Boundaries: allow *disjunctions* of intervals (TCSP) and it is **NP-hard** (same paper).
Full Allen interval-algebra consistency is **NP-complete** (Allen, *CACM* 26(11):832–843,
1983; Vilain & Kautz, AAAI-86, pp. 377–382 — the Point Algebra is polynomial). The
tractable interval class is **ORD-Horn**: Nebel, B. & Bürckert, H.-J. (1995), "Reasoning
about temporal relations: a maximal tractable subclass of Allen's interval algebra,"
*JACM* 42(1):43–66 — polynomial, path-consistency decides satisfiability, and it is the
unique greatest tractable subclass containing all 13 basic relations. Full classification:
Krokhin, Jeavons & Jonsson, *JACM* 50(5):591–640, 2003 (eighteen maximal tractable
subalgebras).

**If time were ever wanted *inside* the logic** rather than beside it, the licensed
construction is a *concrete domain*: Baader & Rydval (IJCAR 2020, LNCS 12166, pp. 413–431)
confirm "Allen's interval logic as well as the region connection calculus RCC8 can be
represented as ω-admissible concrete domains," which per Lutz & Miličić (*J. Automated
Reasoning* 38(1–3):227–259, 2007) stay decidable **with general axioms**. Note the contrast:
concrete domains with general TBoxes are typically *undecidable* without ω-admissibility
(Lutz; Baader & Rydval). Baader & Hanschke (IJCAI-91, pp. 452–457) is the origin of the
scheme.

### 2.4 Tier 3 — proportional and cardinality quantifiers

Available, complete, and cheaper than expected — these exceed first-order expressiveness on
a syllogistic base, which makes them strong differentiators.

> **Endrullis, J. & Moss, L. S. "Syllogistic Logic with 'Most'."** WoLLIC 2015, LNCS 9160,
> pp. 124–139; journal version *Mathematical Structures in Computer Science* 29(6):763–782,
> 2019, DOI 10.1017/S0960129518000312. `All X are Y`, `Some X are Y`, `Most X are Y`, on
> **finite** models, "most" = strictly more than half. Sound, complete, **decidable in
> polynomial time**.
>
> **Moss, L. S. (2016). "Syllogistic Logic with Cardinality Comparisons." In *J. Michael
> Dunn on Information Based Logics*, Outstanding Contributions to Logic 8, Springer.**
> Finite sets; adds "there are at least as many x as y" / "there are more x than y";
> soundness, completeness, efficient proof search and model construction; **implemented**.
>
> **Moss, L. S. & Topal, S. (2020). "Syllogistic Logic with Cardinality Comparisons, on
> Infinite Sets." *The Review of Symbolic Logic* 13(1):1–22.** DOI
> 10.1017/S1755020318000126. arXiv:1705.03037. Same syntax over infinite universes, with
> complemented terms.

**Gotcha for `Most`:** the proof system requires **infinitely many rules, and this is
proved unavoidable.** Implementable only as a parametrized rule *generator*, never a table.
Same phenomenon as the numerical layer (§1.2) — cheap to decide, impossible to finitely
axiomatize. Note this is a cliff on the *proof-theoretic* axis, not the complexity axis.

Also relevant: **Ivanov, N. & Vakarelov, D. (2012). "A system of relational syllogistic
incorporating full Boolean reasoning." *JoLLI* 21:433–459.** arXiv:1102.4496. Set terms and
relational terms both closed under Boolean operations, relational terms additionally closed
under converse. Completeness theorem plus complexity: **NEXPTIME-complete with infinitely
many relational variables, EXPTIME-complete with only finitely many.** That
finite/infinite-vocabulary distinction appears nowhere else in this literature.

---

## 3. Four ways to silently lose decidability

None of these announces itself in the notation.

### 3.1 Never let a numerical quantifier scope under a temporal or deontic operator

**The most important prohibition for us specifically, because we have TFL⁺.**

> **Hampson, C. & Kurucz, A. (2015). "Undecidable Propositional Bimodal Logics and
> One-Variable First-Order Linear Temporal Logics with Counting." *ACM Transactions on
> Computational Logic* 16(3), Article 27, pp. 1–36.**

From the abstract, verbatim: "we analyse seemingly 'mild' extensions of decidable
one-variable fragments with counting capabilities … We show that over most classes of
linear orders these logics are (sometimes highly) undecidable, **even without constant and
function symbols, and with the sole temporal operator 'eventually'**."

Their language has **one variable, only monadic predicates, no equality, no constants**,
plus counting to two. Results: `⟨ω,<⟩ × C_diff`-satisfiability is **Σ¹₁-complete**
(Thm 3.1) — not merely undecidable, not even recursively enumerable; `FOLTL^≠` is r.e. but
undecidable over all finite linear orders and **Σ¹₁-complete over ⟨ω,<⟩** (Cor. 3.4);
`[K4.3, Diff]` and `K4.3 × Diff` are undecidable (Cor. 4.2).

We sit inside C² (§1.4), which is precisely the targeted region. **Counting and temporal /
deontic operators must live in separate syntactic strata.** Any design permitting "at least
three applicants" to scope under "within 30 days" is undecidable.

### 3.2 Any modal or temporal layer must be a fusion, not a product

**Fusion** (independent join, no interaction axioms) — decidability transfers:
Kracht, M. & Wolter, F. (1991), "Properties of independently axiomatizable bimodal logics,"
*JSL* 56(4):1469–1485; Fine, K. & Schurz, G. (1996), "Transfer theorems for multimodal
logics," in *Logic and Reality: Essays on the Legacy of Arthur Prior*, OUP, pp. 169–213.
Weak/strong frame-completeness, canonicity and the finite model property transfer
unconditionally; **decidability** transfers given weak completeness of the components.
Complexity transfer: Spaan's 1993 ILLC dissertation *Complexity of Modal Logics*. Extended
to description-logic-like systems, including ABox reasoning: **Baader, Lutz, Sturm & Wolter
(2002), "Fusions of Description Logics and Abstract Description Systems," *JAIR* 16:1–58**
(arXiv:1106.1802).

**Product** (grid, with commutativity and Church–Rosser) — undecidability: Gabbay, D. &
Shehtman, V. (1998), "Products of modal logics, part 1," *Logic Journal of the IGPL*
6(1):73–146; Gabelaia, Kurucz, Wolter & Zakharyaschev (2005), "Products of 'transitive'
modal logics," *JSL* 70(3):993–1021 — products of transitive logics are undecidable and
lack the finite model property. Reference work: **Gabbay, Kurucz, Wolter & Zakharyaschev,
*Many-Dimensional Modal Logics: Theory and Applications*, Studies in Logic and the
Foundations of Mathematics 148, Elsevier, 2003** (xiv+747 pp.). Almost all 3-dimensional
products are undecidable.

**The theorem to design against — monodicity:**

> **Hodkinson, I., Wolter, F. & Zakharyaschev, M. (2000). "Decidable fragments of
> first-order temporal logics." *Annals of Pure and Applied Logic* 106(1–3):85–134.**
>
> *Monodic* = every formula beginning with a temporal operator has **at most one free
> variable**.
>
> **Theorem 2 (read this first):** for F = ⟨ℕ,<⟩ or ⟨ℤ,<⟩, `TL² ∩ TL^mo ∩ TL(F)` is **not
> recursively enumerable** — two-variable *monadic* first-order temporal logic is Σ¹₁-hard.
> **Being monadic alone does not save you.**
>
> **Theorem 71:** monadic + monodic **is decidable**, over arbitrary linear flows, finite
> flows, ⟨ℕ,<⟩, ⟨ℤ,<⟩, ⟨ℚ,<⟩, and (finite domains) ⟨ℝ,<⟩. Recipe: restrict the classical
> part to any decidable FO fragment, and the temporal part to monodic formulas. Two-variable
> monodic and guarded monodic are also decidable (Thm 74) — though the *unrestricted*
> temporal guarded fragment with two variables is not even r.e. (Thm 73).

A sentence-level operator applied to whole TFL propositions satisfies monodicity
automatically. Modal analogue: Wolter & Zakharyaschev (2001), "Decidable fragments of
first-order modal logics," *JSL* 66(3):1415–1438.

**The cheap version of the same idea:** Finger, M. & Gabbay, D. (1992), "Adding a temporal
dimension to a logic system," *JoLLI* 1(3):203–233 — temporal operators applied *only to
whole sentences*, never inside them, transfers soundness, completeness **and** decidability.
Generalised in Finger & Weiss (2002), *Logic Journal of the IGPL* 10(2):165–189. The
description-logic instance is Baader, Ghilardi & Lutz (2012), "LTL over Description Logic
Axioms," *ACM ToCL* 13(3): operators on axioms only is decidable in elementary time **even
with rigid roles** (2EXPTIME → NEXPTIME → EXPTIME-complete as rigid symbols are dropped),
where operators-inside-concepts is Σ¹₁-hard.

For reference, the temporal-DL landscape (Lutz, Wolter & Zakharyaschev, TIME 2008,
pp. 3–14): `LTL_ALC` expanding domains without TBox is **PSPACE-complete** — no harder than
either component, proved via a fusion characterisation — but with a TBox it is
EXPTIME-complete, temporal TBoxes are EXPSPACE-complete, **a single rigid role makes it
Σ¹₁-hard**, and temporal `CTL*_ALC` TBoxes are undecidable.

### 3.3 Never combine ditransitive verbs with pronouns; pin the anaphora policy

See §1.3. `TV+Rel+GA` undecidable; `DTV+Rel+RA` undecidable even under the restricted
policy.

### 3.4 Do not add general transitive relations

Quine's **fluted fragment** is the natural first-order home of variable-free,
order-preserving term logic (Quine, W. V. O. (1960), "Variables explained away," *Proc.
American Philosophical Society* 104:343–347).

> **Pratt-Hartmann, I., Szwast, W. & Tendera, L. (2019). "The Fluted Fragment Revisited."
> *Journal of Symbolic Logic*.** arXiv:1812.06440. The fluted fragment is **decidable but
> of non-elementary complexity** — refuting W. C. Purdy's published claim that it is in
> NEXPTIME (Purdy, *Studia Logica* 71:177–198, 2002). For FL^m: ⌊m/2⌋-NEXPTIME-hard for
> m≥2; in (m−2)-NEXPTIME for m≥3.
>
> **Pratt-Hartmann, I. & Tendera, L. (2019). "The Fluted Fragment with Transitivity."
> MFCS 2019, LIPIcs.** Verbatim: the logic "enjoys the finite model property when only one
> transitive relation is available… the satisfiability problem is **undecidable already for
> the two-variable fragment of the logic in the presence of three transitive relations**."

Comparatives (§2.2d) are safe only because transitivity enters as a *proof rule*.

*(Purdy's erroneous NEXPTIME claim is worth citing in a paper about certifying validity —
a published, peer-reviewed complexity result in exactly our area was wrong for 17 years.)*

---

## 4. What does not exist

Negative findings. Several are opportunities rather than disappointments.

### 4.1 The term-logic tradition has no rigorous extensions of its own

**No tense extension, no deontic extension, and no semantically certified modal extension**
in the Sommers/Englebretsen plus-minus line. Modal work exists inside the tradition
(Englebretsen; Castro-Manzano's recent papers) but was found to lack proved metatheory — no
soundness/completeness against a semantics, no decidability result.

**Do not cite** Castro-Manzano, J. M. (2022), "Traditional Logic for Non-Traditional
Reasoning," *Research in Computing Science* 151(5):115–127, **as a defeasible term logic**.
"Non-traditional" there means modality, numeracy and relevance — not defeasibility.

### 4.2 The one certified modal syllogistic sits outside the plus-minus tradition

> **Johnson, F. (1989). "Models for modal syllogisms." *Notre Dame Journal of Formal Logic*
> 30(2):271–284.** DOI 10.1305/ndjfl/1093635084. Open access on Project Euclid.

The only modal syllogistic with a calculus, a **proved** completeness theorem, and a
**proved** decision procedure. Syntax is Łukasiewicz prefix (McCall's, lightly modified —
"LXM"): primitives `A`, `I`, `N`, `C`, `L` plus a rejection marker `*`; 14 assertion axioms
(incl. Barbara LXL, Baroco LLL), 4 rules, 12 starred rejection axioms, 3 rejection rules.
Semantics partitions the domain per term into four blocks (essentially-x,
accidentally-x, essentially-non-x, accidentally-non-x) under six conditions.

- **Thm 2** (soundness): "Accepted wffs are valid, and rejected wffs are invalid."
- **Thm 4** (completeness): "Valid wffs are accepted, and invalid wffs are rejected."
- **Thm 5** (finite model property, explicit bound): falsifiability implies falsifiability
  in a model with `W ⊆ {1,…,4ⁿ}`, which "yields a decision procedure for validity."

The `4ⁿ` bound is less alarming than it looks: the canonical model is fixed by *which* basic
sets are nonempty — 64 booleans for a three-term syllogism — and the six conditions plus
falsity of the target are constraints over those booleans. It is a SAT/CSP, not
`2^(4ⁿ)` enumeration. Covers assertoric + necessity + one-sided possibility over
arbitrary-length polysyllogisms. **Does not cover two-way contingency `Q`.** No complexity
bound is proved — unclaimed territory.

Companions: Johnson, F. (1995), "Apodeictic syllogisms: Deductions and decision procedures,"
*History and Philosophy of Logic* 16(1):1–18, DOI 10.1080/01445349508837237 — reportedly
gives one semantic and two *syntactic* decision procedures (*abstract wording UNVERIFIED,
see §5*); Johnson, F. (1993), "Modal Ecthesis," *HPL* 14(2):171–182 (adds singular terms,
drops `M`). Base system: **McCall, S. (1963). *Aristotle's Modal Syllogisms*. North-Holland**
— six modal axioms plus four conversion/subordination rules, but **no semantics**, which
Johnson states explicitly. McCall + Johnson is the one complete package.

**Malink is exegetical, not metatheoretic.** From his own "Précis," *Philosophy and
Phenomenological Research* 90(3):716–723, 2015: the system is "adequate with respect to the
modal syllogistic in the sense that every schema held to be valid by Aristotle … is
deducible in this system but no schema held to be invalid by him is deducible in it," and
the predicable semantics "establishes the consistency of the modal syllogistic." That is
adequacy to a fixed ~400-item claim corpus — **not** soundness/completeness of a calculus
w.r.t. its semantics, and not decidability. Malink (2006), *HPL* 27(2):95–141, is a
first-order theory over three binary relations with five axioms; invalidity is shown by ~400
hand-built countermodels, and **no finite model property is proved**, so finite-model search
is not a certified decider. Cite him for the predicable semantics; do not implement him.

Two further calculi, both with named gaps: **Uckelman & Johnston (2010), "A Simple Semantics
for Aristotelian Apodeictic Syllogistics," *Advances in Modal Logic* 8, pp. 454–469** —
sound for L-X, **completeness not proved**, and the authors report the extension fails ("our
semantics does not preserve the validity of modal reductio ad absurdum … when at least one
premise is possible"). **Protin, C. L. (2023), "A Logic for Aristotle's Modal Syllogistic,"
*HPL* 44(3):225–246** (arXiv:2110.00316) — Lemma 2.5 proves soundness; the author writes
immediately after, "It is an open question if S5 is independent from AML and whether we have
completeness."

**Thom, P. (1996)** has a genuine axiomatic calculus covering contingency *and* singular
terms — the most expressive system surveyed — but ch. 6 is titled "Flaws in the Fabric," and
Malink cites him as holding the modal syllogistic inconsistent. *Whether Thom proves
completeness is UNVERIFIED.* Patterson (1995) is semi-formal with no calculus; Nortmann
(1996) and Schmidt (2000) are translations into modal predicate logic, not syllogistic
calculi.

**No decidable modal syllogistic covering two-way contingency exists**, under any
reconstruction. Two independent teams hit the wall exactly there and said so in print.

**One qualification — an epistemic syllogistic does exist, with proofs:**

> **Li, Y. & Wang, Y. (2023). "Epistemic Syllogistic: First Steps." TARK 2023, *EPTCS*
> 379:392–406.** DOI 10.4204/EPTCS.379.31. arXiv:2307.05043.

Outside the Sommers tradition — treats syllogistics as fragments of first-order *modal*
logic — but exactly the right shape: `φ ::= All(t,g) | Some(t,g)`, `g ::= A | ¬A | KA | K¬A`,
read **de re**. Small natural-deduction calculus. Thm 3: sound and strongly complete. Thm 8:
completeness. Thms 24/32/33: weak and strong completeness for `TNES`/`S4NES`/`S5NES` w.r.t.
reflexive/S4/S5 frames. **Decidability is observed in the conclusion but not proved.** The
best-engineered modal/epistemic term-style logic available and the natural extension point
if propositional attitudes are ever wanted.

Medieval alternative with better behaviour (modal subjects are ampliated, making it
cleaner): **Spencer Johnston (2015), "A Formal Reconstruction of Buridan's Modal
Syllogism," *HPL* 36(1):2–17**, DOI 10.1080/01445340.2014.934090. *Metatheory UNVERIFIED.*

### 4.3 Natural logic has nothing on generics, defaults, or defeasibility

**The terminological trap, which must be stated explicitly if natural logic is discussed in
the paper:** "monotonicity" in the monotonicity calculus is a property of a *function's
argument position* (upward/downward entailing contexts). "Monotonicity of entailment" — the
thing nonmonotonic logic negates — is a property of the *consequence relation*. These are
unrelated properties sharing a word. **The monotonicity calculus is itself a fully monotonic
consequence relation.**

Negative evidence is quantitative: term counts over the full text of the two field surveys
(Icard & Moss 2014; Moss's NASSLLI *Natural Logic* lectures) give **"generic" = 0,
"default" = 0, "defeasib\*" = 0** in both. An arXiv search for `all:"natural logic" AND
all:"defeasible"` returns 0 hits.

The one on-point statement is van Benthem's, and it is an admission of absence. In "A brief
history of natural logic" (in *Logic, Navya-Nyaya and Applications: Homage to Bimal Krishna
Matilal*, College Publications, 2008), under a subsection headed "From classical to default
logic": "*by default 'birds fly', but there are exceptions such as penguins… **A systematic
extension of the above monotonicity calculus to deal also with default implications based on
predicate inclusions would be a highly interesting project!***" The founder labelling it
open, ~18 years ago; nobody has carried it out.

Why it cannot be patched in: the join algebra is associative composition over a fixed
relation algebra with **no notion of premise ordering, priority, or defeat**. Retraction is
not expressible. Adding defeasibility is not an extension of the calculus; it is a change to
the consequence relation. The real literature lives elsewhere — Pelletier & Asher, "Generics
and Defaults," *Handbook of Logic and Language*, pp. 1125–1177; Cohen, *Computational
Intelligence* 13(4):506–533, 1997.

### 4.4 Three unclaimed technical gaps

1. **No modal or temporal extension of the Pratt-Hartmann/Moss decidable-fragment program
   exists.** Crossref and arXiv sweeps return only four modal-syllogistic items total, and
   an arXiv full-text search for "temporal syllogistic" returns **zero results**. "Complexity
   of deontic or temporal extensions of the numerically definite relational syllogistic"
   appears to be open territory.
2. **The complexity of Johnson's LXM validity problem is unclaimed** — decidability proved,
   complexity not.
3. **No 2025–2026 paper builds an LLM-*output* verification system on natural logic** in our
   sense. The nearest neighbours (ProoFVer, QA-NatVer, TabVer, Strong et al. 2024) all put an
   LLM *inside* a fact-verification pipeline over retrieved evidence. *Caveat: established by
   arXiv metadata search, which does not cover non-arXiv venues.*

---

## 5. Verification caveats — do NOT cite these as settled

Carried forward verbatim from the sweeps' own flags.

1. **Prior 1958 (Good Samaritan paradox).** SEP attributes it to A. N. Prior, "Escapism: The
   Logical Basis of Ethics," in A. I. Melden (ed.), *Essays in Moral Philosophy*, 1958.
   Crossref returned only *reviews* under that title. **Verify volume/pages before use.**
2. **Decidability/complexity of Åqvist's dyadic deontic systems E/F/G.** Completeness results
   and HOL embeddings were found; **no decidability or complexity theorem**. Do not assert
   dyadic deontic logic is decidable without a specific citation. (A TU Wien 2025 diploma
   thesis — Köll, "SMT-Based Automated Reasoning for Åqvist's Deontic Logics" — may settle
   this; could not be fetched.)
3. **KD's PSPACE *upper* bound attribution.** Hardness is airtight (Ladner 1977, since
   K ⊆ KD ⊆ S4). The matching upper bound is standard and universally stated but the
   canonical first statement specifically for D was not located. Cite Ladner 1977 plus
   Blackburn, de Rijke & Venema, *Modal Logic*, CUP 2001.
4. **Metric temporal DL bounds.** Gutiérrez-Basulto, Jung & Ozaki, "On Metric Temporal
   Description Logics," ECAI 2016, exists; the "EXPTIME to 2EXPSPACE" range came from the
   publisher's abstract page, not the paper. Fetch the PDF before citing specific bounds.
5. **GKWZ 2003 book, per-theorem claims.** Book verified (Elsevier, SLFM 148, 2003,
   xiv+747 pp.) and its overall thesis; product-undecidability verified via *JSL* 70(3).
   Individual theorem numbers in the book were **not** checked.
6. **Sun & Robaldo's own OUT₃ bound** verified only via Ciabattoni & Rozplokhas's
   restatement (paywalled, HTTP 403).
7. **Moss (2011) irreflexivity condition.** Citation triple-verified (dblp + Crossref +
   Semantic Scholar by DOI), but the "transitive and irreflexive" phrasing came from a
   Springer snippet (403 on the full page), corroborated by Moss's own slides. High
   confidence, snippet-sourced.
8. **Li, D. (2026), "A Decidable Ground Fragment of the Monotonicity Calculus," *Logics*
   4(2), art. 6**, DOI 10.3390/logics4020006. Crossref-verified verbatim ("*we prove that
   with a slight modification of the conditions for term formation, it is decidable over
   ground terms, i.e., terms that contain no variables*") but the MDPI page returns 403.
   Directly on point — the decidable fragment is precisely the variable-free one — so worth
   confirming.
9. **Icard, Moss & Tune (2017), "A Monotonicity Calculus and Its Completeness," MoL,
   pp. 75–87**, ACL `W17-3408`. Title/authors/venue/pages/DOI verified; **the theorem
   statement was not read.** Do not assert what it says without opening the PDF. (Note: Icard
   & Moss 2014 proves completeness only "in some special cases" and *conjectures* the general
   case — the 2014 paper is frequently over-cited on this point.)
10. **Johnson (1995) abstract wording**, **Thom (1996) completeness**, and **Spencer Johnston
    (2015) metatheory** — all UNVERIFIED (publisher blocks).
11. **HELP dataset up/down/non-monotone breakdown** (7,784 / 21,192 / 1,105) — seen only in a
    search snippet.
12. **Chen & Gao (2024) LLM accuracy table** — extracted via a text proxy, digits not checked
    against a rendered PDF.

**Two citation corrections.** (a) There is **no** Icard & Moss paper titled "Recent Progress
in Natural Logic"; the correct title is **"Recent Progress on Monotonicity," *Linguistic
Issues in Language Technology* 9(7):167–194, 2014** (ACL `2014.lilt-9.7`). (b) There is **no**
Icard work on generics or defaults — his "comparative" papers are on comparative
*probability*.

**Two live discrepancies in the natural-logic literature**, worth naming rather than
silently resolving if we ever cite it: the **join table differs between MacCartney (2009) and
Icard (2012)** — NaturalLI adopts Icard's, which is closed over the seven relations under
stronger assumptions ("optimistically assumes every operator is additive and multiplicative")
— and **projectivity is formalized twice**, MacCartney's 7⁷ signature space versus Icard &
Moss's lattice-based additive/multiplicative classification, which forms a monoid under
composition and is the better engineering target.

---

## 6. Notes for the paper

Independent of any implementation decision, five items here are usable as-is:

1. **PHM 2009 Thm 6.12** converts our derivation-search incompleteness from a caveat into a
   theorem (§1.1).
2. **Pratt-Hartmann's Thm 4** — relational inference is complexity-free, and the apparent
   difficulty of relational arguments "is purely psychological" — is a quotable framing for
   why a relational term logic is a reasonable target.
3. **The fragment map** (§1.4) locates TFL precisely in a well-studied landscape, which is
   stronger than describing the fragment informally.
4. **Purdy's 17-year-uncorrected NEXPTIME error** (§3.4) and **Pratt-Hartmann's demonstration
   of incomplete published numerical proof systems** (§1.2) both argue, in print and from
   outside our project, that differential verification of a logic engine is warranted. That
   is independent support for the Phase 1 engineering.
5. **Natural logic is complementary, not competing** (§4.3), and should be framed that way:
   it buys lexical/surface coverage and gives up deductive closure. Our engine already has
   multi-premise combination, de Morgan for quantifiers, and indirect proof — all of which
   MacCartney & Manning and Icard & Moss explicitly disclaim. Their own footnote 15 reports
   that randomly chosen relations reach the uninformative "black hole" relation in **about
   five joins on average**; TFL derivations lose no information with proof length.

One architectural observation worth recording: the fact-verification literature (ProoFVer,
QA-NatVer, TabVer, Strong et al. 2024) has converged independently on **neural proposer +
symbolic decider** — an LLM produces a candidate proof, a deterministic automaton renders the
verdict. That is the shape of our pipeline, arrived at by four separate groups. The
difference worth stating: their decider is a DFA over a neurally-generated operator string;
ours is a genuine decision procedure.
