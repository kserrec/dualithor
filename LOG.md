# LOG

Decisions and surprises, newest last. One-line rationale for any deviation from PLAN.md.

## 2026-07-29

- **0.1 done** (prior session): engine vendored verbatim from `guides`; 201/201 tests, quick
  oracle (1k/suite) clean.
- **0.2 started**: `node engine/oracle.js -n 100000` launched in the background
  (~expect hours). Per-suite counts, failures (expect zero), and wall time to be recorded
  here when it completes.
- **0.3 drafted**: read `engine/tfl.js` in full (2,034 lines); wrote `docs/port-spec.md` —
  notation table, AST, parser/printer contracts, validation rules, canonical form, rule
  inventory, proof search, the P/Z closure decision, the TFL⁺ term-matched condition-(iii)
  correction, verdict vocabulary (`unknown` ≠ `invalid`), NL-rendering exact-string
  contract, export inventory with not-ported/deferred lists, and a port-hazards section
  (UTF-16 vs UTF-8 string ordering, insertion-order iteration as semantics, search fuel
  defaults, Unicode tables, deep-recursion behavior). Awaiting Kyle's accuracy
  confirmation per the acceptance check.
- Open decisions surfaced by the spec, to settle in Phase 1 (flagged in port-spec §16):
  (a) how to match JS UTF-16 string ordering in canonical sorts — replicate code-unit
  comparison vs restrict generators to the BMP; (b) whether Unicode letter/lowercase
  classification and `toLowerCase` parity justifies a `uucp`-class dependency for 1.2/1.9
  or whether ASCII-restricted differential corpora suffice.
