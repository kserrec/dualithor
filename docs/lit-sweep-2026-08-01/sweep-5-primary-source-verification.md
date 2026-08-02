# Sweep 5 — Primary-source verification of three load-bearing citations

Date: 2026-08-01. Method: PDFs downloaded and text-extracted locally (`pdftotext`), then read
directly. Working copies live in
`/tmp/claude-1000/-home-serrecchia-Projects-tfl-verify/6e242743-c826-47dc-b12d-3a20997d2530/scratchpad/papers/`.

Every quotation below is text I actually read from the extracted source. Where I could only
reach an abstract, a bibliographic record, or a third-party restatement, that is stated
explicitly.

---

## CLAIM 1 — Defeasible logic is linear time (Maher 2001)

### What I read
The full text of the paper, from the author-posted arXiv version `cs/0405090v1` (24 May 2004),
whose header reads "Under consideration for publication in Theory and Practice of Logic
Programming" and whose arXiv journal-ref is TPLP vol. 1, no. 6, 2001. Downloaded from
`https://arxiv.org/pdf/cs/0405090`. This is the author's own copy of the accepted paper, not
the publisher's typeset version; I did not get behind the Cambridge Core paywall.

### Bibliographic details — CONFIRMED exactly
Maher, M. J. (2001). "Propositional Defeasible Logic has Linear Complexity." *Theory and
Practice of Logic Programming* 1(6):691–711. DOI 10.1017/S1471068401001168.
Volume, issue, pages and DOI independently confirmed via DBLP. Author affiliation at the time:
Loyola University Chicago / Griffith University.

### Theorem 5 — quoted CORRECTLY, verbatim
The paper reads, exactly:

> **Theorem 5**
> The consequences of a defeasible theory D can be computed in O(N ) time, where N is
> the number of symbols in D.

The survey's quotation is word-for-word identical. No fabrication here.

### Does the bound cover defeaters and the superiority relation? — YES
Confirmed. Section 4.1 defines `Basic` as the composition of three transformations from
Antoniou, Billington, Governatori & Maher: "The first places the defeasible theory in a normal
form, the second eliminates defeaters, and the third reduces the superiority relation to the
empty relation." Theorem 4 then states:

> **Theorem 4 ((1))**
> Let D be a defeasible theory and let Σ be the language of D. Let D′ =Basic(D).
> Then D′ is a basic defeasible theory and, for all conclusions c in Σ,
>    D ⊢ c iff D′ ⊢ c.
> Furthermore, D′ can be constructed in time linear in the size of D, and the size of D′ is
> linear in the size of D.

So the survey's structural reading is right: full defeasible logic (defeaters + priorities)
reduces in linear time and with linear blowup to *basic* defeasible logic (no defeaters, empty
superiority relation), on which the linear algorithm runs.

### What exactly is computed — the FULL set of conclusions, not one literal
The survey is, if anything, understating. Section 2.3 defines a *conclusion* as a tagged
literal of one of four forms: `+Δq`, `−Δq`, `+∂q`, `−∂q` (definitely provable; proved not
definitely provable; defeasibly provable; proved not defeasibly provable). The introduction
says "we show that the set of all conclusions can be computed in time linear in the size of the
theory," and Theorem 3 establishes that the transition system computes exactly the conclusions
of the theory. So O(N) buys the entire consequence set over all four tags, not membership of a
single literal.

### Corrections — conditions the survey dropped

1. **Theorem 4 is not Maher's result.** The paper labels it "Theorem 4 ((1))" and prefaces it
   with "The following result was proved in (1), albeit in parts and with slightly different
   terminology." Reference (1) is Antoniou, Billington, Governatori & Maher, "Representation
   Results for Defeasible Logic," *ACM Transactions on Computational Logic* 2:255–287, 2001.
   The survey's "attributed to Theorem 4" is numerically correct but presents an imported
   result as Maher's own. The paper says outright: "It is beyond the scope of this paper to
   present a definition of Basic."

2. **DROPPED CONDITION — the superiority relation must be acyclic.** This is built into the
   definition of a defeasible theory, Section 2.2: "We assume > to be acyclic (that is, the
   transitive closure of > is irreflexive)." And Section 2.1: "Consequently, defeasible logic
   requires that the superiority relation is acyclic." A cyclic priority relation is not a
   defeasible theory at all, and the linear bound says nothing about it. If TFL-Verify lets
   users author priorities, acyclicity is a precondition that must be checked, not assumed.

