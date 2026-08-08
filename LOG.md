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
- **4.1 done — the translation contract.** `translate/schema.ml`: the strict JSON shape a
  translator model may answer with, validated for *shape only* — whether a `tfl` string is
  a real proposition is 4.3's question, so the `translate` library stays independent of the
  engine and a malformed wrapper is never confused with an unparseable formula. Two
  deliberate leniencies, both to stop a formatting habit being scored as a translation
  failure: an absent array reads as empty (a model with nothing to decline routinely omits
  `untranslatable`, and rejecting the payload would discard real translations *and*
  corrupt the parse-rate metric), and one markdown code fence is stripped. An empty object
  is still a refusal — "neither array is present". Rejections carry the path to the
  offending value (`translations[2].confidence`), because that reason is the only evidence
  we get when a model's rate collapses mid-run. `test/test_schema.ml`, 26 checks, paired
  accept/refuse cases plus an assertion that each refusal names the *right* index.
- **4.2 done — the translation prompt.** `translate/prompts.ml`: 15 few-shot pairs whose
  formulas are propositions from `paper_cases` (or term-structure instances of them) with
  English attached, so the shapes we teach are shapes the engine is known to decide
  correctly. Every few-shot uses the ASCII aliases (`-`, `+-`); the one exception is the
  passive's pairing subscripts, which have no ASCII spelling in the notation.
  **No verdicts anywhere in the prompt** — showing a model a valid/invalid judgement would
  invite it to reason to the answer and fit a formula to it, which is exactly the confound
  the fidelity claim has to avoid. Four worked *decline* examples carry the other half of
  the contract; the router claim rests on a model refusing rather than forcing a lossy
  formula. `test/test_prompts.ml`, 21 checks: the acceptance check (every formula parses)
  plus round-tripping through the printer, coverage assertions naming each construction
  the set keeps alive, a check that the passive example's subscripts really read as
  pairing roles rather than degrading into a relation named "Lov₂₁", and an assertion that
  no verdict vocabulary leaked into the prompt text.
