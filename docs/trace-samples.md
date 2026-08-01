# Trace samples (PLAN 3.3, regenerated after 3.4)

Verbatim traces from `Tfl_verify.check`, one per decision style, for the
legibility review. Every trace line is

```
n. [rule] plus-minus step — English gloss  (from parent lines)
```

with the gloss produced by the deterministic renderer (1.9) — the same strings
the back-translation check (4.4) will rely on. Proof-carrying verdicts also get
a one-sentence `explanation`. Certificate verdicts (P/Z, numerical) have no
step sequence, so the trace frames the argument itself: numbered premises, then
the conclusion — no verdict is ever traceless.

**What changed in 3.4.** A relational complex in subject position used to gloss
as *"some lov some girl is boy"*. Glosses now describe the *converse*
orientation where one exists — *"some boy lov some girl"* — which states the
same thing subject-first. The formal step is never rewritten; only its English
gloss moves. Conversion is applied only to the forms it is valid on (see
"Where this does not reach", below).

## Categorical (P/Z decision)

`−M+P · −S+M ⊢ −S+P` — **valid**, method `PZ`

```
1. [premise] −M+P — every m is p
2. [premise] −S+M — every s is m
3. [conclusion] −S+P — every s is p
```

## Relational (direct derivation)

`−Man+(Lov+Woman) · −Woman+Human ⊢ −Man+(Lov+Human)` — **valid**, method `derivation`

```
1. [premise] −Man+(Lov+Woman) — every man lov some woman
2. [premise] −Woman+Human — every woman is human
3. [DON] −Man+(Lov+Human) — every man lov some human  (from 2, 1)
```

Explanation: *Because every man lov some woman, and every woman is human, every
man lov some human.*

## Relational (indirect proof)

`+Boy+(Lov+Girl) · −Boy−(Lov+Coward) ⊢ +Girl−Coward` — **valid**, method `indirect`

```
1. [premise] +(Lov+Girl)+Boy — some boy lov some girl
2. [premise] −(Lov+Coward)−Boy — no boy lov some coward
3. [counterclaim] −Girl+Coward — every girl is coward
4. [DON] +(Lov+Coward)+Boy — some boy lov some coward  (from 3, 1)
5. [contradiction] ⊥ — which is impossible  (from 2, 4)
```

Explanation: *Because some lov some girl is boy, and no lov some coward is boy,
and every girl is coward, it would follow that no lov some coward is boy, yet
some lov some coward is boy — which is impossible.*

## Where this does not reach

**1. The explanation sentence still uses the old form — the visible gap.**
Compare the trace lines above ("some boy lov some girl") with the explanation
sentence directly below them ("some lov some girl is boy"). They describe the
same premises. The trace layer is ours to shape, but `explain_proof` is part of
the frozen 1.9 rendering contract, verified byte-exact against the reference
engine, so improving it is a deliberate deviation with the full engine gate
rather than a free change. **Needs a decision.**

**2. Universals with a relational subject cannot be converted.** "Every head of
a horse is a head of an animal" is an A-form, and A-forms do not convert —
"every mortal is a man" does not follow from "every man is mortal". So this
one keeps the awkward shape, and no orientation trick can fix it:

```
1. [premise] −Horse+Animal — every horse is animal
2. [It] −(Head+Horse)+(Head+Horse) — every head some horse head some horse
3. [DON] −(Head+Horse)+(Head+Animal) — every head some horse head some animal  (from 1, 2)
```

Reading these well would need real English machinery — inserting "of",
building relative clauses — inside the frozen renderer.

**3. Term names render bare and lowercased.** `Lov` glosses as "lov". This is
not an engine matter: the translation prompts (4.2) choose the term names, so
naming the relation `Loves` glosses as "loves".

**4. Predicates take no article** in the general-subject reading: "every horse
is animal", not "is an animal". The article logic only fires when the subject
is a specific individual ("Socrates is a man"). Another frozen-renderer item.

**5. DON parent order** is as the engine records it (`from 2, 1`), which can
read backwards relative to the narrative.

Items 2, 4 and 5 are properties of the frozen rendering contract; item 1 is the
one where the inconsistency is now visible enough to be worth a decision.
