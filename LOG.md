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

## 2026-08-01

- **1.12 done — the mass differential gate, and the handover.** `dune exec
  test/test_differential.exe -- -mass`: 18 gates, **884,000 generated inputs** plus the
  reference's own corpus (604 distinct strings, 2,382 checks), **zero disagreements**,
  12m14s. Per-family volumes: parse/print 200k, inference core 100k, argument decision
  249k, relational 105k, programs/queries/equivalence 105k, rendering 130k. Full table and
  method in `docs/differential-report.md`. **From this commit the OCaml engine is
  authoritative**; `engine/` is frozen reference material and the harness stays in
  `dune test` at its standing counts (~100s) as a regression gate.
  Mass mode is a `-mass` flag rather than a separate executable: every gate's standing and
  handover counts sit side by side at its call site (`~count:(count 10_000 100_000)`), so
  the ratio a gate runs at is visible where it is defined. Counts differ per gate by two
  orders of magnitude because the costs do — 100k parse round-trips cost less than 5k
  relational checkArguments, each of which runs four bounded searches on each side.
  The three new gates close the two bughunt-probed coverage gaps: arbitrary-shape
  checkArgument comparing *outcomes* (19,909/20,000 refused identically, 91 decided
  identically), the same shapes sanitized to fragment-valid so the decision path is
  exercised too (2,744 decided, 1,256 refused), and consistency-proof narrations (4,269
  `refute_set` proofs, all carrying the `fact` lines no derive/indirect proof produces).
  **Surprise worth recording:** the valid-arbitrary gate errored on its first run with
  `EngineError("quantity levels are supported only in categorical (atomic) syllogisms")` on
  `+a+a; +a+a; +a¹+(+a+a) ⊢ +a+a`. Not a port bug — a *second* class of refusal that
  fragment-shaped generators can never reach: `checkArgument` guards its numerical route
  on legal propositions, after `validateProp` has already passed them. Both engines raise
  it identically; the gate now compares outcomes on both sides, and the distinction
  (fragment validation vs procedure guards) is recorded in the 1.14 taxonomy.
- **1.14 done — robustness: the total surface, the depth cap, the work cap. Phase 1 is
  complete.** `lib/tfl/safe.ml` is now the only entry point anything downstream may use.
  (a) **Taxonomy.** `Lexical | Syntactic | Outside_fragment`, classified by *where* the
  refusal was raised, never by its message text: `Safe.parse` runs the tokenizer alone
  first, so a failure there is lexical by construction and one from the parser proper is
  syntactic. Costs one extra linear pass; buys immunity from a message edit silently
  reclassifying anything. The full inventory — 22 distinct refusals — is in
  `docs/engine-surface.md`, which also records the sub-split the 1.12 gate surfaced:
  `Outside_fragment` covers both the standing fragment rules (`validate_prop`) and the
  *procedure guards* that fire on propositions the parser and validator both accepted.
  **Deviation from the PLAN's three-class list:** a fourth kind, `Internal`, for exceptions
  that should be unreachable. It classifies the engine, not the input — a bug to fix, not
  an escalation to make — and folding a crash into `Outside_fragment` would let a defect
  hide inside an expected outcome. The fuzz run is the evidence it never fires.
  (b) **Total API.** `parse`, `parse_all`, `check`; every exception mapped to a structured
  failure. `check` validates each proposition under its own label before deciding, because
  `check_argument` validates its whole input at the head and a refusal would otherwise be
  reported against the argument when one premise is at fault. Every failure names its
  input (`premise 2`, `conclusion`, or `argument`).
  (c) **Depth cap.** Nesting in this notation is exactly bracket nesting, so depth is
  measured from the token stream *before* any recursion: past 64 levels the input is a
  structured `Syntactic` refusal rather than a `Stack_overflow` (port-spec §16.5 closed
  **for the `Safe` entry points**; `Program.parse_program` is still exposed — see the
  2026-08-01 bughunt entry and PLAN 3.1).
  64 is ~20× any real formula and far below what the engine's tree walks can take.
  **Fuzz: 102,000 adversarial inputs** — 30k random byte strings (invalid UTF-8 included),
  20k token strings, 30k truncations of printed formulas cut on byte indices (so UTF-8
  sequences are sliced mid-sequence), 10k inputs nested 1–3,000 deep in both bracket
  flavours balanced and unbalanced, 2k pathological lengths to 20,000 characters, 10k
  `check` calls over garbage. No escaping exception, no `Internal`, **no case over 0.036s**
  against the 1s bound.
  (d) **`find_cancellation` work cap** — the one deliberate behavioural deviation of the
  OCaml engine from the frozen reference. 500,000-node budget shared across the call;
  exhaustion reports no cancellation. Verdict-safe by construction (the closure decides
  before the search runs; the cancellation only decorates the certificate), complete
  through 9 re-usable universals. The audit's 20-universal probe — uncapped, ~days — is
  pinned as a test and returns in under a second.
  Two findings during the pass, both caught by the new tests and diagnosed before any edit:
  `check` was losing input attribution on validation refusals (fixed as above), and the
  cancellation positive control initially reused the audit's own probe, which is *by
  construction* a set whose clash can never cancel — replaced with Barbara's counterclaim,
  which does cancel. Engine change gate (post-1.12 rule), all green: unit suites, 62 paper cases,
  the 18-gate differential at standing counts, and **the 20k oracle — all six
  suites, zero failures, 1,485.2s**. Every count is *identical* to the 1.11
  baseline: 5,111/20,000 valid, 85,731 rule steps, 1,805 proofs, 21,127 passive
  equivalences with 8,832 guarded off, 3,912 refutations, 82,362 statement
  evals. The cancellation cap changed nothing the oracle can see, which is what
  verdict-safe-by-construction should look like from the outside. (The commit
  landed a few minutes ahead of the run finishing, during a power-loss warning;
  the run completed clean and this line records it.)
