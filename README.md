# TFL-Verify

A pipeline that verifies LLM outputs using Term Functor Logic (TFL): natural language is translated into TFL's variable-free plus-minus notation, checked by a symbolic engine, and routed — parseable claims get cheap, auditable verification; unparseable ones get flagged as outside the fragment.

**Status:** pre-work. Nothing here is built yet except the vendored reference engine.

The system — engine and pipeline — is being written in **OCaml**. The existing JavaScript engine below serves as the executable specification for the port: differential testing forces the OCaml engine to agree with it, input for input, before the OCaml engine becomes authoritative. A thin pip-installable Python client ships at release for easy adoption.

- `PLAN.md` — the authoritative project plan (phases, steps, acceptance checks).
- `engine/` — the reference TFL engine, vendored verbatim from [kserrec/guides](https://github.com/kserrec/guides) (`term-functor-logic/lab/`): a pure, dependency-free JavaScript implementation of Sommers & Englebretsen's term logic — parser, inference core, relational layer, logic-programming queries, and a finite-model-semantics fuzz oracle. Frozen: never extended, only consulted. Run `node engine/tfl.test.js` for the test suite, `node engine/oracle.js -n 20000` for the semantic fuzz gate.
