# Differential report — the handover (PLAN 1.12)

This is the artifact that transfers authority. Up to this point `engine/tfl.js` — the
frozen JavaScript reference — has been the executable specification, and every port step
ended by proving the OCaml engine agrees with it. This report records the final,
large-scale run of that comparison. **After it, the OCaml engine in `lib/tfl/` is
authoritative**; the JS engine and the shim stay in the tree as a frozen reference and as
the regression gate that keeps them honest.

Reproduce with:

```
opam exec -- dune exec test/test_differential.exe -- -mass
```

Without `-mass` the same harness runs at its standing counts (~100s) and is part of
`dune test`.

## How the comparison works

`engine/shim.js` is a Node process reading JSON lines `{fn, args}` and answering with the
reference engine's result. It is harness code — `tfl.js` and `oracle.js` are never
modified, only consulted. Both engines exchange ASTs in the JS engine's own shape
(`{type:'atom', name, singular}`, `{sign, term, level}`, `{type:'prop', …}`), so the OCaml
serialization is itself under test.

Two input sources feed every gate:

1. **The corpus** — every string literal in `engine/tfl.test.js`, extracted by a scanner in
   the harness. Formula strings must parse identically on both sides; the non-formula
   strings (test names, prose) must *fail* identically, which is where most parser-error
   agreement comes from. Every corpus string that parses also goes through the inference
   core and the renderer.
2. **QCheck generators** (`test/gen.ml`), one per layer, listed in the table below.

A comparison is a disagreement unless both engines produce structurally equal JSON — or,
where an engine may refuse, the *same* refusal: same error class, same message, and for
parse errors the same 0-based position.

## Gates and volumes

| gate | generator | inputs | what is compared |
|---|---|---|---|
| printers/parsers on generated ASTs | `prop_gen` | 100,000 | printed string, then the AST parsed back from it |
| parse outcomes on random token strings | `token_string_gen` | 100,000 | AST or ParseError (message + position), through all three entry points |
| inference core A | `prop_gen` | 100,000 | `canonProp`, `contradictory`, `obverse`, `contrapositive`, `tautology`, `occurrences`, `validateProp` — 7 comparisons per input |
| checkArgument / checkInconsistent (categorical) | `atomic_argument_gen` | 100,000 | full result record, inconsistency certificate included |
| derive proofs, line for line | `atomic_argument_gen` | 20,000 | whole proof: found flag and every line's number, text, rule and parents |
| passives | `relational_prop_gen` | 100,000 | passive prop, symmetry-guard verdict, swap index |
| checkArgument (relational) | `relational_argument_gen` | 5,000 | full record including Pron/Anchor fresh-name sequences |
| parseProgram | `program_src_gen` | 30,000 | propositions and per-line errors |
| queryTerm | `query_term_gen` | 10,000 | answers, content **and** order |
| queryProp | `atomic_argument_gen` | 25,000 | three-way verdict with its supporting result |
| checkProgramConsistency | `relational_argument_gen` | 10,000 | full record |
| equivalents + decideEquivalence | `equivalence_pair_gen` | 30,000 | neighbourhood, DNF rows or rewrite path |
| numerical decision (TFL⁺) | `leveled_argument_gen` | 100,000 | full decision record: the three conditions, carried level, particular counts |
| readProp / readTerm | `prop_gen` | 100,000 | byte-exact English strings |
| explainProof | `relational_argument_gen` | 10,000 | narrations of both the direct and the indirect proof |
| **checkArgument on arbitrary shapes** | `arbitrary_argument_gen` | 20,000 | outcome: same EngineError, or same full record |
| **checkArgument on arbitrary valid shapes** | `valid_arbitrary_argument_gen` | 4,000 | same |
| **consistency-proof narrations** | `atomic_argument_gen` | 20,000 | `explainProof` over `refute_set` proofs — the `fact`-rule lines |

The three bold gates are new in 1.12, closing the two coverage gaps the 2026-07-30 bughunt
probed (it ran them at 2k; they are permanent now).

- *Arbitrary shapes.* Every earlier argument-level gate used fragment-shaped generators, so
  agreement on **rejection** was barely tested. `arbitrary_argument_gen` draws whole
  propositions from `prop_gen` — propositional terms, nested compounds, quantity levels in
  places the fragment forbids — and the gate compares the outcome either way. There are two
  distinct refusals in play: `validateProp`'s fragment rules, and the numerical guard that
  fires when a level rides a non-categorical argument. Since ~99% of those draws are
  invalid, a second gate sanitizes the same shapes into fragment-valid ones (± only on
  fixed references, levels only on a particular subject) so the *decision* path gets
  exercised on odd-but-legal arguments too.
- *Consistency narrations.* `refute_set` proofs carry `fact` lines, a rule no `derive` or
  `indirectProof` proof produces, so the renderer's fact clause was previously ungated.

