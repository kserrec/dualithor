# Definitional-text protocol (PLAN 4.6, second sample)

**Pre-registered 2026-08-02, before any sentence of the new sample was fetched,
read or labelled.** `PROTOCOL.md` and its 5%/12% result are frozen and are not
revised by anything here.

## Why there is a second sample

The first sample measured **normative** regulatory text and found coverage of
3/60 strict, 7/60 treating deontic modality as ambient. All three sentences that
survived the strict reading are the same kind of sentence:

```
r25  Your medical source is not a qualified medical source…
r41  ADA means the Americans with Disabilities Act of 1990…
r54  …selection is subject to the income-eligibility requirements in § 5.653.
```

Definitional and predicative, none of them normative. That is a lead, not a
finding — three items is nothing — and it is the kind of lead that becomes
p-hacking the moment it is pursued without saying so first.

## Hypothesis

> **H.** Term logic fits regulatory text that *says what things are* and fails on
> text that *says what must happen*. Coverage is a property of the **genre** of a
> passage, not of the corpus it comes from.

This is a real prediction and it can fail. If definitional passages come back
near the 5–12% normative baseline, **H is refuted**, and the conclusion is
stronger and worse for the project than the first sample alone: the fragment
does not fit regulatory prose of any genre, and no amount of domain-shopping
inside regulation will help.

## Pre-registered predictions

Recorded before sampling, scored as measured, never edited afterwards.

| | Domain | Prediction (strict coverage) |
|---|---|---|
| **D1** | **Definitions sections** of the same three parts — 7 CFR 273, 20 CFR 416, 24 CFR 5 | **35–60%** |
| **D2** | **Standards of identity**, 21 CFR 131 / 133 / 137 — definitional regulation, different agency and subject matter | **35–60%** |

D1 holds the corpus constant and varies only the genre, which is the cleanest
possible test of H. D2 varies agency, subject and drafting house style as well,
to check that any D1 effect is not an artifact of three particular parts.

**Both are reported whatever they show**, alongside the normative baseline, and
no further domain is added after seeing these numbers without a third dated
protocol saying so first.

## Method

Identical to `PROTOCOL.md` — same extraction, same sentence splitter, same
minimal candidate filter with no upper length bound, same deterministic
every-*k*-th sampling, same blocker categories and criteria in `CRITERIA.md`.
The extraction pipeline is shared code (`bench/cfr.ml`), not a reimplementation,
so the two samples cannot drift apart.

**One difference, and it is the independent variable:** paragraphs are drawn
only from sections whose heading contains "Definition" (D1), or from whole parts
that are standards of identity (D2).

Selection is by **section**, never by sentence. Picking sentences that look
definitional — matching "means", say — would select for what the fragment can
already do and would guarantee a high number that means nothing. Genre is chosen
at the section level and then every candidate sentence in those sections enters
the pool, tractable or not.

Target 30 sentences per domain, so the two samples together are the same order
of size as the first.

## What a positive result would and would not mean

Recorded now so it cannot be overstated later.

If definitional coverage is high, the honest claim is *"we can formalize the
definitions section of a regulation"*. That is genuinely useful — it is use case
(b), checking a rule set for self-consistency, and it is what the already-built
and currently-unused definitions layer (PLAN 6.2) exists for. **It is not**
*"we can verify eligibility decisions"*. The decisions live in the normative text
measured by the first sample, and that number stays 5%.

## Results, scored as measured

| | Domain | Predicted | **Measured (strict)** | Verdict |
|---|---|---|---|---|
| D1 | Definitions sections | 35–60% | **25%** (5/20) | prediction **wrong**, but 5x the normative baseline |
| D2 | Standards of identity | 35–60% | **3%** (1/30) | prediction **badly wrong** |
| — | Normative baseline (PROTOCOL.md) | 25–45% | 5% (3/60) | prediction wrong |

**H is partly supported and partly refuted, and the split is informative.**

Genre does matter, in the predicted direction: definitions sections reach 25%
against 5% for normative text from the same corpus, a fivefold difference with
the corpus held constant. That is the cleanest comparison available and it
supports the "says what things are" half of the hypothesis.

But the effect is much smaller than predicted, and **D2 refutes the assumption
that "definitional" is one genre.** Standards of identity define foods —
*"Cream contains not less than 18 percent milkfat"* — and they do it
**numerically**. Arithmetic blocks 47% of them, the highest single blocker
anywhere in this project. A standard of identity is a quantitative
specification wearing a definition's grammar, and term logic has no more
purchase on it than on an obligation.

**What actually distinguishes the tractable sentences.** All six in-fragment
items across both domains are *naming* or *class-inclusion* statements —
`ADA means the Americans with Disabilities Act of 1990`,
`Nonmedical source means a source of evidence who is not a medical source`,
`SSI benefits also include any federally administered State supplementary payments`.
The fragment fits **taxonomy**: statements that place a term in a hierarchy or
give it a name. It does not fit description, quantification, or obligation, and
"definitional" turned out to be a poor proxy for "taxonomic".

**7 CFR 273 contributed nothing to D1**: it contains no section headed
"Definitions" at all — SNAP's definitions live in 7 CFR 271.2, a part outside
the pre-registered fetch list. That is recorded rather than repaired. Adding a
source after seeing a zero is exactly the adjustment this protocol exists to
prevent; a third dated protocol could add it deliberately.

**No further domain was sampled after seeing these numbers.**
