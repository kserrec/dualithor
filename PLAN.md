# TFL-Verify: Project Plan

*Goal:* Build and evaluate a pipeline that verifies LLM outputs using term logic (TFL), producing (a) an open-source system and (b) an arXiv/workshop paper.

*Core claims to test:*
1. *Fidelity claim:* NL→TFL translation is more faithful and more human-auditable than NL→FOL translation, because TFL's variable-free plus-minus syntax mirrors natural-language surface form.
2. *Router claim:* TFL fragment membership (does the sentence parse into TFL at all?) is a clean, mechanical escalation signal — parse success → verify cheaply; parse failure → flag/escalate. FOL pipelines have no equivalent signal.

*Prior art to cite (read abstracts in Phase 2):* Logic-LM (Pan et al. 2023), LINC (Olausson et al. 2023), natural logic / NatLog (MacCartney & Manning), NaturalLI (Angeli & Manning), Sommers & Englebretsen's TFL, Castro-Manzano's TFL programming/Aristotelian databases work.

*Translator models under test (via OpenRouter unless noted):* a current Claude model, GPT-5.6, Kimi (current K-series). Look up current OpenRouter model slugs at runtime — do not hardcode from memory.

*Language decision (Kyle, 2026-07-29):* the entire system — engine and pipeline — is **OCaml**. Rationale: the engine is tree manipulation over algebraic data types, and OCaml's exhaustiveness checking proves at compile time that every inference rule handles every term shape — a machine substitute for human code review on a codebase Kyle won't be reading line-by-line. Python appears in exactly two places: a **pip-installable client** at release (Phase 8) wrapping the compiled binary so ML researchers can adopt the tool, and a tiny dev-only matplotlib script for paper figures. Toolchain: opam + dune; libraries: `yojson` (JSON), `cohttp` + TLS (OpenRouter calls), `qcheck` (property-based testing), `alcotest` or plain asserts (unit tests). Node ≥ 18 remains a **dev-time** requirement only, for the reference engine below.

*The reference engine (vendored, stays in-repo permanently):* Kyle's existing TFL implementation, copied verbatim from the `guides` repo (`term-functor-logic/lab/`) into `engine/`:
- `engine/tfl.js` — ~2,000-line pure JavaScript, zero dependencies: parser + printer for the full plus-minus notation (categoricals, singulars, negative/compound/relational terms, propositional terms, proterms, TFL⁺ numerical levels), inference core (canonicalization, rewrite rules, P/Z validity, derivation, indirect proof), logic-programming layer (programs, queries, consistency), DNF equivalence, and NL rendering (`readProp`, `explainProof`).
- `engine/tfl.test.js` — 201 assertions (`node engine/tfl.test.js`).
- `engine/oracle.js` — finite-model semantics + six fuzz suites checking the engine's syntactic verdicts against semantic truth (`node engine/oracle.js -n 20000`).

**The JS engine is the executable specification for the OCaml port.** It is never extended, only consulted. The OCaml engine becomes authoritative only after the differential gate (1.12) passes. `guides` is a separate, untouched project; this copy is the maintained one.

*Ground rules for every step below:* each step is sized for Claude (Fable/Opus) to execute in a single pass, end to end, with its acceptance check passing at the end. If a step feels ambiguous or too large mid-execution, stop and ask Kyle rather than guessing. Commit after each completed step with the step id in the message (`1.4: …`). Keep a running LOG.md noting decisions and surprises — this becomes paper material. **After 1.12, any change touching OCaml engine logic must end with the OCaml test suite, the OCaml oracle (20k), and the curated paper-cases suite green; a red oracle is a stop-everything event.**

---

## Phase 0 — Reference Verification & Port Spec

*0.1 Vendor the reference engine.* ✅ DONE (2026-07-29)
`tfl.js`, `tfl.test.js`, `oracle.js` copied verbatim from `guides`; 201/201 tests pass in place; quick oracle run (1,000 iterations/suite) clean across all six suites.

