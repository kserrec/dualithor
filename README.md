# TFL-Verify

A research and teaching implementation of Term Functor Logic (TFL) in OCaml, with an
experimental natural-language-to-TFL translation pipeline and a JSON-lines command-line
interface.

**Project decision (2026-08-08):** the regulatory-verification product is discontinued.
Strict coverage on sampled normative regulation was 3/60 (5%), definitions sections were
5/20 (25%), and standards of identity were 1/30 (3%). The router, policy benchmark, and
coverage-expansion roadmap are not being built. The engine will be preserved for a narrow
release; the only remaining paper bet is a fair human study of whether deterministic
TFL-derived English makes formalization errors easier to detect than matched deterministic
FOL-derived English.

**Engine state:** the OCaml port agrees with the frozen JavaScript reference on 884,000
generated inputs plus the reference corpus, and the categorical core is backed by a
finite-model oracle and a 62-case literature audit. That is strong evidence for the port,
not a claim of formal verification: the shared oracle does not model TFL⁺ quantity levels,
relational search is incomplete and may return `Unknown`, and the numerical layer now
certifies `Valid` but abstains instead of asserting `Invalid`. The total `Tfl.Safe` surface
has survived 102,000 adversarial inputs. The deterministic renderer is reproducible, but
determinism alone does not guarantee grammatical or semantically correct English.

**Research state:** on 91 authored, notation-shaped sentences, the latest run scored Sonnet
90/91, GPT 90/91, and Kimi 91/91 faithful, with zero unparseable outputs, 30/30 correct
declines, and 24/24 correct argument verdicts. This is an upper-bound development result,
not ecological or comparative evidence. The canonical TFL textbook also already solves
missing premises algebraically, so that proposed novelty claim is retired. The current
five-phase go/no plan and its stopping rules are at the head of `PLAN.md`; the primary-
source correction is in `docs/missing-premise-priority-audit-2026-08-08.md`.

## Quickstart

Requires [opam](https://opam.ocaml.org/) with OCaml ≥ 4.14; Node ≥ 18 is a dev-time requirement only (the differential gate against the reference engine).

```
opam install . --deps-only --with-test
opam exec -- dune build
opam exec -- dune test
```

API keys for the pipeline's LLM calls live in a gitignored `.env` at the repo root (`OPENROUTER_API_KEY=…`) — never committed, never logged.

## Layout

- `PLAN.md` — the authoritative project plan (phases, steps, acceptance checks).
- `lib/tfl/` — the OCaml TFL engine (authoritative since the differential handover).
- `lib/verify/` — the verification API the pipeline calls: verdict, method, and a glossed proof trace, with JSON in both directions.
- `translate/` — the experimental NL→TFL client, prompt, cache, and back-check.
- `bench/` — fidelity and regulatory-coverage measurement code.
- `router/`, `analysis/` — dormant scaffolds; neither is a current product track.
- `bin/` — the JSON-lines `check`, `parse`, and `render` command-line interface.
- `data/` — benchmark corpora, eval sets, results (see `data/README.md`; licensed corpora are gitignored and CI-guarded).
- `test/` — unit suites, paper-cases audit, the ported oracle, and the differential harness.
- `engine/` — the reference TFL engine, vendored verbatim from [kserrec/guides](https://github.com/kserrec/guides) (`term-functor-logic/lab/`): a pure, dependency-free JavaScript implementation of Sommers & Englebretsen's term logic — parser, inference core, relational layer, logic-programming queries, and a finite-model-semantics fuzz oracle. Frozen: never extended, only consulted. Run `node engine/tfl.test.js` for the test suite, `node engine/oracle.js -n 20000` for the semantic fuzz gate.
