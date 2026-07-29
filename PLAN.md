# TFL-Verify: Project Plan

*Goal:* Build and evaluate a pipeline that verifies LLM outputs using Term Functor Logic (TFL), producing (a) an open-source system and (b) an arXiv/workshop paper.

*Core claims to test:*
1. *Fidelity claim:* NL→TFL translation is more faithful and more human-auditable than NL→FOL translation, because TFL's variable-free plus-minus syntax mirrors natural-language surface form.
2. *Router claim:* TFL fragment membership (does the sentence parse into TFL at all?) is a clean, mechanical escalation signal — parse success → verify cheaply; parse failure → flag/escalate. FOL pipelines have no equivalent signal.

*Prior art to cite (read abstracts in Phase 1):* Logic-LM (Pan et al. 2023), LINC (Olausson et al. 2023), natural logic / NatLog (MacCartney & Manning), NaturalLI (Angeli & Manning), Sommers & Englebretsen's TFL, Castro-Manzano's TFL programming/Aristotelian databases work.

*Translator models under test (via OpenRouter unless noted):* a current Claude model, GPT-5.6, Kimi (current K-series). Look up current OpenRouter model slugs at runtime — do not hardcode from memory.

*The existing engine (located and vendored — no longer "ask Kyle"):* Kyle's TFL engine lives in the `guides` repo at `term-functor-logic/lab/` and has been copied verbatim into this repo's `engine/` directory. It is:
- `engine/tfl.js` — ~2,000-line **pure JavaScript** module, zero dependencies, no DOM; loads in Node via `require`. Parser + printer for the full plus-minus notation (categoricals, singulars, negative/compound/relational terms, propositional terms, proterms, TFL⁺ numerical quantity levels), inference core (canonicalization, derivation rules, syllogistic P/Z validity check, indirect proof), logic-programming layer (`parseProgram`, `queryProp`, `checkProgramConsistency`), equivalence decision (DNF), and natural-language rendering of terms/propositions/proofs (`readProp`, `explainProof`).
- `engine/tfl.test.js` — ~200 assertion tests, run with bare `node engine/tfl.test.js`.
- `engine/oracle.js` — finite-model semantics for the whole fragment plus a fuzz harness that checks the engine's *syntactic* verdicts against *semantic* truth (categorical exactness, rule-step soundness, relational derivations, passive equivalence, indirect-proof soundness, statement-model agreement). Run with `node engine/oracle.js -n 20000`.

*Language decision:* the pipeline (translation, routing, benchmarks, analysis) is **Python 3.11+**; the engine **stays in JavaScript** and is exposed to Python as a JSON-over-stdio CLI (`node engine/cli.js`), called via `subprocess`. Do **not** port the engine to Python: its correctness is certified by the fuzz oracle against model-theoretic semantics, and a port forfeits that assurance for zero functional gain. Node ≥ 18 is a documented runtime requirement.

*Ground rules for every step below:* each step is sized to be executed by Claude (Fable/Opus) in a single pass, end to end, with its acceptance check passing at the end. If a step feels ambiguous or too large mid-execution, stop and ask Kyle rather than guessing. Commit after each completed step with the step id in the message (`0.3: …`). Keep a running LOG.md noting decisions and surprises — this becomes paper material. **Any change that touches `engine/tfl.js` logic must end with `node engine/tfl.test.js` green AND `node engine/oracle.js -n 20000` clean; a red oracle is a stop-everything event.**

---

## Phase 0 — Engine Vendoring, Verification & Hardening

Nothing else in this project starts until Phase 0 is complete. The engine was built as courseware; before it certifies benchmark verdicts for a paper, it gets refactored for this purpose and double- and triple-checked for accuracy, effectiveness, thoroughness, and robustness.

*0.1 Vendor the engine.* ✅ DONE (2026-07-29)
`engine/tfl.js`, `engine/tfl.test.js`, `engine/oracle.js` copied verbatim from `guides/term-functor-logic/lab/`; test suite passes (201/201) in the new location.