*0.2 Long-run reference verification.* ✅ DONE (2026-07-29 — clean at 100k, all six suites, 9h47m; table in LOG)
Run `node engine/oracle.js -n 100000` in the background (expect hours). Record per-suite iteration counts, failures (expect zero), and wall time in LOG.md. Any failure: stop and report to Kyle — do not fix.
Accept: clean at 100k; results logged.

*0.3 Port specification document.* ✅ DONE (2026-07-30 — accuracy check delegated to Claude by Kyle; full re-verification against the code, two corrections applied, §6/§12 independently machine-verified)
Read `engine/tfl.js` fully. Write `docs/port-spec.md`: every exported function grouped by layer (parse/print, inference, relational, programs/queries, NL rendering, numerical); the exact accepted notation (transcribe the header table, including ASCII aliases); the verdict vocabulary (`valid | invalid | contradicted | unknown`, methods `PZ | derivation | indirect | numerical`) and the meaning of `unknown` (derivation search is incomplete outside the categorical fragment); error behavior (ParseError with position); the documented Murphree condition-(iii) correction (term-matched numerical condition — see guides ROADMAP note); and an explicit **not-ported list** (courseware-only: `checkExpression` grading, `printHtml*`; Aristotelian extras `answer`/`strongerAnswer`/`possibility`/`suggestMissingPremise` deferred unless a later phase needs them).
Accept: doc exists; Kyle confirms it's accurate.

## Phase 1 — OCaml Engine (the port)

Every step from 1.4 on ends by running the differential harness (1.3) over the layer just built, plus all prior OCaml tests. No pipeline work starts until 1.14 is done.

*1.1 Project scaffold + AST.* ✅ DONE (2026-07-29)
Dune project (`lib/tfl/`). GitHub Actions CI: one minimal workflow running `dune build` + `dune test` on push (the visible "this builds" signal for a public repo; keep it lean — no matrix, no caching cleverness until slowness hurts). Define the AST as variants mirroring the spec: `term` (Atom of name×singular | Neg | Compound of signed list | Rel of head×signed objects | PropTerm), `signed_term` (sign × term × level), `prop` (subject × predicate); signs as a variant (Plus | Minus | Wild). Structural equality. QCheck random generators for terms/props (sized, covering every constructor) — these feed every later property test.
Accept: `dune build` + `dune test` green; generators produce all constructor shapes (coverage assertion).

*1.2 Tokenizer, parser, printer.* ✅ DONE (2026-07-30)
Full notation from the spec: typographic and ASCII signs, quoted terms, singulars (`*`), proterm primes, subscripts/superscripts, nested relational complexes, propositional terms `[…]`, quantity levels. Printer emits the same canonical style as the JS printer (typographic −/±, compact spacing, quoting rule). Port the parser/printer unit tests from `tfl.test.js`. Property: `parse (print p)` structurally equals `p` for all generated `p`.
Accept: ported tests + round-trip property green (≥10k QCheck cases).

*1.3 Differential harness.* ✅ DONE (2026-07-30)
`engine/shim.js`: Node script reading JSON lines `{fn, args}` and answering with the reference engine's result for: parse (→ normalized AST as JSON or error), print, canonProp, contradictory/obverse/contrapositive, checkArgument, checkInconsistent, queryProp, decideEquivalence, readProp. OCaml side: a test runner spawning the shim, serializing OCaml ASTs to the same JSON shape, and asserting equality on (a) corpus inputs (every formula string appearing in `tfl.test.js`) and (b) QCheck-generated random inputs. Start by gating 1.2's parser/printer.
Accept: parser/printer differential agreement on full corpus + ≥10k random strings/ASTs.

*1.4 Inference core A — normal forms and immediate inferences.* ✅ DONE (2026-07-30)
Validation rules, canonicalization (`canonTerm`/`canonProp`), term/prop keys, `contradictory`, `obverse`, `contrapositive`, `tautology`.
Accept: ported unit tests green; differential agreement on corpus + ≥10k random props.