3. **DROPPED CONDITION — propositional / ground only, and grounding is outside the bound.**
   The title says "propositional," but the survey's phrasing loses what that costs. The
   introduction states: "We have already established that full first-order defeasible logic has
   a recursively enumerable inference problem" — i.e. first-order defeasible logic is only
   semi-decidable, not decidable, let alone linear. Example 1 makes the grounding step
   explicit: five rule schemas over two constants "give rise to nine propositional rules by
   instantiating each variable." N in Theorem 5 is the size of the *already-ground* theory. Any
   rule language with variables pays a grounding blowup that the theorem does not cover.

4. **DROPPED CAVEAT — the constant factor is bad, by the author's own account.** The paper's
   Conclusion: "the transformations used to convert an arbitrary defeasible theory to the
   appropriate form for the algorithm of Figure 1 impose a large constant factor on the cost of
   initializing S. Although the cause has not been pinpointed, it appears to be derived from
   the multiplication of rules and propositions during the transformations." Section 4.1 calls
   the two transformations "profligate in their introduction of propositions and generation of
   rules." Linear, yes — cheap in practice, not automatically.

5. **Scope caveat — this is one specific variant of defeasible logic.** The result covers the
   standard ambiguity-blocking, team-defeat logic of Nute/Billington/Antoniou. Section 5 says
   variants "can be expected" to have linear complexity "although the details will require
   careful verification," and that "well-founded defeasible logic can be expected to have
   quadratic complexity." Do not generalize the O(N) to a nearby variant without checking.

6. **Minor:** Theorem 5's O(N) is stated in "symbols in D," while the algorithm analysis is
   given in "the number of literal occurrences in D′" plus initialization proportional to the
   number of propositions in D′. The step from one to the other rests on Theorem 4's linearity.
   Consistent, but the two units are not the same and the paper does not belabor the bridge.

### VERDICT: **CONFIRMED WITH CORRECTIONS**
Citation exact; quotation exact; the defeaters-and-superiority coverage is real. Corrections:
Theorem 4 is imported from Antoniou et al. 2001, not proved here; acyclicity of `>` is a
dropped precondition; the result is ground-propositional and first-order defeasible logic is
merely r.e.; and the author himself flags a large constant factor.

---

## CLAIM 2 — Simple Temporal Network consistency is polynomial (Dechter, Meiri & Pearl 1991)

### What I read
The full published paper, from the UCLA Cognitive Systems Laboratory technical-report reprint
`https://ftp.cs.ucla.edu/pub/stat_ser/r113-reprint.pdf` (TECHNICAL REPORT R-113), which is a
scan of the Elsevier typeset article — header "Artificial Intelligence 49 (1991) 61-95",
"Received November 1989 / Revised July 1990". This is the actual published text.

### Bibliographic details — CONFIRMED exactly
Dechter, R., Meiri, I. & Pearl, J. (1991). "Temporal constraint networks." *Artificial
Intelligence* 49:61–95. (The reprint's cover line notes it received the 2020 AIJ Classic Paper
Award.)

### The STN/TCSP distinction — CONFIRMED, with a terminology note
From the abstract: "We distinguish between simple temporal problems (STPs) and general temporal
problems, the former admitting at most one interval constraint on any pair of time points."
Section 3: "A TCSP in which all constraints specify a single interval is called a simple
temporal problem (STP)."

The constraint form the survey gives is exactly right. Equation (3.1):
`a_ij ≤ X_j − X_i ≤ b_ij`, equivalently the pair of inequalities `X_j − X_i ≤ b_ij` and
`X_i − X_j ≤ −a_ij`.

**Terminology correction:** the paper never uses "STN" or "Simple Temporal Network." It says
STP throughout. "STN" is later community usage. Harmless, but if the paper is being cited for
the term, the term is not in it.

Also worth carrying: unary constraints are not a separate case. Section 2 introduces "A special
time point, X0, ... to represent the 'beginning of the world'. All times are relative to X0,
thus we may treat each unary constraint T_i as a binary constraint T_0i".

### Polynomiality via negative cycles — CONFIRMED
> **Theorem 3.1** (Shostak [42], Liao and Wong [30], Leiserson and Saxe [29]). A
> given STP, T, is consistent if and only if its distance graph, G_d, has no negative
> cycles.