*0.2 Engine inventory doc.*
Read `engine/tfl.js` fully (all ~2,000 lines) plus the test file's section headers. Write `docs/tfl-engine-inventory.md` describing: every exported function grouped by layer (parse/print, inference, relational, programs/queries, Aristotelian NL layer, grading, numerical), the exact input notation accepted (transcribe the header comment's notation table), what validity checking exists and its verdict vocabulary (`valid | invalid | contradicted | unknown`, methods `derivation | indirect | numerical`), error behavior on unparseable input (ParseError with position), and what the oracle does and does not cover. Flag anything that is courseware-specific (exercise grading, HTML printers) as refactor candidates for 0.4.
Accept: inventory doc exists and Kyle confirms it's accurate.

*0.3 Baseline correctness verification.*
Run `node engine/tfl.test.js` and a long oracle run: `node engine/oracle.js -n 100000` (expect minutes-to-hours; run in background). Record iteration counts, failures (expect zero), and wall time in LOG.md. If anything fails, stop and report to Kyle — do not fix in the same step.
Accept: both green at full scale; results logged.

*0.4 Refactor pass — separate the verifier from the courseware.*
With zero changes to inference logic: (a) split or clearly section `engine/tfl.js` so the verification-relevant surface (parse, print, checkArgument, derive, indirectProof, checkInconsistent / checkProgramConsistency, queryProp, readProp, explainProof) is distinct from courseware-only surface (`checkExpression` grading, `printHtml*`); (b) delete nothing yet — mark courseware-only exports as such in comments; (c) make the module cleanly requireable with no browser globals assumptions. Re-run tests + 20k oracle.
Accept: tests + oracle green; a one-page `docs/engine-surface.md` lists the verification API vs courseware API.

*0.5 Independent accuracy audit ("triple check").*
Fresh-eyes review of the inference core against Sommers & Englebretsen's system (and the guides repo's ROADMAP notes, including the documented Murphree condition-(iii) correction): hand-verify the engine on a curated list of ~40 textbook arguments — all 15 classically valid syllogism forms without existential import (Barbara, Celarent, …), the invalid forms that trap existential import (e.g. Darapti-style), obversion/contraposition/conversion cases, 5+ relational arguments from the book, 3+ indirect proofs, and 5 numerical (TFL⁺) cases. Write them as a new permanent test file `engine/paper-cases.test.js`. Any disagreement between engine and book gets logged and reported to Kyle before any change.
Accept: `node engine/paper-cases.test.js` passes; disagreements (if any) resolved with Kyle and logged.

*0.6 Robustness pass — parser error taxonomy and adversarial input.*
LLM output will hit this parser, so it must fail informatively and never crash or hang. (a) Classify parse failures into a structured taxonomy: `lexical` (bad character), `syntactic` (bad structure), `outside-fragment` (parses nowhere into a proposition). (b) Add a top-level safe entry point that catches all engine errors and returns a structured result, never throws. (c) Fuzz the parser with ≥100k garbage strings (random bytes, truncated valid strings, deeply nested groups, pathological lengths) asserting: no crash, no hang > 1s, always a structured error. Re-run tests + 20k oracle.
Accept: fuzz script committed and green; taxonomy documented in `docs/engine-surface.md`.

*0.7 JSON CLI bridge.*
`engine/cli.js`: reads one JSON request per line on stdin, writes one JSON response per line on stdout. Commands: `parse {stmt}`, `check {premises, conclusion}`, `consistent {stmts}`, `render {stmt}` (NL reading via `readProp`), `explain` (proof → numbered plain-English lines via `explainProof`). All responses include `ok`, and on failure the 0.6 error taxonomy. Node-side tests piping JSON in and asserting JSON out.
Accept: CLI tests pass; a README section documents the protocol with examples.

## Phase 1 — Project Scaffolding & Inputs