Per function family the handover volumes are: parse/print 200,000; inference core 100,000;
argument decision 249,000; relational 105,000; programs/queries/equivalence 105,000;
rendering 130,000 — **884,000 generated inputs**, plus the corpus.

## Results

Run 2026-08-01, OCaml 4.14.1 (native) against Node's `engine/tfl.js`, single core,
**12m14s** across the gates.

**Zero disagreements**, everywhere:

| gate | inputs | time |
|---|---|---|
| corpus (604 distinct strings) | 2,382 checks | — |
| printers/parsers on generated ASTs | 100,000 | 44.9s |
| parse outcomes on random token strings | 100,000 | 19.2s |
| inference core A | 100,000 | 138.5s |
| checkArgument / checkInconsistent (categorical) | 100,000 | 40.9s |
| derive proofs, line for line | 20,000 | 93.4s |
| passives | 100,000 | 5.8s |
| checkArgument (relational) | 5,000 | 141.1s |
| parseProgram | 30,000 | 10.3s |
| queryTerm | 10,000 | 20.3s |
| queryProp | 25,000 | 7.2s |
| checkProgramConsistency | 10,000 | 46.4s |
| equivalents + decideEquivalence | 30,000 | 7.2s |
| numerical decision | 100,000 | 11.0s |
| readProp / readTerm | 100,000 | 29.9s |
| explainProof | 10,000 | 38.6s |
| checkArgument on arbitrary shapes | 20,000 | 17.8s |
| checkArgument on arbitrary valid shapes | 4,000 | 59.1s |
| consistency-proof narrations | 20,000 | 2.0s |

The new gates reached what they were built to reach — a gate that never fires proves
nothing, so the harness counts it:

- **Arbitrary shapes:** 19,909 of 20,000 refused *identically by both engines*, 91 decided
  identically. The lopsidedness is the point — this gate exists for rejection agreement.
- **Arbitrary valid shapes:** 2,744 decided identically and 1,256 refused identically. The
  refusals here are the procedure guards, not fragment validation: a quantity level riding
  a non-categorical argument. Fragment-shaped generators never produce that combination, so
  before this run those guards' agreement was untested.
- **Consistency narrations:** 4,269 `refute_set` proofs narrated identically, every one of
  them carrying `fact` lines the earlier `explainProof` gate could not produce.

## Harness self-test

A clean run means nothing unless the harness can detect a real divergence, so the run
begins with a negative control: `+É+P`, the documented §16.4 case, where the JS reference
parses `É` as a bare name and the OCaml engine raises a lexical error. The run fails if
that comparison comes back clean.

## Documented divergences

These are deliberate, recorded before this run, and normalized in the harness — never in
the engine.

1. **Non-ASCII bare names** (port-spec §16.4, Kyle 2026-07-29). OCaml bare-name letters are
   ASCII only; a non-ASCII letter in bare-name position raises a lexical error where the JS
   reference accepts it as a name. Quoted terms still accept arbitrary text, so no
   expressive power is lost. Generators keep names ASCII; the one case that straddles it is
   the negative control above. The OCaml error appends a quoting hint, which the harness
   strips before comparing message text.
2. **Canonical sort ordering** (§16.1). The JS engine sorts with UTF-16 code-unit order;
   OCaml compares UTF-8 bytes (code-point order). The two agree on the whole BMP and differ
   only for astral-plane characters. Sort order never changes a verdict — only which of
   several equivalent canonical spellings wins — and the generators stay inside the BMP, so
   this run does not straddle the difference.
3. **Deep nesting** (§16.5). Pathologically deep input overflows the stack on both sides:
   `RangeError` in JS, `Stack_overflow` in OCaml. Generated depth is capped so both engines
   stay in their sound range. PLAN 1.14 replaces the OCaml behaviour with a structured
   depth error in the total `Safe` API.
4. **`side_coeff` on a non-atomic side.** OCaml raises a clean `EngineError` where the JS
   reference throws a `TypeError`. The input is unreachable from parsed text (2026-07-30
   bughunt); the OCaml behaviour is the saner one and is kept.
5. **Planned, not yet landed:** PLAN 1.14(d) caps `find_cancellation`'s universal-re-use
   search, which is uncapped in the reference (4^u nodes; a 14-line valid input hangs it for
   minutes). Verdicts are decided *before* that search runs, so a node budget is
   verdict-safe by construction. When it lands it becomes a documented deviation of the
   OCaml engine from the frozen reference, and this list gains an entry.

## What the handover changes

- The OCaml engine is authoritative. `engine/` is frozen reference material: consulted,
  never extended, never "fixed".
- Engine changes from here land only with the OCaml unit suite, the ported oracle at 20k
  (PLAN 1.11), and the curated paper-cases suite (1.13) green. A red oracle is a
  stop-everything event.
- This harness stays in `dune test` at its standing counts as a regression gate, and the
  `-mass` run is repeatable whenever a change warrants it.
