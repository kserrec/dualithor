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

*4.6 Real-text arm.* — **the next measurement, and the one most likely to change the picture.**
4.5b's sentences were authored by Claude, which biases them toward being translatable. Sample ~60 sentences from **public-domain regulatory sources** (US federal works are public domain — eCFR, agency guidance; note the licence for anything else and do not commit corpora, per the standing rule). Two numbers come out, and the second is now the more interesting one:
- **Fidelity on messy input** — same four-tier scoring as 4.5b, gold hand-written and engine-verified.
- **Coverage** — what fraction of real regulatory sentences land inside the fragment at all. *After 4.5b, coverage has replaced fidelity as the project's largest unknown:* translation works, but a tool that refuses 80% of real sentences is a demonstration, not a system.
Report `Outside_fragment` reasons by category (tense, arithmetic, cross-reference, defeasible, multi-clause) — that distribution is what tells us which layer to build next, and it is paper material either way.
Accept: coverage and fidelity reported with the refusal-reason breakdown; sentences and gold committed to `data/fidelity/real/`; spend logged.

*4.4 Back-translation fidelity check.* — **promoted: this is the correctness mechanism, not a nicety.**
`translate/backcheck.ml`: render the model's own TFL back to English with the engine's deterministic `read_prop` (1.9), and score nl↔rendering agreement. The reasoning, settled 2026-08-01: a few-shot patch fixes the one error you already found and generalises to nothing, while a back-check catches **meaning-inverting errors nobody anticipated**. Deterministic verbalisation is a TFL-only capability — FOL pipelines have no canonical English reading to compare against.
**Pinned acceptance test:** it must flag GPT-5.6-terra's E-form sign flip (`c02`, `c06` — "No non-member is eligible" → `-(-Member)+Eligible`, which renders as "every non-member is eligible") **without being told what to look for.** That turns 4.5b's finding from an anecdote into a demonstration of the architecture.
Division of labour to hold onto: prompt patching buys *coverage*; the back-check buys *correctness*. Never rely on a prompt for soundness.
Accept: runs end-to-end on the 4.5b and 4.6 sets; catches c02/c06 unaided; false-positive rate on correct translations reported.

*4.7 Matched FOL arm.* — **required before core claim 1 can be stated at all.**
Claim 1 says TFL translation is *more* faithful than FOL. 4.5b shows TFL works well; it shows nothing comparative. Same sentences, same models, translated to FOL and scored equivalently. Needs FOL scoring infrastructure we do not have — minimally a parser and a structural comparator; an off-the-shelf prover for equivalence is acceptable here since nothing in the FOL arm is load-bearing for our own verdicts.
Also run the arm the 2026-08-01 novelty sweep found no trace of anyone trying: **LLM→FOL→mechanical transduction into TFL**, versus direct TFL emission. Models know FOL; the transduction is deterministic code.
*Grammar prompting* (ship the BNF) is **dropped from the near term** — published evidence supports it for low-resource formal languages, but at a 100% parse rate there is nothing left for it to fix. Revisit only if 4.6 shows syntax failures on real text.
Accept: FOL arm scored on the same items; the comparative claim is either supported with numbers or withdrawn.

*4.8 Dev/eval split.* ✅ DONE (2026-08-02 — `data/fidelity/items.jsonl` `split` field, 42 dev / 43 eval; `test/test_fidelity_set.ml`, 29 checks)
The moment a prompt is changed in response to an observed error, the items that revealed it stop being evaluation data. Split now, while nothing has been tuned: a development set we may inspect freely, and an evaluation set touched once. Record which items are which in the data files.
Accept: split committed; `test_fidelity_set.ml` enforces that no eval item's sentence or formula appears in the prompt.
Every item already implicated in an observed error is forced to dev (`c02`/`c06` the sign flip, `i04` the `few` inversion, `i06` the renderer level-drop, `b04` the definite-description convention); the rest is stratified so both halves carry the same constructions. Three guards, not one: the eval-contamination check, a **pinned eval id list in the test** so relabelling a failed item is a reviewable code change rather than a data edit, and a **no-shared-sentence-or-formula** check across the split. That third guard is the one that earned its keep — group J's arguments are built from the same material as groups A, F and I, and the first cut had three collisions, so promoting dev item `a01` into the prompt would have silently contaminated eval item `j04`. Item *content* is unchanged, so the 4.5b run stays reproducible and re-cuts by split off cache. Two eval coverage holes follow from the burn rule and are recorded in `data/fidelity/README.md`: no negative-term E-form and no quantity level 3 (its only item is `i04`, whose gold is wrong). 4.6 should fill both.