And on the algorithm: "The d-graph of an STP can be constructed by applying Floyd-Warshall's
all-pairs-shortest-paths algorithm [38] to the distance graph (see Fig. 4). The algorithm runs
in time O(n^3), and detects negative cycles simply be [sic] examining the sign of the diagonal
elements d_ii. It constitutes, therefore, a polynomial time algorithm for determining the
consistency of an STP, and for computing both the minimal domains and the minimal network."
Assembling one solution is a further O(n²), so total O(n³).

**Correction:** Theorem 3.1 is explicitly credited to Shostak; Liao & Wong; and Leiserson &
Saxe. The negative-cycle characterization is **not** original to Dechter–Meiri–Pearl. They
restate it and give a proof. Citing DMP for the *characterization* is a misattribution; citing
them for the STP framing, the minimal-network results, and the Floyd-Warshall packaging is
fair.

**Correction:** **Bellman–Ford does not appear in this paper.** The words "Bellman" and "Ford"
occur nowhere in the text. The only algorithm given for STP consistency is Floyd–Warshall
(Fig. 4, all-pairs, O(n³)). Single-source Bellman–Ford negative-cycle detection in O(nm) is
standard, correct, and the right choice for a sparse STN — but it is the survey's addition, not
DMP's, and must not be cited to this paper.

### NP-hardness of disjunctive TCSP — CONFIRMED as present, with a sharp attribution correction
Section 4: "Davis [12] showed that determining consistency for a general TCSP is NP-hard."

> **Theorem 4.1** (Davis [12]).
>    (i) Deciding consistency for a TCSP is NP-hard.
>   (ii) Deciding consistency for a TCSP with no more than two intervals per edge is NP-hard.

Both parts are proved in the paper by reduction from 3-colouring; part (i) uses unary domains
{[1],[2],[3]} and edge constraints `X_j − X_i ∈ {[−2],[−1],[1],[2]}`.

**Correction (significant):** reference [12] is "**E. Davis, Private communication (1989)**."
The NP-hardness of disjunctive TCSP is credited by DMP to a *private communication* from Ernest
Davis. The theorem statement and its proof do appear in this paper — so "in the same paper" is
literally true — but the result is not DMP's, and its original source is unpublished. If the
paper is cited as the origin of the hardness result, that is wrong.

**Correction (smaller):** the paper says NP-**hard**, never NP-complete. Membership in NP is
not asserted here.

### Is a negative cycle a human-readable certificate? — PARTIALLY REFUTED
Two separate questions, and the survey conflates them.

*Is a negative cycle a sound, checkable, human-readable certificate of inconsistency?* **Yes**,
and the paper's own proof is the argument: "Suppose there is a negative cycle, C, consisting of
nodes i_1 ..., i_k = i_1. Summing the inequalities along C yields X_i1 − X_i1 < 0, which cannot
be satisfied." A cycle is a finite list of edges; summing their weights is arithmetic a reader
can check by hand; each edge corresponds to one original constraint. That is a genuine
certificate, and the survey's intuition is right.

*Does the algorithm in the paper yield the cycle?* **No.** Floyd–Warshall as given in Fig. 4
maintains only the distance matrix `d_ij`; the paper says negative cycles are detected "simply
by examining the sign of the diagonal elements d_ii." That gives a yes/no answer plus the
identity of *a node lying on some* negative cycle. It does not give the cycle. Recovering the
edge sequence needs predecessor/witness bookkeeping that the paper does not describe — and
predecessor reconstruction under Floyd–Warshall with negative cycles is a known-fiddly case.
Bellman–Ford's predecessor-graph cycle walk is the cleaner route, but again, that is not in
this paper.

**Engineering consequence for TFL-Verify:** producing the certificate is real work you have to
implement, and you cannot cite Dechter–Meiri–Pearl as having provided it. Budget for it.

### VERDICT: **CONFIRMED WITH CORRECTIONS**
Citation exact; the STP/TCSP distinction, the `a ≤ t_j − t_i ≤ b` form, the negative-cycle
consistency criterion, Floyd–Warshall O(n³), and the NP-hardness of the disjunctive case are
all genuinely in the paper. Corrections: the negative-cycle theorem is credited to Shostak /
Liao & Wong / Leiserson & Saxe; the NP-hardness is credited to E. Davis, *private communication
(1989)*, and stated as NP-hard not NP-complete; Bellman–Ford is not in the paper at all; and
the paper's algorithm returns a yes/no plus a diagonal sign, not an extractable negative cycle.

---

## CLAIM 3 — Input/output logic is coNP-complete (Ciabattoni & Rozplokhas 2023)