*1.1 Python project scaffolding.*
Add to this repo: `translate/`, `router/`, `bench/`, `data/`, `analysis/`, `paper/`, `LOG.md`, `pyproject.toml` (pytest, ruff), `.gitignore` covering `.env`, `data/raw/`, `data/results/`. README stub paragraph: what TFL-Verify is, the two claims, the engine provenance (guides repo), Node ≥ 18 + Python 3.11+ requirements.
Accept: `pytest` runs (zero tests ok), `ruff check` passes, commit made.

*1.2 Python↔engine bridge.*
`engine_client.py` (importable as a package module): a class that spawns `node engine/cli.js` as a persistent subprocess and exposes `parse(stmt) -> ParseResult`, `check(premises, conclusion) -> CheckResult`, `consistent(stmts)`, `render(stmt)`, `explain(...)` — all frozen dataclasses serializable to JSON, mirroring the CLI protocol, with subprocess restart on death and a timeout per call. Unit tests: round-trip 10 known-good and 5 known-bad statements through the live subprocess.
Accept: pytest green including the live-subprocess tests.

*1.3 Configure API access.*
`.env` (gitignored) with `OPENROUTER_API_KEY`. `translate/llm_client.py`: one function `complete(model_slug, system, user, max_tokens) -> str` using OpenRouter's OpenAI-compatible endpoint, with retry (3 attempts, exponential backoff), timeout, and a cost/token counter that logs to `data/usage.jsonl`. Look up the three current model slugs (Claude, GPT-5.6, Kimi K-series) on OpenRouter at execution time and record them in `config.py`.
Accept: a smoke test hits each of the three model slugs with "reply OK" and gets responses; usage log written.

*1.4 Literature pass A — LLM+solver pipelines.*
Fetch and skim (web search allowed): Logic-LM, LINC, plus any newer prominent LLM→formal-language verification pipeline found while searching. Write the first half of `docs/related-work-notes.md`: 3–6 bullets per paper — what they did, benchmark used, reported numbers, how TFL-Verify differs.
Accept: notes cover ≥3 papers in this family.

*1.5 Literature pass B — natural logic and TFL lineage.*
Same treatment for: NatLog (MacCartney & Manning), NaturalLI (Angeli & Manning), Sommers & Englebretsen's TFL (book-level summary is fine), Castro-Manzano's TFL programming / Aristotelian databases papers. Append to `docs/related-work-notes.md`.
Accept: notes file covers all six items in the prior-art list (across 1.4 + 1.5).

## Phase 2 — Verification Interface & Traces

*2.1 Verification interface hardening.*
Extend `engine_client.py` so `CheckResult` carries: verdict (`valid | invalid | contradicted | unknown | error`), method, and a `trace` — the engine's proof rendered as numbered lines. Wire `explainProof`/`readProp` through the CLI so each trace line is the plus-minus step plus a one-line English gloss. Handle the `unknown` verdict explicitly (the relational derivation search is not complete — `unknown` ≠ `invalid`; document this).
Accept: JSON round-trip tests pass; `unknown` semantics documented in the interface docstring.

*2.2 Verification test suite.*
≥30 pytest cases through the live bridge: classical valid syllogisms (Barbara, Celarent, etc.), known invalid forms, relational cases, numerical cases, malformed input, empty input — drawing pairs from `engine/paper-cases.test.js` (0.5) so the two suites agree.
Accept: all pass; coverage of `engine_client.py` ≥ 90%.

*2.3 Trace legibility review.*
Generate 3 sample traces (one categorical, one relational, one indirect proof) as markdown in `docs/trace-samples.md`. This is a paper selling point — auditable proofs.
Accept: Kyle reviews the 3 samples and approves the format.

## Phase 3 — Translation Layer

*3.1 Translation contract.*
`translate/schema.py`: the LLM must return strict JSON: `{"translations": [{"nl": ..., "tfl": ..., "confidence": ...}], "untranslatable": [{"nl": ..., "reason": ...}]}`. Validator rejects malformed payloads.
Accept: validator unit-tested against good and bad payloads.

