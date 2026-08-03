# Real-text sampling protocol (PLAN 4.6)

**Pre-registered 2026-08-02, before any sentence was read, labelled or scored.**

The coverage number this run produces is the project's largest open question, and
it is trivially manipulable: pick sentences that look translatable and coverage
goes up without anything being true. So the procedure is fixed here first, it is
mechanical end to end, and `bench/sample_real.ml` implements exactly it. **No
sentence is dropped, swapped or re-sampled after labelling begins.** If the
procedure turns out to have a flaw, the fix is a new dated protocol and a fresh
sample, never an edit to this one.

## Source

US federal regulation, which is public domain — the standing rule against
committing corpora does not bite, and the sampled sentences are committed
alongside their labels so the measurement is reproducible.

- **eCFR API**, snapshot date `2026-01-01`, raw XML:
  `https://www.ecfr.gov/api/versioner/v1/full/2026-01-01/title-{T}.xml?part={P}`
- Raw downloads live in `data/raw/` (gitignored). Only the sample is committed.

Three parts, chosen **before fetching** for being eligibility-and-benefit rules —
the domain this project is aimed at — and for coming from three different
agencies, so no single drafting style dominates:

| Part | Subject | Agency |
|---|---|---|
| 7 CFR 273 | SNAP: certification of eligible households | USDA |
| 20 CFR 416 | Supplemental Security Income for the aged, blind, and disabled | SSA |
| 24 CFR 5 | HUD programs: general requirements | HUD |

## Extraction

Raw text is taken from primary source, never through a summariser — the standing
constraint after four of six literature sweeps caught a PDF summariser
fabricating content.

1. Take the contents of every `<P>` element. Headings, tables, notes and
   citations-only elements are not `<P>` and are therefore excluded.
2. Strip the inline tags `<I>` and `<E>` (the only two that occur) and decode
   XML entities.
3. Strip a leading enumerated-paragraph marker (`(a)`, `(1)`, `(iv)`, and runs of
   them), which is numbering rather than sentence content.
4. Split into sentences on a period, question mark or colon followed by
   whitespace and a capital letter, protecting a fixed list of regulatory
   abbreviations that would otherwise split mid-sentence: `U.S.C.`, `C.F.R.`,
   `Pub. L.`, `No.`, `Nos.`, `Sec.`, `Secs.`, `e.g.`, `i.e.`, `etc.`, `cf.`,
   `Dr.`, `Mr.`, `Mrs.`, `Ms.`, `St.`, `Jr.`, `vs.`, and single capital letters
   followed by a period.

## Candidate filter

Deliberately minimal, because **every filter biases the coverage number** and the
obvious ones bias it upward.

- Must end in `.`
- Must contain at least 5 whitespace-separated words.
- Must contain at least one lowercase letter (excludes all-caps fragments).

**There is no upper length bound, and there must never be one.** The
pre-registered prediction (`scope-and-predictions.md` §1B.1) is that multi-clause
structure is the *dominant* refusal reason. Dropping long sentences would delete
the very evidence the run exists to gather and would inflate coverage by exactly
the amount that matters.

Near-duplicates are **not** removed. Regulation repeats itself, and that
repetition is a real property of the text.

## Sample

- Candidates from each part are kept in document order.
- From each part take every *k*-th candidate, `k = floor(N_part / 20)`, starting
  at index 0, until 20 are taken. Target **60 sentences, 20 per part.**
- Ties and short-falls resolve by taking the remaining candidates in order.
- Deterministic: no random seed, no shuffling. Re-running `sample_real.ml`
  against the same snapshot reproduces the sample exactly.

## Labelling, and the order it happens in

1. The sample is produced and committed **first**.
2. Then every sentence is hand-labelled `in` or `out` of the fragment, with a
   refusal-reason category for every `out`: `tense`, `arithmetic`,
   `cross-reference`, `defeasible`, `multi-clause`, `other` (with a note).
   This is the answer key the router (5.1) is scored against — without human
   ground truth, "the router said this was outside the fragment; was it right?"
   has no answer.
3. Then gold TFL is hand-written for every `in` sentence and engine-verified.
4. **Only then** does anything go to a model.

The labels are a human judgement about the *fragment*, not a prediction of what
the engine will do. Where the two disagree, that disagreement is the router
measurement — it is not a licence to change the label.

## Implementation corrections

Recorded because the protocol above is pre-registered and its implementation is
not allowed to drift from it silently.

- **2026-08-02, before labelling began.** The first implementation decoded only
  *named* XML entities and a short list of decimal numeric ones, so hex
  references — `&#xA7;` for the section sign, `&#x2014;` for the em dash — came
  through as literal text in the sampled sentences. The protocol says "decode XML
  entities"; the code did not. Fixed by decoding decimal and hex numeric
  character references generically, and the sampler re-run. No sentence had been
  labelled at that point, so this is an implementation fix rather than a
  re-sample.

## Known artifacts of the splitter, to be handled in labelling, not in code

Recorded rather than fixed, because tuning the splitter while looking at the
sampled text is how an instrument gets shaped to taste.

- A run-in heading is not split off when it is followed by an enumerated marker
  rather than a capital: *"Responsibility of obtaining verification. (i) The
  household has primary responsibility…"* arrives as one item. The splitter
  matches the protocol as written; the protocol is what is limited. Label such an
  item on its propositional content.
- The minimal filter admits list fragments that are not assertions at all —
  *"Up to three months, at State agency option."* Nothing is dropped for this,
  because a system pointed at a real regulation meets them. They are labelled
  `not-a-proposition`, and coverage is reported **both** over the whole sample
  and over the propositional subset, so neither number can hide the other.
