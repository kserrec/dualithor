# Translation-fidelity measurement, prompt revision 2 (PLAN 4.5b / 4.10)

Run 2026-08-02, after the 4.10 prompt change. **Supersedes
`fidelity-report-2026-08-02.md`**, which is kept unedited as the record of what
was measured under the previous prompt but must not be cited.

91 gold sentences + 10 out-of-fragment sentences + 8 arguments, through three
models. **$0.05** — Sonnet and GPT were served entirely from cache, and only two
Kimi batches actually re-called (see "The run that did not count", below).
Per-item results in `data/results/` (gitignored); every failure is reproduced in
full here.

## What changed in the prompt

One guideline, added to rule 2. The prompt already told the model to keep a
verb as the relation name in stem form (`loves` → `Lov`). The gap was
**nominalized** relations, which regulatory text is full of — "the holder of a
permit", "a dependent of a claimant". A model naming that relation `Holder`
produces a formula whose English reading is "some applicant does not **holder**
some permit", because the renderer puts the relation name where a verb goes and
cannot tell a noun from a verb. The prompt now asks for the verb stem (`Hold`,
`Depend`) and says to keep the noun where no verb form exists.

This is a readability change, not a soundness one: a term name is opaque to the
engine, so it cannot move a verdict. It buys coverage of the audit surface,
which is what prompt patching is allowed to buy.

## Results

| model | split | faithful | declines | argument verdicts |
|---|---|---|---|---|
| anthropic/claude-sonnet-5 | eval | 98% (43/44) | 100% (5/5) | 3/3 |
| | dev | 100% (47/47) | 100% (5/5) | 5/5 |
| | **all** | **99% (90/91)** | **100% (10/10)** | **8/8** |
| openai/gpt-5.6-terra | eval | 100% (44/44) | 100% (5/5) | 3/3 |
| | dev | 98% (46/47) | 100% (5/5) | 5/5 |
| | **all** | **99% (90/91)** | **100% (10/10)** | **8/8** |
| moonshotai/kimi-k3 | eval | 100% (44/44) | 100% (5/5) | 3/3 |
| | dev | 100% (47/47) | 100% (5/5) | 5/5 |
| | **all** | **100% (91/91)** | **100% (10/10)** | **8/8** |

**Zero unparseable in 273 attempts. Zero missing. Zero refusals.** Every model
attempted every sentence, and all 24 argument verdicts reproduced end to end.

## Against the previous prompt

| | prompt v1 | prompt v2 |
|---|---|---|
| Sonnet | 100% (91/91) | 99% (90/91) |
| GPT | 98% (88/90 attempted, 1 refused) | 99% (90/91), no refusal |
| Kimi | 100% (91/91) | 100% (91/91) |
| declines | 30/30 | 30/30 |

**The naming guideline did no harm and cleared one problem.** GPT's over-refusal
of `b08` — introduced by the v1 prompt rewrite and left unchased on purpose,
because chasing an eval item is what 4.8 exists to prevent — is gone without
having been targeted. Sonnet lost one item. Net movement is one item in each
direction across 273 attempts, which is noise at this sample size and should be
reported as "unchanged" rather than as an improvement or a regression.

Neither of the two remaining failures involves a relation name, so the guideline
is untested by this set — authored sentences about permits and dependents were
not in it. **Its real test is 4.6**, on regulatory text where nominalized
relations actually occur.

## Every failure, in full

Two items, both graded `wrong`, and **neither is a meaning inversion** — each is
a decomposition choice that the scorer cannot accept because it changes the
structure the gold commits to.

**`e02` (Sonnet, eval) — "No person under eighteen is a shareholder."**

```
gold  −"person under eighteen"−Shareholder
got   −(+Person+(Under+Eighteen*))−Shareholder
```

The gold treats "person under eighteen" as one opaque quoted term. Sonnet
decomposed it into a compound of `Person` and a relational complex `Under` with
the singular `Eighteen*`. That is arguably *more* structure than the gold, not
less, and it is not wrong about the world — but it is a different formula, and
the scorer compares structure under consistent renaming. Recorded as a failure
because that is what it is against this gold; noted here because "the model was
more analytic than our gold" is a different failure from "the model got it
wrong", and the distinction matters for 10.2's fidelity audit.

**`e07` (GPT, dev) — "Some first-time buyer is a non-resident."**

```
gold  +"first-time buyer"+(−Resident)
got   +"first-time buyer"+"non-resident"
```

The mirror image: the gold decomposes `non-resident` into a negated term, which
licenses further inference; GPT kept it opaque as a quoted term, which does not.
Same class — a structural choice, no error about meaning.

Both are dev/eval-labelled and neither has been acted on.

## The run that did not count

The first attempt at this measurement produced **Kimi 100% (71/71)** — twenty
sentences short of 91 — and reported it with a clean summary and exit 0. Two
batches had failed and the runner tallied nothing at all for them, so the lost
sentences left the numerator and the denominator together.

Two defects, both fixed before the run above:

1. **`parse_response` ran outside the retry loop.** PLAN 4.9 had fixed the
   narrow case — an empty 200 body — inside `call_once`, but any *other*
   contentless-but-parseable 200 was still fatal on the first attempt. Both
   failed batches died there with `unexpected response shape`. It is now inside
   the loop: an unreadable body is retryable, a structured provider error still
   fails fast.
2. **A failed batch tallied nothing**, not even `missing`. It now counts every
   sentence, and a run with any missing slot prints `!! INCOMPLETE — these
   numbers are NOT a measurement` and exits non-zero.

A third defect was found by the test written for the first two, never in the
wild: `index 0` on an empty `choices` array raises `Undefined`, not
`Type_error`, so it escaped `parse_response` uncaught and would have killed the
process rather than producing an error.

**What was never diagnosed:** the exact payload OpenRouter returned. The old
error message discarded it — it printed empty — and an empty body was ruled out
directly (yojson raises `Blank input data` on blank input, which would have
produced a different message). Failure messages now carry the body's byte count
and first 300 bytes, so a recurrence will be diagnosable. This is recorded as an
open unknown rather than a solved problem.

## Standing limitations

- **The set is authored, not sampled.** It is an upper bound on fidelity. 4.6 is
  the real-text arm.
- **The naming guideline is now part of the measured system.** Part of the
  rendering's readability comes from a convention we ask the model for, not from
  the engine alone, so the Phase 9 claim reads "given a naming convention, the
  deterministic rendering is auditable". That is a qualification, but it replaces
  an unstated dependency with a stated one: the 4.3 smoke found three models
  choosing three different stems for one verb, so naming was already
  model-dependent and uncontrolled.