### What I read
- Full text of **Ciabattoni & Rozplokhas**, arXiv:2306.09496 (`https://arxiv.org/pdf/2306.09496`),
  including the rule table, Corollary 1 with proof, and the bibliography.
- Full text of **Sun & Robaldo**, from the authors' open-access copy at the University of
  Luxembourg ORBilu repository
  (`https://orbilu.uni.lu/bitstream/10993/33477/1/ComplexityOfIOLogic.pdf`), title "On the
  Complexity of Input/Output Logic," including all complexity theorems. **The survey's note
  that this source is paywalled and could only be reached via Ciabattoni & Rozplokhas's
  restatement is now obsolete** — an author copy is freely available and I read it.
- Full text of **Parent & van der Torre**, "Input/output logics without weakening,"
  *Filosofiska Notiser* 6(1):189–208, 2019 (`https://filosofiskanotiser.com/Parent_Torre.pdf`).
- For **Makinson & van der Torre 2001**: bibliographic record only, via the Semantic Scholar
  Graph API (abstract elided by the publisher) plus the reference entries in Ciabattoni &
  Rozplokhas and in Sun & Robaldo. I did **not** read the paper itself; it is paywalled at
  Springer. Its abstract I saw only as a search-engine summary, which I am not quoting.

### Ciabattoni & Rozplokhas — venue supplied, CONFIRMED
Ciabattoni, A. & Rozplokhas, D. (2023). "Streamlining Input/Output Logics with Sequent Calculi."
In *Proceedings of the 20th International Conference on Principles of Knowledge Representation
and Reasoning* (**KR 2023**), eds. Marquis, Son & Kern-Isberner, **pp. 146–155**.
DOI 10.24963/kr.2023/15. Preprint arXiv:2306.09496 (15 June 2023). Both authors at TU Wien.
The survey's missing venue was a real gap, but the paper is real and peer-reviewed.

### coNP-completeness — CONFIRMED verbatim
> **Corollary 1.** The entailment problem is a co-NP-complete problem for all eight considered
> I/O logics.

Section 5.2 opens: "We investigate the computational properties of the four original I/O logics
and their causal versions. One corollary of our previous results is co-NP-completeness for all
of them."

### Reduction to SAT — CONFIRMED
Section 5.2: "we can explicitly reduce the entailment problem in all these logics to the
(un-)satisfiability of one classical propositional formula of polynomial size, a thoroughly
studied problem with a huge variety of efficient tools available." The contributions list in
§1 says the automated procedures "are obtained via reduction to unsatisfiability of a classical
logic formula of polynomial size." The survey's characterization is accurate.

### CORRECTION (major) — "all eight I/O logics" is a conflation of two different eights
This is the most consequential error found in the whole sweep.

**Ciabattoni & Rozplokhas's eight** = the four original Makinson–van der Torre logics OUT1–OUT4,
plus the four **Bochman causal** counterparts OUT⊥1–OUT⊥4, which extend each original with the
axiom (BOT) `(⊥,⊥)`. From §1: "These results are uniformly obtained for all four original I/O
logics and their causal versions." The word "throughput" does not occur anywhere in their paper.

**Sun & Robaldo's eight** = OUT1–OUT4 plus the four **throughput** versions OUT1+–OUT4+, which
add the identity axiom (ID) `(a,a)`. Their §2.1, read directly: "For each of these four
operators, a throughput version that allows inputs to reappear as outputs is defined as
`out+_i(O,A) = out_i(O_id, A)`, where `O_id = O ∪ {(a,a) : a ∈ L_P}` ... Thus, we obtain eight
basic input/output logic systems in total."

These are **not the same eight**. The overlap is only OUT1–OUT4. So the survey's framing —
that Ciabattoni & Rozplokhas "complete" Sun & Robaldo's partial results across all eight — is
wrong on both ends:
- Ciabattoni & Rozplokhas do resolve **OUT3**, which Sun & Robaldo left open, and add four
  causal logics Sun & Robaldo never touched.
- They do **not** address the throughput family at all, so **OUT3+ remains unresolved** by both
  papers (Sun & Robaldo's Theorem 3.12 leaves it, like OUT3, between coNP and P^NP).

If TFL-Verify's routing depends on a throughput-style I/O logic (inputs reappearing as outputs
— which is often what you want if obligations are to be chained with facts), the coNP-complete
guarantee is *not* established for the reusable case.

