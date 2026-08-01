# LOG

Decisions and surprises, newest last. One-line rationale for any deviation from PLAN.md.

## 2026-07-29

- **0.1 done** (prior session): engine vendored verbatim from `guides`; 201/201 tests, quick
  oracle (1k/suite) clean.
- **0.2 done — 100k oracle run clean across all six suites, zero failures.**
  `node engine/oracle.js -n 100000`, single core, wall time **9h 46m 47s**
  (09:46:00–19:32:47):
  | suite | result | detail | time |
  |---|---|---|---|
  | categorical exactness | 0 failures | 24,686/100,000 valid | 276.6s |
  | rule-step soundness | 0 failures | 422,714 steps checked | 11,599.7s |
  | relational derivation soundness | 0 failures | 7,260 proofs found in 100,000 tries | 9,796.7s |
  | passive equivalence | 0 failures | 103,568 equivalences; 44,250 guarded off | 2,980.5s |
  | indirect-proof soundness | 0 failures | 17,439 refutations found in 100,000 tries | 10,551.4s |
  | statement-model agreement | 0 failures | 426,866 evals; 100,000 equivalences | 1.7s |

  The three proof-search suites dominate the cost (rule-step, relational derivation,
  indirect proof: ~9 of the 9.8 hours). Combined with the same-day external check against
  Castro-Manzano 2018's validity tables (see the §12 entry below), the reference engine
  enters the port phase verified against both its own finite-model semantics at 100k depth
  and a published external source.
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
- **§12 double-check (Kyle's request):** re-verified port-spec §12 line-by-line against
  `engine/tfl.js` (checkArgument decision order, verdict/method vocabulary, the three
  numerical conditions — all accurate as written), then verified the engine mechanically
  against the primary source now in hand: enumerated all 4,000 two-premise syllogistic
  patterns (10 moods × 10 × 10 × 4 figures) through `checkArgument` and compared against
  Castro-Manzano et al. 2018 Table 9 plus the 15 classical no-import moods — **exact
  agreement, zero mismatches**; the paper's four worked examples (Tables 10–13) all
  reproduce; att-1 valid / att-3 invalid confirms the term-matched condition (iii) is
  what makes the engine agree with the paper's own tables where the loose phrasing would
  not. Script: scratchpad `check-cm2018.js` (not committed — the frozen engine is only
  consulted); §12 updated with the worked discriminator and verification note. These
  cases are earmarked for the 1.13 paper-cases suite.
- **Final prior-art pass (agreed cap):** SatLM (completes the pipeline taxonomy —
  declarative constraints + SAT solver), grammar-constrained decoding (design-relevant:
  the paper must answer "why not force parseable output?" — GCD would silently destroy
  the router signal and the fidelity audit; flagged as a possible ablation arm), and the
  abstention/selective-prediction surveys (the vocabulary for positioning
  `Outside_fragment`: a deterministic abstention signal outside the model vs confidence
  estimates inside it). Prior-art collection now closed until the Phase 8 write-up pass.

## 2026-07-30

- **1.2 done — tokenizer, parser, printer** (`lib/tfl/notation.ml`). All 62 parser/printer
  unit tests ported from `tfl.test.js` (HTML-printer tests excluded — courseware-only,
  spec §13; the JS file's seeded random-AST round-trip is subsumed by the QCheck
  property), plus round-trip `parse (print x) = x` at 10k QCheck cases each for
  propositions and terms. All green, and the pre-existing 1.1 suite stays green.
  Port decisions made here, all downstream of the recorded §16 language decisions:
  - **Error positions count Unicode code points** (the tokenizer decodes UTF-8 up front
    and works over a code-point array). Equal to the JS reference's UTF-16 indices on all
    BMP input — which is all the differential corpus generates — so positions compare
    exactly in 1.3.
  - **Whitespace is the JS `\s` set transcribed** (ASCII whitespace + NBSP, U+1680,
    U+2000–200A, U+2028/29, U+202F, U+205F, U+3000, U+FEFF): the reference's own test
    corpus exercises NBSP and thin space, so ASCII-only skipping would fail the ported
    suite. Fixed small set — no Unicode-tables dependency.
  - **Quantity levels saturate at 10⁹** instead of overflowing OCaml's int on absurd
    digit runs (JS accumulates into doubles; huge levels are out-of-contract per
    spec §16.3 and validation caps at 3 anyway).
  - **Unrecognized non-ASCII characters error with a quoting hint** ("quote the term to
    use non-ASCII names") — the §16.4 ASCII narrowing means a non-ASCII letter that the
    JS engine would accept as a bare name is a lexical error here; the message points at
    the supported escape hatch. Full taxonomy lands in 1.14.
  - Test layout: the shared QCheck generators (`test/gen.ml`) moved into a tiny unwrapped
    `test_gen` library so `test_tfl` and `test_notation` can both link them (dune forbids
    one module in two stanzas).
- **1.3 done — differential harness, parser/printer gated clean.** `engine/shim.js` (a new
  harness endpoint per PLAN — `tfl.js` itself untouched) answers JSON-lines `{fn, args}`
  requests with the reference engine's results for the port-spec §17 function set. OCaml
  side: `test/ast_json.ml` (ASTs in the JS engine's exact JSON shape, ASCII signs),
  `test/shim_client.ml` (one long-lived Node process per run, strict request/response
  lines), `test/test_differential.ml`. Three gates, all clean in ~16s wall:
  - **Corpus**: all 604 distinct string literals mechanically extracted from
    `tfl.test.js` (comments/templates skipped, escapes decoded) × 3 parse entry points =
    1,812 checks, 0 disagreements. Non-formula strings count too — both engines must fail
    with the same error position and message. Successful parses additionally push the
    OCaml AST through the JS printer and require byte-equal output.
  - **10k random ASTs**: JS printer reproduces the OCaml printed string; JS parser
    recovers the exact AST.
  - **10k random token strings** (mostly ill-formed): outcomes agree on all three entry
    points.
  Harness details: the §16.4 quoting-hint suffix is stripped in the harness (never the
  engine) before message comparison; a **negative control** runs first — the harness must
  detect the documented `+É+P` divergence (JS parses É as a name, OCaml raises) or the
  run fails, guarding against a vacuously-clean harness. `yojson` installed and added to
  opam depends (`:with-test` for now; becomes a runtime dep at 2.2). Test library
  `test_gen` renamed `test_support` (now: gen, ast_json, shim_client). Differential tests
  run under `dune test` (CI included — GitHub runners ship Node).
- **1.4 done — inference core A** (`lib/tfl/infer.ml`): `validate_prop`/`validate_term`
  (Engine_error with the JS messages verbatim, checks in the JS order — order determines
  which message fires first, and the differential gate compares messages), fixed
  reference (`is_proterm_name`/`is_fixed_ref`), `head_roles`/`make_head_name` (pulled
  ahead of 1.6 because canonTerm strips identity pairing subscripts), canonical form
  (`canon_term`/`canon_prop`), keys, `node_count`/`prop_nodes`, EN/IN/Contrap/It, and
  net-sign `occurrences` + `can_be_plus`. Two findings recorded while porting:
  - **Canonical form is level-less.** The JS engine rebuilds every signed term through
    2-arg `ST(sign, term)`, whose level defaults to 0 — so `canonProp` silently drops
    quantity levels (`propKey('+V²+C')` = `'+V+C'`, confirmed by probe). Levels live only
    on raw propositions and are consumed by the numerical decision (1.8). The port
    reproduces this exactly; port-spec §6 should mention it (pending Kyle's 0.3 pass).
  - `headRoles`' lazy-prefix regex means the base keeps ≥1 character even for an
    all-subscript name; ported as a trailing-run scan clamped at 1.
  Tests: 17 unit tests ported from the D2 canonical/EN-IN-Contrap/guard sections of
  `tfl.test.js` (incl. pairing-subscript canonical noise, pulled ahead with head_roles).
  Differential: shim gained `tautology`/`validateProp`/`occurrences`; the gate now runs
  all 7 core functions (canonProp, contradictory, obverse, contrapositive, tautology,
  occurrences, validateProp incl. exact EngineError messages) over every corpus string
  that parses as a proposition (240 of 604; corpus total 2,052 checks) plus 10k generated
  props — zero disagreements, ~51s wall for the whole differential suite.
- **1.5 done — inference core B**: `lib/tfl/rules.ml` (replace_at with the wild-slot
  fix-sign resolution, DON donor readings, apply_don/apply_simp/apply_add),
  `lib/tfl/derive.ml` (saturate with the JS iteration order reproduced exactly —
  unary IN/Contrap/Simp then binary DON both directions + Add against earlier lines,
  dedup by printed key, fuel semantics incl. the unguarded-overshoot corners; It
  seeding via mentioned_terms; derive; ancestry extract), `lib/tfl/decide.ml` (coreLit
  literals, the P/Z closure — implications, points as insertion-ordered literal sets,
  unit propagation with genuine case splits, fixed-reference forcing + point merging to
  fixpoint — plus find_cancellation with the wild-readings walk and 256-combo cap, and
  check_argument). Two deliberate stubs, each replaced by its own PLAN step: indirect
  proof (1.6) reports not-found — it can only widen `unknown`, never flip a verdict —
  and nonzero levels raise until the numerical decision (1.8); the differential gate
  generates only level-0 atomic-categorical arguments, where neither stub is reachable
  on the JS side either. Tests: 26 unit tests ported (P/Z, REGAL verdicts, statement
  arguments, singulars/identity incl. a traced DON derivation, Simp/Add, trace shape);
  relational-derivation and oracle-spot-check sections deferred to 1.6/1.10 with the
  layers they exercise. Differential: shim gained `derive`; new gates — 10k random
  atomic-categorical arguments through checkArgument (full result records: verdict,
  method, certificate incl. point order, clash, cancellation) and checkInconsistent,
  plus 3k whole-proof `derive` comparisons (line-for-line: n/prop/text/rule/parents)
  at maxLines 60 to keep the searches affordable. Zero disagreements; differential
  suite ~40s wall. All suites green from scratch.
- **0.3 closed — spec accuracy check delegated to Claude (Kyle, 2026-07-30).** Kyle
  reviewed §6 in depth (canonical form; confirmed after discussion of why obversion/
  contraposition stay out of the identity key) and delegated the rest. Verification
  performed: §§1–8, 10–11, 16–17 are pinned by the 1.2–1.5 differential gates (the port
  was written from the spec and agrees with the code on ~2M comparisons); §12's numerical
  tables were machine-verified against Castro-Manzano 2018 on 2026-07-29; the remaining
  sections (§9 relational, §12 checkArgument order, §13 programs/queries/equivalence,
  §14 NL rendering, §15 inventory) were re-read line-against-code today. Two corrections
  applied, per the doc's own "code wins — fix the document" rule:
  - §6: canonical form drops quantity levels (the 1.4 finding, now in the spec).
  - §14: the "few" gloss quoted "few S are not P" in a section promising byte-exact
    strings; the engine emits "is" and lowercases — corrected to the literal outputs
    (`few s is not p` / `few s is p`, probe-verified).
  No other discrepancies found.
- **1.6 done — relational layer** (`lib/tfl/relational.ml`): orientations, the passive
  transformation with the symmetry guard (dedup by prop key across orientations, raw
  props stored as in JS), pronominalization (witness marking in JS order — subject
  before predicate, objects left-to-right, depth-first; fresh-prime allocation against
  the used-set; most-witnesses-wins with first-orientation ties) and collect_names.
  `derive.ml` gained the Pass rule (guarded passives, canonicalized at push) and
  refute_set/indirect_proof (Pron/Anchor seeding parented on entries, contradictory-hit
  detection via the seen table, synthetic ⊥ closing line); `decide.ml`'s checkArgument
  lost its 1.6 stub — the full JS decision order now runs. Tests: 26 unit tests ported
  (the 1.5-deferred relational-derivation section plus D3: passive mechanics, scope
  traps, n-ary guard, the ∃∀→∀∃ one-way entailment at maxLines 1600, the verbatim
  course pronominalization, indirect proofs incl. the whole-D3-stack case, and
  no-overclaim checks). Differential: shim gained passives/indirectProof; new gates —
  10k relational props through `passives` (prop, guard verdict, swap index) and 600
  mixed relational arguments through `checkArgument` at maxLines 60 comparing **full
  records including whole proofs** (Pron/Anchor fresh-name sequences included) — zero
  disagreements. PLAN 1.6 allowed verdict-level agreement with LOG-documented proof-path
  variance; none was needed — proofs match line-for-line. Two harness lessons logged:
  the relational-argument generator must emit only fragment-valid props (a ±-signed
  predicate raises on the OCaml side instead of comparing; invalid-input agreement is
  the 1.4 gate's job), and full-fuel (maxLines 150) relational checkArgument at 1,500
  cases blew a 10-minute budget — an `unknown` costs four bounded searches on both
  engines; maxLines 60 × 600 keeps the whole differential suite at ~75s.
- **1.7 done — programs, queries, equivalence** (`lib/tfl/program.ml`): parse_program
  (code-point comment stripping — `--` in any ASCII/typographic mix — and the JS trim
  whitespace set; per-line ParseErrors collected, never thrown; no validation, per
  spec), query_term (restricted-rule saturation {IN,Contrap,Simp,DON} at 300 lines,
  orientation-based collection, tautology/obverse-tautology dropping, strongest-only
  retention via the 60-line `implies` mini-saturation, propNodes-desc sort), query_prop
  (three-way verdict with the PZ-invalid contradictory retry), check_program_consistency
  (numerical early-return, complete/incomplete split, refuteSet proofs), equivalents
  (BFS closure under obverse/contrapositive, 64-node cap, exact reading strings),
  statement_model (one-world semantics; ASCII lowercase-initial per §16.4) and
  decide_equivalence (sorted-atom truth-table DNF path with typographic-minus rows, else
  the rewrite closure). Tests: 18 unit tests ported from the D4 section (Fido/Socrates
  program included; checkExpression tests are courseware-only, not ported). Differential:
  shim's queryProp switched to AST arguments (it took program source before) and gained
  parseProgram/queryTerm/checkProgramConsistency/equivalents; five new gates — 2k random
  program sources through parseProgram (garbage lines and comments included), 1k
  queryTerm (answer content AND order), 2k queryProp (support records included), 1.2k
  checkProgramConsistency on mixed programs at maxLines 60, 3k equivalents +
  decideEquivalence pairs (half derived by obversion/contraposition so genuine
  equivalences appear) — zero disagreements. Differential suite now 12 tests, ~85s wall.
- **1.8 done — numerical quantifiers (TFL⁺)** (`lib/tfl/decide.ml`): side_coeff and
  numerical_decision with the three conditions — algebraic sum, particular counts, and
  the **term-matched** condition (iii) exactly as the JS engine implements it
  (carriedLevel = max level over +-subject premises whose subject IS the conclusion's
  subject term). check_argument's last stub is gone: any nonzero level now routes to the
  decision method with the full decision record attached (result type gained a
  `decision` field — the compiler's record exhaustiveness flushed out every
  construction site). Tests: 12 unit tests ported from the D9 section — the paper's
  Tables 10–13 (kaa-1, akt-4, bao-3, ekg-2), the att-1/att-3 term-matched
  discriminator, routing (level 0 stays P/Z), level validation placement, and the level
  guards on the 1.7 queries. The readProp many/most/few glosses move to 1.9 with the
  renderer. Differential: 10k leveled atomic-categorical arguments through
  checkArgument comparing the full decision record (valid, three conditions,
  carriedLevel, conclusionLevel, particular counts) — zero disagreements; level-0 draws
  re-cover the P/Z route in passing. Differential suite now 13 tests, ~2m36s wall.
  With 1.8 the whole inference surface is ported; 1.9 (NL rendering) is the last
  functional layer before the oracle port.
- **1.9 done — NL rendering** (`lib/tfl/render.ml`): read_term/read_prop (fixed-ref
  re-orientation, article selection by leading vowel of the rendered predicate,
  many/most/few with the "few" polarity inversion, typographic quotes around
  propositional-term readings; ASCII-only lowercasing per §16.4) and explain_proof
  (given-line narration, the ⊥ impossibility clause with the clashing pair). Byte-exact
  contract: 10 unit tests — the D5 readProp sections and D9 glosses ported, plus
  probe-verified reference strings for readTerm shapes and explainProof (the JS
  explainProof tests run through the deferred answer() layer, so its expected strings
  were captured from the reference directly). Differential: shim gained
  readTerm/explainProof; corpus gate now compares readProp/readTerm on every parseable
  corpus string (2,382 checks total); 10k random props through readProp+readTerm and
  1,500 arguments' direct + indirect proofs through explainProof — the OCaml proof
  record crosses the pipe in the JS proof shape, so both explainers narrate the same
  proof. Zero disagreements; 15 differential tests, ~1m35s wall. **The functional port
  is complete** — every exported surface in port-spec §15's "ported" table now has an
  OCaml implementation gated against the reference. Next: the oracle port (1.10).
- **Security audit of the session's work (findings, decisions).** One real ship-time
  finding, demonstrated on the reference engine: `findCancellation`'s universal-re-use
  DFS is uncapped (4^u nodes; only the wild-readings walk has the 256 cap). Probe: an
  inconsistent set whose clash can never cancel (`+A+B`, `−B−B`) plus u disjoint junk
  universals — 26ms/105ms/1.9s/6.5s at 7/9/11/12 universals, exact ×4 growth; ~7min at
  15, ~days at 20. Verdicts are decided before the search runs, so capping it is
  verdict-safe display-only work. Deferred to **1.14(d)** (PLAN updated) as a documented
  deviation from the frozen JS reference; the JS engine keeps the behavior (dev-only,
  never exposed). Accepted/no-action items so future audits don't re-litigate: the
  `sat` 2-SAT split search has an exponential worst case on paper but no slow instance
  could be constructed (unproven, left as-is); opam deps stay unpinned until 8.5
  (planned); actions stay tag-pinned until release hygiene at 8.5. Fixed now:
  `permissions: contents: read` added to ci.yml (the workflow only builds and tests;
  the default token never needed more). Hygiene sweep was clean: no secrets in tree or
  history, `.env` gitignored ahead of existence, shim dispatch prototype-safe, no
  injection paths, zero npm deps. Also from the same-day bughunt: zero confirmed bugs;
  deep-nesting Stack_overflow vs RangeError divergence is §16.5/1.14 (planned); the
  `side_coeff` non-atomic edge is unreachable from parsed input (OCaml raises a clean
  EngineError where JS TypeErrors — the saner behavior, kept).
- **1.10 done — oracle port A, the finite-model semantics** (`test/semantics.ml`). It
  lives with the tests, not in `lib/tfl`: the shipped engine certifies validity
  symbolically, and this module exists only to catch it being wrong. Ported from
  `engine/oracle.js` faithfully — bitmask denotations, complement/intersection,
  relational complexes with pairing-subscript roles and left-to-right scope, the
  propositional-term domain pun, no existential import anywhere (the empty domain is a
  model unless a singular or proterm needs a world), quantity levels ignored exactly as
  the JS oracle ignores them. Two shapes raise `Unmodeled` rather than guess, both
  places the JS oracle throws or records `undefined`: a non-atomic relation head, and a
  bare propositional term over anything but a plain unary atom.
  **Deliberate deviation:** past the model cap the JS oracle samples from an LCG whose
  state is shared with its own formula generation, so its stream is not reproducible
  from OCaml. Our sampling is our own; the differential gate therefore compares only
  vocabularies both engines enumerate exhaustively (`exhaustive_upto`), and reports how
  many instances it skipped — in practice zero, because the gate generators reuse the
  oracle's own small vocabulary (A/B/C + one singular + one proterm, relational at
  n ≤ 2 where a binary relation still contributes only 2⁴ extensions).
  Gates (`test/test_semantics.ml`, ~4s wall): 9 anchors stated as semantic facts
  (Barbara valid, Darapti invalid without import, I/E conversion, A-conversion invalid,
  the n = 0 model, fixed reference through a universal, the [A] pun, both Course 2 L3
  scope traps non-equivalent, the ∀∀ passive equivalent) + a negative control (a
  deliberately wrong entailment claim must be reported) + differential vs the shim:
  5,000 vocabularies, 10,000 per-model `evalProp` evaluations (an aggregate entailment
  check can cancel a term-level bug; this one cannot), and 5,000 entailment instances
  (3,000 categorical at n ≤ 3, 2,000 relational at n ≤ 2) — zero disagreements, with
  ~25%/~15% of instances entailed, so the gate is not degenerate. `engine/shim.js`
  gained `oracleEntails`/`oracleEvalProp`/`oracleVocab` (harness code; `oracle.js`
  itself untouched and now a dep of both shim-backed suites). `Harness.gate` extracted
  on its second use. Next: 1.11, the six fuzz suites in QCheck.
- **1.11 done — oracle port B, the six fuzz suites** (`test/test_oracle.ml`), clean at 20k
  iterations, all six, zero failures. CLI mirrors the reference's:
  `dune exec test/test_oracle.exe -- -n N` ↔ `node engine/oracle.js -n N`; the default is
  1,000 so `dune test` stays quick.

  | suite | result | detail | OCaml 20k | JS 20k (0.2 table ÷5) | ratio |
  |---|---|---|---|---|---|
  | categorical exactness | 0 failures | 5,111/20,000 valid | 15.7s | 55.3s | 3.5× |
  | rule-step soundness | 0 failures | 85,731 steps checked | 634.5s | 2,319.9s | 3.7× |
  | relational derivation soundness | 0 failures | 1,805 proofs in 20,000 tries | 536.3s | 1,959.3s | 3.7× |
  | passive equivalence | 0 failures | 21,127 equivalences, 8,832 guarded off | 124.4s | 596.1s | 4.8× |
  | indirect-proof soundness | 0 failures | 3,912 refutations in 20,000 tries | 396.1s | 2,110.3s | 5.3× |
  | statement-model agreement | 0 failures | 82,362 evals, 20,000 equivalences | 0.5s | 0.3s | 0.7× |
  | **total** | | | **1,707.4s** | **7,041.3s** | **4.1×** |

  Native OCaml is ~4× the reference's speed on identical work; the one suite the JS wins is
  the trivial one (0.5s vs 0.3s — statement models never touch the model enumerator). The
  JS column is the 0.2 100k run scaled linearly, same machine, single core. Direct
  head-to-head spot check at n = 1,000 on an otherwise idle machine, same day: JS 262.3s
  vs OCaml 69.4s — **3.8×**, confirming the scaled figure.
  **Independent-confirmation note:** the per-suite *counts* land on the reference's rates
  despite completely different generators (QCheck vs the oracle's LCG) — 25.6% valid vs
  24.7%, 4.29 rule-steps per iteration vs 4.23, 21,127 passive equivalences vs 20,714
  scaled, 8,832 guarded off vs 8,850. The proof-search suites run a little hotter (1,805
  proofs vs 1,452 scaled; 3,912 refutations vs 3,488), i.e. our generators feed the search
  slightly richer relationals — more coverage, not less.
  Where a suite's model search is incomplete the failure is one-sided by construction: past
  the cap the semantics samples, which can only miss a counter-model, never invent one.
  Suite 1 is the exception (it compares verdicts for *equality*) and its vocabulary stays
  under the cap at n = 4, so it always enumerates exhaustively.
- **1.13 done, pulled ahead of 1.12** (`test/paper_cases.ml`, 62 cases, all green, no
  engine-vs-book disagreements). Rationale for the reordering: the step is independent of
  the port by its own terms, and it was the one piece of real work available while the 20k
  oracle gate held the dune build lock for 28 minutes. Contents: the 15 syllogistic moods
  valid without existential import; the 9 subalternate moods that need import, each of
  which must therefore come back *invalid*; 4 standard fallacies; 13 immediate inferences
  (conversion valid for I and E only, obversion on all four forms, contraposition on A and
  O only); 10 relational cases including De Morgan's head-of-a-horse and the ∀∃/∃∀ scope
  trap; 4 indirect proofs (the Course 2/3 worked proofs, method asserted, plus the
  does-not-overclaim negative); and 7 numerical cases from Castro-Manzano et al. 2018's
  Tables 10–13 with the att-1/att-3 discriminator. Every expectation was written from the
  literature and hand-checked against the 1.10 semantics before running anything.
  Two verdict conventions, both from port-spec §12: inside the atomic-categorical fragment
  an invalid argument must come back exactly `invalid` (P/Z is complete there); outside it
  the search is incomplete, so those cases assert only that the engine never returns
  `valid` (unknown ≠ invalid). One correction during the pass, on test *selection* not on
  an expectation: three arguments filed as indirect proofs turned out to be found by direct
  derivation, so they moved to the relational section and the courseware's own worked
  proofs (boys/girls/cowards; some boy loves every girl) took their place with the method
  asserted.
