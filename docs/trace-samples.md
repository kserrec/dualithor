# Trace samples (PLAN 3.3)

Three verbatim traces from `Tfl_verify.check`, one per decision style, for the
legibility review. Every trace line is

```
n. [rule] plus-minus step — English gloss  (from parent lines)
```

with the gloss produced by the deterministic renderer (1.9) — the same strings
the back-translation check (4.4) will rely on. Proof-carrying verdicts also get
a one-sentence `explanation`. Certificate verdicts (P/Z, numerical) have no
step sequence, so the trace frames the argument itself: numbered premises, then
the conclusion — no verdict is ever traceless.

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
1. [premise] +(Lov+Girl)+Boy — some lov some girl is boy
2. [premise] −(Lov+Coward)−Boy — no lov some coward is boy
3. [counterclaim] −Girl+Coward — every girl is coward
4. [DON] +(Lov+Coward)+Boy — some lov some coward is boy  (from 3, 1)
5. [contradiction] ⊥ — which is impossible  (from 2, 4)
```

Explanation: *Because some lov some girl is boy, and no lov some coward is boy,
and every girl is coward, it would follow that no lov some coward is boy, yet
some lov some coward is boy — which is impossible.*

## Known legibility caveats (for the review)

1. **Canonical re-orientation.** Proof lines show the engine's canonical forms,
   so the indirect proof's first premise prints as `+(Lov+Girl)+Boy` ("some
   lov some girl is boy") rather than the input's `+Boy+(Lov+Girl)` ("some boy
   lov some girl"). The steps are faithful to the actual derivation; the cost
   is that premises can read reshuffled.
2. **Relation names render bare.** `Lov` glosses as "lov" — the renderer
   lowercases the term name verbatim (byte-exact 1.9 contract with the frozen
   reference). Translation-layer prompts can choose readable relation names
   ("Loves"), which would gloss as "loves".
3. **DON parent order** is as the engine records it (`from 2, 1`), which can
   read backwards relative to the narrative.

These are all properties of the frozen rendering contract, not bugs; changing
any of them would be a documented deviation. The review question is whether the
format above is legible enough for the paper as-is.
