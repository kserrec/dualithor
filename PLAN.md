# TFL-Verify: Project Plan

*Goal:* Build and evaluate a pipeline that verifies LLM outputs using term logic (TFL), producing (a) an open-source system and (b) an arXiv/workshop paper.

*Core claims to test:*
1. *Fidelity claim:* NL→TFL translation is more faithful and more human-auditable than NL→FOL translation, because TFL's variable-free plus-minus syntax mirrors natural-language surface form.
2. *Router claim:* TFL fragment membership (does the sentence parse into TFL at all?) is a clean, mechanical escalation signal — parse success → verify cheaply; parse failure → flag/escalate. FOL pipelines have no equivalent signal.

---

## Scope amendment — 2026-08-02

**The principle: stop building what established tools already do better, and concentrate the
remaining effort on the things only the term-logic approach makes possible.** General
"verify LLM output with a symbolic engine" is occupied — SemEval-2026 Task 11 is an entire
ACL shared task on it and ARc (arXiv:2511.09008) is a deployed AWS service — and both are
FOL + general solvers. We do not compete there. Everything below is scoped to what is ours.

**The three capabilities that are ours, with their honest novelty status.**

1. **The back-check** — render the model's TFL back to English with the engine's own
   deterministic reading and compare it to the source sentence. **Proven** (step 4.4: caught
   GPT's two meaning-inverting sign flips unaided, 2% false positives, both of those being
   defects in *our* renderer rather than judge errors). **But the round trip itself is
   occupied prior art**: Amrollahi, Lopez & Barrett, *Faithful Autoformalization via
   Roundtrip Verification and Repair* (arXiv:2604.25031, 2026) formalize → back-translate →
   re-formalize → check equivalence, on Texas statutes; lit sweep 1 §11b/§15 ranks it the
   second-largest threat to our novelty and states that our claim must be pinned to the
   *human-facing* rendering, not the round trip. Our back-check is also machine-consumed
   today (an LLM judge reads the rendering). **What is actually ours: the verbalizer is a
   total deterministic function rather than a second language model** — Vernie & Grabmair
   flag their own LLM-generated verbalization as an unverified artifact inside the audit
   path — **and putting that rendering in front of a person, which is Phase 9.** Never write
   "FOL structurally cannot do this."
2. **Missing-premise / enthymeme completion** (Phase 6.1) — the sharpest pure novelty, and
   **a build, not a port**; see the rewritten step for why the reference engine's version is
   not the novel one and why the algebra is not plain subtraction.
3. **Fragment routing** (Phase 5.1) — real, thinnest of the three, and its value is gated by
   the unrun real-text coverage measurement (step 4.6).

**Phase 9 is the centrepiece, not an epilogue.** Without a human in the loop, capability 1
reduces to "our English generator is deterministic" — a true and worthwhile paragraph, not a
paper. The auditability study is what converts it into a contribution.

**Cut or deferred, with reasons.** Phase 7 (the defeasible/"unless" layer) — **deferred**:
non-novel (Governatori and Ciabattoni, the formalism's own authors, did LLM→defeasible
deontic logic on real regulation a year ahead) and someone else's ground. Step 6.3 (Murphree
numerical term logic) — **cut**: blocked behind an open soundness question, and it widens the
fragment, which cuts against this project's own thesis that the narrowness is the product.
Phase 8 — **trimmed** to policybench plus the syllogism set; the broad accuracy sweep,
DeonticBench and the legal-benchmark pick all go (DeonticBench exists to evaluate Phase 7,
so it leaves with it).

**Three things this amendment adds that were not in the plan at all:** a step to fix the
English renderer (Phase 5.0 — it is load-bearing under three of the four keepers and has two
proven bugs), a plumbing step before the real-text run (step 4.9 — a retry bug that silently
dropped 22 sentences from the last run, and the cost ceiling this project's docs claim exists
and does not), and a corrected trigger for the deferred defeasible layer.

**Execution order.** Doc order below is thematic; this is the order the work runs in:

> ~~4.9 plumbing~~ ✅ → ~~5.2 pronoun policy~~ ✅ → ~~5.0 renderer~~ ✅ → **4.10 verb-like relation
> naming + 4.5b re-run** (next session) → 4.6 real-text coverage (with
> hand-labelled in/out answer key) → 5.1 router + 5.3 numerical audit → 6.1 missing premise →
> 4.7 FOL arm (reshaped) → Phase 9 study (pilot, then decide on a panel) → Phase 8 trimmed →
> Phase 10 analysis → Phase 11 write-up and release.

**Predictions that become unmeasurable under this amendment** (`scope-and-predictions.md`):
Block A §1.5 (FOLIO coverage) and Block B §1B.6 (defeasible-layer coverage). They are recorded
as *not run* in the scorecard, never deleted — reporting how a pre-registered prediction fared
is the whole reason to write one down. Block A §1.6 (selective accuracy ≥98%) **survives** the
trim: policybench alone still yields the (coverage, accuracy-given-coverage) pair.

---

*Prior art to cite (read abstracts in Phase 2):* Logic-LM (Pan et al. 2023), LINC (Olausson et al. 2023), natural logic / NatLog (MacCartney & Manning), NaturalLI (Angeli & Manning), Sommers & Englebretsen's TFL, Castro-Manzano's TFL programming/Aristotelian databases work.

*Translator models under test (via OpenRouter unless noted):* a current Claude model, GPT-5.6, Kimi (current K-series). Look up current OpenRouter model slugs at runtime — do not hardcode from memory.

*Language decision (Kyle, 2026-07-29):* the entire system — engine and pipeline — is **OCaml**. Rationale: the engine is tree manipulation over algebraic data types, and OCaml's exhaustiveness checking proves at compile time that every inference rule handles every term shape — a machine substitute for human code review on a codebase Kyle won't be reading line-by-line. Python appears in exactly two places: a **pip-installable client** at release (Phase 8) wrapping the compiled binary so ML researchers can adopt the tool, and a tiny dev-only matplotlib script for paper figures. Toolchain: opam + dune; libraries: `yojson` (JSON), `cohttp` + TLS (OpenRouter calls), `qcheck` (property-based testing), `alcotest` or plain asserts (unit tests). Node ≥ 18 remains a **dev-time** requirement only, for the reference engine below.

*The reference engine (vendored, stays in-repo permanently):* Kyle's existing TFL implementation, copied verbatim from the `guides` repo (`term-functor-logic/lab/`) into `engine/`:
- `engine/tfl.js` — ~2,000-line pure JavaScript, zero dependencies: parser + printer for the full plus-minus notation (categoricals, singulars, negative/compound/relational terms, propositional terms, proterms, TFL⁺ numerical levels), inference core (canonicalization, rewrite rules, P/Z validity, derivation, indirect proof), logic-programming layer (programs, queries, consistency), DNF equivalence, and NL rendering (`readProp`, `explainProof`).
- `engine/tfl.test.js` — 201 assertions (`node engine/tfl.test.js`).
- `engine/oracle.js` — finite-model semantics + six fuzz suites checking the engine's syntactic verdicts against semantic truth (`node engine/oracle.js -n 20000`).

**The JS engine is the executable specification for the OCaml port.** It is never extended, only consulted. The OCaml engine becomes authoritative only after the differential gate (1.12) passes. `guides` is a separate, untouched project; this copy is the maintained one.

