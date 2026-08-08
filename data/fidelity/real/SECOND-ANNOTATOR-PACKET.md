# Independent regulatory-sentence annotation packet

> **Canonical text/fallback copy.** The participant-facing version is
> `INDEPENDENT-ANNOTATION.html`. It presents the same nine rows as an offline form and
> exports a structured JSON answer file.

**Packet version:** 2026-08-08-v1

**Estimated work:** 30–45 minutes

**External consequence:** none. This is an offline research annotation; it creates no
account, spends no money, publishes nothing, and asks for no personal information.

## Independence statement

Please do not open any other file in this repository and do not discuss individual
sentences with the project author before returning your completed judgments. The other
files contain the project-side decisions. This packet intentionally contains none of
those labels or formulas.

When finished, confirm this statement:

> I labelled these sentences without viewing the project-side labels or formulas.

## The decision

For each sentence, decide whether all of its asserted meaning can be represented as
**one** proposition in the term-logic notation below.

- Mark `in` only if you can give one complete formula.
- Mark `out` if any asserted tense, arithmetic, modality, exception, cross-sentence
  reference, independent clause, or other structure would be lost.
- A formula merely parsing is not enough.
- A quoted phrase is one atomic term. Quote a genuine multiword name or lexical unit, but
  do not quote a structured clause merely to force it through.
- The engine does not resolve pronouns or other anaphors from earlier sentences. A `*`
  marks a fixed individual; it does not discover what a pronoun refers to.
- A section citation may remain inside a term when it only names that term. Mark `out` if
  the cited rule's contents are needed for the assertion.
- Read regulatory `means` as an exhaustive definition. If both sides are general classes,
  one-way inclusion is incomplete. If both sides name one individual thing, the singular
  identity form below is symmetric.

## Notation

Each proposition has four parts and no spaces:

```text
(quantity sign)(subject term)(quality sign)(predicate term)
```

```text
−S+P     every S is P
−S−P     no S is P
+S+P     some S is P
+S−P     some S is not P
±Ada*+P  Ada is P; * marks a fixed individual and ± is wild quantity
```

Terms containing spaces or punctuation must be quoted, for example
`−"service animal"+Animal`. A binary relation has the shape
`−Contract+(Govern±Law*)`. Two singular terms can state identity, for example
`±Twain*+Clemens*`.

Use the blocker names `tense`, `arithmetic`, `cross-reference`, `anaphora`,
`defeasible`, `multi-clause`, `deontic`, `not-a-proposition`,
`definitional-equivalence`, or a short plain-language name if none fits.

## Sentences to label

The order is deliberately different from source order. Repeated text is retained because
the source sampling retained it. Judge every row independently before comparing rows.

### S01 — 24 CFR 5

Section 214 means section 214 of the Housing and Community Development Act of 1980, as
amended (42 U.S.C. 1436a).

- Label (`in` or `out`):
- Exact formula if `in`:
- All blockers if `out`:
- One- or two-sentence rationale:

### S02 — 20 CFR 416

Your medical source is not a qualified medical source as defined in § 416.919g.

- Label (`in` or `out`):
- Exact formula if `in`:
- All blockers if `out`:
- One- or two-sentence rationale:

### S03 — 21 CFR 137

It is referred to hereafter as the No. 72 sieve.

- Label (`in` or `out`):
- Exact formula if `in`:
- All blockers if `out`:
- One- or two-sentence rationale:

### S04 — 20 CFR 416

SSI benefits also include any federally administered State supplementary payments.

- Label (`in` or `out`):
- Exact formula if `in`:
- All blockers if `out`:
- One- or two-sentence rationale:

### S05 — 24 CFR 5

However, selection is subject to the income-eligibility and income-targeting requirements
in § 5.653.

- Label (`in` or `out`):
- Exact formula if `in`:
- All blockers if `out`:
- One- or two-sentence rationale:

### S06 — 20 CFR 416

Disability program means the Federal program for providing supplemental security income
benefits for the blind and disabled under title XVI of the Act, as amended.

- Label (`in` or `out`):
- Exact formula if `in`:
- All blockers if `out`:
- One- or two-sentence rationale:

### S07 — 24 CFR 5

ADA means the Americans with Disabilities Act of 1990 (42 U.S.C. 12101 et seq.).

- Label (`in` or `out`):
- Exact formula if `in`:
- All blockers if `out`:
- One- or two-sentence rationale:

### S08 — 20 CFR 416

Nonmedical source means a source of evidence who is not a medical source.

- Label (`in` or `out`):
- Exact formula if `in`:
- All blockers if `out`:
- One- or two-sentence rationale:

### S09 — 24 CFR 5

ADA means the Americans with Disabilities Act of 1990 (42 U.S.C. 12101 et seq.).

- Label (`in` or `out`):
- Exact formula if `in`:
- All blockers if `out`:
- One- or two-sentence rationale:

## Return format

Preferred: open `INDEPENDENT-ANNOTATION.html`, complete all nine rows, confirm the
independence statement, click **Export completed answers**, and return the downloaded
`tfl-independent-annotation-complete.json` file unchanged. The HTML file sends nothing
over the network, uses no browser storage, and does not embed answers into itself.

If the HTML form cannot run, return a completed copy of this Markdown file instead. Do not
look at the rest of the repository to check whether your formulas parse; the project will
run that mechanical check only after your labels are locked.
