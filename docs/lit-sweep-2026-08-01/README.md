# Literature sweep, 2026-08-01 — index and synthesis

Six parallel sweeps run on 2026-08-01, after Kyle redirected the project toward
expressiveness and real-world impact. They exist because the earlier
`docs/expressiveness-literature.md` survey, while valuable, was organised around
"what can be added without escalating" and had no coverage of the field this
application actually lands in.

**Status: research notes. Nothing here is a proposal, and no PLAN step has been
written or revised on the basis of it.** No pre-existing document in `docs/` was
modified. In particular `scope-and-predictions.md` §1 (the pre-registered
predictions) is deliberately untouched — rewriting predictions after the fact
would destroy the only thing that makes them worth having, and whether to freeze
them and add a new pre-registration is Kyle's call.

## The six reports

| File | Target | Bottom line |
|---|---|---|
| `sweep-1-rules-as-code.md` | Catala, OpenFisca, LegalRuleML, Blawx, Regorous, legal NLP benchmarks | No system both auto-formalizes rule text **and** lets a non-expert audit the result. The field splits cleanly and nothing bridges it. |
| `sweep-2-controlled-natural-language.md` | Attempto Controlled English, PENG, Grammatical Framework, OWL verbalization | Deterministic formal→English rendering is prior art four times over, since 2008. But no CNL has ever been evaluated on the *audit* task. |
| `sweep-3-description-logic-argumentation.md` | EL++/SNOMED CT, OWL justifications, Dung/ASPIC+/ABA, contestability | DL explanations are correct and **not** lay-readable — proven on laypeople. Keep Nute-style defeasible logic over ASPIC+/ABA. |
| `sweep-4-tfl-full-scope.md` | Sommers, Englebretsen, Murphree, Peterson, Castro-Manzano, Mozes | Murphree's numerical term logic is a strict superset of our TFL⁺ layer. Missing-premise suggestion is algebraic and unpublished. |
| `sweep-5-primary-source-verification.md` | Maher 2001, Dechter/Meiri/Pearl 1991, Ciabattoni & Rozplokhas 2023 | All three confirmed with corrections. One claim in the earlier survey is **inverted**. |
| `sweep-6-novelty-check.md` | Five novelty claims, each attacked adversarially | Three refuted, one partial, one survives. |

## What the sweeps killed

- **A deontic layer built on input/output logic.** Three independent hits: Governatori
  and Ciabattoni (the formalism's own authors) already did LLM→defeasible deontic logic
  on real regulatory text (arXiv:2506.08899); the "Ross's paradox is blocked in OUT₁/OUT₃"
  claim in `expressiveness-literature.md` §2.3(f) is **backwards** (all eight I/O logics
  satisfy weakening of output); and constrained output — the contrary-to-duty device — is
  at the second level of the polynomial hierarchy, not coNP.
- **"Deterministic back-rendering is our differentiator."** Prior art in ACE (2008),
  ACE↔OWL, PENG, and Grammatical Framework.
- **"No modal or temporal extension of TFL exists."** Englebretsen, *NDJFL* 29(3), 1988.
- **"First to verify LLM output symbolically."** SemEval-2026 Task 11 is an entire shared
  task on this; ARc (arXiv:2511.09008) is a deployed service.
- **The GDPR Article 22 framing.** Art 22(3)'s contest right is scoped to decisions based
  on contract and consent, **not** statutory authorisation — which is the basis for most
  government eligibility decisions.

## What survives, better evidenced than before

1. **The audit gap.** Fuchs (CNL 2018), ACE's own author, designed precisely this
   experiment and wrote *"For lack of resources I did not do the experiment."*
   Vernie & Grabmair (2026) name non-expert accessibility as an open concern.
   Alrabbaa et al. (RuleML+RR 2022) measured laypeople on logic proofs: **mean 2.36/12**.
   Three independent groups, one unsolved problem.
2. **Missing-premise suggestion as a novel contribution.** TFL's first validity condition
   is an equation over a free abelian group on signed terms, so the missing premise is
   `C − ΣPᵢ` — subtraction, no search, on the fragment where P/Z decides. No publication
   states this. It also answers the "why was I **not** found eligible?" question that the
   DL world needs abduction for.
3. **Fragment routing.** Nobody has it. ORE 2012 on 294,469 SNOMED concepts is the
   illustration: ELK 6.2 s; FaCT++ 408.9 s; jcel 1041.6 s; HermiT timed out at 30 min;
   Pellet ran out of memory. Fragment membership as *works* vs *does not run*.
4. **A Nute-style defeasible layer**, confirmed against its main rival: defeasible logic is
   linear and its superiority relation is free, where adding preferences to ABA lifts
   grounded reasoning from P to Δ₂ᴾ. Carneades' proof standards map *into* defeasible logic
   (Governatori, ICAIL 2011), so burden-of-proof machinery comes along.
5. **Murphree's numerical term logic** as a strict superset of TFL⁺ — held behind the
   §1.2 soundness audit of the numerical layer we already have.
6. **One piece of open territory**: the complexity of deontic or temporal extensions of the
   numerically definite relational syllogistic. DBLP returns zero hits on both searches.

## The finding that should temper the ambition

The two systems with real production footprints — Oracle Policy Automation and OpenFisca —
use the **least** expressive formalisms available. The richest logics have the weakest
deployment records: Regorous is "prototype technology," DataLex is "for demonstration
purposes only," Blawx is "not production-quality," Carneades has been dormant since 2017.
Two readings are possible — expressive logic is a deployment liability, or nobody has yet
paired one with adequate tooling and institutional trust — and sweep 3 states plainly that
it cannot distinguish them.

## Method note, and why it matters here

**Four of the six sweeps independently reported that the PDF-fetching summariser returned
confident, fabricated content** — in one case "confident content-free answers" generated
from undecodable binary noise. All four worked around it by downloading with `curl` and
extracting text with `pdftotext`, and each logs the specific claims caught and discarded.

That failure mode is almost certainly the origin of the inverted Ross's-paradox claim in
`expressiveness-literature.md`. **Consequence: any citation in this project not sourced
from extracted primary text should be treated as unverified until it is.** That includes
much of the earlier survey.

Each report ends with its own numbered verification caveats. Those are not decoration —
read them before citing anything.

## Not preserved

The sweeps downloaded ~18 MB of copyrighted PDFs and extracted text into the session
scratch directory. Those are deliberately **not** in this repo. References to scratch paths
inside the reports point at that directory and are now stale.