### CORRECTION — the survey understates what Sun & Robaldo covered
Verified against the primary text, not a restatement:
- Theorem 3.2: `out1` fulfillment is coNP-complete. Theorem 3.4: `out1+` coNP-complete.
- Theorem 3.6: `out2` coNP-complete. Theorem 3.8: `out2+` and `out4+` coNP-complete.
- Theorem 3.14: `out4` coNP-complete.
- Theorem 3.11: `out3` is "between coNP and P^NP". Theorem 3.12: same for `out3+`.

So Sun & Robaldo covered **six** logics at coNP-complete (1, 2, 4 and 1+, 2+, 4+), not three.
Ciabattoni & Rozplokhas's own summary of them ("(Sun and Robaldo 2017) showed that the
entailment problem for OUT1, OUT2, and OUT4 is co-NP-complete, while for OUT3 the complexity
was determined to lie within the first and second levels of the polynomial hierarchy, without
exact resolution") is accurate as far as it goes, but it silently drops the throughput results
— which is almost certainly where the survey's undercount came from.

Minor terminological note: Sun & Robaldo analyse the **fulfillment problem** (`x ∈ out_i(O,A)`);
Ciabattoni & Rozplokhas analyse the **entailment problem** (`G ⊢ (B,Y)`). These correspond via
the soundness/completeness theorems (Sun & Robaldo's Theorem 2.1, from Makinson & van der Torre
2000), but they are not literally the same decision problem statement.

Sun & Robaldo citation details **CONFIRMED independently**: Sun, X. & Robaldo, L. (2017). "On
the complexity of input/output logic." *Journal of Applied Logic* 25:69–88. Confirmed both from
Ciabattoni & Rozplokhas's bibliography ("Sun, X., and Robaldo, L. 2017. On the complexity of
input/output logic. J. Appl. Log. 25:69–88.") and from the ScienceDirect / Semantic Scholar
records.

### ROSS'S PARADOX SUB-CLAIM — **REFUTED**
The survey claims Ross's paradox "is blocked by design in OUT1/OUT3 because they lack output
weakening." This is backwards. All four original I/O logics **have** (WO), weakening of the
output, and it is precisely (WO) that generates Ross's paradox.

Ciabattoni & Rozplokhas's own rule table, read directly:
> (WO) (A, X) derives (A, Y ) whenever X |= Y

and:
> The basic system, called simple-minded output OUT1, consists of the rules {(TOP), (WO),
> (SI), (AND)}. Its extension with (OR) ... leads to basic output logic OUT2, with (CT) ... to
> simple-minded reusable output logic OUT3, and with both (OR) and (CT) to basic reusable
> output logic OUT4.

Sun & Robaldo say the same thing independently: "WO (weakening the output): from (a, x) to
(a, y) whenever y ∈ Cn({x})" and "The derivation system based on the rules SI, WO and AND is
called deriv1."

So OUT1 contains (WO), and OUT3 = OUT1 + (CT) contains it too. Ross's paradox — from
"you ought to mail the letter" infer "you ought to mail-or-burn the letter", i.e. from `(a, x)`
infer `(a, x ∨ y)` — is a one-step instance of (WO) in **every** one of OUT1–OUT4, and in the
causal versions as well. It is not blocked anywhere in the family.

The decisive statement is Parent & van der Torre 2019, read directly:
> All the input/output logics of Makinson and van der Torre satisfy the rule WO.

Their entire paper exists to build variants that **drop** (WO), replacing it with closure under
logical equivalence ("from (a, x) infer (a, y) whenever x ⊢ y and y ⊢ x"), precisely to escape
these problems. The likely origin of the survey's inversion is visible in the same paper: "It
builds on previous research by Stolpe [40, 41], who began work on versions of input/output
logic without WO. **His focus is on out1 and out3.**" That is a statement about Stolpe's
*non-standard WO-free variants of* out1 and out3 — which appears to have been garbled into
"out1 and out3 lack WO."

Note also: **Ciabattoni & Rozplokhas never mention Ross's paradox.** The word "Ross" appears in
their text only inside a bibliography entry for an unrelated co-author (Rossi, A.). Whatever
source the survey used for the Ross claim, it was not this paper.