*3.2 Translation prompt.*
`translate/prompts.py`: system prompt explaining TFL notation with 10–15 few-shot NL→TFL pairs spanning universal affirmative/negative, particular, singular terms, negative terms, and relationals. Source examples from `engine/paper-cases.test.js` so notation is guaranteed to parse. Include the ASCII aliases (`-`, `+-`) in the prompt so models don't need typographic minus.
Accept: every few-shot example's TFL side passes `parse` via the bridge.

*3.3 Translator harness.*
`translate/translator.py`: `translate(model_slug, sentences) -> TranslationResult`, calling the LLM client, validating JSON, and running `parse` on every returned TFL string. Parse failures are recorded with their 0.6 taxonomy class, not fatal.
Accept: smoke test — 5 hand-written sentences through all three models; results and parse rates printed.

*3.4 Back-translation fidelity check.*
`translate/backcheck.py`: render the TFL back to English **using the engine's own deterministic `render` (readProp) first**, then an LLM call scores semantic match nl↔rendering on a 0–2 scale. (The deterministic rendering is a TFL-only advantage — FOL has no free faithful verbalizer; note this for the paper.)
Accept: runs end-to-end on the 5 smoke sentences.

## Phase 4 — Router

*4.1 Router logic.*
`router/route.py`: given a claim/inference, attempt translation + parse. Outcomes: `VERIFIED_VALID`, `VERIFIED_INVALID`, `OUTSIDE_FRAGMENT` (translation refused or parse failed), `TRANSLATION_SUSPECT` (parsed but back-check score 0), plus `UNKNOWN` (parsed and checked but the engine returned `unknown`). No external solver in v1 — `OUTSIDE_FRAGMENT` is a terminal flag. Stub `router/escalate.py` documenting the future Prolog/Z3 hook.
Accept: unit tests covering all five outcomes with mocked components.

## Phase 5 — Benchmarks

*5.1 Dataset loaders — ProofWriter.*
Download to `data/raw/`; write `bench/loaders.py` with a common normalized record `{id, premises: [...], conclusion, gold_label}` and the ProofWriter loader. Unit test on a fixture slice; full counts printed and logged in LOG.md.
Accept: loader test passes; counts logged.

*5.2 Dataset loaders — FOLIO and LogicBench.*
Add both loaders to `bench/loaders.py`, same contract, same acceptance ritual.
Accept: loader tests pass; counts logged.

*5.3 Dataset loaders — syllogism-focused dataset.*
Web-search for the current best syllogism dataset (candidates: SylloBase, Avicenna); pick one, justify in LOG.md, add its loader.
Accept: loader test passes; choice + counts logged.

*5.4 Fragment filtering.*
`bench/filter.py`: heuristically tag items likely inside the TFL fragment (categorical/syllogistic surface forms). Produce two eval sets per dataset: in-fragment (target ~200–500 items each) and a random mixed sample (~200) for router evaluation. Write to `data/eval/`.
Accept: filtered sets written; 20 random items manually spot-checked in LOG.md.

*5.5 Baseline: direct LLM answering.*
`bench/baseline_direct.py`: each model answers each eval item directly (valid/invalid/unknown), no solver. Cache all responses to disk keyed by (model, item) so reruns are free.
Accept: runs on a 20-item slice for all three models; accuracy computed.

*5.6 Main pipeline runner.*
`bench/run_pipeline.py`: full pipeline (translate → parse → check → router verdict) per model per eval set, cached, with a `--limit` flag and a hard cost ceiling read from config (default: stop at $10 per model per dataset; Kyle can raise it).
Accept: 20-item slice completes for all three models; per-item records written to `data/results/*.jsonl`.

*5.7 Full runs — one step per dataset.*
Execute baseline + pipeline at full eval-set size for ONE dataset (ProofWriter first), check cost, report spend to Kyle in LOG.md. Then repeat as separate steps: 5.7b FOLIO, 5.7c LogicBench, 5.7d syllogism dataset. Never start the next dataset in the same pass.
Accept (each): results files complete for that dataset × 3 models; spend logged.

