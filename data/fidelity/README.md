# The fidelity gold set

The measuring instrument for the translation-fidelity experiment: can current
models translate English into TFL faithfully enough for the pipeline to be
worth building? That is the project's largest open risk — plus-minus notation
is essentially absent from pretraining data where FOL is abundant — and it is
answerable cheaply, so it is answered before any layer work.

**Everything here is authored by us and committed.** `test/test_fidelity_set.ml`
verifies it on every `dune test` run: every gold formula parses, every
argument's stated verdict is the engine's own, and no item leaks in from the
few-shot prompt.

## Composition

91 translatable sentences (67 standalone + 24 inside arguments), 8 arguments,
10 sentences that should be declined. 85 items across 51 tags.

| Group | Items | What it isolates |
|---|---|---|
| A | 10 | The four categorical forms, bare terms |
| B | 8 | Singular terms, including quoted names and one definite description |
| C | 8 | Negative terms, including double negation |
| D | 8 | Compound (conjunctive) terms |
| E | 8 | Quoted multiword terms — the hyphen trap |
| F | 8 | Relationals with a particular object |
| G | 6 | Relationals with a universal object (the ∀∃ / ∃∀ distinction) |
| H | 5 | Relational subjects and nested objects |
| I | 6 | TFL⁺ quantity levels |
| J | 8 arguments | Multi-premise items that **reuse a relation or term** |
| K | 10 | Out of fragment — the model should decline |

Group J exists for a specific question the 4.3 smoke could not answer. Across
models, relation naming diverged (`Wrk` / `Work_for` / `Work`), which is
harmless because we never mix models inside one argument. What would *not* be
harmless is one model naming the same relation two ways across the premises of
a single argument — no inference would connect them. No item in the smoke
reused a relation, so that failure mode is untested. Every group J item reuses
one.

Group K is the router measurement. A model that translates these anyway has
failed the half of the contract the escalation claim depends on, and a lossy
formula that parses is worse than a refusal.

## The dev/eval split (PLAN 4.8)

Every item carries `"split": "dev"` or `"split": "eval"`. **42 dev, 43 eval.**

The reason for it is narrow and worth stating exactly. The moment a prompt is
changed in response to an observed error, the items that revealed that error
stop being evaluation data — a score over them is now partly a score of our own
tuning. Nothing has been tuned yet, so the split is drawn *now*, while the line
is still clean:

- **dev** may be read, argued over, and lifted verbatim into the few-shot
  prompt. That is what it is for.
- **eval** may never appear in the prompt, and may not be moved to dev after
  its result is known.

`test/test_fidelity_set.ml` enforces all three of the ways this goes wrong:

1. No eval sentence or formula appears in the few-shot prompt.
2. The eval id list is **pinned in the test file**, so relabelling an item that
   came back wrong is a reviewable code change, never a quiet data edit.
3. **No sentence or formula is shared across the split.** This one is not
   theoretical: group J's arguments are assembled from the same material as
   groups A, F and I, and the first cut of the split had three collisions
   (`a01`/`j04`/`j05`, `a03`/`i01`/`j08` among them). Promoting `a01` into the
   prompt would have contaminated eval item `j04` invisibly. Each collision
   class now sits wholly on one side.

Assignment is otherwise stratified within each group so both halves carry the
same constructions, with one deliberate exception: **every item already
implicated in an observed error is forced to dev**, because a prompt fix for it
is foreseeable. Those are `c02` and `c06` (the E-form sign flip the 4.4
back-check caught), `i04` (the `few`-inversion error in our own gold, which the
4.2 prompt taught), `i06` (which exposed the renderer dropping quantity levels
on relational predicates), and `b04` (our disputable definite-description
convention).

**Two coverage holes in the eval half follow directly from that rule, and both
are real limitations of any eval-only number:**

- *No negative-term E-form.* Both such items (`c02`, `c06`) are burned. Eval
  still has E-forms from groups A, D, E and F.
- *No quantity level 3.* `i04` is the only level-3 item in the set, and it is a
  dev item. Level 3 is unmeasurable on eval. (Its gold was also **wrong** until
  2026-08-02 — `+Volunteer^3+Employee`, the opposite of its own sentence,
  because level 3 marks the predominant complement and so inverts the English
  polarity. Corrected, along with the `prompts.ml` wording that taught the
  error; the rule is now pinned in `test/test_prompts.ml`.)

4.6 should fill both when it adds real-text items.

**The split changed no item's content.** When it was drawn, `items.jsonl` was
byte-identical to the version the 4.5b run graded apart from the added `split`
field, so that run re-cut by split at zero cost. (`i04`'s gold was corrected
later the same day — see below — which did require re-running.)

## Fields

`kind` is `sentence`, `argument`, or `decline`.

- `tfl` — the gold formula. Verified to parse.
- `also_ok` — alternate formalizations judged equally faithful. Recorded so
  scoring does not punish a defensible structural choice, and verified to be
  genuinely different propositions from the gold (an alternate identical to the
  gold is noise in the scorer).
- `verdict` on an argument — verified to be what `Tfl_verify.check` returns.
- `reason` on a decline — why the notation cannot carry the sentence.
- `split` — `dev` or `eval`. See "The dev/eval split" above.
- `note` — where our convention is an engineering decision rather than a
  sourced one. `b04` is the live example: definite descriptions have **no
  dedicated treatment anywhere in the tradition** (lit sweep 4, Q2), so reading
  "the Secretary" as a singular term is our choice, and models may reasonably
  differ.

## How this should be scored

Exact string match against the gold is the **wrong** primary metric, and the
4.3 smoke showed why: term names are arbitrary. Three models wrote `Wrk`,
`Work_for`, and `Work` for the same verb, and all three were right. Charging a
model for choosing a different stem measures nothing.

The intended layers, weakest to strongest evidence:

1. **Parses.** Syntax only. This is what the smoke measured at 100%, and it was
   never the part in doubt.
2. **Structurally isomorphic to the gold** under a consistent renaming of
   terms — same shape, same signs, same nesting, with a bijection between term
   names that is stable across the item. This is the real "got it right"
   metric.
3. **Semantically equivalent** per the engine's own equivalence decision, for
   formulas that are shaped differently but say the same thing.
4. **Faithful anyway** — a judgment call for what is left, and the only layer
   that needs a human or an LLM judge.

Arguments get a fifth: does the model's translation of the whole argument
yield the gold verdict? That is the end-to-end question, and it is the one that
can be right even when individual formulas differ.

## Known gaps

**These sentences are authored, not sampled from real statutes.** Sentences
written by someone who knows the notation are biased toward being translatable,
which flatters every number here. A real-text arm — sampled from public-domain
regulatory sources — is still needed and is not in this file. Until it exists,
results from this set are an upper bound, and should be reported as one.

The policy register is imitated (eligibility, trusteeship, corporate governance,
benefits) but the sentences are ours.
