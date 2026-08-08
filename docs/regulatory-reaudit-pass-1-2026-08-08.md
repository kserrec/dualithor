# Regulatory accepted-set re-audit — first pass

**Status:** first project-side adjudication pass locked 2026-08-08; independent human pass and
reconciliation still required. This document does not revise the frozen 2026-08-02
measurements.

## Scope and method

The audited population is exactly the nine records labelled strict `in` in the two
pre-registered regulatory datasets: `r25`, `r41`, `r54`, `d01`, `d03`, `d05`, `d11`,
`d17`, and `d47`. The source files remain unchanged. In particular, the exact duplicate
`r41`/`d11` remains twice in the raw count because both sampling protocols independently
selected it.

The original test was stricter than “the parser accepts a string”: one TFL proposition
must preserve the complete sentence. This pass therefore applies four consequences of
the already-documented fragment.

1. Quoting makes a lexical or referential term atomic; it cannot make a structured clause
   disappear. Parseability is necessary, not sufficient.
2. Regulatory `means` is exhaustive. A definition between general classes requires both
   inclusion directions. One TFL proposition can express this only when both sides are
   singular names, because the engine's singular identity form is symmetric.
3. The project permits a context-fixed singular description to wear `*`, but records this
   as an engineering convention: the reviewed term-logic sources provide no dedicated
   definite-description theory.
4. A primed or starred term is a fixed constant, not an anaphora resolver. No formula may
   silently supply an antecedent from another sentence.

The machine-readable judgments are in
`data/fidelity/real/audit-pass-1.jsonl`. A repository test verifies the population,
canonical parsing, deterministic rendering, duplicate handling, and provisional counts.
The blinded packet maps `S01` through `S09` to `d17`, `r25`, `d47`, `d01`, `r54`, `d05`,
`r41`, `d03`, and `d11`, respectively; the map is recorded here, outside the packet, so
the two identical ADA rows remain separately reconcilable.

## Judgments

| ID | First-pass judgment | Exact formula or blocker | Why |
|---|---|---|---|
| `r25` | in, convention-dependent | `±"Your medical source"*−"qualified medical source as defined in § 416.919g"` | One negative predication once the surrounding provision fixes the source. The treatment of the possessive singular as a fixed reference is an engineering convention. |
| `r41` | in | `±ADA*+"Americans with Disabilities Act of 1990 (42 U.S.C. 12101 et seq.)"*` | Singular identity between two names for one Act. |
| `r54` | in | `−Selection+("is subject to"±"income-eligibility and income-targeting requirements in § 5.653"*)` | Universal generic subject related to the named requirement bundle; the reference names rather than incorporates the rules. |
| `d01` | in | `−"federally administered State supplementary payment"+"SSI benefit"` | “Benefits include any X” asserts that every X is a benefit. |
| `d03` | **out** | `definitional-equivalence` | The formula formerly written in the note gives only one half of an exhaustive general-class definition. The converse needs a second proposition. |
| `d05` | in, convention-dependent | `±"Disability program"*+"Federal program for providing supplemental security income benefits for the blind and disabled under title XVI of the Act, as amended"*` | Singular identity between a defined label and the one Federal program; treating the full definite description as a singular term is an engineering convention. |
| `d11` | in | same as `r41` | Exact source duplicate, deliberately retained and judged identically. |
| `d17` | in | `±"Section 214"*+"section 214 of the Housing and Community Development Act of 1980, as amended (42 U.S.C. 1436a)"*` | Singular identity between two legal names for one section. |
| `d47` | **out** | `anaphora` | “It” gets its referent only from the preceding sentence; the engine performs no cross-sentence resolution. |

## Provisional effect on coverage

These are first-pass sensitivity numbers, not reconciled results:

| Slice | Frozen 2026-08-02 label count | First pass |
|---|---:|---:|
| Normative | 3/60 (5%) | 3/60 (5%) |
| D1 definitions | 5/20 (25%) | 4/20 (20%) |
| D2 standards of identity | 1/30 (3%) | 0/30 (0%) |
| All records, duplicates retained | 9/110 (8.2%) | 7/110 (6.4%) |
| All exact sentence texts, de-duplicated | 8/107 (7.5%) | 6/107 (5.6%) |

There are three exact duplicate pairs in the 110 records. `r41`/`d11` is the only accepted
pair; `d23`/`d24` and `d45`/`d49` are rejected pairs. Removing all three repeated rows
therefore changes both numerator and denominator.

The two convention-dependent records are a second useful sensitivity boundary. Excluding
both would put the first pass at 5/110 raw and 4/107 de-duplicated. That is not the primary
first-pass label; it exposes exactly where a second human judgment can change the result.

## Gate status

PLAN Phase B steps 1 and 2 are complete. The pass is locked by its repository commit.
Phase B remains open until an independent human labels the blinded packet without seeing
this file or the JSONL, both passes are reconciled in public, and the final counts are
regenerated. No Phase C work is authorized before then.