---

## Phase 5 — Router, and the two engine debts

*5.1 Router logic.*
`router/route.ml`: attempt translation + parse + check. Outcomes: `Verified_valid`, `Verified_invalid`, `Outside_fragment` (translation refused or parse failed), `Translation_suspect` (parsed, back-check disagrees), `Unknown` (checked, engine returned unknown). No external solver in v1 — `Outside_fragment` is terminal. Stub `router/escalate.ml` documenting the future Prolog/Z3 hook.
Paper framing found 2026-08-01, worth building toward: fragment membership as *works* vs *does not run* — on 294,469 SNOMED concepts, ELK 6.2 s, FaCT++ 408.9 s, HermiT timed out at 30 min, Pellet ran out of memory (ORE 2012).
Accept: unit tests cover all five outcomes with mocked components.

*5.2 Pin the anaphora resolution policy.* — **a live correctness question about existing code.**
`expressiveness-literature.md` §1.3: `Sat(TV+Rel+RA)` (restricted anaphora — every pronoun bound to its *closest* permissible antecedent) is NEXPTIME-complete; `Sat(TV+Rel+GA)` (general anaphora) is **undecidable**, by a tiling encoding in six sentences. Our engine has pronominalization and **nobody has checked which policy it implements.** Read the code, determine the policy, pin it with a test, document it in `docs/engine-surface.md`. Adjacent reading: Purdy, "A Variable-Free Logic for Anaphora," DOI 10.1007/978-94-011-1152-2_3, 1994.
Accept: the policy is named, tested, and documented; if it is GA, that is a stop-and-report to Kyle.

*5.3 Audit the TFL⁺ numerical layer.* — **the one place the engine may be unsound.**
Pratt-Hartmann 2008 demonstrates the incompleteness of previously published proof systems for the numerically definite syllogistic; 2009 and 2013 prove no finite syllogistic rule set can be complete there. Our layer descends from that lineage and **we have already independently hit one such error** — the Murphree condition-(iii) correction in port-spec §12. `Sat(Syl+Num)` is only NP-complete, so the principled route is to decide it algorithmically (Presburger-style integer reasoning) rather than search for rules that provably do not exist.
Accept: `numerical_decision` checked against Pratt-Hartmann's results; either confirmed sound on our fragment or the gap is characterised and reported to Kyle before any change. Blocks 6.3.

---

## Phase 6 — TFL-native capabilities (the "impact *with* TFL" phase)

Everything here is pure term logic, adds no new formalism, and is available *because* the logic is algebraic. Prioritised above the defeasible layer on Kyle's clarification (2026-08-01) that the goal is impact **with TFL as the vehicle**, not impact generally.

*6.1 Missing-premise suggestion — enthymeme completion.* — **a novel contribution, not a port.**
TFL's first validity condition is an equation over a free abelian group on signed terms, so the missing premise of an incomplete argument is exactly `C − ΣPᵢ`, with the particular-count and level conditions as side constraints. **No publication states this** (lit sweep 4, Q3): Mozes 1989 lists "suggest missing rules" as a feature and is silent on method; two Castro-Manzano papers restate the idea and specify only the trigger. Constant time on the fragment where P/Z decides; unavailable outside it, where verdicts come from derivation search.
Two reasons this ranks first in the phase: there is **no FOL counterpart** — you cannot subtract two first-order formulas and get the missing hypothesis — and it answers the question description logics need abduction for. Sweep 3: OWL justifications explain *why yes* and cannot explain *why not*, and **"why was I not found eligible?" is the primary question in eligibility determination.** The suggested premise comes back rendered in English by machinery we already have.
Accept: implemented for the categorical fragment; returns `None` (never a guess) outside it; suggestions verified by re-running the completed argument to `Valid`; rendered in English; property test over generated arguments.

