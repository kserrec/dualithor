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
- **Port-language decisions (Kyle, 2026-07-29)** — both questions flagged in port-spec §16
  settled. Guiding principle: JS artifacts live in the test harness, never in the engine.
  (a) *Canonical-sort ordering:* the OCaml engine compares strings byte-wise over UTF-8
  (code-point order) — no UTF-16 emulation. Sort order never affects verdicts, only which
  equivalent canonical spelling wins, so nothing unsound hides in the difference. QCheck
  name generators stay inside the BMP so the differential corpus never straddles the
  divergence; the 1.12 report documents the deliberate ordering difference.
  (b) *Bare term names are ASCII-letter only* in the OCaml engine — no `uucp`/`uutf`
  dependency. The notation's fixed non-ASCII symbols (−, ±, sub/superscripts, primes) are
  unaffected, and quoted terms still accept arbitrary text, so no expressive power is
  lost; the translation prompt will teach quoting for non-ASCII names. A non-ASCII letter
  in bare-name position gets a `Lexical`-class error advising quoting (1.14 taxonomy).
  Renderer lowercasing and the statement-variable lowercase-initial check are ASCII-only;
  differential corpora keep names ASCII; the residual divergences from the JS reference
  are documented in the differential report.
