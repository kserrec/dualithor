# TFL-Verify

A pipeline that verifies LLM outputs using Term Functor Logic (TFL): natural language is translated into TFL's variable-free plus-minus notation, checked by a symbolic engine, and routed — parseable claims get cheap, auditable verification; unparseable ones get flagged as outside the fragment.

**Status:** pre-work. Nothing here is built yet except the vendored engine.

- `PLAN.md` — the authoritative project plan (phases, steps, acceptance checks).
- `engine/` — the TFL engine, vendored verbatim from [kserrec/guides](https://github.com/kserrec/guides) (`term-functor-logic/lab/`): a pure, dependency-free JavaScript implementation of Sommers & Englebretsen's term logic — parser, inference core, relational layer, logic-programming queries, and a finite-model-semantics fuzz oracle. Run `node engine/tfl.test.js` for the test suite, `node engine/oracle.js -n 20000` for the semantic fuzz gate.

Per PLAN.md Phase 0, the engine gets a purpose-focused refactor and a fresh correctness audit before any pipeline work begins.