**Engineering consequence for TFL-Verify:** if the design assumes Ross's paradox is free — that
choosing OUT1 or OUT3 buys you immunity — that assumption is false, and any deontic layer built
on standard I/O logic will license disjunctive-obligation weakening. Blocking it means adopting
a WO-free system (Stolpe 2015, *J. Appl. Log.* 13(3):239–258, cited in Ciabattoni &
Rozplokhas's bibliography; or Parent & van der Torre 2019), which is **outside** the eight
logics the coNP-completeness result covers. You cannot have both the cited complexity guarantee
and the Ross immunity from the same system.

### Contrary-to-duty via constrained output — CONFIRMED (indirectly), with an added warning
Citation details **CONFIRMED**: Makinson, D. & van der Torre, L. (2001). "Constraints for
Input/Output Logics." *Journal of Philosophical Logic* 30(2):155–185, DOI
10.1023/A:1017599526096. Verified via the Semantic Scholar Graph API (journal "Journal of
Philosophical Logic", volume 30, pages 155–185, year 2001, DBLP key journals/jphil/MakinsonT01)
and via the reference entries in both Ciabattoni & Rozplokhas and Sun & Robaldo. **I did not
read the paper itself** — Springer paywall; Semantic Scholar reports the abstract as elided by
the publisher.

That constrained output is the CTD device is confirmed from a primary source I *did* read,
Sun & Robaldo §2.2, which is about this exact construction:
> An important feature deontic frameworks must have is the ability of determining which
> obligations are detached in a situation that already violates some among them. ... In
> input/output logic, this is handled by introducing the definitions of maxfamily and outfamily,
> which lead to the concept of constrained input/output logic (Makinson and van der Torre, 2001)

and:
> maxfamily and outfamily allow to straightforwardly overcome well-known limits of standard
> deontic logic, above all dealing with contrary-to-duty reasoning, i.e. reasoning about what to
> do in the face of violations of obligations.

The mechanism, from the same section: `maxfamily_i(O,A,C)` is the family of maximal subsets O′
of the norm set O such that `out_i(O′,A) ∪ C` is satisfiable; `outfamily_i` is the family of
their outputs. Credulous inference takes the union (`out∪`), sceptical the intersection
(`out∩`).

**CORRECTION / DROPPED CONDITION (engineering-critical):** the coNP-completeness result applies
to the **unconstrained, monotonic** I/O logics. Constrained I/O logic — the CTD machinery — is
non-monotonic and **strictly harder**. From Sun & Robaldo, read directly:
- Theorem 3.15: consistency checking is NP-complete for i ∈ {1,2,4,1+,2+,4+}; NP-hard and in
  P^NP for i ∈ {3,3+}.
- Theorem 3.16: maxfamily membership is **BH2-complete** for i ∈ {1,2,4,1+,2+,4+}
  (BH2 = intersection of an NP and a coNP language); Theorem 3.17: BH2-hard and in P^NP for
  {3,3+}.
- Theorem 3.18: full-join (credulous) fulfillment is **NP^NP-complete** for all eight.
- Theorem 3.19: full-meet (sceptical) fulfillment is **coNP^NP-complete** for all eight.
- Theorem 3.22: positive-dynamic permission checking is NP^NP-complete for i ∈ {1,2,3,4}.

So the survey's two design claims sit in tension and must not be quoted together as a package:
"coNP-complete, reducible to one SAT call" is true of the *unconstrained* logics, and the moment
you adopt constrained output to handle contrary-to-duty you are at the **second level of the
polynomial hierarchy**, not coNP. A single SAT oracle call no longer suffices.

### VERDICT: **CONFIRMED WITH CORRECTIONS** (with the Ross's-paradox sub-claim **REFUTED**)
The Ciabattoni & Rozplokhas paper is real (KR 2023, pp. 146–155), Corollary 1 says exactly what
the survey says it says, and the polynomial reduction to propositional (un)satisfiability is
genuine. But: the "eight" logics are OUT1–OUT4 plus Bochman's four *causal* versions, not the
eight (originals + throughput) of Sun & Robaldo, so the "completes earlier partial results"
framing is a conflation and OUT3+ is still open; Sun & Robaldo actually settled six logics, not
three, and their paper is openly available so the survey's paywall caveat can be retired; the
Ross's-paradox claim is flatly false, since (WO) is a rule of OUT1 and OUT3 and of every
original I/O logic; and constrained output, the CTD device, escalates the complexity to the
second level of the polynomial hierarchy, which the survey dropped.

---

## Fabrication check

No fabricated quotations were found in the three claims as stated to me. The one verbatim
quotation the survey offered (Maher's Theorem 5) is exact. The failures in this sweep are
failures of *attribution*, *scope*, and one *inversion of a technical fact* (Ross / WO) — not
invented text. That said, the Ross/WO error is the kind of confident, plausible-sounding,
fully-inverted statement that automated summarisation produces, and it is the single most
dangerous item here because it would have been designed against silently.
