# Labelling criteria for the real-text sample (PLAN 4.6)

> **Historical scope:** these criteria and the committed labels apply to the
> frozen flawed 2026-08-02 samples. The corrected 2026-08-11 samples are
> unlabeled; see `ERRATUM-2026-08-11.md`.

Written before labelling, applied to all 60 sentences, and fixed thereafter.

A sentence is **in-fragment** if its propositional content can be written as
**one** TFL proposition without dropping meaning. That is the translation
prompt's own contract: *"Use one proposition per sentence. If a sentence needs
two, it does not belong in the notation — decline it"* and *"never drop structure
it does have."*

Every sentence records **all** blockers that apply, not one. A single "primary
reason" would hide the fact that most real regulatory sentences are blocked
several times over, and the whole point of this measurement is to learn which
layer to build next.

## Blocker categories

The five PLAN 4.6 names, plus two the corpus forced:

| Category | Meaning |
|---|---|
| `tense` | tense, aspect, dates, deadlines, temporal ordering |
| `arithmetic` | numbers, comparatives, thresholds, proportions, counting |
| `cross-reference` | rules incorporated by section number, not merely named |
| `defeasible` | exceptions — *unless*, *except that*, *as long as* |
| `multi-clause` | more than one independent restriction, condition or predication |
| **`deontic`** | *shall*, *must*, *may* — obligation, prohibition, permission |
| **`not-a-proposition`** | headings, list fragments, imperatives, bare noun phrases |

`deontic` and `not-a-proposition` are additions to PLAN's list. Both were forced
by the data rather than chosen: modality is in the majority of these sentences,
and the minimal candidate filter admits fragments on purpose (see PROTOCOL).
Adding a category the corpus demands is honest; silently folding it into `other`
would hide the finding.

## The two judgement calls that move the number

Neither has an obviously correct answer, and each swings coverage by a lot. So
**both readings are labelled and both numbers are reported**, rather than one
being chosen quietly.

**1. Is deontic modality content, or ambient?**

- **Strict reading:** *"The State agency shall develop a NOE"* asserts an
  obligation. Rendering it as *"every State agency develops a NOE"* turns a rule
  into a false claim about the world. The modality is content, so the sentence is
  out.
- **Ambient reading:** the entire document is a body of rules. *"Shall"* marks
  that this is a rule rather than a fact — it is a property of the register, not
  of the proposition — so the propositional content is *"every State agency
  develops a NOE"* and the sentence is in.

Both are defensible. The strict reading is the honest default for a system that
claims to preserve meaning; the ambient reading is what a legal-formalization
project would normally assume. Reported as `coverage_strict` and
`coverage_ambient_deontic`.

**2. Is a cross-reference a blocker, or an opaque term?**

- A reference that merely **names** something — *"the requirements in § 5.653"* —
  can be carried as one quoted term without changing truth conditions.
- A reference that **incorporates rules** — *"in accordance with § 273.2(f)(8)(ii)"*
  qualifying how an action must be performed — cannot: the referenced content is
  doing work the formula would silently drop.

Only the second is labelled `cross-reference`. Where the distinction is arguable
it is recorded in the note.

## Standing rule

These labels are a human judgement about **the fragment**, not a prediction of
what the engine or a model will do. Where the router later disagrees with a
label, that disagreement *is* the router measurement (PLAN 5.1) and is never a
licence to revise the label.
