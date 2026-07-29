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
- **1.1 done.** Toolchain: no opam/dune existed on the machine; installed the opam 2.5.2
  binary user-level (`~/.local/bin`, no sudo, `--no-setup` so no shell-config edits) and
  created the `default` switch on the **system OCaml 4.14.1** (`ocaml-system`) rather than
  building a compiler — instant, and kept CPU free while the 0.2 oracle run occupies a
  core. Installed dune 3.24.1 and qcheck-core 0.91. Note: the PLAN's approved `qcheck`
  dependency lands as `qcheck-core` (the core library plus its runner; the `qcheck`
  metapackage adds OUnit integration we don't use). Scaffold: `lib/tfl/ast.ml` (variants
  mirroring port-spec §2; typed wrappers over structural equality), `test/gen.ml` (sized
  QCheck generators, parser-producible shapes only, ASCII names per the port-language
  decisions), `test/test_tfl.ml` (deterministic-seed coverage assertion over 1,000
  generated props — every constructor shape present — plus 10k-case reflexivity
  properties), GitHub Actions CI (`dune build` + `dune test` on push, OCaml 4.14 to match
  the dev machine). `dune build` + `dune test` green locally.
- **2.3 done, pulled ahead of Phase 1** — zero-dependency docs work chosen to run alongside
  the 0.2 oracle (1.2's differential gate wants the CPU the oracle is using). Covered
  Logic-LM, LINC, SymbCoT (ACL 2024), FoVer (TACL 2025), plus an NL→FOL translation-quality
  aside (arXiv:2509.22338) in `docs/related-work-notes.md` Part A; Part B (2.4) is the next
  parallel-friendly chunk. Phase 1 resumes at 1.2 once the oracle finishes.
- **2.4 done, same rationale.** Part B covers NatLog (FraCaS 70%/89%), NaturalLI (74.2%
  held-out facts), Sommers & Englebretsen 2000 (book-level; the two validity conditions,
  Englebretsen 1996 p. 167), and Castro-Manzano et al. 2018 (*BRAIN* 9(3)) — read in full
  from the PDF, not just the abstract. Confirmed from the source: their condition (iii) is
  phrased loosely ("≤ the maximum level of the premises"); our engine's term-matched
  strengthening agrees with their Tables 10–13 — the port-spec §12 note now has a primary-
  source anchor. Their named future work (relational module, numerical module, Murphree
  1998) is essentially what our vendored engine implements. All six prior-art items from
  the PLAN preamble are now covered across 2.3 + 2.4.
- **Prior-art sweep extended (Kyle's request)**: added Part C to the notes — syllogistic-
  fragment theory (Pratt-Hartmann & Moss: completeness/complexity per fragment — the
  theoretical grounding for the router claim), MonaLog (monotonicity NLI), NeuBAROCO
  (LLM syllogism benchmark; added as a 6.3 candidate in PLAN — bias annotations enable a
  "does the pipeline neutralize belief bias?" cut), LLM+Prolog pipelines (Reliable
  Reasoning Beyond NL, LoRP — the future escalate.ml hook), and autoformalization
  (Wu et al. 2022).
- **Final prior-art pass (agreed cap):** SatLM (completes the pipeline taxonomy —
  declarative constraints + SAT solver), grammar-constrained decoding (design-relevant:
  the paper must answer "why not force parseable output?" — GCD would silently destroy
  the router signal and the fidelity audit; flagged as a possible ablation arm), and the
  abstention/selective-prediction surveys (the vocabulary for positioning
  `Outside_fragment`: a deterministic abstention signal outside the model vs confidence
  estimates inside it). Prior-art collection now closed until the Phase 8 write-up pass.
