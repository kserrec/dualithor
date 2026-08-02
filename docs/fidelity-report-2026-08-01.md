# Translation-fidelity measurement (PLAN 4.5b)

> ⚠️ **SUPERSEDED 2026-08-02 — see `fidelity-report-2026-08-02.md`.**
> The numbers below were graded against a gold set containing one formula that
> meant the opposite of its own sentence (`i04`: "Few volunteers are employees."
> was gold-ed as `+Volunteer^3+Employee`, which the engine reads as "few
> volunteer is **not** employee"), and against a prompt that taught that error.
> All three models copied it and were scored **correct**. The gold and the
> prompt were both corrected and the whole run redone.
> **This file is kept unedited as the record of what was measured on 2026-08-01.
> Do not cite its numbers.**

Run 2026-08-01. 91 gold sentences + 10 out-of-fragment sentences + 8 arguments,
through three models. 45 API calls, **$0.44**. Per-item results land in
`data/results/` (gitignored); every failure is reproduced in full below, which
is the part worth keeping.

**Why this ran before any layer work:** it is the project's largest open risk.
Plus-minus notation is essentially absent from pretraining data where FOL is
abundant, and the second literature sweep found a neighbouring measurement —
NL→TLA+ at 26.6% syntactic / 8.6% semantic validity, attributed by its authors
to corpus scarcity. If fidelity collapsed, the thesis went with it.

## Result

| Model | Faithful | Parse rate | Declines | Argument verdicts |
|---|---|---|---|---|
| moonshotai/kimi-k3 | **100%** (91/91) | 100% | 10/10 | 8/8 |
| anthropic/claude-sonnet-5 | **99%** (90/91) | 100% | 10/10 | 8/8 |
| openai/gpt-5.6-terra | **96%** (87/91) | 100% | 10/10 | 8/8 |

**Genuine model errors across all three models: two.** Both GPT, both the same
bug. Everything else below is instrument, not model.

### Pre-registration, checked

Written before the run: *"≥70% structural accuracy is viable; below ~50% is a
genuine negative result."* The outcome is 96–100%. **The prediction was wrong by
a wide margin, in the good direction**, and is recorded here rather than
quietly updated.

`scope-and-predictions.md` §1.3 also predicted TFL parse rates "possibly no
better than NL→FOL, plausibly worse, especially for the weakest model." On this
set that reads wrong too — though it is untested against a matched FOL arm, so
it stays open rather than refuted.

## The two genuine errors

**GPT-5.6-terra flips the quality sign on E-forms with a negative subject term.**

| Item | Sentence | Gold | GPT wrote | What GPT's formula says |
|---|---|---|---|---|
| c02 | No non-member is eligible. | `−(−Member)−Eligible` | `-(-Member)+Eligible` | *Every* non-member is eligible |
| c06 | No non-signatory is bound. | `−(−Signatory)−Bound` | `-(-Signatory)+Bound` | *Every* non-signatory is bound |

Two for two on that construction — systematic, not noise. It is also precisely
the class of error this pipeline exists to catch: the formula parses, reads
plausibly, and asserts the opposite of the sentence. A direct-answering
baseline has no mechanism to surface it.

## What the run settles

**The out-of-distribution fear is refuted for syntax.** 273 formulas, **zero
unparseable**, all three models. TLA+'s 26.6% does not transfer. The likely
reason is that TFL's structural simplicity — four parts, no variables, no
quantifier scope — outweighs its absence from training data. That was the
countervailing force we could name but not size.

**Naming consistency is not a problem.** 24 of 24 argument verdicts reproduced
end-to-end: each model's *own* premises and conclusion, fed back through the
engine, gave the gold verdict. Group J existed only to catch a model naming one
relation two ways across premises. It caught nothing.

**The router signal works.** 30 of 30 out-of-fragment sentences declined with
correct reasons — tense, arithmetic, defaults, propositional attitude. And no
over-declining: not one model refused a sentence it should have translated.

## Instrument defects found, and disclosed

**A gold-set inconsistency, corrected after seeing the data.** Group D
(intersective adjective+noun) accepted both the compound and the opaque quoted
reading — a decision made *before* the run. Group E contains the same
construction and did not. Models read "long-term resident" as long-term ∧
resident, which is right; my gold called it wrong. Five items (`e02`–`e06`) now
carry the compound reading in `also_ok` and are flagged `"scoring": "disputed"`.

Raw numbers before that correction: **94.5% / 97.8% / 91.2%** (Sonnet / Kimi /
GPT). The correction applies a pre-existing decision to items it should always
have covered rather than inventing a rule to raise scores — but it was made
post-hoc, and both numbers are reported for that reason.

**A scorer bug, also post-hoc.** Name anchoring used subsequence matching, which
handles dropped letters (`Wrk`/`Work`) but not a substituted one — a model wrote
`Notifi` for `Notify`. Added a four-character common-prefix rule. Trustee and
Fiduciary share no prefix, so the converse trap stays blocked.

**Two scorer bugs caught *before* the run, by its own tests** — worth recording
because both would have produced confident wrong numbers:

- Comparing canonical forms made the scorer **blind to quantity levels**.
  `Infer.canon_prop` rebuilds signed terms through `Infer.st`, which sets level
  0, so `+Claimant^2+Veteran` and `+Claimant+Veteran` compared equal. A fidelity
  scorer that cannot see a dropped "most" is not measuring fidelity.
- Canonicalisation also commutes I- and E-forms, scoring a converted formula as
  structurally identical. Conversion is truth-preserving but moves the subject,
  and mirroring surface order is the property under test — it now grades one
  tier down, as `equivalent`.

## Residual scoring variance, not model error

Three of the five remaining non-matches are multiword modifier phrases where
several decompositions are defensible and the models chose differently from each
other:

| Item | Model | Wrote | Reading |
|---|---|---|---|
| e02 | Sonnet | `-(+Person+(Under+Eighteen*))-Shareholder` | relational — person *under* eighteen |
| e06 | GPT | `-(+Duly+Authorized+Officer)+Signatory` | three-element compound |
| e03 | GPT | `+("self-employed"+Worker)+Claimant` | relational complex, not a compound |

Enumerating every acceptable decomposition would be fitting the gold to the
data. Group E needs redesign — either a scoring rule for modifier phrases, or
retirement of the construction from the headline metric.

## The caveat that bounds everything above

**These sentences are authored, not sampled from statutes.** Clean, single-clause,
policy-register sentences written by someone who knows the notation are biased
toward being translatable. This is an **upper bound**. It shows frontier models
hit the notation reliably on well-formed input; it does not show that
translation is solved on real regulatory text.

The real-text arm is owed, and after this result it is the most valuable
measurement remaining.

## Not yet run

Three of the four planned arms. Only bare few-shot has been measured.

- **Grammar prompting** (ship the BNF) — the published mitigation for
  low-resource formal languages. With a 100% parse rate there is nothing left
  for it to fix here, so it becomes interesting only on real text.
- **A matched FOL arm** — needed before any claim that TFL translates *better*
  than FOL. Requires FOL scoring infrastructure we do not have.
- **LLM→FOL→mechanical transduction** — the sweep found no trace of anyone
  trying it.
