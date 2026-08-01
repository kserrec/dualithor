# TFL-Verify

A pipeline that verifies LLM outputs using Term Functor Logic (TFL): natural language is translated into TFL's variable-free plus-minus notation, checked by a symbolic engine, and routed — parseable claims get cheap, auditable verification; unparseable ones get flagged as outside the fragment.

**The two claims under test:**

1. **Fidelity:** NL→TFL translation is more faithful and more human-auditable than NL→FOL translation, because TFL's variable-free plus-minus syntax mirrors natural-language surface form.
2. **Router:** TFL fragment membership — does the sentence parse into TFL at all? — is a clean, mechanical escalation signal: parse success → verify cheaply; parse failure → flag or escalate. FOL pipelines have no equivalent signal.

**Status:** the OCaml engine is **authoritative** as of the differential handover (2026-08-01): the full port — parser/printer, inference core, P/Z categorical decision, relational layer, programs/queries/equivalence, TFL⁺ numerical decision, NL rendering — agrees with the reference engine on 884,000 generated inputs plus the reference's own corpus, with zero disagreements (`docs/differential-report.md`). The ported finite-model oracle is clean at 20k iterations across all six fuzz suites, and a curated 62-case audit against the literature passes. `opam exec -- dune test` runs everything (the differential gate needs Node ≥ 18). The engine is also total at its public surface (`Tfl.Safe`): every refusal is a structured `Lexical | Syntactic | Outside_fragment` failure, verified against 102,000 adversarial inputs with no crash and no case over 0.04s (`docs/engine-surface.md`). **Phases 1–3 are complete**: on top of the engine there is now an OpenRouter client for the three translator models under test, and the verification API (`Tfl_verify.check`) that returns a verdict, a method, and an auditable trace — every step in plus-minus notation with a deterministic English gloss (`docs/trace-samples.md`). Translation, routing and benchmarks are next.

The system — engine and pipeline — is being written in **OCaml**. The JavaScript engine below was the executable specification for the port: differential testing forced the OCaml engine to agree with it, input for input, and now keeps it honest as a standing regression gate. A thin pip-installable Python client ships at release for easy adoption.

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
- `translate/`, `router/`, `bench/`, `analysis/` — the pipeline: NL→TFL translation, fragment routing, benchmark runners, metrics (Phases 2–7; `translate/` has the OpenRouter client, the rest are scaffolded).
- `data/` — benchmark corpora, eval sets, results (see `data/README.md`; licensed corpora are gitignored and CI-guarded).
- `test/` — unit suites, paper-cases audit, the ported oracle, and the differential harness.
- `engine/` — the reference TFL engine, vendored verbatim from [kserrec/guides](https://github.com/kserrec/guides) (`term-functor-logic/lab/`): a pure, dependency-free JavaScript implementation of Sommers & Englebretsen's term logic — parser, inference core, relational layer, logic-programming queries, and a finite-model-semantics fuzz oracle. Frozen: never extended, only consulted. Run `node engine/tfl.test.js` for the test suite, `node engine/oracle.js -n 20000` for the semantic fuzz gate.