- **Bughunt (whole project) — 3 confirmed, 2 fixed, 1 roadmapped; plus a verification
  gap closed.** The previous hunt (2026-07-30) predates 1.10–1.14, so `Safe`, the
  semantics module and the cancellation cap had never been examined. The 884k-input
  differential means OCaml-vs-JS port bugs are effectively excluded *on covered paths*,
  so the hunt targeted code with no JS counterpart and input shapes no generator builds.
  1. **A quoted term containing `--` broke a program line — fixed.** `strip_comment`
     scanned for two adjacent minuses anywhere, quoted spans included, so
     `+"well--known"+P` — which parses perfectly on its own — came back from
     `parse_program` as `Unclosed quote (at position 1)`: an error that blames the quote
     for a comment marker nobody wrote. The frozen reference does the same (verified by
     running it), so this was inherited, not a port defect. The stripper is now
     quote-aware: it walks name and quoted tokens whole instead of testing every
     position. **Deliberate deviation from the reference**, normalized in the harness the
     way §16.4 is — `diff_parse_program` runs the reference's naive rule beside the
     engine's and skips only sources where they legitimately differ, reporting the count.
     At standing counts 4 of 2,000 sources hit it, so without the skip the gate would
     have gone red — the random token generator does produce quoted `--`.
  2. **`explain_proof` raised on a found-but-empty proof — fixed.**
     `explain_proof {found = true; lines = []}` raised `Invalid_argument("List.nth")`
     (the reference TypeErrors on the same input). Unreachable from engine-produced
     proofs, which always have at least one line — but reachable the moment 3.1
     deserializes a proof record from JSON, which is 3.1's job. Now returns None, matching
     the documented "None for missing/failed proofs" contract and the accepted
     side_coeff precedent: unreachable input gets the saner answer, not a crash.
  3. **`Program.parse_program` still stack-overflows on deep input — roadmapped to 3.1.**
     1.14's depth cap lives in `Tfl.Safe`, so the program-loading path is unguarded:
     measured a hard `Stack_overflow` at 200,000 levels where `Safe.parse` returns a
     clean syntactic refusal. No contract is violated (1.14's contract names `Tfl.Safe`),
     but the LOG line claiming "§16.5 closed" was overstated and is now corrected.
  **Verification gap closed (not a bug):** the semantics differential generated only
  atoms and relational complexes, so `Semantics.eval_term`'s Compound and PropTerm
  branches — which the oracle's rule-step suite leans on heavily — were never compared
  against `oracle.js`. Checked by hand first (8 propositions × every A/B/C assignment at
  n = 1 and 2 = 576 evaluations, identical), then closed permanently: `sem_compound_prop`
  and a new `sem_propterm_prop` now feed both `diff_vocab` and `diff_eval`.
  Cleared without action, so they are not re-litigated: `too_deep`'s running bracket
  counter can go negative on excess closers, but the parser always errors on an unmatched
  closer before recursing; `Safe.parse` tokenizing twice cannot reclassify a failure;
  the cancellation budget abandons only call-local state; `head_roles` on an
  all-subscript quoted name falls back to identity roles; level saturation on a huge `^`
  run is the documented §16.3 out-of-contract case.
- **Security audit (second full pass; first was 2026-07-30).** New ground since the last
  one: `Safe`, the semantics module, the oracle suites and the cancellation cap. Two real
  findings, both proven by measurement, both **inherited from the frozen reference** and
  both unreachable through `Tfl.Safe` today — deferred to **8.4**, where the CLI and
  Python client first expose the library to callers who are not our own pipeline:
  (a) `decide_equivalence` enumerates every assignment of the *union* of two propositions'
  atoms, while the 16-atom cap is per proposition — so two 16-atom statements give 2³²
  rows. Measured ×4 per two atoms: 0.80s at 2²¹, 3.59s at 2²³, 15.68s at 2²⁵, so ~33
  minutes at the maximum, from roughly 160 bytes of input. That asymmetry is what makes it
  a denial of service rather than mere slowness.
  (b) the parser allocates ~120× the input size — `Notation.decode` builds a cons list of
  every code point before converting to an array, and `Safe.parse` decodes twice. 20 MB in
  → 2.4 GB allocated, 1.38 GB peak heap; time stays linear at ~0.35 s/MB, so this is
  memory, not an algorithmic blowup. It also scopes the 1.14 "no case over one second"
  claim: that held for the ≤20 KB fuzz corpus; 5 MB takes 1.5s.
  **Fixed now:** `data/raw/`, `data/results/` and `data/eval/` are gitignored — CLAUDE.md
  asserted that protection in the present tense and it did not exist, while `git add -A`
  is this repo's habitual commit pattern and Phase 6 downloads licensed corpora into
  exactly those paths. A licensing accident, not an attacker, but history is the part you
  cannot take back. CI now fails if an ignore rule is dropped or a corpus file becomes
  tracked. Created **SECURITY.md** with the known-trust-decisions the repo had nowhere to
  record.
  **Re-verified, unchanged:** no secrets in tree or history (sampled every commit), CI is
  `on: push` with no `pull_request_target` and a `contents: read` token, four well-known
  opam dependencies with no install scripts, zero npm dependencies, shim subprocess
  quoted and dev-only. The `sat` search accepted as exponential-on-paper in the last audit
  now has data: flat ~0.15s to 30 disjoint universals and a 25-long chain, and that 0.15s
  is the cancellation budget, not the search.
- **Open question for Kyle (raised 2026-08-01, unanswered — carried forward).** PLAN
  1.14(a) names three failure classes; the implementation has a fourth, `Internal`, for
  exceptions that should be unreachable. The argument for it: it classifies the engine
  rather than the input, so folding a crash into `Outside_fragment` would let a defect
  hide inside an expected outcome, and the router would escalate where it should page
  someone. The argument against: it is a deviation from the plan's vocabulary, and the
  fuzz shows it never fires. It is implemented, documented in `docs/engine-surface.md`,
  and reversible in about ten lines if Kyle prefers three classes.
- **2.1 done — pipeline scaffold.** Four dune libraries: `translate/` (carrying the
  `.env` loader the 2.2 client will read keys from), `router/`, `bench/`, `analysis/`
  (empty stanzas their phases will fill — no placeholder code). `data/` tree created with
  a committed README naming which subdirectories are gitignored and why; a root `dune`
  marks `data/` as `data_only_dirs` so dune never interprets what Phase 6 downloads
  there. README rewritten per the step: the two claims, quickstart, layout. New
  `test/test_env.ml` (11 checks) guards the quiet key-handling failures: stray
  whitespace/quotes on a key breaking auth without a useful error, a missing `.env`
  reading as no bindings rather than an exception, the process environment beating a
  stale file. Full `dune test` green.
  `ocamlformat` 0.29.0 was installed into the switch to pin `.ocamlformat` to a real
  version — a dev-only tool, not a library dependency; CLAUDE.md already names
  ocamlformat defaults as the project style.
- **Style commit alongside 2.1: repo-wide `dune fmt`.** The pre-config tree was
  hand-approximated ocamlformat style; the real formatter reflows 27 existing files,
  nine of them engine modules. The diff is whitespace/reflow only (ocamlformat refuses
  to emit output whose parse tree differs from its input), so this is not an
  engine-logic change — but because engine files are touched at all, it lands only
  after the full post-1.12 gate: unit suite + paper-cases + 20k oracle + mass
  differential, all green on the reformatted tree.
  Result: quick suite green; mass differential `success (ran 18 tests)`, zero
  disagreements; oracle clean at 20k across all six suites, 1,486s. Committed.
- **2.2 done — OpenRouter client.** `translate/llm_client.ml`: one `complete ~model
  ~system ~user ~max_tokens` surface over cohttp-lwt-unix; three attempts with
  exponential backoff and a per-attempt wall-clock timeout, retrying only what is
  transient (429, 5xx, timeout, network) — auth and malformed-request errors fail fast;
  every call appends tokens/cost/request-id to `data/usage.jsonl` (gitignored: a growing
  local ledger, never credentials). Model slugs looked up live and **tier-matched** so no
  vendor is represented by a flagship while another sends its budget model:
  `anthropic/claude-sonnet-5` ($2/$10 per Mtok), `openai/gpt-5.6-terra` ($1/$6 — there is
  no plain "gpt-5.6"; Terra is the middle tier between the Sol flagship and the Luna
  budget model), `moonshotai/kimi-k3` ($3/$15). Live smoke: all three answered "OK";
  total spend $0.0028, ledger verified key-free. `smoke.exe` is hand-run only — it
  spends money and needs the key, so it is never wired into `dune test`.
  Dependencies added per the approved set (CLAUDE.md): `yojson` moves to runtime,
  plus `lwt`, `cohttp-lwt-unix`, `tls-lwt` (never hand-roll TLS). One system
  prerequisite surfaced: `zarith` needs `pkg-config`, installed by Kyle via apt
  (GitHub's ubuntu runners ship it, so CI is unaffected).
- **3.1 done — the verification API.** New library `lib/verify/` (`Tfl_verify`, public
  name `tfl-verify.verify`): `check ~premises ~conclusion` on plain strings returns
  `{verdict; meth; trace; explanation}` with verdict
  `Valid | Invalid | Contradicted | Unknown | Error of error_info` (the 1.14 taxonomy),
  and the Unknown ≠ Invalid contract documented at the head of the module. JSON goes both
  ways: `to_json`/`of_json` are exact inverses (round-trip-tested on every method the
  engine can produce plus synthetic corners it can't yet, e.g. `Internal`), and `of_json`
  is total — malformed payloads return `Error msg`, never an exception.
  **Trace policy (a design point the PLAN left open):** proof-carrying verdicts
  (derivation/indirect) render the proof's own lines — step text, rule, parents, and a
  deterministic English gloss per line via 1.9, the synthetic ⊥ line glossed "which is
  impossible"; certificate and search-less verdicts (P/Z, numerical, failed searches)
  render the argument itself as numbered premise/conclusion lines, so **no verdict is
  ever traceless** — the auditable-trace claim shouldn't have a silent hole for the very
  method that decides most of the fragment.
  One live bug caught by probing before pinning tests: the framing trace numbered the
  conclusion 1 — OCaml evaluates `@`'s arguments right to left, so the conclusion's
  counter increment ran first. Sequenced explicitly; pinned in the suite.
  `Safe.parse_program` lands with it (the roadmapped §16.5 gap): per-line, pre-parse
  bracket-depth check on the same comment-stripped text the program parser reads, naming
  the offending line; 300k-level nesting — past the measured 200k crash — now a
  structured `Syntactic` refusal, pinned. `docs/engine-surface.md` updated; while there,
  removed a `val describe` the table listed but the code never implemented.
  Gate for the safe.ml change: unit suites + paper-cases green; 20k oracle and mass
  differential recorded below.
  Gate results for the 3.1 safe.ml change: mass differential `success (ran 18 tests)`,
  zero disagreements; oracle clean at 20k across all six suites, 2,236s.
- **3.2 done — the verification suite.** `test/test_verify_cases.ml`: 35 arguments
  through `Tfl_verify.check` end to end — 8 valid moods, the import traps and standard
  fallacies, immediate inferences, 7 relational cases (De Morgan's head-of-a-horse, the
  ∀∃/∃∀ scope trap under paper_cases' not-certified contract, the worked indirect proof),
  3 numerical, and the API's own ground: empty conclusion, empty and whitespace-only
  premises, invalid bytes (lexical), the wild-sign fragment refusal, the depth cap, and
  an empty premise list (legal input — the conclusion alone decides, invalid). Verdict
  expectations are shared with paper_cases so the engine surface and the public API can
  never quietly disagree. Green.
- **3.3 drafted — trace samples for the legibility review.** `docs/trace-samples.md`:
  three verbatim `Tfl_verify.check` traces (P/Z categorical, direct relational
  derivation, indirect proof), generated by a throwaway executable and pasted unedited,
  plus the three known legibility caveats named for the review — canonical
  re-orientation of premises in proof lines, bare relation-name glosses ("lov"), and
  DON parent order. Awaiting Kyle's format approval per the acceptance check; the PLAN
  box stays open until then.
- **Refactor of the Phase 3 work — zero functional change.** One real duplication: 3.1's
  depth check re-implemented, inside `safe.ml`, the exact `decode → strip_comment →
  trim_cps → cps_to_string` pipeline `Program.parse_program` uses — two copies of a
  pipeline that *must* agree, since drift would leave the depth check inspecting
  different text than the parser. Extracted as `Program.line_code`, called from both, so
  the invariant is structural rather than a comment promising it. (The one deliberate
  addition to the engine's exported surface; nothing existing changed signature.)
  Also in `safe.ml`: the `code = ""` guard was provably redundant — empty input either
  tokenizes to no tokens (`too_deep` returns None) or raises into the existing catch-all,
  None either way — and the hand-rolled `scan` recursion became `List.find_map`, still
  short-circuiting. Both new test suites hand-rolled their own pass/fail counters instead
  of the shared `Harness`; both now use it, which revealed the case suite's hardcoded
  "35 cases passed" was off by one (36 test blocks).
  One test added, pinning behavior measured rather than assumed: the depth pass decodes
  and tokenizes each line itself, ahead of the parser, so it is a second place hostile
  bytes reach — invalid UTF-8, lone surrogates, NUL bytes, control characters and a deep
  line ending in an invalid byte all stay per-line recorded errors, no raise. (The
  suspected escape — an exception slipping past the `guard` and breaking Safe's
  never-raises contract — was checked empirically first and does not happen:
  `Notation.decode` uses `String.get_utf_8_uchar`, which substitutes rather than raises.)
  Full engine gate on the refactored tree: quick suite green (12 files), mass
  differential `success (ran 18 tests)` with zero disagreements, oracle clean at 20k
  across all six suites (2,490s).
  Considered and deliberately skipped, with Kyle's agreement: hoisting the two suites'
  six-line `v_name` into `test_support` (would link `tfl_verify` into every engine test
  executable, coupling engine testing to a downstream layer), and the double parse in
  `Tfl_verify.check` for proofless verdicts (removing it needs `Safe.check` to return its
  parsed propositions — an interface change).
- **3.4 done — readable gloss orientation (from Kyle's 3.3 review).** Kyle's one complaint
  about the trace samples: `+(Lov+Girl)+Boy` glosses as "some lov some girl is boy", which
  he found harder to read than the TFL it explains — and the E-form sibling
  "no lov some coward is boy" the same way. Cause: canonical form puts the relational
  complex in subject position, and the renderer concatenates word-for-word, having no
  relative-clause machinery. Same proposition, readable the other way round.
  Fix, entirely in our trace layer: gloss the converse orientation when one exists —
  "some boy lov some girl", "no boy lov some coward". **The formal step is never
  rewritten**; only its English gloss moves, so the proof record stays byte-faithful to
  what the engine derived. No change to `Render`, so no deviation from the frozen 1.9
  contract and no impact on the rendering differential gate — the trace record has no
  counterpart in the JS engine at all.
  The correctness guard matters more than the readability: converting a form conversion
  is invalid on would make the gloss assert something the step does not — a lying audit
  trail, worse than an awkward one. `Relational.orientations` supplies a converse only
  for I- and E-forms (A and O return unchanged), and we add a level check of our own
  because that converse is built with `Infer.st`, which sets level 0 — glossing a "most"
  step as a bare "some" would understate it. All three guards pinned: A-form, O-form and
  levelled subjects are asserted *identical* after the call, not merely different.
  **Two open items, both now visible in `docs/trace-samples.md`.** (a) `explain_proof` is
  frozen, so the explanation sentence still reads "Because some lov some girl is boy…"
  directly beneath trace lines that read well — the inconsistency is more conspicuous
  than the original uniform awkwardness, and improving it is a deliberate deviation with
  the full gate. Kyle's call. (b) Universals with a relational subject (De Morgan's
  head-of-a-horse: "every head some horse head some animal") cannot be converted at all —
  A-forms do not convert — and reading them well would need real English machinery inside
  the frozen renderer.
- **3.3 accepted.** Kyle approved the trace format on the post-3.4 samples ("these sound
  good now"). Phase 3 is complete. Carried forward, not silently closed: the frozen
  `explain_proof` sentence still renders relational subjects the old way, so it reads
  inconsistently with the trace lines directly above it. Fixing it is a deliberate
  deviation from the frozen reference plus the full engine gate, and Kyle has not been
  asked to spend that — it stays a named open item in `docs/trace-samples.md` rather than
  a quiet acceptance.