*1.5 Inference core B — rules, derivation, categorical validity.* ✅ DONE (2026-07-30)
Occurrence counting, rewrite rules (DON, Simp, Add), `derive`, `checkInconsistent`, and `checkArgument` with the P/Z categorical decision. Verdict record mirrors the JS shape (verdict, method, proof lines).
Accept: ported tests green; differential agreement of `checkArgument` verdicts on corpus + ≥10k random categorical arguments.

*1.6 Relational layer.* ✅ DONE (2026-07-30)
`headRoles` (pairing subscripts), passive transformation with its guards, pronominalization, indirect proof, `refuteSet`.
Accept: ported tests green; differential agreement on corpus + random relational arguments (verdict-level for derivation search; document any acceptable proof-path differences in LOG.md — verdicts must still match).

*1.7 Programs, queries, equivalence.* ✅ DONE (2026-07-30)
`parseProgram`, `queryTerm`/`queryProp`, `checkProgramConsistency`, `equivalents`/`decideEquivalence` (DNF), `statementModel`.
Accept: ported tests green; differential agreement on corpus + random programs/queries.

*1.8 Numerical quantifiers (TFL⁺).* ✅ DONE (2026-07-30)
Quantity levels through parse/print/canon (already in 1.1–1.2 syntax) and `numericalDecision`, implementing the **term-matched** condition (iii) exactly as the JS engine does.
Accept: ported tests green; differential agreement on corpus + random leveled arguments.

*1.9 NL rendering.* ✅ DONE (2026-07-30)
`readTerm`/`readProp` (deterministic English readings) and `explainProof` (numbered step lines with glosses). Match the reference's output strings exactly — the pipeline's back-translation check (4.4) depends on deterministic rendering.
Accept: ported tests green; differential string equality on corpus + random inputs.

*1.10 Oracle port A — finite-model semantics.* ✅ DONE (2026-08-01 — `test/semantics.ml`; 5k entailment instances + 10k per-model evaluations + 5k vocabularies differential-clean)
OCaml module: models over domain {0..n−1} per the reference oracle's semantics (no existential import; singulars/proterms as singletons; relational denotations with left-to-right scope and subscript roles; propositional-term domain pun; ± as restricted-some). Entailment check by model enumeration up to size n.
Accept: on ≥5k random (argument, small-n) instances, semantic entailment verdicts agree with the JS oracle's evaluator via the shim.