- **Second literature sweep (Kyle's redirect toward expressiveness and real-world impact).**
  Six parallel sweeps, archived verbatim in `docs/lit-sweep-2026-08-01/` with a README
  carrying the synthesis. Not a PLAN step; no plan was rewritten on the basis of it.
  **Three things it killed:** a deontic layer on input/output logic (Governatori and
  Ciabattoni — the formalism's own authors — already published LLM→defeasible deontic logic
  on real regulatory text, arXiv:2506.08899; the "Ross's paradox is blocked in OUT₁/OUT₃"
  claim in `expressiveness-literature.md` §2.3(f) is **inverted**, since all eight I/O
  logics satisfy weakening of output; and constrained output, the contrary-to-duty device,
  sits at the second level of the polynomial hierarchy rather than coNP). Deterministic
  back-rendering as *our* differentiator (prior art in ACE since 2008, plus PENG and GF).
  And the claim that no modal/temporal extension of TFL exists (Englebretsen, NDJFL 29(3),
  1988).
  **What it found instead:** missing-premise suggestion is an *unpublished* result, not a
  port — TFL's first validity condition is an equation over a free abelian group on signed
  terms, so the missing premise is `C − ΣPᵢ`, no search, on the fragment where P/Z decides;
  it also answers the "why was I *not* found eligible?" question that description logics
  need abduction for. Murphree's numerical term logic (NDJFL 39(3), 1998) is a strict
  superset of our TFL⁺ levels. Nute-style defeasible logic beats ASPIC+/ABA for our case
  because the superiority relation is free inside the linear algorithm, where adding
  preferences to ABA lifts grounded reasoning from P to Δ₂ᴾ.
  **Two cautions.** The audit gap is real and named in print by three independent groups —
  Fuchs (CNL 2018), ACE's own author, designed this exact experiment and wrote "For lack of
  resources I did not do the experiment" — but Alrabbaa et al. (RuleML+RR 2022) measured
  laypeople on logic proofs at a mean of 2.36/12, so a logic-based trace is not
  automatically comprehensible. And the systems with real production footprints use the
  *least* expressive formalisms; the richest logics have the weakest deployment records.
  **Method finding that reaches backwards.** Four of six sweeps independently caught the
  PDF summariser fabricating content, in one case from undecodable binary noise; all four
  switched to `curl` + `pdftotext`. That is almost certainly the origin of the inverted
  Ross claim. Any citation in this project not sourced from extracted primary text should
  be treated as unverified until it is — including much of the earlier survey.
  **Left untouched deliberately:** `scope-and-predictions.md` §1 (pre-registered
  predictions — rewriting them after the fact would destroy the only reason they exist)
  and the two known errors in `expressiveness-literature.md`, both recorded in the new
  README instead. Kyle's call.
- **4.3 done — the translator harness.** `translate/translator.ml` plus
  `translate/cache.ml`. Four outcomes per input sentence; `Absent` is the one that had to
  be invented, because a model that silently drops a sentence would otherwise shrink the
  denominator and flatter every rate we report. Matching replies to inputs is on a
  normalised key (case-folded, whitespace-collapsed) and **refuses paraphrases**: pairing a
  formula with a sentence it may not be about is undetectable downstream — the parse rate
  still computes, the back-check compares the wrong pair, and the fidelity audit measures
  nothing. Reporting `Absent` is strictly better than a plausible wrong pairing.
  A test caught a real bug before the live run: `index_by_nl` deduped at indexing time, so
  a model answering the same sentence twice had its second formula silently discarded
  rather than surfacing in `extra` — which is exactly the "model disagrees with itself"
  signal we would want to see. Fixed by consuming one reply per claimed sentence.
  Cache keyed by a digest of the exact (model, system, user) triple — deliberately *not*
  fuzzy, since a hit must mean "this exact question was asked", never "something like it".
  `data/cache/` gitignored and added to the CI untracked guard.
  **Live smoke, $0.035 total:** all three models, 5 sentences, **100% parse rate** (4/4
  attempted each), and all three declined the tense sentence with a temporal reason — the
  router signal fired on its first real test.
  **Two things the run showed that the parse rate hides**, both now on the record for the
  fidelity experiment: (a) the three models produced three *different* structures for "No
  temporary worker is eligible for the pension" — Sonnet quoted it as one term, GPT read
  "the pension" as a singular inside a relational, Kimi read "temporary worker" as a
  compound (+Temporary+Worker), which glosses as "no temporary **and** worker…". All three
  parse; they are not the same claim. (b) Relation naming diverged across models (`Wrk` /
  `Work_for` / `Work`) — harmless for one sentence, but two premises of one argument that
  name the same verb differently will not connect, so term-naming consistency across a
  multi-premise item is a threat the fidelity measurement must cover explicitly.
- **4.5a done — the fidelity gold set.** `data/fidelity/items.jsonl`: 85 items, 91
  translatable sentences, 8 arguments, 10 declines, across 51 construction tags. Ours,
  authored, committed. `test/test_fidelity_set.ml` (25 checks) runs on every `dune test`
  and guards the three ways a gold set silently becomes fiction: an unparseable gold
  formula (the model gets charged for our typo), a wrong stated verdict (a faithful
  translation scored as producing the wrong answer), and **contamination** — a test
  sentence that also appears in the few-shot prompt measures copying, not translation,
  and the contaminated items are exactly the ones that look like successes.
  Group J exists because of a gap in the 4.3 smoke: relation naming diverged *across*
  models (`Wrk`/`Work_for`/`Work`), which is harmless since we never mix models inside an
  argument — but no smoke item reused a relation, so the failure mode that *would* matter,
  one model naming a relation two ways across premises of one argument, went untested.
  Every group J item reuses one.
  **Scoring decision recorded here because it changes what the experiment means:** exact
  string match against gold is the wrong primary metric. Term names are arbitrary — three
  models wrote three different stems for one verb in the smoke and all three were right.
  The primary metric is structural isomorphism to the gold under a *consistent* renaming
  of terms, with the engine's own equivalence decision as the next layer down.
  Honest limitation, recorded in `data/fidelity/README.md` rather than discovered later:
  these sentences are authored, not sampled from statutes. Sentences written by someone
  who knows the notation are biased toward being translatable, so this set yields an upper
  bound and must be reported as one. A real-text arm is owed.
- **4.5b done (bare few-shot arm) — the fidelity risk is measured, and it did not
  materialise.** Full write-up: `docs/fidelity-report-2026-08-01.md`. 45 calls, $0.44.
  Kimi 100% (91/91), Sonnet 99% (90/91), GPT 96% (87/91) faithful; **273 formulas, zero
  unparseable**; 30/30 out-of-fragment sentences declined with correct reasons and no
  over-declining; 24/24 argument verdicts reproduced end-to-end.
  **Genuine model errors across all three models: two**, both GPT-5.6-terra, both the same
  bug — it flips the quality sign on an E-form with a negative subject, writing
  `-(-Member)+Eligible` for "No non-member is eligible", which asserts the opposite. Two
  for two on that construction. It is also exactly the error class this pipeline exists to
  catch: parses, reads plausibly, means the reverse.
  **The out-of-distribution fear is refuted for syntax.** The sweep's calibration point
  (NL→TLA+ at 26.6% syntactic, attributed to corpus scarcity) does not transfer. Best
  explanation: TFL's structural simplicity — four parts, no variables, no quantifier scope
  — outweighs its absence from training data. That countervailing force was named before
  the run but could not be sized.
  **Naming consistency is a non-issue.** Group J existed solely to catch a model naming one
  relation two ways across premises of one argument. It caught nothing, 24/24.
  **Prediction check, recorded rather than quietly updated:** the pre-registered threshold
  was ≥70% structural accuracy for viability. Actual 96–100%. Wrong by a wide margin, in
  the good direction. `scope-and-predictions.md` §1.3's "parse rates possibly no better
  than FOL, plausibly worse" also looks wrong here, but stays open — there is no matched
  FOL arm yet.
  **Instrument defects, disclosed.** (a) Post-hoc: group D accepted both the compound and
  quoted readings of an intersective adjective+noun — decided *before* the run — and group
  E, the same construction, did not. Models read "long-term resident" as long-term ∧
  resident, correctly; my gold called it wrong. Five items patched and flagged
  `"scoring":"disputed"`. Raw pre-correction numbers (94.5 / 97.8 / 91.2) are reported
  alongside the corrected ones, because the fix came after seeing data. (b) Post-hoc: name
  anchoring used subsequence matching, which handles a dropped letter (Wrk/Work) but not a
  substituted one (Notifi/Notify); added a 4-character common-prefix rule. (c) Two scorer
  bugs caught *pre-run* by its own tests — canonicalising before comparison made the scorer
  blind to quantity levels (`Infer.st` sets level 0), and also commuted I/E forms so a
  conversion scored as structurally identical. Both fixed by comparing raw trees.
  **Bound on all of it:** the sentences are authored, not sampled from statutes, so this is
  an upper bound on well-formed input — not evidence that translation is solved on real
  regulatory text. The real-text arm is now the most valuable measurement remaining.
- **PLAN rewritten from Phase 4 onward; `expressiveness-literature.md` corrected.** Kyle's
  instruction was to take the *end-state* of the day's decisions, not the intermediate
  positions — several of which were reversed once the sweeps landed. What changed:
  **Dropped.** The input/output-logic deontic layer, on three independent counts: the
  ground is occupied by the formalism's own authors (Horner/Mateis/Governatori/Ciabattoni,
  arXiv:2506.08899, LLM→defeasible deontic logic on real regulatory text); the
  "Ross's paradox is blocked in OUT₁/OUT₃" claim was **inverted** (all eight I/O logics
  satisfy weakening of output, so Ross holds in every one); and constrained output — the
  contrary-to-duty device — is at the second level of the polynomial hierarchy, not coNP.
  Contrary-to-duty now goes through defeasible rule priorities instead, at linear cost.
  **Deferred with reasons.** Metric time (STN): the one non-TFL component, and its headline
  certificate is weaker than the survey claimed — the published algorithm detects a
  negative cycle by a diagonal sign, yielding a yes/no plus a node, not the readable chain
  of deadlines. Deadlines become terms for now. Grammar prompting: nothing left for it to
  fix at a 100% parse rate. Murphree numerical: blocked behind the 5.3 soundness audit.
  **Promoted.** Missing-premise suggestion to Phase 6.1 — it is an *unpublished* result
  (`C − ΣPᵢ` over the free abelian group), has no FOL counterpart, and answers the
  "why was I *not* found eligible?" question description logics need abduction for. 4.4's
  back-check from nicety to correctness mechanism, with a pinned acceptance test: it must
  catch GPT's `c02`/`c06` sign flip unaided. Phase 9 (the auditability study) created as
  its own phase — per the sweeps it is the actual contribution, and three groups name it
  open in print, Fuchs having designed the experiment and written that he never ran it.
  **Added.** 4.6 real-text arm (coverage has replaced fidelity as the largest unknown),
  4.7 matched FOL arm (core claim 1 is comparative and currently unsupported), 4.8 dev/eval
  split before any prompt tuning, 5.2 anaphora-policy pin, 5.3 numerical soundness audit,
  6.2 definitions layer using the 1.7 programs code nothing currently calls.
  **Phases renumbered:** old 6→8, 7→10, 8→11; a mapping note sits at the end of PLAN.
  `expressiveness-literature.md` now carries a READ-THIS-FIRST header and three inline
  `⚠️ CORRECTED` blocks. The Castro-Manzano citation it warned against does not exist under
  that title — the paper is "Remarks on the Idea of Non-monotonic (Diagrammatic)
  Inference," *Open Insight* 8(14):243–263, 2017 — and its claim that no certified modal
  extension of TFL exists is wrong (Englebretsen, NDJFL 29(3):381–395, 1988).
