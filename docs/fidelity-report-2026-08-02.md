# Translation-fidelity measurement, corrected re-run (PLAN 4.5b)

Run 2026-08-02. Supersedes `fidelity-report-2026-08-01.md`, which is kept
unedited as the record of what was measured that day but must not be cited.

91 gold sentences + 10 out-of-fragment sentences + 8 arguments, through three
models. 45 API calls, **$0.54** (includes two batches re-called after a
transient empty response). Per-item results in `data/results/` (gitignored);
every failure is reproduced in full below.

## Why this was redone

The 4.4 back-check, run over the 2026-08-01 results, flagged our own gold for
`i04`. It was right.

TFL⁺ quantity levels mark vague quantifiers on the subject term — `^1` many,
`^2` most, `^3` few. **Level 3 marks the predominant *complement*, so its
polarity is flipped.** Straight from the frozen JS reference, which is the
executable specification:

```
+Volunteer^3-Employee    ->  few volunteer is employee
+Volunteer^3+Employee    ->  few volunteer is not employee
```

Our gold paired the sentence *"Few volunteers are employees."* with
`+Volunteer^3+Employee` — the opposite claim. `translate/prompts.ml` taught the
levels as "`^1` many, `^2` most, `^3` few" with no mention of the flip, so all
three models produced the same wrong formula and every one of them was scored
**exact**. Nothing in the pipeline noticed, because a wrong-but-well-formed
formula parses and grades cleanly against a wrong gold.

Both were corrected: the gold now reads `+Volunteer^3-Employee`, and the prompt
states the flip explicitly and teaches it with a worked pair. Changing the
prompt changes the cache key, so the entire run was redone at full cost.

## Result

Reported per split (PLAN 4.8). *Faithful* is over sentences the model
**attempted**; the *missing* column is sentences it declined or dropped, which
the percentage does not see.

| Model | Split | Faithful | Missing | Declines | Argument verdicts |
|---|---|---|---|---|---|
| moonshotai/kimi-k3 | eval | **100%** (44/44) | 0 | 5/5 | 3/3 |
| | dev | **100%** (47/47) | 0 | 5/5 | 5/5 |
| | all | **100%** (91/91) | 0 | 10/10 | 8/8 |
| anthropic/claude-sonnet-5 | eval | **100%** (44/44) | 0 | 5/5 | 3/3 |
| | dev | **100%** (47/47) | 0 | 5/5 | 5/5 |
| | all | **100%** (91/91) | 0 | 10/10 | 8/8 |
| openai/gpt-5.6-terra | eval | **100%** (43/43) | 1 | 5/5 | 3/3 |
| | dev | **96%** (45/47) | 0 | 5/5 | 5/5 |
| | all | **98%** (88/90) | 1 | 10/10 | 8/8 |

Parse rate is 100% across all three models: **zero unparseable formulas in 269
attempts.**

### Against the superseded run

| Model | 2026-08-01 (bad gold) | 2026-08-02 (corrected) |
|---|---|---|
| moonshotai/kimi-k3 | 100% (91/91) | 100% (91/91) |
| anthropic/claude-sonnet-5 | 99% (90/91) | 100% (91/91) |
| openai/gpt-5.6-terra | 96% (87/91) | 98% (88/90), 1 missing |

The corrected numbers are *higher*, which deserves stating plainly: the prompt
fix removed four wrong answers and introduced one new refusal. It did not
remove the error class that mattered.

## Every failure, in full

**`c02` and `c06` — GPT, the E-form sign flip. Unchanged by the prompt fix.**

```
No non-member is eligible.      gold -(-Member)-Eligible   got -(-Member)+Eligible
No non-signatory is bound.      gold -(-Signatory)-Bound   got -(-Signatory)+Bound
```

These are the only meaning-inverting errors in the study, and they survived a
prompt rewrite that fixed everything else. That is the division of labour PLAN
4.4 predicted and this run confirms: **prompt patching buys coverage, the
back-check buys correctness.** The engine reads the returned formulas as "every
non-member is eligible" and "every non-signatory is bound" — the opposite of the
source sentences. Both are dev items.

**`b08` — GPT, a new refusal caused by our own prompt change.**

```
Priya is both a director and a shareholder.    gold +-Priya*+(+Director+Shareholder)
declined: "two predicates joined by conjunction; the notation permits only one
proposition per sentence and has no connective"
```

GPT translated this correctly on 2026-08-01 and refuses it now. The compound
*term* `(+Director+Shareholder)` is exactly what the notation is for, so this is
an over-refusal, not a coverage limit. It is an **eval** item, and it is the
reason the eval faithfulness figure is over 43 attempts rather than 44 — a
refusal is invisible to a percentage computed over attempts, which is why the
missing column is in the table above.

We did not chase it. Attributing it to the added level-3 pair versus the
reworded notation block would need an ablation, and tuning the prompt further
against an eval item is exactly what PLAN 4.8 exists to prevent.

**Everything else is clean.** The three group-E multiword disagreements that the
superseded run recorded (`e02`, `e03`, `e06` — "person under eighteen", "duly
authorized officer", "self-employed worker" read as compounds our `also_ok` list
did not enumerate) no longer appear.

## The gold set is not innocent

Two of this study's five distinct problems were **ours**, not the models':

1. `i04`'s gold asserted the opposite of its sentence, and the prompt taught the
   error, so a wrong answer scored as exact across all three models.
2. The renderer drops quantity levels whenever the predicate is a relational
   complex (`+Officer^1+(Sign+Contract)` reads "some officer sign some
   contract", identical to level 0), and it renders a compound term as "every
   registered and voter is citizen". Both surfaced as back-check false
   positives — see the 4.4 section below.

The first is fixed. The second is inherited from the frozen reference
(`render.ml` gates the quantifier word on `not rel_pred`; port-spec §14
documents the same) and is **still open**. It matters because the rendering is
now an audit surface: a human checking a levelled relational proposition is
shown "some" where the formula says "many".

`test/test_prompts.ml` now pins the level-3 rule against the engine's own
English reading, so the specific error cannot return silently.

## 4.4 back-check, re-measured on the corrected run

91 GPT translations, judged by Sonnet, judge never shown the TFL. 8 calls,
**$0.08**.

- **Acceptance: PASSED.** Both `c02` and `c06` flagged **unaided**, with
  accurate diagnoses — *"quality reversed: no vs every"*, *"quality flipped:
  'no...is bound' vs 'every...is bound'"*.
- **False positives: 2/88 = 2%**, against a pre-registered 5–20% and a 20%
  abandon threshold. Down from 3/87 = 3%, and the item that disappeared is
  `i04` — the check had been right about it all along.
- **Both remaining "false positives" are real defects in our renderer, not judge
  errors** — `i06` (level dropped on a relational predicate) and `d03`
  ("registered voter" read back as "registered and voter"). The true
  false-positive rate against a correct renderer is **0/88**.

## What this does and does not establish

Established: models translate this authored set into TFL essentially perfectly,
with a 100% parse rate, and they honour the decline contract. The
pre-registered ≥70% threshold is cleared by a wide margin.

Not established, and unchanged by the correction:

- **These sentences are authored, not sampled.** Written by someone who knows
  the notation, they are biased toward being translatable. This is an upper
  bound and must be reported as one. PLAN 4.6 is the real-text arm.
- **Nothing here is comparative.** Core claim 1 says TFL translation is *more*
  faithful than FOL. No FOL arm has been run. PLAN 4.7.
- **Coverage, not fidelity, is now the open question.** A tool that refuses most
  real regulatory sentences is a demonstration, not a system.
