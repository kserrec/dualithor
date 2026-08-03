# Coverage of real regulatory text (PLAN 4.6)

Measured 2026-08-02. **This is the project's central empirical result.**

Three samples drawn mechanically from the eCFR under protocols pre-registered
before any sentence was fetched or read. All raw material, labels and criteria
are committed under `data/fidelity/real/`.

**Every number below regenerates from the committed labels**:
`opam exec -- dune exec bench/coverage_stats.exe`. Committed labels with no
committed derivation is a quiet trap — edit one label and the tables go stale
with nothing to say so.

## Headline

| Genre | n | Strict coverage | Ambient-deontic | Pre-registered prediction |
|---|---|---|---|---|
| Normative regulation (7 CFR 273, 20 CFR 416, 24 CFR 5) | 60 | **5%** (3) | 12% (7) | 25–45% — **wrong** |
| Definitions sections (20 CFR 416, 24 CFR 5) | 20 | **25%** (5) | 25% | 35–60% — **wrong** |
| Standards of identity (21 CFR 131/133/137) | 30 | **3%** (1) | 7% | 35–60% — **wrong** |

"Strict" = the sentence's content can be written as one TFL proposition without
dropping meaning. "Ambient-deontic" = the same, treating *shall/must/may* as a
property of the register rather than as content. Both are reported because the
choice is a real judgement call that moves the number; neither was picked to
flatter the result. Criteria in `data/fidelity/real/CRITERIA.md`.

**All three pre-registered predictions were wrong, and all three are recorded as
wrong.** Reporting how a prediction fared is the whole reason to write one down.

## What blocks formalization, and by how much

Every applicable blocker is recorded per sentence, not one "primary reason" —
**46 of the 60 normative sentences are blocked more than once**, and that fact is
the finding. No single lever fixes a sentence that three things block.

| Blocker | Normative | Definitions | Standards of identity | Generalises beyond TFL? |
|---|---|---|---|---|
| multi-clause | 65% | 40% | 37% | **No** — our one-proposition-per-sentence contract; FOL handles conjunction |
| deontic (*shall/must/may*) | 48% | 5% | 43% | **Yes** — needs a modal logic |
| cross-reference | 35% | 25% | 27% | **Yes** — needs a document model, not a sentence model |
| tense | 27% | 5% | 10% | **Yes** |
| arithmetic | 25% | 5% | **47%** | **Yes** |
| not-a-proposition | 18% | 25% | 30% | shared (headings, list fragments, imperatives) |
| defeasible | 7% | 10% | 0% | **Yes** — and it is the *rarest* |

Two categories, `deontic` and `not-a-proposition`, were added to PLAN 4.6's list
because the corpus forced them. Folding either into "other" would have hidden the
result.

### The surprise

**Defeasibility is the rarest blocker.** The field treats exceptions as *the*
hard problem in legal formalization — it is why Phase 7 existed. In this sample
it blocks 7% of normative sentences and 0% of standards of identity, while
arithmetic and cross-reference — both routinely waved away as engineering — block
three to five times as much.

## Ceiling analysis: what any given lever would buy

Computed over the normative sample: coverage if a set of blockers were solved.

| If we could handle… | Coverage |
|---|---|
| nothing (today) | 5% |
| ambient deontic (a convention, not a build) | 12% |
| **sentence splitting only** | **8%** |
| splitting **and** ambient deontic | 28% |
| …plus opaque cross-references | 38% |

**Sentence splitting alone buys three points.** PLAN pre-authorised it as the
cheap conditional build if multi-clause structure dominated. Multi-clause does
dominate — and the lever is still nearly worthless, because the sentences it
would fix are usually deontic as well. A lever aimed at the most common blocker
can be worth almost nothing when blockers co-occur; that is the practical lesson
of the multi-blocker labelling.

## Genre matters, but "definitional" was the wrong cut

Definitions sections reach five times the normative baseline **with the corpus
held constant**, which is the cleanest comparison available and supports the idea
that coverage is a property of genre.

But standards of identity are definitions too — they define what cream *is* — and
they came back **worse than obligations**, at 3%. They define numerically:

> *Cream contains not less than 18 percent milkfat.*
> *The egg yolk solids content is not less than 1 percent by weight of the finished food.*

Arithmetic blocks 47% of them, the highest single blocker measured anywhere in
this project. **A standard of identity is a quantitative specification wearing a
definition's grammar.**

What actually distinguishes the six tractable sentences across both samples is
that every one is a **naming or class-inclusion** statement:

```
ADA means the Americans with Disabilities Act of 1990.
Nonmedical source means a source of evidence who is not a medical source.
SSI benefits also include any federally administered State supplementary payments.
```

The fragment fits **taxonomy** — placing a term in a hierarchy or giving it a
name. Not description, not quantification, not obligation.

## The claim this supports, and the one it kills

**Killed:** *point this at a regulation and verify eligibility decisions.* The
decisions live in normative text, and normative text is 5%. `PLAN.md` said before
the measurement that "a tool that refuses 80% of real sentences is a
demonstration, not a system"; the real figure is 88–95%.

**Also killed, and this one matters to the field rather than to us:**
*surface-closeness to English buys coverage.* It does not. What blocks
formalization is not syntactic distance from natural language — it is missing
expressive primitives. A logic that looks like English fails on the same
sentences as one that does not, for reasons having nothing to do with looking
like English. That is a correction to a motivation much of this subfield leans
on, including our own.

**Not touched:** the two contributions that were never coverage-dependent — the
auditability study (Phase 9), which needs ~30 items and has 91 engine-verified
ones already, and closed-form missing-premise computation (6.1), which works on
whatever parses.

## Why these numbers are worth anything

Not because they are favourable — they are not. Because the procedure was fixed
first:

- Sampling protocol pre-registered before fetching (`PROTOCOL.md`), genre
  hypothesis and both domain predictions pre-registered before the second fetch
  (`PROTOCOL-2.md`).
- **No upper length bound** on candidate sentences, deliberately: dropping long
  sentences would have deleted the evidence for the dominant blocker and inflated
  coverage by exactly the amount that matters.
- Genre selected at the **section** level, never by sentence. Choosing sentences
  that look definitional would have selected for what the fragment can already do.
- Raw text parsed from primary source XML, never through a summariser.
- 7 CFR 273 contributed nothing to the definitions sample because it contains no
  section headed "Definitions". Recorded rather than repaired — adding a source
  after seeing a zero is the adjustment the protocol exists to prevent.
- Every prediction that failed is marked failed.