*6.2 Definitions layer.* — capability we already own and do not use.
The programs/queries layer (`parse_program`, `query_prop`, `check_program_consistency`) was ported in 1.7 and nothing calls it. A legal definitions section — *"'Qualified Person' means…"* — is a symbol table, and asking whether an entity falls under a defined term is exactly `query_prop`. This is also the natural home for **use case (b)**: auditing whether a rule set is self-consistent, which the engine already decides. Load programs only through `Safe.parse_program` (3.1).
Accept: a worked definitions example end to end; an inconsistent rule set detected with a readable trace.

*6.3 Murphree numerical term logic.* — **blocked behind 5.3.**
Murphree, *NDJFL* 39(3):346–362, 1998 — exact-*n*, fractional, and numerically quantified relational complexes. A **strict superset** of what we have: A/E/I/O are the n∈{0,1} case and our TFL⁺ levels are its "subjective" special case; composable with our relational layer. Ranked the highest-value unimplemented capability by lit sweep 4. Not started until 5.3 clears, because it extends the one part of the engine with an open soundness question.
Accept: differential-clean against the frozen reference where they overlap; full engine gate green.

---

## Phase 7 — Defeasible layer

The one structural addition that survived the 2026-08-01 sweeps. It clears the obstacle — "unless", "except as provided in" — that today keeps TFL out of policy text entirely, and it does so **without touching the engine**: rules are TFL propositions, the layer is a control layer over them.

**Prior art, stated up front so the paper does not overclaim.** Horner, Mateis, Governatori & Ciabattoni, "Toward Robust Legal Text Formalization into Defeasible Deontic Logic using LLMs" (arXiv:2506.08899, 2025) does LLM formalization of real regulatory text into defeasible deontic logic, by the formalism's own authors. Fang et al., *LLM-ASPIC+*, ECAI 2025. **This layer is not novel.** What differentiates ours is the atomic layer beneath it: term logic with deterministic English rendering and a mechanical fragment boundary.

*7.1 Read before designing.* Catala's **default expression** is the closest existing analogue to what we are about to build (lit sweep 1) and should be read first. Also read arXiv:2506.08899 in full — it reshapes the plan and has not been read directly.
Accept: a short design note naming what we take, what we reject, and why.

*7.2 Representation.* Strict rules (`A → B`), defeasible rules (`A ⇒ B`), defeaters (`A ↝ ¬B`), and a superiority relation, over TFL propositions. **State which variant we implement** — Maher 2001's linear result is for standard *team-defeat* defeasible logic; the well-founded variant is expected quadratic.
Two conditions the survey dropped and sweep 5 recovered: the superiority relation must be **acyclic** (fine — "specific overrides general" and "later overrides earlier" are the orderings policy text uses), and the linear bound is on the **already-ground** theory, with full first-order defeasible logic only recursively enumerable. That second one likely does not bite us: TFL has no variables, so our theories are ground by construction.
Accept: types defined; parser and printer round-trip; acyclicity enforced with a test.

*7.3 The inference engine.* Forward-chaining saturation over the four proof tags (`+Δ`, `−Δ`, `+∂`, `−∂`). Maher 2001, Thm 5, read directly and confirmed: consequences computable in O(N). The derivation **is** the certificate — the formalism is proof-theoretic by construction, which is why this formalism and not ASPIC+/ABA (sweep 3: skeptical preferred is Π₂ᴾ-complete, and adding preferences to ABA lifts grounded reasoning from P to Δ₂ᴾ, whereas the superiority relation is free inside the linear algorithm).
Accept: differential against SPINdle on a shared corpus; complexity measured against the linear claim.