- **Predictions frozen; Block B pre-registered.** `scope-and-predictions.md` §1 now carries
  a 🔒 header and is untouched otherwise (Kyle's approval). A new §1B records six
  post-redirect predictions made before the measurements exist — real-text coverage 25–45%
  (now the project's largest unknown), real-text fidelity 80–92%, back-check false-positive
  rate 5–20%, TFL and FOL within 5 points on accuracy with TFL winning only on
  auditability, non-expert audit accuracy 70–85%, and the defeasible layer worth +10–25
  points of coverage at flat accuracy. The already-scored 4.5b threshold is carried in the
  scorecard as ❌ wrong.
- **4.4 done — the back-check, and it found more than it was built to find.**
  `translate/backcheck.ml`: render the model's formula through the 3.4 readable orientation,
  then ask a judge whether that reading makes the same claim as the source sentence. The
  judge never sees the TFL — showing it the formula would let it rate the formula it can
  see rather than the English it produced, which is the failure being tested for. Missing
  judgements fail *closed* (scored 0), because silence must never read as "no disagreement".
  `test/test_backcheck.ml` (14 checks) leads with the test that decides whether the
  mechanism can work at all: a meaning-inverting formula must render into *different*
  English from the correct one. It does — `-(-Member)-Eligible` reads "no non-member is
  eligible", `-(-Member)+Eligible` reads "every non-member is eligible".
  **Acceptance PASSED.** Over all 91 GPT translations from 4.5b, judged by Sonnet: both
  known-bad items flagged **unaided**, with accurate diagnoses ("quantifier reversed,
  opposite claim"). False positives 3/87 = **3%**, against a pre-registered 5–20% and a
  20% abandon threshold.
  **Two of those three "false positives" are real defects in our own artifacts** — the
  check surfaced them without anyone looking, which is a stronger demonstration than the
  pinned catch:
  (a) **The renderer drops quantity levels whenever the predicate is a relational complex.**
  `+Officer^1+(Sign+Contract)`, `^2` and `^3` all read "some officer sign some contract",
  identical to level 0. `render.ml` gates the quantifier word on `not rel_pred`, and
  port-spec §14 documents the same, so this is inherited from the frozen reference, not a
  port bug. It matters now that the rendering is an *audit surface*: a human checking a
  levelled relational proposition is shown "some" where the formula says "many", and the
  back-check is correspondingly blind to a dropped quantifier there.
  (b) **Our own gold for i04 is semantically wrong, and the 4.2 prompt taught the error.**
  Port-spec §14: **`few` inverts the English polarity** — `+S³+P` → "few s is not p",
  `+S³−P` → "few s is p", because level 3 is the *predominant complement*. So "Few
  volunteers are employees" is `+Volunteer^3−Employee`; our gold has `+Volunteer^3+Employee`,
  which asserts the opposite. All three models matched the wrong gold, which is not a
  coincidence: `prompts.ml` teaches "^3 few" with no mention of the inversion — the same
  loose phrasing that caused the mistake. Nothing changed yet: fixing `prompts.ml` changes
  the cache key and invalidates the 4.5b run (~$0.44 to redo), so it is Kyle's call.

## 2026-08-02

- **4.8 done — the dev/eval split, drawn before anything has been tuned.**
  Every item in `data/fidelity/items.jsonl` now carries `"split"`: **42 dev, 43
  eval**. Nothing else in the file changed — it is byte-identical to what 4.5b
  graded apart from the added field — so the frozen report stays reproducible
  and the whole set re-cuts by split off cache for $0.
  Assignment is stratified within each group so both halves carry the same
  constructions, with one override: **every item already implicated in an
  observed error is forced to dev**, since a prompt fix for it is foreseeable —
  `c02`/`c06` (the E-form sign flip), `i04` (the `few` inversion our own gold
  gets wrong), `i06` (the renderer level-drop on relational predicates), `b04`
  (the definite-description convention we chose rather than sourced).
- **The guard that earned its keep was the one PLAN didn't ask for.** The step
  specified an eval-contamination check. Writing it surfaced a second, quieter
  failure: dev and eval *shared material*. Group J's arguments are assembled
  from the same sentences as groups A, F and I, so the first cut of the split
  had three collisions — `a01`/`j04`/`j05` and `a03`/`i01`/`j08` among them.
  Promoting dev item `a01` into the few-shot prompt would have contaminated
  **eval** item `j04`, invisibly, which is precisely the outcome the split
  exists to prevent. `test_fidelity_set.ml` now checks that no sentence and no
  proposition (compared canonically, not as a string) straddles the split, and
  the split was re-cut so each collision class sits wholly on one side. Found
  by the test, not by inspection — the hand-drawn split looked fine.
  Third guard: the eval id list is **pinned in the test file**, so relabelling
  an item that came back wrong is a reviewable code change rather than a quiet
  data edit. 29 checks, up from 25; full `dune test` green.
- **Re-cutting 4.5b by split, at no cost.** `bench/run_fidelity.ml` now tallies
  and reports eval / dev / all separately, and the TSVs carry the split in
  column 1. The `all` column reproduces the frozen 4.5b numbers exactly
  (Kimi 100%, Sonnet 99%, GPT 96%).

  | model | eval | dev |
  |---|---|---|
  | kimi-k3 | 100% (44/44) | 100% (47/47) |
  | claude-sonnet-5 | 98% (43/44) | 100% (47/47) |
  | gpt-5.6-terra | 98% (43/44) | 94% (44/47) |

  The shape is what the burn rule predicted: **both meaning-inverting errors
  (`c02`, `c06`) are in dev.** Every remaining miss across all three models is
  the *same* disagreement — group E's multiword terms (`e02`, `e03`, `e06`),
  where a model read "person under eighteen" or "duly authorized officer" as a
  compound our `also_ok` list happens not to enumerate. Those are structural
  reading choices, not errors of meaning.
  **Deliberately not fixed:** widening `also_ok` on `e02`/`e06` would be editing
  *eval* gold in response to an eval result. Same self-serving move as moving a
  failed item to dev, one layer down in the scorer. Flagged for Kyle instead.
- **Two eval coverage holes follow from the burn rule**, recorded in
  `data/fidelity/README.md` and owed to 4.6: eval has no negative-term E-form
  (both are burned) and no quantity level 3 (`i04` is the only level-3 item in
  the set, and its gold is wrong).
- **Still Kyle's call, unchanged from 2026-08-01:** the `prompts.ml` "^3 few"
  wording and the `i04` gold. Both are now dev items, so fixing them costs no
  eval measurement — which is exactly what 4.8 was for. It still invalidates the
  cached 4.5b run (~$0.44 to redo).

- **The `few` inversion, fixed — and the back-check was right about our gold.**
  Kyle approved the spend, so both halves landed: the `i04` gold and the
  `prompts.ml` level-3 wording. Verified against the frozen JS reference before
  touching anything, rather than trusting the port-spec restatement —
  `readProp(parseProposition('+Volunteer^3+Employee'))` returns *"few volunteer
  is not employee"*, so our gold for "Few volunteers are employees." asserted
  the opposite of its own sentence. Gold now `+Volunteer^3−Employee`; the
  notation block states the flip in both directions; a worked pair
  ("Few voters are radicals." → `+Voter^3−Radical`) teaches it, because the
  *rule alone* is precisely what had failed. Sixteen few-shots now, one over
  PLAN 4.2's 10–15 — deliberate: dropping a working pair to make room would
  have traded proven coverage for the fix.
  `test_prompts.ml` pins it two ways (structural: a `Few …` pair must carry
  level 3 and a minus predicate; independent: it must **read back** through the
  engine without a negation), both verified to fire on the inverted formula.
- **Re-run 4.5b in full — Kimi 100%, Sonnet 100%, GPT 98% (88/90, one refusal).**
  `docs/fidelity-report-2026-08-02.md`; `-08-01.md` carries a SUPERSEDED banner
  and is kept unedited. 45 calls, $0.54; back-check re-measure 8 calls, $0.08;
  session total 53 calls, **$0.62**.
  **The result that matters is what did *not* change.** The prompt rewrite fixed
  all four group-E multiword misses and every model's `i04`. It did nothing to
  `c02`/`c06`, GPT's E-form sign flip — the only meaning-inverting errors in the
  study. PLAN 4.4 stated "prompt patching buys coverage, the back-check buys
  correctness" as a prediction; this is it observed.
  **4.4 re-measured: acceptance PASSED again**, both known-bad flagged unaided,
  false positives **2/88 = 2%** (was 3/87). The one that disappeared was `i04` —
  it had never been a false positive.
  Both survivors are again **our** renderer's defects, not judge errors: `i06`
  (quantity level dropped when the predicate is a relational complex) and `d03`
  ("registered voter" read back as "registered and voter"). True false-positive
  rate against a correct renderer: 0/88.
- **The prompt fix also broke something, and it is recorded rather than chased.**
  GPT now *refuses* `b08` ("Priya is both a director and a shareholder."),
  which it translated correctly before, calling it "two predicates joined by
  conjunction" — but `(+Director+Shareholder)` is a compound term and exactly
  what the notation is for. It is an **eval** item. Attributing it to the added
  pair versus the reworded block needs an ablation, and tuning further against
  an eval item is what 4.8 exists to prevent. Left alone, reported in the
  report's failure section. It is also why that report now carries a *missing*
  column: a refusal is invisible to a percentage computed over attempts.
- **Two defects found in our own plumbing, one fixed here, one flagged.**
  Fixed: `smoke_backcheck.ml` parsed the fidelity TSV expecting 5 columns, and
  the 4.8 commit earlier today added a 6th (`split`). It would have silently
  loaded **zero** rows and printed a 0/0 false-positive rate that reads as a
  pass — so the header check is now fatal rather than skipped. A regression I
  introduced, caught only because the back-check happened to be the next thing
  run.
  Flagged, not fixed: `llm_client.ml` treats an empty 200 body as `Llm_error`,
  not `Retryable`, so it does not retry. Two Kimi batches hit it mid-run and 22
  sentence-slots vanished; the reported percentages still looked healthy
  (100% of 71) because `attempted` excludes missing. Re-running filled them for
  $0.05, but 4.6 is a bigger run and will hit this again.
  Also noted: `CLAUDE.md` says "the cost ceiling in config is enforced in code."
  There is no ceiling in `translate/config.ml` and none enforced anywhere.

- **Scope amendment — PLAN rewritten from Phase 4 onward. No code changed.**
  Kyle's framing: a lot of the plan was spending effort on things that already
  exist and are done better elsewhere, which produces no real-world value.
  Redirect onto what only the term-logic approach makes possible. The amendment
  block sits at the head of PLAN with the execution order; the per-step changes
  are recorded in place. Four findings drove it, three of which corrected Kyle's
  own starting position:
  1. **The back-check's round trip is occupied prior art.** Amrollahi, Lopez &
     Barrett (arXiv:2604.25031, 2026) do formalize → back-translate → re-formalize
     → check equivalence, on Texas statutes. Lit sweep 1 §11b/§15 already ranked it
     the second-largest novelty threat and said our claim must pin to the
     human-facing rendering. Our 4.4 is also machine-consumed (an LLM judge reads
     the rendering), so on that axis we are currently in the same bucket. What
     survives: the verbalizer is a **total deterministic function** rather than a
     second language model, and Phase 9 puts it in front of a person. **Consequence
     for the plan: Phase 9 is the centrepiece, not the epilogue** — without it,
     capability 1 reduces to "our English generator is deterministic."
  2. **The missing-premise feature is a build, not a port, and "subtraction" is
     too simple.** `engine/tfl.js:1863`/`:1909` is bounded brute force — enumerate
     every two-term proposition over ≤8 term names and test each — i.e. guess-and-
     check, which is exactly what abduction has always been. Porting it buys zero
     novelty. And P/Z permits **re-using universal premises** (`tfl.js:389–396`), so
     the closed form solves a small integer equation with unknown multiplicities,
     not `C − ΣPᵢ` literally. The reference's own comment knew it. Claim wording
     fixed everywhere: "closed form where others must search", never "no FOL
     counterpart."
  3. **The renderer is load-bearing under three keepers and had no PLAN step.**
     New step **5.0**. `lib/tfl/render.ml` — our OCaml — drops quantity words when
     the predicate is a relational complex (line 107 gates on `not rel_pred`) and
     reads compound terms as conjunctions. Those two are the *only* remaining 4.4
     false positives (true rate against a correct renderer: 0/88), and each would
     put wrong English in front of a Phase 9 participant, making the study measure
     our bug. Verdict-safe by construction, so the frozen-reference rule does not
     block it.
  4. **The pronoun-policy check was about to be dropped and protects a headline
     claim.** If our pronominalization implements general anaphora the fragment is
     undecidable, and the paper's "decidable where ACE is not" sentence is false —
     taking the router claim's substrate with it. One session. Kept, and moved to
     the front of Phase 5.
- **Decisions Kyle made in the same conversation.**
  - **The JS reference's authority is split.** Frozen forever and *never edited* —
    a reference you may edit becomes a mirror, and the day someone "fixes" it to
    match an OCaml bug the gate goes silent. Authoritative on **verdicts** forever
    (two independent implementations agreeing on 884k inputs is real evidence);
    **no authority at all** over English rendering, where it is one earlier draft
    with two proven bugs. Rendering deviations exempt only the constructions
    actually changed and **report the exempted count**, the same pattern
    `diff_parse_program` already uses for the comment stripper. Nothing is lost
    that was worth having. (Kyle's question — "should we update both?" — answered
    no, for that reason.)
  - **Phase 9 item sourcing.** The faithful half is easy (88 correct translations
    exist); the unfaithful half is the design's weakest joint, because the entire
    4.5b study produced **two** meaning-changing errors and they are the same error
    twice. Decision: real errors first, harvested from the 4.6 real-text run;
    hand-made items only to fill the gap; every item labelled which kind it is and
    the two reported separately. Mix fixed in writing before the first participant.
    **4.6 now owes an error-collection deliverable it did not have.**
  - **Phase 9 runs as a pilot with ~10 friends and colleagues first**, explicitly
    labelled a pilot before it runs, then a decision on a paid panel. Recorded with
    what n≈10 cannot buy (at that size, 55%–90% are indistinguishable) and the fact
    that friends are not non-experts *about this project*. The label matters: a
    pilot may change its design freely; an unlabelled run scaled up after an
    encouraging number is contaminated.
- **Cuts, deferrals and one reshape.**
  - **Phase 7 (defeasible) deferred outright**, and **8.3 (DeonticBench) with it** —
    DeonticBench exists to evaluate Phase 7, so it is one decision. The proposed
    reopening trigger ("only if coverage starves Phase 9") was **withdrawn as
    unfireable**: the study needs ~40 items and 4.5b alone supplies 91. Replaced by
    the real trigger — §1B.1 predicts multi-clause structure and cross-reference
    dominate the refusals, in which case the cheap coverage lever is **sentence
    splitting before translation**, which is nowhere in the plan and costs a
    fraction of a defeasible engine.
  - **6.3 (Murphree) cut**, not deferred: it widens the fragment, which runs against
    this project's own thesis that the narrowness is the product.
  - **6.2 (definitions layer) kept as a tool feature, cut from the paper.** Ported in
    1.7 and nothing calls it; it is the difference between an argument checker and
    something you can point at a policy document, and Kyle's first priority is the
    tool.
  - **4.7 reshaped, not kept as written.** Building a FOL parser + structural
    comparator was the largest remaining build and the largest remaining chunk of
    reimplementing others' work — to confirm a tie §1B.4 already predicts (within 5
    points). Now three parts: a cheap accuracy number off an existing prover, the
    **head-to-head moved into Phase 9 as a control arm** (participants audit our
    rendering vs a raw FOL formula — the experiment that actually supports claim 1),
    and the FOL→TFL transduction arm, which nobody has run.
  - **Phase 8 trimmed** to policybench + the syllogism set. The syllogism set is kept
    for a **corrected reason**: belief bias is precisely SemEval-2026 Task 11's
    subject with dozens of published systems, so it is the most crowded ground left,
    not our clearest win — but after the trim it is the only public benchmark in the
    plan and the only external comparability point a reviewer can be pointed at.
  - **New step 4.9**: the empty-200-body retry bug (22 sentences silently vanished
    last run; the log had already warned 4.6 would hit it again) and the cost ceiling
    `CLAUDE.md` claims exists and does not. Both run before the real-text measurement.
  - **CLI moved earlier** out of 11.4 — 4.6 and 6.1 both want it.
- **Predictions affected, recorded rather than dropped.** Block A §1.5 (FOLIO
  coverage) and Block B §1B.6 (defeasible coverage) become unmeasurable and are
  marked *not run*. Block A §1.6 (selective accuracy ≥98%) **survives** the Phase 8
  trim: policybench alone still yields the (coverage, accuracy-given-coverage) pair.

- **4.9 done — the two plumbing defects closed before the real-text run.**
  Both were recorded on 2026-08-02 and unactioned; both bite a bigger run.
  - **The empty-200-body bug.** The classification lived inline in `call_once`
    and only ever produced "2xx → body". An empty body therefore travelled all
    the way to `parse_response`, which raised `Llm_error` — **outside** the
    retry loop, by construction. Fixed by splitting the decision out as a pure
    `disposition_of ~code ~raw : Body | Retry | Fatal`, with an empty or
    whitespace-only 2xx classified `Retry`. The retry loop is now `with_retries`,
    generic over its thunk. Both changes exist so the behaviour is testable
    without a network — a test needing a live endpoint would never be run, and
    this defect survived precisely because nothing tested it.
  - **Confirmed the test is not vacuous.** The empty-body check was reverted for
    one run: `test_llm_client: empty 200 body is retried` fails on the old
    classification. Restored immediately. 25 checks in the new suite, covering
    the classification, that a `Retryable` actually produces further attempts
    (the half the 22 lost sentences needed — classification alone buys nothing),
    and that fatal errors and the ceiling are not retried.
  - **The cost ceiling.** `Config.cost_ceiling_usd = 5.0`, checked in `complete`
    before every request, so a runaway loop overshoots by at most one call.
    Sized against real spend: the whole 4.5b run across three models was $0.54,
    so five dollars is roughly ten full runs — it will never interrupt honest
    work, and a bug cannot get far. Cache hits never reach the client and are
    never counted, which is the right accounting: they are free.
  - **A stopped run prints no summary.** `run_fidelity` catches `Cost_ceiling`,
    reports the spend, and exits 1 without the summary table. A half-run
    reported as a run is the *same* failure as the 22 missing sentences: every
    percentage still computes and nothing in the output says the denominator is
    wrong. That is now two occurrences of this shape, so it is worth naming as a
    class — **a measurement that degrades quietly is worse than one that fails.**
  - **`CLAUDE.md` left standing, because it is now true.** Its claim has two
    halves and only the ceiling half was missing; spend reporting is now in
    `run_fidelity` and all three smokes, so the sentence needed no rewording.
  - **Found while there:** the cost reader matched only `` `Float ``, so a
    genuinely free call — JSON `0`, which yojson types as `` `Int `` — would have
    been filed as unpriced. Fixed. The residual hole is real and reported rather
    than hidden: a reply OpenRouter prices at nothing *at all* cannot be counted,
    so the spend line names how many such calls there were and says the total is
    a lower bound. The ceiling is only ever as good as the provider's accounting.
  - No OCaml engine logic touched (changes are in `translate/`, `bench/`,
    `test/`), so the 20k oracle and mass differential gates are not triggered.
    `dune test` green.

- **5.2 done — and the answer is a third option nobody wrote down: the engine
  implements *no* anaphora resolution at all.**
  The question mattered because Pratt-Hartmann Thm 15/16 put a knife-edge on
  the same syntax — restricted anaphora NEXPTIME-complete, general anaphora
  **undecidable** — and the paper claims our fragment is decidable where ACE is
  not. The plan expected RA or GA. It is neither.
  - **A primed name is a constant.** `Boy′` denotes one individual and is
    related to nothing: not to `Boy`, not to any antecedent, not by proximity
    and not by co-indexing. The prime's entire effect is `Infer.is_fixed_ref`,
    the same predicate `*` satisfies, and the 1.10 semantics assigns proterms
    single domain elements in the same table as singulars.
  - **Two independent proofs that nothing is resolved.** `±Boy′+Boy` — "that boy
    is a boy" — is not valid, and has a one-element countermodel. And
    `pronominalize` records an explicit `±T′+T` anchor for every witness it
    introduces; nothing would need anchoring if the reference resolved itself.
    That function turned out to be **Skolemization for indirect proof**, running
    in the opposite direction from anaphora resolution: it creates constants for
    existential witnesses rather than consuming a pronoun and finding its
    antecedent. The name is what made this look like a live risk.
  - **Not a stop-and-report, but the paper's justification changes.** We sit
    strictly *below* both RA and GA rather than between them: Thm 16's tiling
    encoding needs a pronoun co-varying with a quantified antecedent, and that
    is inexpressible here. So the sentence must be **"our fragment has no
    anaphora"** — never "restricted anaphora", which would claim Thm 15's
    NEXPTIME expressiveness we do not have. PLAN's Phase 11 claim list is
    corrected accordingly and §1.3 of `expressiveness-literature.md` now points
    at the answer instead of asking the question.
  - **The same fact is a coverage cost.** Pratt-Hartmann's witness sentence —
    "Every artist who admires a beekeeper hates every carpenter who despises
    him" — cannot be translated at all: `him` is either a general term (does not
    co-refer) or a proterm (one fixed individual for the whole formula). 4.6
    should expect back-references among the `Outside_fragment` reasons, and it
    belongs in the limitations. Decidability and coverage are the same fact from
    either side, which is the project's thesis stated in miniature.
  - **Method note worth keeping.** Every *negative* in the test is carried by an
    exhibited countermodel from the 1.10 semantics, never by an engine verdict:
    outside the categorical fragment the engine answers `Unknown` where the
    truth is "invalid", so a verdict can never establish a negative. The
    discriminating pair — a proterm object does not co-vary, a general-term
    object does — would have been unprovable from verdicts alone, since the
    control comes back `Unknown`. That `Unknown` is now pinned too.
  - No engine logic touched: this step is a test and two documents. `dune test`
    green, 18 new checks.

- **5.0 done — the renderer is now ours, and it is the audit surface.**
  Kyle approved the readings on 2026-08-02 after reviewing them one construction
  at a time. Three deviations from the frozen JS renderer, each verdict-safe by
  construction (an English reading decides nothing), each commented at its
  branch, exempted by name in the differential, and pinned in a golden test.
  - **Two proven bugs, one line of logic each.** The level gate
    `lvl > 0 && not rel_pred` became `lvl > 0`: `rel_tail` already rendered a
    relational predicate in both polarities, so nothing else moved, and level 3's
    polarity inversion carried over unchanged. The compound joiner became `" "`
    from `" and "` — a compound is one term, and English writes an intersection
    by juxtaposition. These were the **only two remaining false positives** in
    the 4.4 back-check.
  - **A third deviation Kyle asked for after seeing the readings: the comma
    seam.** A relational subject trails off with no closing word and an
    affirmative relational predicate opens with none, so "every head some horse
    head some animal" ran together with nothing between. A comma marks it. Chosen
    over inserting "is" for a reason that generalises: **the comma needs no
    knowledge of English words.** "is" is right for a noun-like relation and
    wrong for a verb-like one ("every lov some woman is lov some girl"), and the
    renderer cannot tell them apart. Where the tail already opens with "does
    not", that word is the marker and no comma is added.
  - **The pinned corpus exemption earned its keep immediately.** Adding the comma
    took the corpus count from 5 to 7 and the gate failed, naming the two new
    strings (the De Morgan head-of-a-horse pair) before anything was committed.
    That is the whole point of pinning an exact number rather than reporting one:
    a widening exemption becomes a reviewable diff instead of a silent drift.
  - **The exemption predicate is exact, and the gate corrected it once.** A
    rendering differs from the reference *iff* it hits one of the three
    constructions. The first cut was not recursive through propositional terms
    `[…]`, whose interiors `read_term` renders via `read_prop` — the differential
    failed loudly with "few … does not d__4_ …" against "some …". Now mutually
    recursive over terms and propositions.
  - **Two decisions from Kyle worth keeping.** "Of" is refused as a *decision*,
    not a deferral: the object's sign carries the quantity while the preposition
    is lexical to the relation and slot, and a guessed preposition asserts a
    relationship the formula never states, on the audit surface, where the
    back-check cannot see it. Term naming reaches the first object slot only.
    And "Alice is registered voter", missing its article, is accepted as
    readable.
  - **A new defect found while explaining a formula to Kyle, deferred as 4.10.**
    A negative relational predicate renders `"does not " ^ reading`, which forces
    a noun-like relation into a verb slot: "some employee does not member some
    union". **It is not confined to counterclaims** — that example is an ordinary
    true statement. Same root cause as "of" and as the comma-vs-"is" choice, and
    term naming cannot rescue it (`"member of"` gives "does not member of some
    union"). The lever is naming relations verb-like in `prompts.ml`, which Kyle
    approved and deferred, together with the 4.5b re-run the prompt change forces
    by invalidating the cache.
  - **Gates, all green on the final source.** `dune test` (21 reading groups, 62
    paper cases, 604 corpus strings, 0 disagreements); mass differential 884k
    inputs through 18 gates, **zero disagreements**, 14m50s, exemption holding its
    pin at 7+1 with 123,247 renderings still compared byte-for-byte and all three
    deviations reached; 20k oracle all six suites, **zero failures**, 25m59s. Both
    long gates were re-run from scratch after the comma landed rather than
    trusting the earlier pass.
  - Also corrected: `render.ml`'s own header still claimed its strings "mirror
    the JS renderer exactly" and are a byte-exact contract. False after three
    deliberate deviations, and it would have told the next reader the reference
    still governs English here.

- **5.3 first pass — the numerical layer asserts a wrong verdict. Reported, not
  fixed; the change is verdict semantics and that is Kyle's call.**
  - **The defect.** `check_argument` routes any nonzero level to
    `numerical_decision` and then does `verdict = (if d.n_valid then Valid else
    Invalid)`. There is **no `Unknown` branch on the numerical path**, so every
    inference the three additive conditions cannot derive is positively asserted
    invalid. Pratt-Hartmann 2009/2013 prove no finite syllogistic rule set is
    complete here, so those inferences must exist — and the incompleteness
    surfaces as a **false `Invalid`**, not as an abstention. The rest of the
    engine respects that boundary; `Unknown ≠ Invalid` is documented in the 3.1
    interface for exactly this reason.
  - **Witness, run against the engine:** `+S^2+P ; +S^2+Q ⊢ +P+Q` — "most S are
    P", "most S are Q", therefore "some P is Q" — comes back **`Invalid`**,
    method `numerical`. Valid on our own stated reading of `^2` (most): two
    strict majorities of one set must intersect, |S∩P| + |S∩Q| > |S| so
    |S∩P∩Q| > 0. Empty domain is safe rather than an existential-import trap:
    if |S| = 0 the premise is false and the argument is vacuously valid.
    Condition (ii) is what kills it — two particular premises against one
    particular conclusion, which is precisely the shape an additive rule set
    cannot see.
  - **No false `Valid` found.** Monotone shapes and the genuinely invalid
    controls (most does not convert, most is not transitive, two "many" sets need
    not meet) all came back correct. The gap looks confined to the `Invalid`
    direction — still a wrong verdict by this project's bar.
  - **Why nothing caught it, which is the more useful finding.** The semantic
    oracle **does not model quantity levels at all** — `test/semantics.ml` says
    so in as many words, and `test_oracle.ml` never mentions a level — so the six
    fuzz suites give this layer zero coverage. And the differential gate cannot
    help *by construction*: the frozen JS reference implements the same rule, so
    both engines agree on the wrong answer. **Two independent implementations
    agreeing on 884,000 inputs is strong evidence about the port and no evidence
    whatsoever about a rule they share.** Worth remembering the next time the
    884k number is quoted as general assurance. The only thing that has ever
    checked this layer against meaning is five hand-verified paper cases.
  - **Options put to Kyle:** (a) return `Unknown` instead of `Invalid` on
    numerical non-derivability — safe, honest, costs the layer its ability to
    assert invalidity; (b) decide it algorithmically, since `Sat(Syl+Num)` is
    only NP-complete and integer reasoning gives real verdicts instead of rules
    that provably cannot be complete; (c) document and leave, which the
    correctness bar rules out. Recommended (a) now, (b) only if 4.6 shows
    most/many/few actually occur in real regulatory text.
  - **Owed either way and cheap:** a semantics for level 2. Strict majority is
    unambiguous, so the fuzz suites can cover `^2` even while `^1` and `^3` stay
    unmodelled for want of a threshold. That is what would have caught this.
  - No code changed. `dune test` untouched and green.

- **5.3(a) done — the numerical layer abstains instead of asserting invalidity.**
  Kyle's call after the finding was reported. One line in `decide.ml`:
  `verdict = (if d.n_valid then Valid else Unknown)`.
  - **What it cost, deliberately.** Three paper cases and one verify case that
    the literature presents as *invalid* now come back `unknown` (Tables 10 and
    11, att-3). The layer can certify validity and can no longer deny it. Those
    tests were **retargeted at the decision record** rather than weakened — the
    three conditions must still fail for exactly the paper's reasons, so the
    rule is as tested as it ever was; we have only stopped drawing an unlicensed
    conclusion from it. The book's verdict now lives in each test's name.
  - **Correction to the finding as first reported.** I said condition (ii) alone
    rejected `+S^2+P ; +S^2+Q ⊢ +P+Q`. Conditions (i) and (ii) both fail: the
    shared subject S appears in each premise and in neither side of the
    conclusion, so it never cancels. The additive algebra cannot express the
    inference at all. The witness is now a pinned test.
  - **The differential normalizes rather than exempts**, which is strictly
    better: our `Unknown` is mapped back to the reference's `invalid` for the
    verdict field only, so the **entire decision record** — three conditions,
    both particular counts, carried and conclusion levels — is still compared
    byte-for-byte. 62,880 normalizations in the mass run, all with matching
    records, so the rule is provably unchanged and only the conclusion is weaker.
  - Gates: `dune test` green, mass differential 884k inputs / 18 gates / **zero
    disagreements** / 19m36s, 20k oracle six suites / **zero failures** / 37m59s.

- **4.10 done, and the first attempt at its re-run did not count.**
  - **The prompt change**: relation names must be verb stems even when the
    English nominalizes them ("the holder of a permit" → `Hold`, never
    `Holder`), because the renderer puts the relation name where a verb goes and
    cannot tell a noun from a verb. Readability, not soundness — a term name is
    opaque to the engine.
  - **Result: unchanged, and one problem cleared.** Sonnet 99%, GPT 99%, Kimi
    100%; zero unparseable in 273 attempts, zero missing, 30/30 declines, 24/24
    argument verdicts, $0.05. GPT's `b08` over-refusal is gone without being
    targeted; Sonnet lost one item. One item each way is noise at this size and
    is reported as unchanged. **Neither remaining failure involves a relation
    name**, so the guideline is untested here — its real test is 4.6.
  - **Both failures are decomposition choices, not meaning inversions.** `e02`
    decomposed "person under eighteen" into a compound where the gold kept a
    quoted term; `e07` did the reverse with "non-resident". Worth carrying into
    10.2: "more analytic than our gold" is a different failure from "wrong".
  - **The first attempt reported Kimi 100% (71/71)** — twenty sentences short —
    with a clean summary and exit 0. Three defects, all fixed:
    **(1)** 4.9's fix was in the wrong layer. The empty-body check went into
    `call_once`, inside the retry loop, but `parse_response` still ran *outside*
    it, so every other unreadable 200 stayed fatal on the first attempt. Now
    inside the loop.
    **(2)** A failed batch tallied nothing, not even `missing`. **Third
    occurrence this session of the same shape — a measurement degrading quietly
    instead of failing.** It now counts them and a run with any missing slot
    declares itself not a measurement and exits non-zero.
    **(3)** Found by the new test rather than in the wild: `index 0` on an empty
    `choices` array raises `Undefined`, not `Type_error`, so it escaped
    `parse_response` uncaught and would have killed the process.
  - **Open, not solved:** what the provider actually returned. The old message
    discarded the payload; an empty body was ruled out by probing yojson
    directly. Messages now carry byte count and first 300 bytes.

- **CLI done (`bin/tfl_cli.ml`, pulled ahead from 11.4).** JSON in, JSON out,
  one object per line; `check`, `parse`, `render`. It never crashes and never
  exits non-zero on bad input — a line protocol loses **every queued request
  behind** a crash, not just the one that caused it, so the test interleaves
  garbage with real work and counts replies (14 checks). The taxonomy class
  survives to the JSON, which is what makes 4.6's coverage measurable from
  outside the engine, and both of today's engine changes surface correctly
  through the boundary. One harness bug worth remembering: `Unix.pipe` is not
  close-on-exec by default, so the child inherited its own stdin write end and
  never saw EOF — the test hung until `~cloexec:true`.

- **4.6 done — real-text coverage is 5%, and it reorders the project.**
  Full result in `docs/coverage-report-2026-08-02.md`; scope consequences in
  PLAN's second 2026-08-02 amendment. Three samples, three pre-registered
  protocols, **three wrong predictions, all recorded wrong.**
  - **Normative regulation 5%** (3/60 strict, 7/60 ambient-deontic) against a
    predicted 25–45%. **Definitions sections 25%** (5/20) and **standards of
    identity 3%** (1/30), both predicted 35–60%.
  - **46 of 60 normative sentences are blocked more than once**, which is the
    finding that matters. Blockers: multi-clause 65%, deontic 48%,
    cross-reference 35%, tense 27%, arithmetic 25%, not-a-proposition 18%,
    defeasible 7%.
  - **Sentence splitting — the cheap lever this plan pre-authorised — buys three
    points**, 5% to 8%. It is aimed at the most common blocker and is still
    nearly worthless, because the sentences it fixes are usually deontic too.
    That is the practical lesson of labelling every blocker instead of one.
  - **Defeasibility is the rarest blocker.** The field treats exceptions as the
    hard problem of legal formalization; here they block 7% of normative
    sentences and 0% of standards of identity, while arithmetic and
    cross-reference block three to five times as much. Phase 7's deferral was
    right for the wrong reason.
  - **"Definitional" was the wrong genre cut.** Definitions sections reach 5x the
    normative baseline with the corpus held constant — genre does matter — but
    standards of identity are definitions too and came back *worse than
    obligations*, because they define numerically ("Cream contains not less than
    18 percent milkfat"; arithmetic blocks 47% of them, the highest single
    blocker measured anywhere in this project). What the six tractable sentences
    share is that all are **naming or class-inclusion** statements: the fragment
    fits taxonomy, not description, quantification or obligation.
  - **Taxonomy is not the new product**, and I proposed it before thinking it
    through. Description logic is purpose-built for subsumption, standardised and
    tooled, and does 294k SNOMED concepts in six seconds. 6.2 stays a tool
    feature with no paper claim.
  - **The correction that actually matters to how the project is run:** I had
    been treating coverage as load-bearing for the whole project. It is
    load-bearing for exactly one framing — point it at a regulation and verify
    decisions — which is now dead. **Phase 9 and 6.1 never depended on it**, and
    both survive untouched.
  - **Method notes worth keeping.** No upper length bound on candidates, on
    purpose: dropping long sentences would have deleted the evidence for the
    dominant blocker and inflated coverage by exactly the amount that matters.
    Genre selected at the section level, never by sentence. Raw XML parsed from
    primary source, never through a summariser. 7 CFR 273 contributed nothing to
    the definitions sample because it has no section headed "Definitions" —
    recorded rather than repaired, because adding a source after seeing a zero is
    the adjustment a pre-registered protocol exists to prevent.
  - `bench/cfr.ml` holds the shared extraction so the samples cannot drift apart
    through a reimplementation; `sample_real` regenerates byte-identical after
    the refactor.

## 2026-08-08

- **Deep-review decision persisted as a bounded five-phase go/no plan.** The former
  regulatory-verification roadmap is superseded. The regulatory product, router,
  policybench, coverage chasing, missing-premise build, and broad packaging work are
  unscheduled. The OCaml engine remains worth a narrow research/teaching release. Before
  any further paper work, the project must complete: primary-source priority audit;
  formula-backed re-audit of the nine accepted regulatory records with an independent
  second human annotator; matched deterministic FOL verbalizer and counterbalanced study
  design; short surviving-claim register; and a task-coherence pilot with an explicit
  paper go/no decision.

- **Gate A done — the missing-premise novelty claim is refuted by the canonical book.**
  Sommers and Englebretsen, *An Invitation to Formal Reasoning* (2000), Chapter 5,
  §3, pp. 118–122 was read from a local primary copy. On pp. 119–120 the authors
  introduce an unknown signed missing premise, place it in the validity equation, and
  isolate it by subtracting the stated premise from the conclusion. On pp. 120–121 they
  solve a two-missing-premise case by reducing the equation and enumerating candidate
  pairs. This occupies the exact broad idea formerly described here as unpublished and
  closed-form where others must search.
  - **Disposition:** Phase 6.1 is cancelled. A multiplicity-aware OCaml implementation
    could be useful engineering or a narrower formal generalization, but there is no
    priority evidence strong enough to justify building it. It must also never be sold as
    the real-world reason for an eligibility denial: it supplies a proposition sufficient
    for derivation, not evidence that the proposition is true or relevant.
  - Evidence and source provenance:
    `docs/missing-premise-priority-audit-2026-08-08.md`. PLAN, README, the literature
    synthesis, the original sweep, coverage report, scope notes, and related-work notes
    were synchronized. No code or data changed, so no engine test was required.

- **Gate B first pass locked; the independent-human gate remains open.** The nine original
  strict accepts are frozen and enumerated in `data/fidelity/real/audit-pass-1.jsonl` rather
  than overwriting either pre-registered label file. Seven now have exact canonical TFL
  formulas and engine-generated readings; two are provisionally rejected:
  - `d03`: regulatory `means` is exhaustive, while the formula formerly embedded in its
    note states only that every nonmedical source is a non-medical source of evidence. The
    converse needs a second proposition, outside the one-proposition contract.
  - `d47`: “It” refers to the sieve introduced by the preceding sentence. A primed or
    starred term creates a constant but does not bind that antecedent; the engine's pinned
    no-anaphora policy makes this record out of fragment.
  - Provisional sensitivity: **7/110** raw versus the frozen 9/110, and **6/107** after
    removing all three exact duplicate pairs versus the frozen 8/107. `r41`/`d11` remains
    duplicated and receives one identical formula. `r25` and `d05` remain in but are
    explicitly marked convention-dependent because fixed singular descriptions are an
    engineering convention, not a sourced description theory.
  - The standalone packet `data/fidelity/real/SECOND-ANNOTATOR-PACKET.md` exposes no first-
    pass labels or formulas. Phase B cannot complete, and Phase C cannot start, until an
    independent human returns and signs that packet. The focused verifier reports 7/7
    checks passed; it pins the population, source text, parses, renderings, duplicate, and
    both raw/de-duplicated counts, and prevents any first-pass formula from leaking into
    the independent packet.

- **Gate B's independent-human packet now has a participant-facing offline form.**
  `data/fidelity/real/INDEPENDENT-ANNOTATION.html` presents the same nine blinded rows with
  conditional formula/blocker fields, live progress, completeness validation, a signed
  independence confirmation, draft save/load, and a versioned JSON export. It is one file
  with no dependency, server, account, network request, or browser storage. A newly opened
  copy starts blank, and answers are never embedded into the HTML: Kyle can try the form
  without his answers travelling in the untouched file sent to the independent annotator.
  Headless Chrome rendered all nine cards and the export control; embedded JSON and
  JavaScript syntax checks passed. The focused audit verifier is now **9/9**, additionally
  pinning exact HTML item multiplicity, absence of first-pass formulas, offline-only
  behavior, and the response schema marker.