**Its authority is split, as of 2026-08-02 (Kyle's decision).** Nothing JavaScript ships or
runs in this project; the OCaml engine has been authoritative since the 884k-input differential
gate passed. The reference stays **frozen forever and is never edited** — a reference you are
allowed to edit stops being an independent check and becomes a mirror, and the day someone
"fixes" it to match an OCaml bug the gate goes silent. But:
- **On verdicts it stays authoritative and the comparison runs forever.** Two independent
  implementations agreeing on 884,000 inputs is real evidence, and a wrong verdict is the one
  thing that must never happen.
- **On English rendering it has no authority at all.** It is not a specification of correct
  English — it is one earlier draft of an English generator, and two of its outputs are proven
  wrong (Phase 5.0). Deferring to it there means pinning our audit surface to a known-broken
  draft.
Deliberate rendering deviations are handled the way the comment-stripper deviation already is:
the harness runs both sides, **exempts only the specific constructions we changed, and reports
the exempted count** so the exemption can never silently grow. Everything else keeps being
compared byte-for-byte.

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
16 pairs (15 originally; a level-3 pair was added 2026-08-02 to correct a taught error — see 4.5b), plus four worked *decline* examples carrying the router half of the contract. **No verdict vocabulary in the prompt** (asserted by test): teaching a validity judgement would invite reasoning-to-the-answer, the confound the fidelity claim must avoid.

*4.3 Translator harness.* ✅ DONE (2026-08-01 — `translate/translator.ml` + `cache.ml`; live smoke 100% parse rate ×3 models, $0.035)
`translate/translator.ml`: `translate ~model sentences`, calling the client, validating JSON, parsing every returned TFL string; parse failures recorded with their 1.14 taxonomy class, not fatal.
Accept: smoke test — 5 hand-written sentences × 3 models; results and parse rates printed.
Four outcomes per sentence (`Translated | Unparseable | Declined | Absent`); `Absent` exists because a silently dropped sentence would otherwise shrink the denominator and flatter every rate. Matching is on a normalised key and refuses paraphrases — a formula paired with the wrong sentence is undetectable downstream. `translate/cache.ml` keys replies by a digest of the exact (model, system, user) triple, per the standing no-double-spend constraint; `data/cache/` gitignored with a CI guard.

*4.5 Translation-fidelity gate.* — **pulled in front of 4.4 and Phase 5 on Kyle's instruction (2026-08-01).**
The project's largest open risk, and the cheapest to settle: plus-minus notation is essentially absent from pretraining data where FOL is abundant (`scope-and-predictions.md` §1.3), and the second literature sweep found a neighbouring measurement — NL→TLA+ at 26.6% syntactic / 8.6% semantic, attributed to corpus scarcity. If TFL translation fidelity collapses, the thesis goes with it, so it is measured before any layer work or benchmark spend.
*4.5a Gold set.* ✅ DONE (2026-08-01 — `data/fidelity/items.jsonl`, 85 items / 91 translatable sentences / 10 declines; `test/test_fidelity_set.ml`, now 29 checks after 4.8)
Authored, engine-verified, contamination-guarded against the few-shot prompt. Group J reuses a relation across premises to test the naming-consistency threat the 4.3 smoke could not reach.
*4.5b The run.* ✅ DONE — bare few-shot arm only. **Re-run 2026-08-02 against a corrected gold and prompt; `docs/fidelity-report-2026-08-02.md` is the citable one and `-08-01.md` is superseded** (45 calls, $0.54). **Kimi 100% (91/91), Sonnet 100% (91/91), GPT 98% (88/90 attempted, 1 refused); zero unparseable in 269 attempts; 30/30 declines; 24/24 argument verdicts.** The pre-registered ≥70% threshold was cleared by a wide margin — prediction recorded as wrong. Three arms remain unrun (grammar prompting, matched FOL, FOL→TFL transduction); the FOL arm needs scoring infrastructure we do not have.
Why it was redone: the 4.4 back-check flagged our own `i04` gold and was right. Level 3 marks the predominant *complement*, so `few` inverts the English polarity — "Few volunteers are employees." is `+Volunteer^3−Employee`, and our gold had `+Volunteer^3+Employee`, which the engine reads as "few volunteer is **not** employee". `prompts.ml` taught "^3 few" with no mention of the flip, so all three models copied the error and were scored **exact**. Both fixed; the level-3 rule is now pinned in `test_prompts.ml` against the engine's own reading. **The one error class that survived the prompt rewrite is the `c02`/`c06` sign flip** — the division of labour in 4.4 stated as a prediction and now observed. The rewrite also introduced one new GPT over-refusal (`b08`, an eval item), left unchased on purpose: tuning further against an eval item is what 4.8 exists to prevent.
*4.5b (original scope).* Four arms — bare few-shot, grammar prompting (ship the BNF; published evidence for low-resource formal languages), a matched **FOL arm** so the numbers mean something, and LLM→FOL→mechanical transduction (the sweep found no trace of anyone trying it). Scoring in layers: parses → structurally isomorphic to gold under consistent term renaming → semantically equivalent per the engine → faithful anyway. **Exact string match is deliberately not the primary metric** — term naming is arbitrary and the 4.3 smoke proved it (three models, three correct stems for one verb).
Accept: all four arms run across three models; per-arm layer-by-layer scores reported; the naming-consistency question answered from group J.
Known gap, to report as a limitation: the set is authored, not sampled from real statutes, so it is an upper bound. A real-text arm is still owed.

*4.6 Real-text arm.* — **the next measurement, and the one most likely to change the picture.**
4.5b's sentences were authored by Claude, which biases them toward being translatable. Sample ~60 sentences from **public-domain regulatory sources** (US federal works are public domain — eCFR, agency guidance; note the licence for anything else and do not commit corpora, per the standing rule). Two numbers come out, and the second is now the more interesting one:
- **Fidelity on messy input** — same four-tier scoring as 4.5b, gold hand-written and engine-verified.
- **Coverage** — what fraction of real regulatory sentences land inside the fragment at all. *After 4.5b, coverage has replaced fidelity as the project's largest unknown:* translation works, but a tool that refuses 80% of real sentences is a demonstration, not a system.
Report `Outside_fragment` reasons by category (tense, arithmetic, cross-reference, defeasible, multi-clause) — that distribution is what tells us which layer to build next, and it is paper material either way.
**Three additions from the 2026-08-02 amendment, all cheap now and expensive later:**
- **Hand-label every sampled sentence in-fragment or out-of-fragment *before* running
  anything.** That answer key is the only thing that makes the router measurable — "the router
  said this was outside the fragment; was it right?" needs human ground truth to score
  against (Block A §1.4 says so). Once Phase 8 is trimmed, this is the *only* remaining source
  of those labels; skipping it means a separate labelling pass later.
- **Harvest every genuine translation error this run produces and keep it.** Phase 9 needs
  roughly fifteen items where the rendering genuinely disagrees with the source, and the entire
  4.5b study yielded **two** (`c02`/`c06`, and they are the same error twice). Real messy text
  is where the rest are expected to come from.
- **Fill the two eval coverage holes** recorded in `data/fidelity/README.md`: no negative-term
  E-form and no quantity level 3 survive on the eval side after the burn rule.
Runs *after* 4.9 (plumbing) and 5.0 (renderer) — a dropped-response bug would corrupt the
counts and a broken renderer would corrupt the fidelity scoring.
Accept: coverage and fidelity reported with the refusal-reason breakdown; in/out answer key
committed with the sample; observed translation errors collected for Phase 9; sentences and
gold committed to `data/fidelity/real/`; spend logged.

*4.9 Plumbing before the real-text run.* ✅ DONE (2026-08-02 — `test/test_llm_client.ml`, 25 checks; no engine logic touched, `dune test` green) — **small, and it ran first.**
Two defects recorded 2026-08-02 and unactioned, both of which bite a larger run:
- `llm_client.ml` classifies an **empty 200 body** as `Llm_error` rather than `Retryable`, so
  it does not retry. Two Kimi batches hit it mid-run and **22 sentence slots vanished**, while
  the reported percentages still looked healthy because `attempted` excludes missing. LOG's own
  words: "4.6 is a bigger run and will hit this again."
- **There is no cost ceiling anywhere**, though `CLAUDE.md` asserts one is enforced in code.
  4.6, 4.7 and Phase 8 are where the money goes.
Accept: empty-body responses retried (with a test that fails on the old classification); a
ceiling in `translate/config.ml` enforced in code and checked before each run; `CLAUDE.md`'s
claim is either true or reworded.
**How it landed.** Response classification is now a pure `disposition_of ~code ~raw`
(`Body | Retry | Fatal`) split out of the I/O, and the retry loop is `with_retries`, generic
over its thunk — both testable with no network, which is why the test can exist at all. An
empty or whitespace-only 2xx body is `Retry`; the 429/5xx-retry and 4xx-fail-fast rules are
unchanged and now pinned. The empty-body check was reverted once to confirm the test is not
vacuous: it fails on the old classification. Ceiling: `Config.cost_ceiling_usd = 5.0`
(~ten full runs against the $0.54 that 4.5b actually cost), checked in `complete` before every
request, so a runaway overshoots by at most one call; cache hits never reach the client and are
never counted. `Cost_ceiling` is a distinct exception and is explicitly *not* retried.
`run_fidelity` prints the ceiling up front, the spend at the end, and on a ceiling stop prints
**no summary at all** — a half-run reported as a run is the same failure mode as the 22 missing
sentences, since every percentage still computes. Both smokes and the back-check smoke report
spend too, which makes the second half of `CLAUDE.md`'s claim true as well, so it was left
standing rather than reworded. One bug found while there: a genuinely free call comes back as
JSON `0`, which yojson types as `Int`, and the cost reader matched only `Float` — it would have
been filed as unpriced. Unpriced replies cannot be counted at all, so the spend report names how
many there were and says the total is a lower bound; that is the one hole in the ceiling and it
is reported rather than papered over.

*4.10 Verb-like relation naming, and the 4.5b re-run that follows it.* — **approved by Kyle 2026-08-02, deliberately deferred to a later session; runs before 4.6.**
**The defect.** `render.ml` renders a negative relational predicate as `"does not " ^ reading`, which is right for a verb-like relation and wrong for a noun-like one: `+Man−(Lov+Woman)` reads "some man does not lov some woman" (fine) while `+Employee−(Member+Union)` reads "some employee does not member some union" (not English). The renderer cannot tell the two apart, so it applies one frame and that frame is wrong about half the time. **This is not confined to counterclaims or contradictions** — the examples above are ordinary true statements, and a Phase 9 participant would meet them in a plain sentence.
**Why the fix is a prompt change and not an engine change.** Deciding noun-like from verb-like needs an English lexicon keyed by relation, which is exactly the guess a deterministic renderer must not make — the same root cause as the missing "of" (5.0) and as choosing a comma over "is". Term naming cannot rescue this one the way it rescues "of": `"member of"` yields "does not member of some union", no better, because the damage is in the frame rather than the name. So the lever is **naming the relation verb-like in the first place** — `Employs` over `Employer`, `Heads` over `Head` — which is `translate/prompts.ml`'s job.
**Why it violates nothing** (checked before approval): a term name is opaque to the engine, so naming cannot move a verdict — this buys *readability*, which is what prompt patching is allowed to buy, and it is not relied on for soundness. It does not touch the 4.8 dev/eval rule, because no eval item revealed the defect; it came out of reading `render.ml`. `test_fidelity_set.ml` already asserts no eval item's sentence or formula appears in the prompt, so a few-shot addition is guarded automatically.
**The two costs, both accepted.** (a) The cache key is a digest of the exact (model, system, user) triple, so editing the prompt makes every 4.5b call a miss: `docs/fidelity-report-2026-08-02.md`'s numbers were measured under the prior prompt revision. **Kyle's call: do the re-run** (~$0.54, and it will now be under the 4.9 cost ceiling with spend reported). (b) It becomes a stated limitation — part of the rendering's readability comes from a naming convention we ask the model for, not from the engine alone, so the Phase 9 claim reads "given a naming convention, the deterministic rendering is auditable". That is a qualification, but it makes us *more* reproducible than the status quo: the 4.3 smoke found three models choosing three different stems for one verb, so naming is already model-dependent and currently uncontrolled.
Accept: the naming guideline in `translate/prompts.ml` with every few-shot formula still parsing; 4.5b re-run and its report regenerated under the new prompt, with the superseded report marked as such; the limitation recorded for Phase 11.

*4.4 Back-translation fidelity check.* ✅ DONE (2026-08-01; **re-measured 2026-08-02** on the corrected run — `translate/backcheck.ml`, `test/test_backcheck.ml` 14 checks, `translate/smoke_backcheck.ml`) — **promoted: this is the correctness mechanism, not a nicety.**
**Acceptance PASSED, twice.** Both `c02` and `c06` flagged unaided, with accurate diagnoses ("quality reversed: no vs every"). False positives **2/88 = 2%** on the corrected run, against a pre-registered 5–20% and a 20% abandon threshold. Both remaining "false positives" are real defects in **our** renderer, not judge errors (`i06` — quantity level dropped when the predicate is a relational complex; `d03` — a compound term read back as "registered and voter"), so the true rate against a correct renderer is 0/88. The third false positive from the first measurement was `i04`, and it was not a false positive at all: it found the wrong gold that forced the 4.5b re-run. ~~**The renderer defect is still open**~~ — **fixed 2026-08-02 in step 5.0**, both of them. The predicted consequence is that a re-run of `smoke_backcheck` now reports **0/88** false positives; that re-measurement has not been run (it costs a few cached-miss judge calls) and the claim stands as a prediction until it is.
`translate/backcheck.ml`: render the model's own TFL back to English with the engine's deterministic `read_prop` (1.9), and score nl↔rendering agreement. The reasoning, settled 2026-08-01: a few-shot patch fixes the one error you already found and generalises to nothing, while a back-check catches **meaning-inverting errors nobody anticipated**. Deterministic verbalisation is a TFL-only capability — FOL pipelines have no canonical English reading to compare against.
**Pinned acceptance test:** it must flag GPT-5.6-terra's E-form sign flip (`c02`, `c06` — "No non-member is eligible" → `-(-Member)+Eligible`, which renders as "every non-member is eligible") **without being told what to look for.** That turns 4.5b's finding from an anecdote into a demonstration of the architecture.
Division of labour to hold onto: prompt patching buys *coverage*; the back-check buys *correctness*. Never rely on a prompt for soundness.
Accept: runs end-to-end on the 4.5b and 4.6 sets; catches c02/c06 unaided; false-positive rate on correct translations reported.

*4.7 Matched FOL arm.* — **required before core claim 1 can be stated at all. Reshaped 2026-08-02: do not build a FOL scoring system.**
Claim 1 says TFL translation is *more* faithful and *more auditable* than FOL. 4.5b shows TFL works well; it shows nothing comparative.
**Why the original scope is cut.** As written this step meant a FOL parser plus a structural comparator — the largest remaining build in the plan, and the largest remaining chunk of reimplementing what other tools already do better. And our own pre-registered §1B.4 predicts NL→FOL and NL→TFL land **within 5 points of each other**, with TFL's advantage appearing only where FOL has no counterpart. Building a large scorer to confirm a tie we already expect is exactly the effort this amendment exists to redirect.
**Three parts instead:**
- **(a) A cheap accuracy number.** Models emit FOL; equivalence against gold decided by an off-the-shelf prover, with a judge for the residue. Nothing in the FOL arm is load-bearing for our own verdicts, so leaning on someone else's tool is correct here. Enough to state parity or to withdraw the accuracy half of claim 1 honestly.
- **(b) The comparison that matters moves into Phase 9 as a control arm.** One group of participants audits our English rendering against the source sentence; another audits a raw FOL formula against the same sentence. **That is the experiment that actually supports claim 1's auditability half**, it is the empty slot lit sweep 1 §14 names, and it costs a study arm rather than a scoring system.
- **(c) Keep the transduction arm** the 2026-08-01 novelty sweep found no trace of anyone trying: **LLM→FOL→mechanical transduction into TFL**, versus direct TFL emission. Models know FOL; the transduction is deterministic code. Cheap and genuinely unclaimed.
*Grammar prompting* (ship the BNF) is **dropped from the near term** — published evidence supports it for low-resource formal languages, but at a 100% parse rate there is nothing left for it to fix. Revisit only if 4.6 shows syntax failures on real text.
Accept: (a) a FOL accuracy number on the same items, supporting or withdrawing the accuracy claim; (c) transduction scored against direct emission; (b) carried into the Phase 9 design rather than scored here.

*4.8 Dev/eval split.* ✅ DONE (2026-08-02 — `data/fidelity/items.jsonl` `split` field, 42 dev / 43 eval; `test/test_fidelity_set.ml`, 29 checks)
The moment a prompt is changed in response to an observed error, the items that revealed it stop being evaluation data. Split now, while nothing has been tuned: a development set we may inspect freely, and an evaluation set touched once. Record which items are which in the data files.
Accept: split committed; `test_fidelity_set.ml` enforces that no eval item's sentence or formula appears in the prompt.
Every item already implicated in an observed error is forced to dev (`c02`/`c06` the sign flip, `i04` the `few` inversion, `i06` the renderer level-drop, `b04` the definite-description convention); the rest is stratified so both halves carry the same constructions. Three guards, not one: the eval-contamination check, a **pinned eval id list in the test** so relabelling a failed item is a reviewable code change rather than a data edit, and a **no-shared-sentence-or-formula** check across the split. That third guard is the one that earned its keep — group J's arguments are built from the same material as groups A, F and I, and the first cut had three collisions, so promoting dev item `a01` into the prompt would have silently contaminated eval item `j04`. Item *content* is unchanged, so the 4.5b run stays reproducible and re-cuts by split off cache. Two eval coverage holes follow from the burn rule and are recorded in `data/fidelity/README.md`: no negative-term E-form and no quantity level 3 (its only item is `i04`, whose gold is wrong). 4.6 should fill both.

---

## Phase 5 — Router, and the three engine debts

Execution order inside this phase is **5.2 → 5.0 → 5.1 → 5.3**. The pronoun check is one
session and protects a headline claim; the renderer unlocks three of the four things the
amendment keeps; the router is not measurable until 4.6 supplies its answer key.

*5.0 The renderer as audit surface.* — **code complete 2026-08-02, awaiting Kyle's approval of the readings** (`test/test_readings.ml`, 17 groups; rendering differential narrowed in `test/test_differential.ml`). — **new 2026-08-02; the highest-value unscheduled work in the project, and it runs before anything human-facing.**
**Both bugs fixed, each a one-line change in `lib/tfl/render.ml`.** The level gate `lvl > 0 && not rel_pred` became `lvl > 0` — `rel_tail` already rendered a relational predicate in both polarities, so the branch needed nothing else, and level 3's polarity inversion carries over unchanged ("few officer does not sign some contract"). The compound joiner became `" "` from `" and "`: a compound is one term and English writes an intersection by juxtaposition, where "and" reads as two separate things.
**A third deviation, added on Kyle's instruction after reviewing the readings: the comma seam.** A relational subject reading trails off with no closing word and an affirmative relational predicate opens with none, so the two ran together — "every head some horse head some animal", the item 3.3/3.4 recorded as having no readable form. A comma now marks the boundary. It was chosen over inserting "is" for a reason that generalises: **the comma needs no knowledge of English words.** "is" reads correctly when the relation is noun-like ("head") and wrongly when it is verb-like ("every lov some woman is lov some girl"), and a deterministic renderer cannot tell those apart. Where the predicate already opens with "does not", that word is the marker and no comma is added, so the rule is "mark the seam only when nothing else does".
**"Of" is refused, as a decision rather than a deferral (Kyle, 2026-08-02).** The object's sign carries the *quantity*; the preposition is a lexical property of the relation and the argument slot (`Head` wants "of", `Lov` nothing, `Gave` "to" on its second object) and the notation encodes it nowhere. A guessed preposition asserts a relationship the formula never states, on the audit surface, where the back-check compares rendering to source and a plausible-sounding error is precisely what survives. The legitimate lever is term naming — a quoted head `"head of"` reads correctly and costs the engine nothing — but it reaches only the **first** object slot, since the head prints before all of them, so `(Gave+Rose−Girl)` can never get its "to". That residue is a limitation, not a bug.
**The differential exemption is exact, not approximate.** A rendering differs from the reference **iff** the input contains a multi-element compound, takes the levelled-relational branch, or hits the comma seam; the predicate is mutually recursive over terms and propositions, because the first cut missed propositional terms `[…]`, whose interiors `read_term` renders through `read_prop`, and the gate caught it. Assertions, because a count reported into a log guards nothing: the corpus exemption is **pinned to exact numbers** (7 readProp, 1 readTerm) with every exempted string printed by name and each accounted for by construction (6 compound, 2 comma); all three deviations must be *reached* (the level case appears nowhere in the corpus, so only the random gate exercises it); and a floor on renderings still compared byte-for-byte. **The pin has already earned its keep**: adding the comma took readProp from 5 to 7 and the gate said so before anything was committed. The exempted fraction of the random gate is a property of `Gen.prop_gen` building compounds liberally, which is why the guard is a floor on what is compared rather than a cap on what is skipped.
**`test/test_readings.ml` also pins the readings that are still wrong**, so the approval covers what remains broken as well as what was fixed: a compound predicate on a named individual takes no article ("Alice is registered voter" — Kyle accepted it as readable), negating a compound collides with negating its head, no verb agreement ("sign", not "signs"), and the missing "of". Each needs English machinery rather than a one-line fix.
`lib/tfl/render.ml` — **our OCaml, not the JavaScript** — turns a TFL formula into English. Four things depend on it and nothing else does the job: the back-check (4.4), the missing premise's English output (6.1), the proof traces (3.3/3.4), and the Phase 9 study, where the rendering *is* the thing a participant reads. It has two proven bugs and two open cosmetic defects:
- **Quantity words are dropped when the predicate is a relational complex.** `render.ml:107` gates the quantifier word on `not rel_pred`, so `+Officer^1+(Sign+Contract)`, `^2` and `^3` all read "some officer sign some contract" — identical to level 0. A reader auditing a levelled proposition is shown "some" where the formula says "many", and the back-check is correspondingly blind there (`i06`).
- **Compound terms read as conjunctions** — "registered voter", one term, comes back as "registered **and** voter" (`d03`).
- Carried from 3.3/3.4: the frozen `explain_proof` sentence still renders relational subjects the old way, so it reads inconsistently with the trace lines directly above it; and A-form relational subjects ("every head some horse head some animal") have no readable form at all.
**Why this ranks first.** Those two bugs are the *only* two remaining false positives in the 4.4 back-check — LOG 2026-08-02: "true false-positive rate against a correct renderer: 0/88." Fixing them improves the project's best existing result. And each would put demonstrably wrong English in front of a Phase 9 participant, on precisely the task the study measures: the study would then be measuring our bug rather than our idea.
**Why it is safe, and why the frozen-reference rule does not block it.** The rule protects *verdicts*. **The renderer produces no verdicts** — changing how a formula reads in English cannot change whether an argument is valid. This is a smaller deviation than the two already approved (the `find_cancellation` work cap, the quote-aware comment stripper), both of which sit closer to decisions.
**Method.** Change the OCaml; never touch the JavaScript. Narrow the rendering differential to **exempt only the constructions actually changed**, with the exempted count reported — the `diff_parse_program` pattern already used for the comment stripper. Everything else keeps being compared byte-for-byte. Pin the new English in an OCaml golden test Kyle can read and approve, since a golden file can say "this is *right*" where a comparison can only say "this matches the old thing".
Accept: both bugs fixed with pinned readings; rendering differential narrowed with its exemption count reported and asserted; **every verdict gate green** — unit suites, 62 paper cases, the 18-gate differential, the 20k oracle; Kyle approves the new readings as he did the 3.3 samples.

*5.1 Router logic.* — *not startable until 4.6 supplies the hand-labelled in/out answer key.*
`router/route.ml`: attempt translation + parse + check. Outcomes: `Verified_valid`, `Verified_invalid`, `Outside_fragment` (translation refused or parse failed), `Translation_suspect` (parsed, back-check disagrees), `Unknown` (checked, engine returned unknown). No external solver in v1 — `Outside_fragment` is terminal. Stub `router/escalate.ml` documenting the future Prolog/Z3 hook.
Paper framing found 2026-08-01, worth building toward: fragment membership as *works* vs *does not run* — on 294,469 SNOMED concepts, ELK 6.2 s, FaCT++ 408.9 s, HermiT timed out at 30 min, Pellet ran out of memory (ORE 2012).
Accept: unit tests cover all five outcomes with mocked components.

*5.2 Pin the anaphora resolution policy.* ✅ DONE (2026-08-02 — `test/test_anaphora.ml`, 18 checks; `docs/engine-surface.md`, "The anaphora resolution policy") — **a live correctness question about existing code, and it ran first in this phase.**
**The answer is a third option neither this step nor the literature note anticipated: the engine implements *no* anaphora resolution at all.** A primed name is a constant. `Boy′` denotes one individual and is related to nothing — not to `Boy`, not to any antecedent, not by proximity and not by co-indexing; the prime only makes the atom a *fixed reference*, exactly as `*` does for a singular, and in the 1.10 semantics it is assigned one domain element. Two independent proofs that nothing is being resolved: `±Boy′+Boy` ("that boy is a boy") is **not** valid and has a one-element countermodel, and `pronominalize` records an explicit `±T′+T` anchor for every witness it introduces — nothing would need anchoring if the reference resolved itself. That function is Skolemization for indirect proof and runs in the opposite direction from anaphora resolution.
**Not a stop-and-report** (GA would have been), but the paper's justification changes: we are strictly *below* both RA and GA rather than between them, because the ingredient Thm 16's tiling encoding needs — a pronoun co-varying with a quantified antecedent — is inexpressible. **The paper must say "our fragment has no anaphora", never "we implement restricted anaphora"**, which would claim Thm 15's NEXPTIME expressiveness we do not have. The same fact is a coverage cost from the other side: Pratt-Hartmann's witness sentence cannot be translated at all, so 4.6 should expect back-references among the `Outside_fragment` reasons and they belong in the limitations.
Every negative in the test is carried by an **exhibited countermodel**, not an engine verdict: outside the categorical fragment the engine answers `Unknown` where the truth is "invalid", so a verdict could never establish one. That `Unknown` is itself pinned, so the incompleteness cannot quietly become a verdict.
**Kept explicitly against a proposal to drop it (2026-08-02), because it protects a headline claim for the cost of one session.** The paper's stated differentiator (§"What the paper actually claims") is that *our fragment is decidable where ACE is not*. If our pronominalization implements general anaphora, that sentence is **false** — and the router claim's whole substrate, "TFL is a small decidable fragment so parse failure is a meaningful signal", goes with it. Read the code, name the policy, pin it, document it. Cheapest insurance in the plan.
`expressiveness-literature.md` §1.3: `Sat(TV+Rel+RA)` (restricted anaphora — every pronoun bound to its *closest* permissible antecedent) is NEXPTIME-complete; `Sat(TV+Rel+GA)` (general anaphora) is **undecidable**, by a tiling encoding in six sentences. Our engine has pronominalization and **nobody has checked which policy it implements.** Read the code, determine the policy, pin it with a test, document it in `docs/engine-surface.md`. Adjacent reading: Purdy, "A Variable-Free Logic for Anaphora," DOI 10.1007/978-94-011-1152-2_3, 1994.
Accept: the policy is named, tested, and documented; if it is GA, that is a stop-and-report to Kyle.

*5.3 Audit the TFL⁺ numerical layer.* — **the one place the engine may be unsound.**
Pratt-Hartmann 2008 demonstrates the incompleteness of previously published proof systems for the numerically definite syllogistic; 2009 and 2013 prove no finite syllogistic rule set can be complete there. Our layer descends from that lineage and **we have already independently hit one such error** — the Murphree condition-(iii) correction in port-spec §12. `Sat(Syl+Num)` is only NP-complete, so the principled route is to decide it algorithmically (Presburger-style integer reasoning) rather than search for rules that provably do not exist.
**Kept 2026-08-02** on the correctness bar alone: this is possible unsoundness in code that already ships, independent of anything it used to gate (6.3 is now cut, so this no longer blocks anything — it stands on its own).
Accept: `numerical_decision` checked against Pratt-Hartmann's results; either confirmed sound on our fragment or the gap is characterised and reported to Kyle before any change.

**5.3 first pass — 2026-08-02. Gap found and characterised; NOTHING CHANGED, awaiting Kyle's decision, because the fix is a verdict-semantics change.**

**The defect: the numerical path returns a wrong verdict, not a missing one.** `decide.ml` routes any nonzero level to `numerical_decision` and then does `verdict = (if d.n_valid then Valid else Invalid)` — **it never returns `Unknown`.** So every inference the three additive conditions cannot derive is positively asserted to be invalid. Pratt-Hartmann 2009/2013 prove no finite syllogistic rule set is complete for the numerically definite syllogistic, so such inferences are guaranteed to exist; here the incompleteness surfaces as a **false `Invalid`** rather than as a safe abstention. Everywhere else in the engine that boundary is respected — `Unknown ≠ Invalid` is documented in the 3.1 interface precisely because derivation search is incomplete.

**Witness, verified against the engine:**

> `+S^2+P` ("most S are P") and `+S^2+Q` ("most S are Q") ⊢ `+P+Q` ("some P is Q") — **engine says `Invalid`, method `numerical`.**

It is valid on the repo's own stated reading of level 2 (`^2` = most; port-spec §5, `paper_cases.ml` §G). Two strict majorities of the same set must intersect: |S∩P| + |S∩Q| > |S| gives |S∩P∩Q| > 0 by inclusion–exclusion. The empty-domain case is safe rather than an existential-import trap — if |S| = 0 then `+S^2+P` is false and the argument is vacuously valid. Condition (ii) is what rejects it: two particular premises against one particular conclusion, and the overlap inference is exactly the shape an additive rule set cannot see.

**No false `Valid` found.** Probes over the monotone shapes (universal-with-most, most-with-negative-predicate, most-descends-to-some) and the genuinely invalid controls (most does not convert; most is not transitive; two "many" sets need not meet) all came back correct. The evidence so far says Valid verdicts are sound and the whole gap is in the `Invalid` direction — which is still a wrong verdict by this project's bar.

**Why nothing caught it, and this is the more important half.** (a) **The semantic oracle does not model levels at all** — `test/semantics.ml`: *"Quantity levels (TFL⁺) are ignored, exactly as the JS oracle ignores them — the intermediate quantifiers have no semantics here"*, and `test_oracle.ml` never mentions a level. So the six fuzz suites give the numerical layer **zero** coverage. (b) **The differential gate cannot help by construction**: the frozen JS reference implements the *same* rule, so both engines agree on the wrong answer. Two independent implementations agreeing on 884k inputs is strong evidence about the *port* and no evidence at all about a rule they share. The only thing that ever checked this layer against meaning is five hand-verified paper cases.

**The options, for Kyle.**
- **(a) Cheap and safe:** numerical non-derivability returns `Unknown` instead of `Invalid`. Honest, matches the rest of the engine, and costs the layer its ability to assert invalidity at all — it would certify Valid only. A verdict-semantics change, so it needs an explicit decision and the full gate.
- **(b) The principled route this step already names:** decide it algorithmically. `Sat(Syl+Num)` is only NP-complete, so integer/Presburger reasoning gives real Valid *and* Invalid instead of searching for rules that provably do not exist. A real build.
- **(c) Document and leave it.** Not acceptable under the correctness bar as written.
**Recommendation: (a) now, (b) only if the numerical fragment turns out to matter to the paper** — 4.6 will show whether "most/many/few" appear in real regulatory text at all.
**Owed either way, and cheap: a semantics for level 2.** Strict majority is unambiguous, so the fuzz suites can cover `^2` even if `^1` and `^3` stay unmodelled for want of a threshold. That is the first thing that would have caught this.

---

## Phase 6 — TFL-native capabilities (the "impact *with* TFL" phase)

Everything here is pure term logic, adds no new formalism, and is available *because* the logic is algebraic. Prioritised above the defeasible layer on Kyle's clarification (2026-08-01) that the goal is impact **with TFL as the vehicle**, not impact generally — and after the 2026-08-02 amendment the defeasible layer is deferred outright, so this phase is where the project's own contributions live. 6.1 is the paper's; 6.2 is the tool's; 6.3 is cut.

*6.1 Missing-premise suggestion — enthymeme completion.* — **a novel contribution, and genuinely a build. Corrected 2026-08-02: it is not a port, and the algebra is not plain subtraction.**
TFL's first validity condition is an equation over a free abelian group on signed terms, so the missing premise of an incomplete argument is `C − ΣPᵢ`, with the particular-count and level conditions as side constraints. **No publication states this** (lit sweep 4, Q3): Mozes 1989 lists "suggest missing rules" as a feature and is silent on method; two Castro-Manzano papers restate the idea and specify only the trigger.
**Two corrections that change what this step costs and how it may be claimed.**
1. **The reference engine's version is not the novel one.** `engine/tfl.js:1863` (`suggestMissingPremise`) delegates to `tacitCandidates` at `:1909`, which is bounded **brute force**: collect the argument's atomic term names (bail out above 8), enumerate every two-term proposition over them, and keep the candidates that are not already entailed, keep the base consistent, and make the query follow. That is guess-and-check, and guess-and-check *is* what abduction has always been — abductive logic programming, Poole's Theorist, ILP. Porting it is cheap and buys **zero novelty**. The closed-form version is implemented nowhere, including here.
2. **"Subtraction" understates the problem.** The engine's own statement of P/Z (`tfl.js:389–396`) is that a set is inconsistent iff some way of resolving the wilds **and re-using universal premises** leaves exactly one particular and an algebraic sum of zero. Re-use means unknown multiplicities: you are solving a small integer equation with unknown coefficients under two side conditions, not doing arithmetic. The reference's own comment already knows it — *"in an isolated argument the algebra pins it down uniquely; in a fact base several rules may bridge the gap."*
**How the claim must be worded.** "Computed in closed form where others must search." **Never "there is no FOL counterpart"** — FOL does this by search, and a reviewer who knows abductive logic programming would kill that sentence in one line. Lit sweep 3's own phrasing ("description logics need *separate abduction*") concedes abduction exists. What survives, and is worth the paper: OWL justifications explain *why yes* and cannot explain *why not*, and **"why was I not found eligible?" is the primary question in eligibility determination** — and our answer comes back rendered in English by machinery we already have (which is why 5.0 precedes this).
Accept: the closed-form computation implemented for the categorical fragment, with its multiplicity handling stated and tested; returns `None` (never a guess) outside it; suggestions verified by re-running the completed argument to `Valid`; rendered in English; property test over generated arguments; a documented comparison against the reference's search on the cases where both apply.

*6.2 Definitions layer.* — **kept 2026-08-02 as a *tool* feature; cut from the paper.**
The programs/queries layer (`parse_program`, `query_prop`, `check_program_consistency`) was ported in 1.7 and **nothing calls it**. A legal definitions section — *"'Qualified Person' means…"* — is a symbol table, and asking whether an entity falls under a defined term is exactly `query_prop`. This is also the natural home for **use case (b)**: auditing whether a rule set is self-consistent, which the engine already decides. Load programs only through `Safe.parse_program` (3.1).
It has no novelty and contributes nothing to the paper — but Kyle's stated first priority is a genuinely useful open-source tool, and this is the difference between "a program that checks arguments" and "a program you can point at a policy document." The code exists; this step is wiring and a worked example.
Accept: a worked definitions example end to end; an inconsistent rule set detected with a readable trace.

*6.3 Murphree numerical term logic.* — ~~blocked behind 5.3~~ **CUT 2026-08-02.**
Murphree, *NDJFL* 39(3):346–362, 1998 — exact-*n*, fractional, and numerically quantified relational complexes; a strict superset of our TFL⁺ levels, ranked the highest-value unimplemented capability by lit sweep 4. **Cut for two reasons.** It is blocked behind the open soundness question in the layer it extends (5.3), and it is a *capability*, not a contribution — it makes the fragment **wider**, which runs directly against this project's own thesis that "the narrowness is the product" (`scope-and-predictions.md` §3): a wider fragment means parse failure carries less information, which weakens the router claim. Recorded, not scheduled.

---

## Phase 7 — Defeasible layer — **DEFERRED 2026-08-02. Not scheduled. Do not start.**

**Why.** It is not novel and it is someone else's ground: Horner, Mateis, Governatori & Ciabattoni (arXiv:2506.08899) — *the formalism's own authors* — published LLM formalization of real regulatory text into defeasible deontic logic a year ahead of us, and the prior-art note below already conceded "this layer is not novel." It buys **coverage, not novelty**, and the coverage is occupied territory. Step 8.3 (DeonticBench) exists specifically to evaluate this layer, so it is deferred alongside — one decision, not two.

**The trigger this was originally given, and why it is withdrawn.** The proposed condition was "build it only if real-text coverage is so low we lack in-fragment material for the Phase 9 study." That will not fire: the study needs roughly 40 items and 4.5b alone already supplies 91 authored sentences. Coverage starvation is not a realistic Phase 9 risk, and leaving that trigger in place would keep a settled decision open.

**What to watch instead, from 4.6's refusal-reason distribution.** §1B.1 predicts the dominant refusal reasons will be **multi-clause structure and cross-reference** — regulation packing three conditions into one sentence and referring to other sections by number — *not* defeasibility. If that is what comes back, the cheap coverage lever is **splitting long sentences into short ones before translation**, which is nowhere in this plan and costs a fraction of a defeasible engine. **That** is the conditional build worth pre-authorizing; add it as a step if 4.6 supports it. Phase 7 reopens only if 4.6 shows defeasibility dominating the refusals *and* a reason emerges to prefer our substrate over the incumbents'.

**Everything below is retained as research notes for that unlikely reopening, not as scheduled work.**

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

## Phase 8 — Evaluation data — **trimmed 2026-08-02 to policybench + the syllogism set**

Reshaped by the 2026-08-01 sweeps: the original ProofWriter/FOLIO/LogicBench set is FOL-shaped academic data with no exceptions, deadlines, or norms. It becomes a **narrow baseline for the term-logic core**, not the centrepiece.

**The 2026-08-02 trim, and what survives it.** Keep **8.1/8.2 (policybench)**, **8.5 (the syllogism set)** and enough of **8.6/8.7** to run them. Cut **8.3 (DeonticBench)** — it exists to evaluate the deferred Phase 7 — **8.4 (the legal-benchmark pick)**, and the broad accuracy sweep across many datasets. That sweep is the most occupied ground in the project: an entire ACL shared task plus a deployed AWS service already do "LLM → symbolic → deterministic validator", and we lose that comparison.

**Two consequences, both to be stated rather than absorbed.** (a) Block A §1.5 and Block B §1B.6 become unmeasurable — recorded as *not run* in the scorecard, never deleted. (b) Block A §1.6 (selective accuracy ≥98%) **survives**: policybench alone still yields the (coverage, accuracy-given-coverage) pair, which is the headline selective-trust number.

**Correction to why the syllogism set is kept.** It was retained as "the clearest predicted win" (§1.2, belief bias). It is not: belief bias — judging an argument by whether the conclusion sounds true rather than whether it follows — is *precisely* SemEval-2026 Task 11's subject ("Disentangling Content and Formal Reasoning in Large Language Models"), with dozens of published systems. It is the **most crowded** ground left, not our best result. **Keep it anyway for a different reason: after this trim it is the only public benchmark left in the plan**, and a reviewer will ask how we compare to the existing systems. Present it as a calibration check that the engine performs competently on measured ground — not as a headline.

*8.1 Policybench — authoring batch 1.* 35 policy/eligibility items with premises, conclusion, gold label, and in/out-of-fragment tag; ~70% in-fragment. Every in-fragment item's intended TFL machine-verified before presenting. Now also tagged for **defeasibility** (does it need an exception rule?), since that is what Phase 7 is evaluated on.
Accept: Kyle signs off batch 1.

*8.2 Policybench — batch 2, freeze, run.* 35 more, no structural duplicates; sign-off; freeze; run baseline + pipeline under the cost ceiling.
Accept: sign-off; results written.

*8.3 DeonticBench.* — **CUT 2026-08-02**, with the Phase 7 deferral it exists to evaluate. (arXiv:2604.04443, 6,232 tasks with reference Prolog per instance. Recorded so it is findable if Phase 7 ever reopens; also still worth *citing* in related work, since it pre-empts any claim to be the first benchmark pairing rule text with symbolic targets.)

*8.4 Legal NLP benchmarks — pick one.* — **CUT 2026-08-02.** Part of the broad accuracy sweep this amendment drops. (Candidates were LegalBench, CUAD, LexGLUE, SARA.)

*8.5 Syllogism set — NeuBAROCO or kin.* **Kept — as the project's only remaining public benchmark and external comparability point**, not as the headline win; see the phase header for the correction. Bias annotations still enable the belief-bias cut (`scope-and-predictions.md` §1.2).
Accept: loader test green.

*8.6 Baseline and pipeline runners.* Direct LLM answering vs the pipeline, per model per set, all calls cached, `--limit`, hard cost ceiling from config (**built in 4.9**: `Config.cost_ceiling_usd`, enforced in `Llm_client.complete`; runners print it up front and report spend at the end). The 4.3 cache already enforces never re-spending on an identical call.
Accept: 20-item slice ×3 models; per-item records in `data/results/`.

*8.7 Full runs.* Policybench → syllogism set. Spend checked and logged before each.
Accept (each): complete for that dataset × 3 models; spend logged.

---

## Phase 9 — The auditability study

**This is the paper's contribution.** Sweeps 1 and 2 agree on the gap and three independent groups name it in print:

- **Fuchs (CNL 2018)**, author of Attempto Controlled English, designs exactly this experiment and writes: *"For lack of resources I did not do the experiment."*
- **Vernie & Grabmair (2026, arXiv:2605.25186)** cite non-expert accessibility as *"a recognized concern in adjacent fields"* — their own reviewer is "a legal expert" and their human never sees the formal object.
- **Alrabbaa et al. (RuleML+RR 2022)** measured laypeople on logic proofs at **2.36/12**, establishing that logic-based ≠ comprehensible.

And it is unoccupied for a structural reason: verbalization systems generate *from* an ontology, so there is no original English source to audit a formalization *against*. The task only becomes meaningful once a machine translates from free English — the LLM setting, which did not exist when that field was built.

**Blocked on 5.0.** The rendering *is* the audit surface, and two of its readings are provably wrong; running this first would measure our renderer bug rather than the idea.

**The task, stated concretely so the design is unambiguous.** The participant is shown two things side by side and **never sees TFL at all**:

> **Original:** No non-member is eligible.
> **System's reading:** every non-member is eligible
> *Do these say the same thing?*  ☐ Yes ☐ No

The pipeline behind that item is: source sentence → LLM → `−(−Member)+Eligible` → our renderer → "every non-member is eligible". The correct answer is **No**; the model flipped the quality sign and the renderer faithfully read the wrong formula back, which is how the error becomes visible to someone who cannot read the notation.

*9.1 Study design.* Non-experts judge whether a rendered reading matches a source sentence, against ground truth, on a balanced set of roughly 30 items — half faithful, half not. Pre-register the design and the hypothesis before running. Methodological ancestor: Kuhn's ontograph experiments (n=64; ACE 91.4% vs Manchester-like 86.3%) — but that task is statement-vs-depicted-situation, and ours is formalization-vs-source-sentence.

**Item sourcing — the design's weakest joint, settled 2026-08-02 (Kyle).** The faithful half is easy: 88 correct translations already exist. The unfaithful half is the problem — **the entire 4.5b study produced exactly two** meaning-changing errors (`c02`/`c06`, and they are the same error twice). Decision: **real errors first, hand-made items only to fill the gap, every item labelled which kind it is, and the two categories reported separately** so anyone can see whether participants did worse on the manufactured ones. The real half comes from the 4.6 real-text run, which is expected to be messier than authored sentences and is being run anyway — hence 4.6 must **collect and keep** every genuine error it produces. Hand-made items are correct formulas deliberately broken (sign flip, term swap, quantity change), which also allows difficulty to be varied on purpose. **The mix is fixed and written down before the first participant sees anything** — choosing it after seeing how people scored is what would invalidate the result.

**The FOL control arm (moved here from 4.7).** One group audits our English rendering against the source; another audits a **raw FOL formula** against the same source. This is the comparison that actually supports core claim 1's auditability half, and it is the position lit sweep 1 §14 names as unoccupied. Optionally a third arm of verbalized description logic, to meet the Power & Third contrast head-on.

*9.2 Pilot — ~10 friends and colleagues, labelled a pilot before it runs.* — **Kyle's decision, 2026-08-02.**
**What it buys:** whether the task is coherent at all — do people understand what is being asked, does the English read as intelligible, is the item count right, are the items too easy or impossible. Nearly every way a design fails, ten people expose.
**What it cannot buy, and must not be reported as if it does:** a defensible number. At n≈10, anything from roughly 55% to 90% accuracy is consistent with the same underlying truth. And friends and colleagues are not non-experts *about this project* — they read charitably and may guess the hoped-for answer. Fine for testing the instrument, not for measuring the population.
**The condition:** it is called a pilot in the plan and in the paper **before** it runs. A pilot may freely change the design on what it learns; an unlabelled run that produces an encouraging number and *then* gets scaled up is contaminated, and a reviewer will say so.
Accept: design and pre-registration written; Kyle approves before any participant sees anything; pilot run and reported as a pilot.

*9.3 Panel run — decided after the pilot.* A paid crowd panel (n≈60) is the version where a negative result is still publishable, and this study is now the paper's centrepiece. Recommended, and deferred to Kyle's call once the pilot has shaped the instrument. Note for the write-up: independent work without IRB review is standard for this venue class, but the consent text and the absence of institutional review should be stated rather than omitted.
Accept: results reported as measured, including a null result.

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

**What the paper actually claims:** in the LLM-formalization setting there is, for the first time, an original source sentence to audit a machine's formalization *against*; TFL preserves that sentence's structure where controlled English reintroduces variables (ACE's robust paraphrase shatters one sentence into several and emits `X1 X2 X3`; its structure-preserving mode is documented "experimental"); the fragment is decidable where ACE is not (Fuchs, CNL 2010 §6: *"This means that ACE is undecidable"* — **condition discharged by 5.2, with a correction: say "our fragment has no anaphora", never "restricted anaphora", which would claim a NEXPTIME expressiveness we do not have**); the algebra yields the missing premise in closed form where others must search; and fragment membership is a mechanical abstention signal nobody else has.

**Two further framings retired 2026-08-02, added to the dead list above.**
- ~~"the back-translation round trip is ours"~~ — Amrollahi, Lopez & Barrett (arXiv:2604.25031, 2026) formalize → back-translate → re-formalize → check equivalence, on Texas statutes. **The mechanism is occupied.** Our claim is the *conjunction*: a **deterministic** verbalizer rather than a second language model (Vernie & Grabmair flag their own LLM verbalization as an unverified artifact inside the audit path), **shown to a person** (Phase 9). Never "FOL structurally cannot do this."
- ~~"missing-premise suggestion has no FOL counterpart"~~ — FOL does it by search; that is what abduction is (abductive logic programming, Poole's Theorist, ILP). The claim is **closed form versus search**, plus the fact that it answers "why was I *not* found eligible", which OWL justifications cannot.

*11.1 Skeleton + background.* TFL primer with a worked engine trace; related work from `docs/related-work-notes.md` **and** `docs/lit-sweep-2026-08-01/`. Must-cite and differentiate: Vernie & Grabmair 2026, Amrollahi/Lopez/Barrett 2026 (roundtrip verification — difference: their back-translation is machine-consumed, never shown to a person), Lorenzo et al. NLLP 2025 (NL→Catala, surface metrics only), Horner et al. 2025, Blawx, Catala, OpenFisca.
Strongest supporting citation, to sit in the motivation: **López & Hildebrandt (arXiv:2410.10906)**, systematic review of 46 studies — **89.13% of works treat regulatory formalization as manual effort; only 13.4% report operational deployment**; section titled *"Where are the lawyers?"*
Accept: sections complete; Kyle reviews the primer.

*11.2 Method + experiments.* Architecture, the differential-verified port as an engineering-soundness note, then experiments.
Accept: numerically consistent with `analysis/report.md`.

*11.3 Intro, abstract, limitations.* Limitations explicitly: fragment narrowness and measured coverage; `Unknown` on relational search misses; **the authored-vs-real-text ceiling on 4.5b**; single-notation dependence; no treatment of definite descriptions anywhere in the tradition (lit sweep 4, Q2) so ours is an engineering convention; no treatment of adverbial modification at all; and the finding that cuts against us — **the systems with real production footprints use the least expressive formalisms**, while the richest logics have the weakest deployment records.
Accept: complete draft; Kyle full pass.

*11.4 Python client.* — **the CLI half moves earlier (2026-08-02): build `bin/tfl_cli.ml` before the real-text run and the missing-premise work, both of which want it anyway.** The pip packaging stays here.
Pip-installable `tflverify` wrapping the compiled binary via a JSON-over-stdio CLI (`bin/tfl_cli.ml`). Land the two hardening items the 2026-08-01 audit deferred here — cap the atom union in `decide_equivalence` (currently up to 2³² assignments; a ~160-byte input costs ~33 minutes), and single-pass decoding so `Safe.parse` reuses its tokens (20 MB in → 1.38 GB peak heap). Both are inherited from the frozen reference; each lands as a documented deviation with the full engine gate.
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
- Cost ceiling enforced in code (built 4.9, `Config.cost_ceiling_usd`), spend reported after every run.
- After 1.12: OCaml engine changes require test suite + 20k oracle + paper-cases green before commit; verdict semantics never change silently. Before 1.12: every port step ends differential-clean against the JS reference.
- The JS reference engine is frozen — never extended, never edited, only consulted. **Its authority is split (2026-08-02): authoritative on verdicts forever; no authority whatsoever over English rendering.** Rendering deviations exempt only the constructions actually changed, and the exempted count is reported so it cannot silently grow.
- **Renderer changes are verdict-safe by construction** and are not blocked by the frozen-reference rule — English readings decide nothing. Every verdict gate must still be green.
- Any deviation from this plan gets logged in LOG.md with a one-line rationale.
- When results contradict the core claims, report them as-is. Negative results go in the paper's limitations, not in the trash.
- **After the 2026-08-01 sweeps:** any citation not sourced from *extracted primary text* is unverified until it is. Four of six sweeps independently caught the PDF summariser fabricating content, one of them from undecodable binary noise; that is the documented origin of the inverted Ross's-paradox claim in `expressiveness-literature.md`.
- **Pre-registered predictions are frozen, never edited.** `scope-and-predictions.md` §1 stands verbatim as the pre-redirect block; new predictions go in a new dated block. The 4.5b threshold (≥70%) is already recorded as wrong.
- **Prompt patching buys coverage; the back-check buys correctness.** Never rely on a prompt for soundness — a patch only ever fixes the error already found.
- Dev/eval split (4.8) precedes any prompt tuning. Once an item reveals an error we act on, it is no longer evaluation data.