*5.8 Policy-language mini-benchmark — authoring, batch 1.*
Author `data/policybench/` items: policy/eligibility-style categorical language ("All employees with five years of service are eligible…"), each with premises, conclusion, gold label, and an in-fragment/outside tag. Batch 1: 35 items, ~70% in-fragment, ~30% outside (tense, defaults, arithmetic). Verify every in-fragment item's intended TFL form parses and gets the intended verdict via the bridge before presenting.
Accept: Kyle reviews and signs off batch 1.

*5.9 Policy-language mini-benchmark — batch 2 + freeze + run.*
Batch 2: 35 more items, same recipe, avoiding structural duplicates of batch 1. After Kyle's sign-off, freeze the dataset, then run baselines + pipeline on it (cost ceiling applies).
Accept: Kyle signs off; results files written.

## Phase 6 — Analysis

*6.1 Metrics.*
`analysis/metrics.py` computing per model × dataset: end-task accuracy (pipeline vs direct baseline), translation parse rate, back-check fidelity distribution, router precision/recall for `OUTSIDE_FRAGMENT` (against the manual fragment tags from 5.4), abstention-aware accuracy (accuracy when the router lets you abstain vs forced answers), token cost per item.
Accept: one markdown report `analysis/report.md` with tables generated from results files.

*6.2 Fidelity audit.*
Random sample of 50 translations per model; score faithful/unfaithful by hand (Kyle + Claude independently, then reconcile). Headline evidence for the fidelity claim. FOL comparison optional: if time permits, have models translate the same 50 items to FOL and audit those for contrast.
Accept: audit spreadsheet + agreement stats in `analysis/`.

*6.3 Figures.*
Accuracy and parse-rate charts (matplotlib, no seaborn), saved to `paper/figs/`.
Accept: figures render and are referenced in report.md.

## Phase 7 — Write-up & Release

*7.1 Paper skeleton + background.*
`paper/draft.md`: full section outline, then write the background section — TFL primer (plus-minus notation, REGAL-style validity conditions, worked example with an engine trace) — and the related-work section from `docs/related-work-notes.md`. Kyle drafts or closely reviews the primer.
Accept: sections complete; Kyle reviews the primer.

*7.2 Method + experiments sections.*
Write method (architecture: translate → parse → check → route; the deterministic back-rendering; the error taxonomy) and experiments (setups, tables from `analysis/report.md`, figures).
Accept: sections complete and numerically consistent with `analysis/report.md`.

*7.3 Intro, abstract, limitations.*
Write intro + abstract last. Limitations explicitly include: nonmonotonicity/generics, fragment narrowness, single-notation dependence, the engine's `unknown` verdict on relational search misses.
Accept: complete draft; Kyle does a full pass.

*7.4 Repo release.*
README with quickstart (Node + Python setup), architecture diagram, example trace output; license (MIT unless Kyle says otherwise); scrub keys; pin dependencies.
Accept: fresh-clone install-and-run works in a clean venv on a machine with Node ≥ 18.

*7.5 Submission targets.*
List current neurosymbolic venues/workshops with deadlines (web search at time of writing — NeSy conference, ACL/NeurIPS workshops). Draft the email to Castro-Manzano's group describing the system and inviting collaboration.
Accept: target list + email draft ready for Kyle.

---

## Standing constraints

- Never commit API keys; `.env` is gitignored from step 1.1.
- All LLM calls cached to disk; never re-spend on identical calls.
- Cost ceiling enforced in code (5.6), reported after every run.
- Engine logic changes require `tfl.test.js` + 20k oracle green before commit; the vendored engine's verdict semantics never change silently.
- Any deviation from this plan gets logged in LOG.md with a one-line rationale.
- When results contradict the core claims, report them as-is. Negative results go in the paper's limitations, not in the trash.