*1.11 Oracle port B — the six fuzz suites in QCheck.* ✅ DONE (2026-08-01 — `test/test_oracle.ml`; all six clean at 20k in 1,707s vs the JS reference's ~7,041s, a 4.1× speedup)
Mirror `oracle.js`: categorical exactness, rule-step soundness, relational derivation soundness, passive equivalence (+ the two scope-trap counter-models), indirect-proof soundness, statement-model agreement.
Accept: all six suites clean at 20k iterations; runtime logged (native speed should beat Node's — record the ratio for fun).

*1.12 Mass differential gate — the handover.* ✅ DONE (2026-08-01 — 884,000 generated inputs + corpus through 18 gates, zero disagreements, 12m14s; `docs/differential-report.md`. **The OCaml engine is authoritative from here.**)
One big run: full corpus + ≥100k random inputs per function family through both engines; verdicts, canonical forms, and renderings must agree (modulo LOG-documented proof-path variance). Close the two coverage gaps the 2026-07-30 bughunt probed (clean at 2k, but fold in permanently): arbitrary-shape arguments (propterms/compounds/levels-anywhere via `Gen.prop_gen`, error outcomes compared too) through `checkArgument`, and consistency-proof narrations (`fact`-rule lines) through `explainProof`. Archive the report as `docs/differential-report.md`. **After this step the OCaml engine is authoritative; the JS engine and shim remain as a frozen reference.**
Accept: zero disagreements; report committed; LOG entry marks the handover.

*1.13 Curated paper-cases audit ("triple check").* ✅ DONE (2026-08-01, pulled ahead of 1.12 — the step is independent of the port by its own terms; `test/paper_cases.ml`, 62 cases, no engine-vs-book disagreements)
Independent of the port: hand-verify ~40 textbook arguments against Sommers & Englebretsen — the 15 classically valid syllogism forms without existential import, the existential-import traps (Barbari/Darapti-style), obversion/contraposition/conversion cases, ≥5 relational arguments from the book, ≥3 indirect proofs, 5 numerical cases. Permanent test file `test/paper_cases.ml`. Engine-vs-book disagreements go to Kyle before any change.
Accept: suite green; disagreements (if any) resolved with Kyle and logged.

*1.14 Robustness — error taxonomy and adversarial input.* ✅ DONE (2026-08-01 — `lib/tfl/safe.ml`; 102,000 adversarial inputs clean, slowest case 0.036s; cancellation cap landed with the audit's probe pinned. **Phase 1 complete.**)
LLM output will hit this parser. (a) Structured failure taxonomy: `Lexical` | `Syntactic` | `Outside_fragment`. (b) Total top-level API (`Tfl.Safe`): never raises, always returns a result type. (c) Fuzz with ≥100k garbage strings (random bytes, truncations, deep nesting, pathological lengths): no crash, no >1s hang, always a structured error. (d) **Cap `find_cancellation`'s work** (2026-07-30 audit): the P/Z certificate decoration explores 4^(universals) re-use combinations uncapped — a 14-line valid input hangs it for minutes-to-days (measured ×4 growth per premise; verdicts decide *before* the search, so a node budget returning `cancellation: null` on exhaustion is verdict-safe by construction). Documented deviation from the frozen JS reference, §16-style; land with the audit's adversarial probe as a pinned test.
Accept: fuzz test committed and green; taxonomy documented in `docs/engine-surface.md`; the cancellation-cap adversarial test green in <1s.

## Phase 2 — Pipeline Scaffolding & Inputs

*2.1 Pipeline scaffold.* ✅ DONE (2026-08-01)
Dune libraries/executables: `translate/`, `router/`, `bench/`, `analysis/`; `data/` dirs; `.env` loading (gitignored; `.gitignore` covers `data/raw/`, `data/results/`); `ocamlformat` config; README updated (what TFL-Verify is, the two claims, OCaml toolchain quickstart, engine provenance).
Accept: `dune build` + `dune test` green from clean checkout; commit made.

*2.2 OpenRouter client.* ✅ DONE (2026-08-01 — slugs: `anthropic/claude-sonnet-5`, `openai/gpt-5.6-terra`, `moonshotai/kimi-k3`; live smoke green on all three, $0.003)
*Credentials (recorded so a later session does not re-provision):* Kyle created the OpenRouter account and key on 2026-08-01; the key lives in `.env` at the repo root (gitignored) as `OPENROUTER_API_KEY`, and the account is funded — the smoke test billed against it successfully. `pkg-config` was installed system-wide via apt for `zarith`; GitHub's runners ship it, so CI needs nothing.
`translate/llm_client.ml`: `complete ~model ~system ~user ~max_tokens` against OpenRouter's OpenAI-compatible endpoint (cohttp + TLS), retry (3 attempts, exponential backoff), timeout, cost/token counter appending to `data/usage.jsonl`. Look up the three current slugs (Claude, GPT-5.6, Kimi K-series) at execution time; record in `config.ml` + LOG.
Accept: smoke test hits all three slugs with "reply OK" and gets responses; usage log written.

*2.3 Literature pass A — LLM+solver pipelines.* ✅ DONE (2026-07-29, pulled ahead of Phase 1 — see LOG)
Web-fetch and skim Logic-LM, LINC, plus any newer prominent LLM→formal-language verification pipeline found while searching. First half of `docs/related-work-notes.md`: 3–6 bullets per paper — what they did, benchmark used, reported numbers, how TFL-Verify differs.
Accept: notes cover ≥3 papers in this family.

*2.4 Literature pass B — natural logic and TFL lineage.* ✅ DONE (2026-07-29, pulled ahead of Phase 1 — see LOG)
Same treatment: NatLog, NaturalLI, Sommers & Englebretsen (book-level), Castro-Manzano's TFL programming / Aristotelian databases. Append to the notes file.
Accept: all six prior-art items covered across 2.3 + 2.4.

## Phase 3 — Verification Interface & Traces

*3.1 Verification API.* ✅ DONE (2026-08-01 — `lib/verify/tfl_verify.ml`; `Safe.parse_program` closes the §16.5 program-path gap; full engine gate green)
`Tfl_verify.check ~premises ~conclusion` returning a record: verdict (`Valid | Invalid | Contradicted | Unknown | Error of taxonomy`), method, and `trace` — numbered lines, each the plus-minus step plus its one-line English gloss (via 1.9). `Unknown` semantics documented prominently (`Unknown` ≠ `Invalid`). JSON serialization for all result types. **Also close the 1.14 gap the 2026-08-01 bughunt proved:** the depth cap lives in `Tfl.Safe`, so `Program.parse_program` — the program-loading path this phase exposes — still stack-overflows on deeply nested input (measured at 200k levels). Add a `Safe.parse_program` wrapper carrying the same cap, and only ever call programs through it.
Accept: JSON round-trip tests green; `Unknown` documented in the interface.

*3.2 Verification test suite.* ✅ DONE (2026-08-01 — `test/test_verify_cases.ml`, 36 cases, green)
≥30 cases through the public API: valid syllogisms, invalid forms, relational, numerical, malformed input, empty input — drawing from `paper_cases` so the suites agree.
Accept: all green.

*3.3 Trace legibility review.* ✅ DONE (2026-08-01 — Kyle approved the format after 3.4)
Generate 3 sample traces (categorical, relational, indirect proof) into `docs/trace-samples.md`. Paper selling point — auditable proofs.
Accept: Kyle reviews and approves the format.
His review found relational-subject glosses ("some lov some girl is boy", "no lov some coward is boy") harder to read than the TFL they explain → 3.4 fixed both; format approved on the regenerated samples. **Still open, deliberately:** the frozen `explain_proof` sentence keeps the old shape, so it now reads inconsistently with the trace lines above it — a renderer deviation Kyle has not been asked to spend yet (`docs/trace-samples.md`, "Where this does not reach").

*3.4 Readable gloss orientation.* ✅ DONE (2026-08-01 — `Tfl_verify.readable_orientation`; no engine change, no frozen-renderer deviation)
From the 3.3 review: a relational complex in subject position glosses word-for-word ("some lov some girl is boy") because the renderer has no relative-clause machinery. The trace layer now glosses the *converse* orientation where conversion is valid — "some boy lov some girl" — leaving the formal step untouched. Guarded by `Relational.orientations`, which offers a converse only for I- and E-forms (A and O come back unchanged), plus a level check of our own since that converse carries level 0 and would understate a "most" step. Reaches only what conversion reaches: universals with a relational subject (De Morgan's head-of-a-horse) and the frozen `explain_proof` sentence keep the old shape — both recorded in `docs/trace-samples.md` as open items.
Accept: guard tests green (A, O and levelled forms provably untouched); samples regenerated.

## Phase 4 — Translation Layer

*4.1 Translation contract.* ✅ DONE (2026-08-01 — `translate/schema.ml`; `test/test_schema.ml`, 26 checks)
`translate/schema.ml`: LLM must return strict JSON `{"translations": [{"nl", "tfl", "confidence"}], "untranslatable": [{"nl", "reason"}]}`. Validator (yojson) rejects malformed payloads with reasons.
Accept: validator unit-tested against good and bad payloads.
Shape only — whether a `tfl` string is a real proposition is 4.3's question, so `translate` stays engine-independent. Two documented leniencies (absent array reads as empty; one markdown fence stripped) so a formatting habit is never scored as a translation failure; rejections name the offending path.

*4.2 Translation prompt.* ✅ DONE (2026-08-01 — `translate/prompts.ml`; `test/test_prompts.ml`, 21 checks)
`translate/prompts.ml`: system prompt teaching the notation + 10–15 few-shot NL→TFL pairs spanning universal affirmative/negative, particular, singular, negative terms, relationals. Source pairs from `paper_cases` so they're verdict-verified. Teach ASCII aliases (`-`, `+-`) so models needn't emit typographic signs.
Accept: every few-shot TFL string parses via the engine.
15 pairs, plus four worked *decline* examples carrying the router half of the contract. **No verdict vocabulary in the prompt** (asserted by test): teaching a validity judgement would invite reasoning-to-the-answer, the confound the fidelity claim must avoid.

*4.3 Translator harness.* ✅ DONE (2026-08-01 — `translate/translator.ml` + `cache.ml`; live smoke 100% parse rate ×3 models, $0.035)
`translate/translator.ml`: `translate ~model sentences`, calling the client, validating JSON, parsing every returned TFL string; parse failures recorded with their 1.14 taxonomy class, not fatal.
Accept: smoke test — 5 hand-written sentences × 3 models; results and parse rates printed.
Four outcomes per sentence (`Translated | Unparseable | Declined | Absent`); `Absent` exists because a silently dropped sentence would otherwise shrink the denominator and flatter every rate. Matching is on a normalised key and refuses paraphrases — a formula paired with the wrong sentence is undetectable downstream. `translate/cache.ml` keys replies by a digest of the exact (model, system, user) triple, per the standing no-double-spend constraint; `data/cache/` gitignored with a CI guard.

*4.5 Translation-fidelity gate.* — **pulled in front of 4.4 and Phase 5 on Kyle's instruction (2026-08-01).**
The project's largest open risk, and the cheapest to settle: plus-minus notation is essentially absent from pretraining data where FOL is abundant (`scope-and-predictions.md` §1.3), and the second literature sweep found a neighbouring measurement — NL→TLA+ at 26.6% syntactic / 8.6% semantic, attributed to corpus scarcity. If TFL translation fidelity collapses, the thesis goes with it, so it is measured before any layer work or benchmark spend.
*4.5a Gold set.* ✅ DONE (2026-08-01 — `data/fidelity/items.jsonl`, 85 items / 91 translatable sentences / 10 declines; `test/test_fidelity_set.ml`, 25 checks)
Authored, engine-verified, contamination-guarded against the few-shot prompt. Group J reuses a relation across premises to test the naming-consistency threat the 4.3 smoke could not reach.
*4.5b The run.* ✅ DONE — bare few-shot arm only (2026-08-01; `docs/fidelity-report-2026-08-01.md`; 45 calls, $0.44). **Kimi 100%, Sonnet 99%, GPT 96% faithful; 273 formulas, zero unparseable; 30/30 declines; 24/24 argument verdicts.** Two genuine model errors total, both GPT, both the same E-form sign flip. The pre-registered ≥70% threshold was cleared by a wide margin — prediction recorded as wrong. Three arms remain unrun (grammar prompting, matched FOL, FOL→TFL transduction); the FOL arm needs scoring infrastructure we do not have.
*4.5b (original scope).* Four arms — bare few-shot, grammar prompting (ship the BNF; published evidence for low-resource formal languages), a matched **FOL arm** so the numbers mean something, and LLM→FOL→mechanical transduction (the sweep found no trace of anyone trying it). Scoring in layers: parses → structurally isomorphic to gold under consistent term renaming → semantically equivalent per the engine → faithful anyway. **Exact string match is deliberately not the primary metric** — term naming is arbitrary and the 4.3 smoke proved it (three models, three correct stems for one verb).
Accept: all four arms run across three models; per-arm layer-by-layer scores reported; the naming-consistency question answered from group J.
Known gap, to report as a limitation: the set is authored, not sampled from real statutes, so it is an upper bound. A real-text arm is still owed.

*4.4 Back-translation fidelity check.*
`translate/backcheck.ml`: render TFL back to English with the engine's own deterministic `readProp` first; one LLM call scores nl↔rendering semantic match 0–2. (Deterministic verbalization is a TFL-only advantage over FOL — note for the paper.)
Accept: runs end-to-end on the 5 smoke sentences.

## Phase 5 — Router

*5.1 Router logic.*
`router/route.ml`: attempt translation + parse + check. Outcomes: `Verified_valid`, `Verified_invalid`, `Outside_fragment` (translation refused or parse failed), `Translation_suspect` (parsed, back-check 0), `Unknown` (checked, engine returned unknown). No external solver in v1 — `Outside_fragment` is terminal. Stub `router/escalate.ml` documenting the future Prolog/Z3 hook.
Accept: unit tests cover all five outcomes with mocked components.

## Phase 6 — Benchmarks

*6.1 Loader — ProofWriter.*
Download to `data/raw/`; `bench/loaders.ml` with normalized record `{id; premises; conclusion; gold_label}` and the ProofWriter loader (note in LOG: ProofWriter assumes a closed world — flag for the filtering step). Unit test on a checked-in fixture slice; full counts logged.
Accept: loader test green; counts logged.

*6.2 Loaders — FOLIO and LogicBench.*
Same contract, same ritual, both datasets.
Accept: loader tests green; counts logged.

*6.3 Loader — syllogism-focused dataset.*
Web-search current best (candidates: SylloBase, Avicenna, NeuBAROCO — the last has human-bias annotations enabling a "does the pipeline neutralize belief bias?" analysis cut; see related-work-notes Part C3); pick one, justify in LOG, add loader.
Accept: loader test green; choice + counts logged.

*6.4 Fragment filtering.*
`bench/filter.ml`: heuristically tag items likely inside the TFL fragment (categorical/syllogistic surface forms). Per dataset: an in-fragment eval set (~200–500 items) and a random mixed sample (~200) for router evaluation, written to `data/eval/`.
Accept: sets written; 20 random items manually spot-checked in LOG.

*6.5 Baseline — direct LLM answering.*
`bench/baseline_direct.ml`: each model answers each eval item directly (valid/invalid/unknown), no solver. All responses cached to disk keyed by (model, item).
Accept: 20-item slice runs for all three models; accuracy computed.

*6.6 Pipeline runner.*
`bench/run_pipeline.ml`: translate → parse → check → route per model per eval set, cached, `--limit` flag, hard cost ceiling from config (default $10 per model per dataset; Kyle can raise).
Accept: 20-item slice completes ×3 models; per-item records in `data/results/*.jsonl`.

*6.7 Full runs — one step per dataset.*
6.7a ProofWriter → 6.7b FOLIO → 6.7c LogicBench → 6.7d syllogism set. Each: baseline + pipeline at full eval size, cost checked and spend logged before the next dataset. Never two datasets in one pass.
Accept (each): results complete for that dataset × 3 models; spend logged.

*6.8 Policybench — authoring batch 1.*
`data/policybench/`: 35 policy/eligibility-style items ("All employees with five years of service are eligible…"), each with premises, conclusion, gold label, in/out-of-fragment tag; ~70% in-fragment, ~30% outside (tense, defaults, arithmetic). Every in-fragment item's intended TFL form machine-verified (parses; intended verdict) before presenting.
Accept: Kyle reviews and signs off batch 1.

*6.9 Policybench — batch 2, freeze, run.*
35 more items (no structural duplicates of batch 1); Kyle signs off; freeze; run baseline + pipeline (cost ceiling applies).
Accept: sign-off; results files written.

## Phase 7 — Analysis

*7.1 Metrics.*
`analysis/metrics.ml` computing per model × dataset: end-task accuracy (pipeline vs direct), translation parse rate, back-check fidelity distribution, router precision/recall for `Outside_fragment` (vs 6.4 manual tags), abstention-aware accuracy, token cost per item. Emit `analysis/report.md` (markdown tables) + `analysis/csv/` for figures.
Accept: report generated from results files.

*7.2 Fidelity audit.*
50 random translations per model; Kyle + Claude score faithful/unfaithful independently, then reconcile. Headline evidence for the fidelity claim. Optional FOL contrast: same 50 items translated to FOL and audited, time permitting.
Accept: audit sheet + agreement stats in `analysis/`.

*7.3 Figures.*
`paper/figs/make_figs.py` — small dev-only matplotlib script reading `analysis/csv/` (accuracy + parse-rate charts; no seaborn). Python here is a dev tool, not part of the system.
Accept: figures render and are referenced in report.md.

## Phase 8 — Write-up & Release

*8.1 Paper skeleton + background.*
`paper/draft.md`: full outline; background section — TFL primer (plus-minus notation, the two validity conditions, worked example with an engine trace) — Kyle drafts or closely reviews; related-work section from `docs/related-work-notes.md`.
Accept: sections complete; Kyle reviews the primer.

*8.2 Method + experiments sections.*
Architecture (translate → parse → check → route; deterministic back-rendering; error taxonomy; the differential-verified port as an engineering-soundness note), then experiments (setups, tables, figures).
Accept: sections complete and numerically consistent with `analysis/report.md`.

*8.3 Intro, abstract, limitations.*
Written last. Limitations explicitly: nonmonotonicity/generics, fragment narrowness, single-notation dependence, `Unknown` on relational search misses, ProofWriter's closed-world mismatch.
Accept: complete draft; Kyle full pass.

*8.4 Python client.*
Pip-installable `tflverify` package: thin wrapper spawning the compiled OCaml binary (JSON-over-stdio CLI added here — `bin/tfl_cli.ml`), exposing `parse`, `check`, `verify_claim`. This is the adoption surface for ML researchers; the OCaml system never depends on it.
**Land the two hardening items the 2026-08-01 audit deferred to here** — this step is where the library stops being called only by our own pipeline (SECURITY.md records both, with measurements): (a) cap the atom union in `decide_equivalence`, which today enumerates up to 2³² assignments because the 16-atom cap is per proposition and the union is unbounded — a ~160-byte input costs ~33 minutes; (b) decode into a pre-sized array in one pass and let `Safe.parse` reuse the tokens it already built, cutting the parser's ~120× memory amplification (20 MB in → 1.38 GB peak heap). Both are inherited from the frozen reference, so each lands as a documented deviation with the full engine gate.
Accept: `pip install` from the repo works in a clean venv; README shows a 5-line Python quickstart.

*8.5 Repo release.*
README: quickstart (opam/dune build, Python client), architecture diagram, example trace; license already in place (MIT); `CITATION.cff` so academics can cite the repo (title, authors, repo URL; add the paper's preprint reference once it exists); scrub keys; pin opam deps.
Accept: fresh-clone build-and-run works on a clean machine spec; CITATION.cff validates.

*8.6 Submission targets.*
Current neurosymbolic venues/workshops with deadlines (web search at time of writing — NeSy, ACL/NeurIPS workshops). Draft the email to Castro-Manzano's group describing the system and inviting collaboration.
Accept: target list + email draft ready for Kyle.

---

## Standing constraints

- Never commit API keys; `.env` gitignored from 2.1.
- All LLM calls cached to disk; never re-spend on identical calls.
- Cost ceiling enforced in code (6.6), reported after every run.
- After 1.12: OCaml engine changes require test suite + 20k oracle + paper-cases green before commit; verdict semantics never change silently. Before 1.12: every port step ends differential-clean against the JS reference.
- The JS reference engine is frozen — never extended, only consulted.
- Any deviation from this plan gets logged in LOG.md with a one-line rationale.
- When results contradict the core claims, report them as-is. Negative results go in the paper's limitations, not in the trash.