*7.4 Contrary-to-duty via priorities.* "If you fail to file, you must pay a late fee" is handled by rule priorities, **not** by a deontic operator. The input/output-logic layer was dropped 2026-08-01 (see `expressiveness-literature.md` §2.3f, corrected): every I/O logic satisfies weakening of output so Ross's paradox is not blocked, and constrained output — the CTD device — sits at the second level of the polynomial hierarchy, not coNP.
Optional and cheap once 7.3 exists: **Carneades proof standards and burden of proof** map *into* defeasible logic with a quadratic translation and polynomial acceptability (Governatori, ICAIL 2011, Thm 7/Cor 8). Directly on point given Robodebt reversed the burden onto claimants.
Accept: a worked penalty/waiver clause decided correctly, with the defeated rule named in the trace.

*7.5 Certificate rendering.* The tagged derivation rendered as English, in the 3.3/3.4 trace style: which rule fired, which was defeated, by what. **Design constraint from sweep 3, and it is a warning not a licence:** Alrabbaa et al. (RuleML+RR 2022) measured laypeople on logic proofs at a mean of **2.36/12**, concluding that methods "explainable by design" are not "understandable by design." The two free wins their data supports are **tree structure** (minimal tree proofs are in P; general minimal proofs are NP-complete) and **natural-language steps**. Both are available to us.
Accept: Kyle reviews and approves the format, as with 3.3.

*Deferred, with the reason recorded.* **Metric time (Simple Temporal Networks).** Deferred 2026-08-01: it is the one genuinely non-TFL component, and its headline feature is weaker than the survey claimed — Dechter/Meiri/Pearl's algorithm detects a negative cycle by the sign of a diagonal entry, giving a yes/no plus a node rather than the readable chain of deadlines, so extraction is unimplemented work. Represent deadlines as terms (`−Filing+"within 30 days of notice"`), which keeps subsumption and loses arithmetic; revisit only if 4.6 shows deadline reasoning blocking real verification cases.

---

## Phase 8 — Evaluation data

Reshaped by the 2026-08-01 sweeps: the original ProofWriter/FOLIO/LogicBench set is FOL-shaped academic data with no exceptions, deadlines, or norms. It becomes a **narrow baseline for the term-logic core**, not the centrepiece.

*8.1 Policybench — authoring batch 1.* 35 policy/eligibility items with premises, conclusion, gold label, and in/out-of-fragment tag; ~70% in-fragment. Every in-fragment item's intended TFL machine-verified before presenting. Now also tagged for **defeasibility** (does it need an exception rule?), since that is what Phase 7 is evaluated on.
Accept: Kyle signs off batch 1.

*8.2 Policybench — batch 2, freeze, run.* 35 more, no structural duplicates; sign-off; freeze; run baseline + pipeline under the cost ceiling.
Accept: sign-off; results written.

*8.3 DeonticBench.* arXiv:2604.04443 (2026): 6,232 tasks with **reference Prolog released for every instance** and explicit program traces. Found by sweep 1; usable evaluation data rather than a competitor, and it pre-empts any claim to be the first benchmark pairing rule text with symbolic targets.
Accept: loader test green; counts logged.

*8.4 Legal NLP benchmarks — pick one.* Candidates from sweep 1: **LegalBench**, **CUAD**, **LexGLUE**, **SARA** (statutory reasoning). Choose by fit to subsumption/eligibility, justify in LOG.
Accept: loader test green; choice and counts logged.

*8.5 Syllogism set — NeuBAROCO or kin.* Retained from the original plan: bias annotations enable the "does the pipeline neutralise belief bias?" cut, which remains the cleanest predicted win (`scope-and-predictions.md` §1.2).
Accept: loader test green.

*8.6 Baseline and pipeline runners.* Direct LLM answering vs the pipeline, per model per set, all calls cached, `--limit`, hard cost ceiling from config. The 4.3 cache already enforces never re-spending on an identical call.
Accept: 20-item slice ×3 models; per-item records in `data/results/`.

*8.7 Full runs — one dataset per step.* Policybench → DeonticBench → legal set → syllogism set. Spend checked and logged before each.
Accept (each): complete for that dataset × 3 models; spend logged.

---

## Phase 9 — The auditability study

**This is the paper's contribution.** Sweeps 1 and 2 agree on the gap and three independent groups name it in print:

- **Fuchs (CNL 2018)**, author of Attempto Controlled English, designs exactly this experiment and writes: *"For lack of resources I did not do the experiment."*
- **Vernie & Grabmair (2026, arXiv:2605.25186)** cite non-expert accessibility as *"a recognized concern in adjacent fields"* — their own reviewer is "a legal expert" and their human never sees the formal object.
- **Alrabbaa et al. (RuleML+RR 2022)** measured laypeople on logic proofs at **2.36/12**, establishing that logic-based ≠ comprehensible.

And it is unoccupied for a structural reason: verbalization systems generate *from* an ontology, so there is no original English source to audit a formalization *against*. The task only becomes meaningful once a machine translates from free English — the LLM setting, which did not exist when that field was built.

*9.1 Study design.* Non-experts judge whether a rendered gloss matches a source sentence, against ground truth, on items where the translation is faithful and items where it is not (4.5b's `c02`/`c06` are real, naturally occurring wrong translations — use them). Pre-register the design and the hypothesis before running. Methodological ancestor: Kuhn's ontograph experiments (n=64; ACE 91.4% vs Manchester-like 86.3%) — but that task is statement-vs-depicted-situation, and ours is formalization-vs-source-sentence.
Accept: design and pre-registration written; Kyle approves before any participant sees anything.

*9.2 Run and analyse.* Accept: results reported as measured, including a null result.

**Contrast arm the paper must address head-on:** Power & Third (COLING 2010, `C10-2116`) show over 600,000 axioms across ~200 ontologies where the axiom↔sentence mapping is empirically transparent *even for description logic* — an attack on the premise that surface-closeness is needed at all.

---

## Phase 10 — Analysis

*10.1 Metrics.* Per model × dataset: end-task accuracy (pipeline vs direct), translation fidelity by the four-tier grade, back-check agreement, router precision/recall for `Outside_fragment` against manual tags, abstention-aware accuracy, cost per item. **Report coverage and accuracy-given-coverage as a pair, never blended** — our abstentions are structural, not a confidence threshold, which is the defensible version of selective prediction. Emit `analysis/report.md` + `analysis/csv/`.
Accept: report generated from results files.

*10.2 Fidelity audit.* 50 random translations per model, Kyle and Claude scoring independently then reconciling. Now partly automated by the 4.4 back-check, which changes this step's job from *finding* unfaithful translations to *validating that the back-check finds them*.
Accept: audit sheet + agreement stats.

*10.3 Figures.* `paper/figs/make_figs.py` — dev-only matplotlib, no seaborn.
Accept: figures render and are referenced.

---

## Phase 11 — Write-up & release

**Claims, as they stand after the 2026-08-01 sweeps.** Three earlier framings are dead and must not appear:
- ~~"first to verify LLM output symbolically"~~ — SemEval-2026 Task 11 is an entire shared task on LLM syllogistic validity; ARc (arXiv:2511.09008) is a deployed service reporting >99% soundness.
- ~~"deterministic back-rendering is our differentiator"~~ — prior art in ACE (2008), ACE↔OWL, PENG, and Grammatical Framework, where reversible linearization is a *generic architectural property*.
- ~~"no modal or temporal extension of TFL exists"~~ — Englebretsen, NDJFL 29(3), 1988.
- The **GDPR Article 22** framing is also out: 22(3)'s contest right is scoped to decisions based on contract and consent, **not** statutory authorisation, which is the basis for most government eligibility decisions.

**What the paper actually claims:** in the LLM-formalization setting there is, for the first time, an original source sentence to audit a machine's formalization *against*; TFL preserves that sentence's structure where controlled English reintroduces variables (ACE's robust paraphrase shatters one sentence into several and emits `X1 X2 X3`; its structure-preserving mode is documented "experimental"); the fragment is decidable where ACE is not (Fuchs, CNL 2010 §6: *"This means that ACE is undecidable"*); the algebra yields the missing premise for free; and fragment membership is a mechanical abstention signal nobody else has.

*11.1 Skeleton + background.* TFL primer with a worked engine trace; related work from `docs/related-work-notes.md` **and** `docs/lit-sweep-2026-08-01/`. Must-cite and differentiate: Vernie & Grabmair 2026, Amrollahi/Lopez/Barrett 2026 (roundtrip verification — difference: their back-translation is machine-consumed, never shown to a person), Lorenzo et al. NLLP 2025 (NL→Catala, surface metrics only), Horner et al. 2025, Blawx, Catala, OpenFisca.
Strongest supporting citation, to sit in the motivation: **López & Hildebrandt (arXiv:2410.10906)**, systematic review of 46 studies — **89.13% of works treat regulatory formalization as manual effort; only 13.4% report operational deployment**; section titled *"Where are the lawyers?"*
Accept: sections complete; Kyle reviews the primer.

*11.2 Method + experiments.* Architecture, the differential-verified port as an engineering-soundness note, then experiments.
Accept: numerically consistent with `analysis/report.md`.

*11.3 Intro, abstract, limitations.* Limitations explicitly: fragment narrowness and measured coverage; `Unknown` on relational search misses; **the authored-vs-real-text ceiling on 4.5b**; single-notation dependence; no treatment of definite descriptions anywhere in the tradition (lit sweep 4, Q2) so ours is an engineering convention; no treatment of adverbial modification at all; and the finding that cuts against us — **the systems with real production footprints use the least expressive formalisms**, while the richest logics have the weakest deployment records.
Accept: complete draft; Kyle full pass.

*11.4 Python client.* Pip-installable `tflverify` wrapping the compiled binary via a JSON-over-stdio CLI (`bin/tfl_cli.ml`). Land the two hardening items the 2026-08-01 audit deferred here — cap the atom union in `decide_equivalence` (currently up to 2³² assignments; a ~160-byte input costs ~33 minutes), and single-pass decoding so `Safe.parse` reuses its tokens (20 MB in → 1.38 GB peak heap). Both are inherited from the frozen reference; each lands as a documented deviation with the full engine gate.
Accept: `pip install` works in a clean venv; 5-line quickstart in the README.

*11.5 Repo release.* README quickstart, architecture diagram, example trace, MIT licence in place, `CITATION.cff`, scrub keys, pin opam deps.
Accept: fresh-clone build-and-run works; CITATION.cff validates.

*11.6 Submission targets.* Current neurosymbolic venues and workshops. Draft the email to Castro-Manzano's group; **also to Governatori/Ciabattoni** (arXiv:2506.08899), whose work this now sits directly alongside.
Accept: target list + email drafts ready for Kyle.

---

## Phase renumbering (2026-08-01)

The redirect inserted two phases. Old references in LOG.md and commit messages map as: **old Phase 6 (Benchmarks) → Phase 8**, **old Phase 7 (Analysis) → Phase 10**, **old Phase 8 (Write-up & Release) → Phase 11**. Phases 0–5 are unchanged.

## Standing constraints

- Never commit API keys; `.env` gitignored from 2.1.
- All LLM calls cached to disk; never re-spend on identical calls.
- Cost ceiling enforced in code (8.6), reported after every run.
- After 1.12: OCaml engine changes require test suite + 20k oracle + paper-cases green before commit; verdict semantics never change silently. Before 1.12: every port step ends differential-clean against the JS reference.
- The JS reference engine is frozen — never extended, only consulted.
- Any deviation from this plan gets logged in LOG.md with a one-line rationale.
- When results contradict the core claims, report them as-is. Negative results go in the paper's limitations, not in the trash.
- **After the 2026-08-01 sweeps:** any citation not sourced from *extracted primary text* is unverified until it is. Four of six sweeps independently caught the PDF summariser fabricating content, one of them from undecodable binary noise; that is the documented origin of the inverted Ross's-paradox claim in `expressiveness-literature.md`.
- **Pre-registered predictions are frozen, never edited.** `scope-and-predictions.md` §1 stands verbatim as the pre-redirect block; new predictions go in a new dated block. The 4.5b threshold (≥70%) is already recorded as wrong.
- **Prompt patching buys coverage; the back-check buys correctness.** Never rely on a prompt for soundness — a patch only ever fixes the error already found.
- Dev/eval split (4.8) precedes any prompt tuning. Once an item reveals an error we act on, it is no longer evaluation data.
