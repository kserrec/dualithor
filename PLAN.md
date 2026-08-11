# Horos: Project Plan

## Active decision — 2026-08-08

Build a complete, usable logic programming language based on term logic (TFL), using the
existing OCaml engine as the verified starting kernel.

This plan completely replaces the former regulatory-verification and human-study plans.
Those projects are discontinued. Their code, datasets, reports, and negative results stay in
the repository as historical evidence, but no old phase is active and `$next` must never
select work from an old roadmap. Git history preserves the superseded plan.

The project is now named **Horos**, and its repository and package are named **`horos`**.
The language is called **TFL** and its eventual human-facing executable is **`tfl`**.

Phases 1 through 5 are complete. Phase 6 is the next implementation phase.

### Maintenance phase — 2026-08-11 correctness repairs ✅ COMPLETE

This named maintenance phase is an explicit exception to roadmap order, approved after the
2026-08-11 whole-codebase bug hunt. It repairs three verified defects without selecting a
phase from either discontinued roadmap:

1. Bound inference candidate-generation work deterministically and return the existing
   public `resource_limit` failure when that budget is exhausted. Preserve every ordinary
   verdict and proof that completes inside the budget, and prove the request/reply process
   remains usable after a refusal.
2. Correct the reversed regulatory sentence splitter, pin document order with focused
   tests, preserve the original flawed samples and reports as historical evidence, and add
   a dated correction protocol with freshly generated samples and an explicit erratum.
3. Prevent the fidelity scorer's abbreviation matcher from treating unrelated words as
   the same root, including the verified `Cat`/`Educated` converse trap.
4. Run the focused suites, forced full suite, 20,000-case OCaml oracle gate, and
   884,000-input differential gate; keep Phase 6 as the next feature phase.

**Acceptance:** pathological valid queries return a classified limit refusal within the
public latency gate and a following request succeeds; corrected samples follow source
document order without replacing the old evidence; the adversarial converse scores wrong;
all required verification is green.

**Delivered:** non-atomic inference now shares a deterministic 8,000,000-term-node work
budget across the four searches for one argument and maps exhaustion to the existing public
`resource_limit` failure; focused API, runtime, and long-lived JSON-lines regressions prove
the refusal is prompt and non-poisoning. The live eCFR splitter now preserves source order,
the explicit `--legacy` path reproduces both frozen flawed samples byte for byte, and dated
unlabeled corrected samples, a post-discovery correction protocol, and an erratum preserve
the historical record without reporting replacement percentages. The fidelity scorer no
longer accepts arbitrary subsequences as roots, and the `Cat`/`Educated` converse is pinned
as wrong. The forced full repository suite passed; all six oracle suites passed at 20,000
iterations each (including 85,731 checked rule steps, 1,805 relational proofs, and 3,912
indirect refutations), and the 884,000-input differential gate passed all 18 comparisons
with zero unexpected divergence. Phase 6 remains the next feature phase.

## What we are building

TFL will be a proof-producing logic programming language in which a program states facts,
classifications, exclusions, relations, and general rules, and a user asks what follows.
The system will answer with both a result and the reasoning that supports it.

The language will retain the feature that makes term logic different from a generic Horn-
clause language: predicates and propositions can themselves occupy term positions, and
ordinary universal classifications already do the work normally split between “facts” and
“rules.” For example, a statement that every man is mortal is both knowledge and an
executable inference rule; it does not need to be translated into a separate implication
syntax before the runtime can use it.

“Full language” means that a user can eventually:

- install one package and run one `tfl` command;
- write and import `.tfl` source files;
- use an interactive read-evaluate-print loop;
- ask ground questions and questions containing answer variables;
- work with classifications, explicit exclusions, singular objects, and multi-place
  relations;
- state and infer published numerical quantities, including at-least, at-most, all-but,
  exact, comparative, and fractional quantities where the selected numerical profile
  defines them;
- express published de re and de dicto necessity and possibility without mislabeling
  alethic modality as obligation, permission, or time;
- select an explicit TFL profile for assertoric, numerical, modal, relevance-sensitive,
  free-term, or supported synthetic reasoning rather than having extensions silently alter
  one another;
- define reusable derived rules and use recursion where its semantics are well-defined;
- receive an honest `true`, `false`, `both`, or `unknown` result rather than having lack of
  proof silently treated as falsity;
- inspect a machine-checkable proof, a plain-English reading, and the source of every
  supporting statement;
- diagnose contradictions and incomplete searches;
- embed the runtime through stable OCaml and JSON interfaces;
- format, test, debug, package, and document real TFL programs with ordinary language
  tooling.

This is a product and language-engineering project. A paper is not a deliverable. Whether
TFL proves uniquely useful in practice remains an open empirical question, and this plan
includes concrete comparative applications so that the project does not manufacture an
answer.

## Semantic commitments

These rules govern every phase.

1. **TFL remains the core calculus.** Existing TFL propositions and published inference
   rules are not silently reinterpreted to imitate Prolog, Datalog, first-order logic, or a
   description logic.
2. **Extensions identify themselves.** Every new construct is classified as one of:
   core TFL syntax, a conservative logical extension, query-only syntax, or a host/runtime
   feature. Proofs record which layer supplied each step.
3. **Open-world reasoning is the default.** Failure to prove a proposition does not make
   the proposition false. Explicit negative information is different from absence of
   positive information.
4. **Contradictions are visible.** If both a proposition and its contradictory are
   supported, the public result must not hide one. The language will either report `both`
   or refuse execution under a precisely documented consistency policy; Phase 25 fixes the
   final contract.
5. **`Unknown` is never advertised as a decision.** A bounded or incomplete search reports
   why it did not decide. Numerical and relational incompleteness stay explicit until a
   complete procedure actually exists.
6. **Every answer can carry provenance.** Derived results retain source location, rule,
   parents, and the exact formal proposition. English explanations supplement that formal
   record; they never replace it.
7. **No usefulness claims by intuition.** Claims about readability, concision,
   explainability, performance, or practical advantage require concrete comparisons in
   Phase 37.
8. **Published systems are implemented as named systems.** Murphree Numerical Term Logic,
   Szabolcsi Numerical Term Logic, Peterson's intermediate quantities, Englebretsen modal
   TFL, free-term TFL, relevance TFL, and their published combinations are not flattened
   into one undocumented dialect. Source, profile, and rule identity remain visible.
9. **Power cannot outrun verification.** A construct enters the stable language only when
   its syntax, consequence relation, proof procedure, interaction boundaries, and known
   completeness limits are fixed against primary sources and independent tests. Merely
   finding a paper or being able to parse notation is not implementation.

Negation-as-failure and an implicit closed-world mode are not part of version 1. They can be
considered after version 1 only as an explicitly marked, stratified extension. This avoids
turning “not currently known” into “known not to be true” inside a language whose central
contract is open-world reasoning.

## Published extension target and reasonable boundary

The stable language target is the strongest source-grounded member of the Sommers-
Englebretsen TFL family that can be implemented and tested honestly. “As powerful as
reasonably possible” therefore means implementing mature published calculi and their
documented combinations, not accumulating unrelated operators under the TFL name.

The required extension baseline is:

- **Numerical TFL:** Wallace Murphree's 1998 Numerical Term Logic and its later tableaux,
  including at-least, at-most, all-but, derived exact quantities, and numerical relational
  complexes. Lorne Szabolcsi's numerical system and Peterson's five-quantity,
  comparative, and fractional work are separate profiles wherever their rules differ.
- **Modal TFL:** Englebretsen's 1988 modal term logic and the 2020 tableaux treatment,
  including de re and de dicto necessity and possibility. This is alethic modality; a
  deontic or temporal reading requires a separately justified logic and is not implied.
- **Relevance TFL:** the 2022/2024 relevance-sensitive tableaux that distinguish ordinary
  TFL validity from the stronger requirement that every premise genuinely contribute.
- **Synthetic TFL:** Castro-Manzano's 2023 profile lattice combining assertoric (`alpha`),
  Murphree-numerical (`nu`), modal (`mu`), and relevance (`rho`) TFL, up through the
  published top system `TFLανμρ`, exposed under the ASCII profile name
  `tfl-alpha-nu-mu-rho`. Each component and smaller combination remains independently
  selectable and testable.
- **Free and empty-term TFL:** the published 2020/2023 treatments of possibly empty or
  non-denoting terms, with existential-import policy explicit rather than accidental.
- **Full published term operations:** source-verified compound-term operations, identity,
  relational passives, associative shift, polyadic simplification, and arbitrary published
  relation arities.
- **Current natural-logic bridge:** the 2026 tableaux translation of Moss's decidable
  natural-logic hierarchy into Sommers TFL, implemented as a compatibility/conformance
  profile rather than falsely presented as newly invented core syntax.

Statistical/probabilistic syllogistic, inductive or abductive tableaux, defeasibility,
deontic logic, temporal logic, mass terms, and cross-sentence anaphora remain candidates,
not version-1 promises. The present literature supplies only a fragment, a preliminary
proposal, a conference abstract, or a different logical family for at least one essential
part of each. Phase 6 applies a written admission test and the release phase repeats the
literature search; any candidate that by then has a precise source semantics, proof method,
and credible validation plan must either receive its own phase or be named explicitly as
post-version-1 work. Nothing is silently called supported.

## Starting point

The repository already contains considerably more than a parser experiment:

- a Unicode and ASCII-compatible parser, canonical printer, and abstract syntax tree;
- categorical, relational, propositional-term, and TFL+ intermediate-quantity
  representations;
- direct, indirect, relational, limited intermediate-quantity, and consistency inference;
- multi-line programs with comments and per-line parse errors;
- ground proposition queries returning yes, no, or unknown;
- “what is this term?” classification queries;
- equivalence queries and proof/certificate data;
- deterministic English readings;
- a total guarded API and a JSON-lines process boundary;
- differential agreement with the frozen JavaScript reference over 884,000 generated
  inputs, finite-model oracle tests for the categorical core, literature cases, and
  adversarial-input tests.

That is the language kernel, not yet a complete language product. Important missing pieces
include a public program runtime, `.tfl` file execution, a human command line, a REPL,
answer variables, full Numerical Term Logic, modal and relevance profiles, free-term
semantics, the published synthetic profile family, a defined user-rule layer, recursion,
modules, source-level diagnostics, incremental evaluation, a debugger, data interfaces,
editor tooling, packaging, and real application evidence.

The frozen JavaScript engine remains a regression oracle for the behavior it already
covers. New language features belong in the OCaml implementation and receive their own
semantics and tests; they are not added to the frozen reference merely to create artificial
differential agreement.

## Architecture boundary

The implementation is organized as six separable layers:

1. **Core representation:** tokens, syntax trees, canonical notation, and source spans.
2. **Compiler:** file loading, declarations, name resolution, imports, validation, and a
   compiled program independent of any user interface.
3. **TFL inference kernel:** the existing formal transformations and decision procedures.
4. **Language runtime:** query planning, answer generation, rule evaluation, recursion,
   consistency state, limits, and proof provenance.
5. **Interfaces:** the `tfl` command, REPL, stable JSON protocol, and OCaml embedding API.
6. **Tooling:** formatter, diagnostics, debugger, editor support, examples, packaging, and
   performance measurement.

Dependencies point downward. The inference kernel never imports the CLI, file system,
JSON, editor, or application layers. A user interface may display English, notation, or
both, but it cannot change a verdict.

## Execution rules

- `$next` executes exactly one phase: the first phase below that is not complete and whose
  dependencies are complete.
- Every phase is intentionally sized as one implementation pass. If it proves too large,
  split it in this document before changing code.
- A phase is complete only when its implementation, focused tests, relevant full tests,
  documentation, and acceptance check all agree.
- Changes to existing inference behavior require the 20,000-case OCaml oracle gate and the
  884,000-input differential gate in addition to the normal suite. Interface-only work
  does not rerun those long gates unless it changes engine results.
- New syntax is not accepted until its meaning, errors, canonical form, and proof behavior
  are specified.
- Existing research and translation assets are legacy inputs. Do not delete or modernize
  them unless a named phase needs them.

---

## Milestone I — Turn the kernel into a language people can run

### Phase 1 — Freeze the core language contract ✅ COMPLETE — 2026-08-09

1. Write the normative core-language reference for the syntax and semantics that already
   exist: signs, quantity levels, singulars, compounds, propositional terms, relational
   terms, programs, comments, ground queries, consistency, and equivalence.
2. Specify the exact meaning of every public result, especially valid, contradicted,
   invalid, unknown, complete, and incomplete.
3. Create a small checked conformance corpus in which each example names the language rule
   it demonstrates and its expected canonical form, reading, result, and proof shape.
4. Inventory known incompleteness and implementation limits without calling them language
   semantics.

**Acceptance:** a reader can implement the existing core from the reference without reading
the OCaml source; every normative example is executable and green; no documented result
collapses unknown into false.

**Delivered:** `docs/core-language.md` plus its corrected mechanics appendix define
contract `core-0.1`; `data/conformance/core-0.1.json` contains 26 language-neutral examples
checked by `test/test_conformance.ml`. The focused corpus and forced full suite are green.
The post-completion audit also fixed bounded public input, equivalence output/work budgets,
terminal-safe names, immutable CI actions, security-fixed compiler/crypto floors, and a
verified dependency lock without changing the next roadmap phase.

### Phase 2 — Public program runtime ✅ COMPLETE — 2026-08-09

1. Add one total production API that compiles a complete program and refuses execution if
   any source line is malformed.
2. Expose ground proposition queries, term-description queries, program consistency, and
   equivalence through that API.
3. Return canonical TFL, English readings, completeness metadata, and proof support in
   stable records rather than test-only serializers.
4. Expose the same operations through the existing JSON-lines process without breaking its
   one-request/one-response crash-isolation contract.

**Acceptance:** an external process can submit a multi-line program and perform every
already-implemented program operation without calling an internal OCaml module or
receiving an uncaught exception.

**Delivered:** `Tfl.Runtime` is the one total production API over an abstract,
all-lines-valid compiled program. Stable records expose canonical TFL, English, explicit
completeness reasons, and proof/certificate/numerical/equivalence support. The
`horos-runtime-0.1` JSON-lines commands compile, query, describe, check consistency, and
compare equivalence without breaking the existing request/reply stream. Focused runtime,
program, safety, and process-boundary tests are green. The 2026-08-10 post-completion
security audit probed the new boundary hostilely and found no defect (recorded in
SECURITY.md); the same day's test audit falsification-tested the Phase 2 suites and
strengthened the three CLI checks that mutations survived: the oversized-line drain, the
describe answers' serialized proof support, and the evidence `kind` discriminators of the
public JSON schema.

### Phase 3 — `.tfl` files and the human command line ✅ COMPLETE — 2026-08-10

1. Define UTF-8 `.tfl` files and implement file loading with stable line and column
   locations.
2. Install a `tfl` executable with human-facing commands to check a file, ask a query, ask
   what follows about a term, and render a proposition.
3. Keep structured JSON output as an explicit machine mode; human output defaults to plain
   readable text.
4. Define useful exit statuses for success, logical non-entailment, compile failure,
   incomplete search, and internal failure.

**Acceptance:** from outside the repository, a user can run a `.tfl` file, distinguish every
outcome by both text and exit status, and request the corresponding JSON record.

**Delivered:** `Tfl.Source_file` loads bounded, case-sensitive `.tfl` paths, rejects
malformed UTF-8 before compilation, and maps statements and every line-attributed failure
to one-based physical lines and Unicode code-point columns in the original source. The
installable `tfl` executable checks files, runs ground queries, describes terms, and renders
propositions with terminal text by default and explicit `tfl-cli-0.1` under `--json`. Exit
statuses distinguish success, complete logical non-entailment, input/compile failure,
incomplete search, and internal failure; incomplete contradictory support stays incomplete
rather than overclaiming non-entailment. The existing `horos` JSON-lines boundary shares
runtime serializers and remains byte-contract compatible. Focused loader, command,
runtime, program, process, and adversarial suites are green; the forced full suite and an
isolated-prefix install/query from outside the checkout are also green.

The post-delivery Phase 3 security audit found and fixed two hostile-path defects: human
output now renders terminal controls and malformed path bytes visibly, and the loader
rejects FIFOs, devices, sockets, directories, and symlinks to nonregular targets without
waiting for content. Repository guards now cover every dotenv filename variant. The
historical translation client's Lwt/Cohttp/TLS/Mirage graph is retained for tests and
manual development but filtered out of a normal Horos installation in both the generated
manifest and transitive lock.

The follow-on Phase 3 test audit used ten targeted invalid mutations to challenge those
claims. It closed every surviving gap with deterministic check/open race and descriptor
inheritance probes, loader byte-cap and exact file-semantics cases, separate standard
output/error capture, multi-diagnostic and usage matrices, full terminal-control class
coverage, explicit unexpected-exception classification, and a clean normal-install CI job
that invokes the installed public `tfl` name outside the checkout.

### Phase 4 — Interactive shell ✅ COMPLETE — 2026-08-11

1. Add a REPL that loads a program once and accepts ground queries, term queries,
   consistency checks, equivalence checks, reload, help, and quit.
2. Preserve command history when the terminal supports it without making history support a
   runtime requirement.
3. Ensure malformed input returns to the prompt without losing the loaded program.
4. Add non-interactive transcript tests for the entire session protocol.

**Acceptance:** a user can explore and reload one program through a complete session; every
REPL operation has the same semantics and data as the program API.

**Delivered:** `tfl repl FILE.tfl` loads one all-lines-valid `Tfl.Runtime.program` and
retains it across ground queries, term descriptions, consistency checks, equivalence
checks, help, reload, and quit. Reload replaces that immutable program only after the
original path loads and compiles completely; a failed reload and every malformed command
return to the prompt with the last valid program intact. Human terminals receive a
dependency-free line editor with the newest 100 commands held only in memory, terminal-safe
echo, up/down navigation, and `Ctrl-C` recovery; unsupported terminals and pipes use a
bounded plain-input fallback, and no history file is written. Optional `--json` emits the
`tfl-repl-0.1` event stream, reusing the public runtime's exact result/evidence serializers
while separating per-command outcome status from the live process status. Non-interactive
human and JSON transcript tests cover every session operation, malformed input, oversized
input draining, successful reload, failed-reload state preservation, and clean quit; the
focused command, source-loader, and runtime suites, an actual pseudo-terminal history probe,
and the full repository suite are green.

The post-delivery Phase 4 correctness review found and fixed four interactive-boundary
defects: plain terminal fallback now keeps the prompt and `Ctrl-C` recovery, wrapped edits
restore the saved prompt position before redrawing, an over-limit terminal edit can be
corrected before submission, and equivalence command delimiters are located by one
quote-aware scan rather than repeated proposition parses. Focused regressions and actual
pseudo-terminal probes cover the corrected behavior without adding a runtime dependency.

The Phase 4 security review found no presently exploitable boundary in the local command,
then closed two resource-hardening gaps: piped and JSON input is no longer retained in an
unusable history, editing history has a 16 MiB aggregate byte ceiling, Backspace truncates
the input buffer in place, and a 16 MiB per-line terminal-output budget prevents repeated
wrapped redraws from amplifying one edit into unbounded output. Crossing that display budget
discards only the current line and returns a structured resource refusal; the loaded program
and session remain intact.

The follow-on Phase 4 test audit challenged the delivery with fourteen one-at-a-time invalid
product mutations. Six existing checks failed as intended; eight survived until the suite
was strengthened. Deterministic pipe-driven editor probes now exercise the terminal scope,
saved cursor origin, actual Backspace redraw, up/down history wiring, draft restoration,
editing-only retention, display-output refusal, and physical-line draining. The JSON session
test now proves the oversized-line `resource_limit`, puts an executable-looking suffix past
the byte ceiling, and compares every runtime operation field exactly with the production
serializer. The focused test command also rebuilds the separately spawned `tfl` executable,
so a source mutation cannot pass against a stale binary. Repeating the original eight
mutations makes the repaired tests fail for the named reasons.

One unrelated suite-health debt was exposed but is not silently folded into Phase 4: across
three unchanged forced full-suite runs, the Phase 1 cancellation-cap wall-clock assertion
passed twice and failed once at 1.200 seconds while other tests were running concurrently;
five isolated unchanged `test_safe` runs all passed. That load-sensitive timing assertion
remains deferred to Phase 1 test maintenance rather than being weakened in this interface
test audit.

### Phase 5 — Source spans and compiler diagnostics ✅ COMPLETE — 2026-08-11

1. Carry file, line, column, and source span from tokens through current program entries and
   query errors. Establish the shared span contract that Phase 17 declarations must use;
   declaration syntax does not exist in the current language.
2. Report multiple independent compile errors in one run with the offending source line
   and a caret range.
3. Separate lexical, syntactic, name-resolution, outside-fragment, incomplete-search, and
   internal failures in both human and JSON forms.
4. Add malformed-file and Unicode-position regression cases.

**Acceptance:** every user-caused failure points to actionable source text; byte offsets are
never mislabeled as character columns; internal failures are never presented as bad user
input.

**Delivered:** `Tfl.Source` now defines half-open, Unicode-code-point source ranges and
line/column spans shared by notation tokens, current program entries, runtime queries,
source-file diagnostics, and verifier error records. Human diagnostics print the exact raw
source line and caret range; JSON exposes the same span, raw source, and source path while
retaining the earlier position fields for compatibility. Compilation preserves multiple
independent lexical or syntactic errors, malformed UTF-8 receives a zero-width location at
the last valid code-point boundary, and the public taxonomy distinguishes lexical,
syntactic, name-resolution, outside-fragment, incomplete-search, and internal failures.
Name-resolution is reserved for Phase 17 because no declaration syntax exists yet, and
incomplete bounded searches remain ordinary result statuses rather than fabricated input
errors. Machine boundaries visibly encode malformed bytes instead of emitting invalid UTF-8
JSON. Focused Unicode, malformed-file, multi-error, human, JSON, runtime, verifier, and
long-lived CLI regressions pass, as does the forced full repository suite including oracle,
corpus, safe-input, and differential gates. Inference verdict behavior is unchanged.

## Milestone II — Implement the published TFL extension family

### Phase 6 — Lock extension sources, semantics, and profiles

1. Build a versioned source manifest for assertoric TFL, Murphree and Szabolcsi Numerical
   Term Logic, Peterson's intermediate quantities, Englebretsen modal TFL, free-term TFL,
   relevance TFL, the 2023 synthetic system, and the 2026 Moss translation. Record exact
   editions, pages, notation, rules, corrections, and source-access gaps.
2. Write a capability matrix for every proposed profile: accepted syntax, consequence
   relation, proof procedure, completeness claim, computational boundary, and permitted
   compositions. Resolve conflicting published rules by separate profiles, never by
   silently choosing one.
3. Define how source files and APIs select a language profile, how the default core behaves,
   how proofs name every contributing profile, and how unsupported mixtures are rejected.
4. Apply a written admission test to the remaining literature candidates: a stable feature
   requires primary-source semantics, implementable proof or decision rules, an independent
   validation strategy, and a clear relationship to TFL. Add a new phase before coding any
   candidate that passes; record the concrete missing requirement for every candidate that
   does not.

**Acceptance:** another implementer can reproduce every stable profile from the pinned
sources without guessing; every conflict and claimed completeness boundary is explicit; no
extension syntax is implemented before this contract and its conformance examples agree.

### Phase 7 — Complete compound and relational TFL

1. Audit the existing compound and relational implementation against the pinned Sommers,
   Englebretsen, tableaux, and implementation sources, including relation arity, polarity,
   pairing indices, and nesting.
2. Implement every admitted compound-term operation, including disjunctive or implicational
   compounds only where Phase 6 verifies their formal rules; preserve canonical notation and
   unambiguous English readings.
3. Complete the published relational transformations: passive voice, associative shift,
   polyadic simplification, and arbitrary admitted relation arities.
4. Add source-linked conformance cases, generated round trips, valid derivations, and nearby
   invalid cases for every operation and transformation.

**Acceptance:** every Phase 6 assertoric, compound, and relational construction either
parses, prints, decides, and produces a replayable proof, or is rejected as outside the
selected profile with the exact source-bound reason; no transformation assumes an invalid
converse or changes relation orientation.

### Phase 8 — Existence, empty terms, and identity

1. Define named existential-import profiles using the published model-adaptive,
   language-adaptive, and free-term treatments; state exactly what universal propositions
   imply when a subject or predicate class is empty.
2. Implement free and empty-term syntax, validation, models, and tableaux without changing
   the existing core profile's results.
3. Implement identity as the exact source-supported TFL reduction or distinguished relation,
   keeping logical identity separate from query-variable equality and textual name equality.
4. Test denoting, non-denoting, empty-class, singular, and identity cases against independent
   finite models and published examples.

**Acceptance:** the same source program can be checked under an explicitly selected
existential-import policy with predictable differences; empty terms never manufacture
existence; identity proofs state which identity semantics they use.

### Phase 9 — Murphree Numerical Term Logic

1. Add the Murphree profile and exact source syntax for at least, at most, all but, and the
   four proposition polarities, freezing every strict/non-strict and off-by-one convention.
2. Implement derived exact quantities, numerical negation, arithmetic side conditions, and
   the published numerical tableaux with the numerical vector visible in proof objects.
3. Integrate numerical propositions with ordinary categorical and compound terms so
   universal and particular TFL are verified special cases at zero and one rather than a
   separate evaluator.
4. Reproduce the published examples and counterexamples, then check small cases against an
   independent cardinality-model oracle instead of treating agreement with our own tableau
   as validation.

**Acceptance:** the language faithfully executes Murphree Numerical Term Logic and labels
the result as that profile; all supported arithmetic is exact; the interface distinguishes
Murphree-rule validity from any stronger standard-cardinality entailment not yet decided.

### Phase 10 — Szabolcsi and Peterson quantity profiles

1. Lock the primary Szabolcsi and Peterson contracts before implementation, recording where
   their validity conditions differ from Murphree and from the existing level-based TFL+
   engine.
2. Implement separately named support for exact, comparative, fractional, proportional,
   and five-quantity propositions wherever the source supplies determinate syntax and
   inference rules.
3. Reconcile “few,” “many,” “most,” and related subjective quantities with the current
   levels without pretending that a context-sensitive quantity has an unqualified numeric
   value.
4. Add paired cases that deliberately produce different results under Murphree, Szabolcsi,
   Peterson, and legacy TFL+ profiles, with the selected rule set present in each proof.

**Acceptance:** every stable published numerical construction admitted in Phase 6 is
usable, every semantic disagreement selects a visible profile, and no result is obtained by
an undocumented blend of numerical calculi.

### Phase 11 — Complete monadic numerical decision

1. Give the supported monadic numerical fragment an independent set/cardinality semantics
   covering positive and negative predicates, empty classes, exact counts, and admitted
   proportional constraints.
2. Implement an exact decision procedure for that documented fragment, choosing an
   internal algorithm or external solver only after the dependency earns its correctness,
   security, size, and proof-certificate cost.
3. Produce checkable entailment certificates or finite countermodels and differentially
   compare the procedure with exhaustive small finite models and the profile-specific
   syllogistic calculi.
4. Measure and document complexity and resource limits; an exhausted search returns
   incomplete metadata rather than a false logical verdict.

**Acceptance:** every in-fragment monadic cardinality query is decided soundly and
completely under the documented semantics, including cases no finite collection of
syllogistic rules can cover; profile-rule validity and semantic entailment remain separately
inspectable.

### Phase 12 — Numerical relational complexes

1. Parse and represent published numerical quantifiers inside multi-place relational
   complexes, including independently quantified subjects and object positions.
2. Implement the source-supported relational transformations and inferences without moving
   a count across a relation position or modal scope illicitly.
3. Provide complete evaluation over an explicitly supplied finite kernel domain and the
   strongest sound general procedure justified by the sources; Phase 17 later exposes that
   domain through language declarations. Report the remaining relational numerical
   fragment as incomplete rather than guessing.
4. Test nested numerical relation examples, converse traps, empty positions, mixed
   quantities, and bounded-domain results against exhaustive enumeration.

**Acceptance:** published examples such as numerically quantified teachers, books, and
students are executable with proofs; every answer states whether it is generally complete,
finite-domain complete, or only sound for the attempted procedure.

### Phase 13 — Modal Term Functor Logic

1. Add Englebretsen's de dicto and de re necessity and possibility syntax, with Unicode and
   ASCII forms and canonical placement on propositions or terms.
2. Implement modal strength, the published modal validity conditions, and the later tableau
   rules with modal steps explicit in proofs.
3. Expose assertoric, modal, and permitted mixed profiles without allowing an alethic box or
   diamond to be called obligation, permission, tense, or probability.
4. Reproduce published valid and invalid modal arguments and add countermodels or an
   independent oracle for the supported fragment wherever the source semantics permits.

**Acceptance:** de re and de dicto readings remain distinct through parsing, inference,
printing, and proof replay; every modal verdict identifies its exact calculus and
completeness boundary.

### Phase 14 — Relevance Term Logic

1. Implement the published premise/conclusion flags and causal-relevance conditions on top
   of the kernel's proof provenance rather than inferring relevance from a prettified proof;
   Phase 29 later incorporates this record into the stable public proof schema.
2. Return ordinary logical validity and relevance-sensitive validity as separate named
   judgments, including which premise was unused or which relevance condition failed.
3. Cover the published exclusions of ex falso, verum ad, petitio principii, and non causa
   ut causa without changing the consequence relation of profiles that do not request
   relevance.
4. Test relevance under reordered premises, duplicate premises, multiple proofs, numerical
   reasoning, and modal reasoning.

**Acceptance:** a user can tell whether an argument is invalid, valid but irrelevant, or
valid and relevant, and can inspect the exact proof dependency that supports that answer.

### Phase 15 — Synthetic TFL profile lattice

1. Implement the published profile lattice over assertoric (`alpha`), Murphree-numerical
   (`nu`), modal (`mu`), and relevance (`rho`) TFL, including every documented
   intermediate combination and the top `TFLανμρ` system, exposed as
   `tfl-alpha-nu-mu-rho` in ASCII interfaces.
2. Compile combined propositions only when their placement of quantities, modalities,
   terms, relations, and relevance flags is licensed by the synthetic grammar.
3. Implement the synthetic tableau and its arithmetic, modal-strength, and flag-closure
   conditions while preserving the independently testable behavior of every base profile.
4. Reproduce the paper's combined examples and add cross-profile metamorphic tests showing
   that removing an unused extension collapses to the appropriate smaller profile.

**Acceptance:** the top published synthetic system can execute a relational argument that
combines counts, de re/de dicto modality, and relevance and return a replayable proof;
selecting any smaller profile rejects or ignores no feature silently.

### Phase 16 — Moss natural-logic compatibility

1. Freeze the exact 2026 tableaux translations for Moss's `A`, `S`, `S-dagger`,
   `R`, `R-dagger`, relative-clause, transitive-relation, and opposite-relation
   fragments that the paper actually covers.
2. Add an opt-in compatibility surface or compiler adapter that translates those forms to
   ordinary TFL while retaining both the source proposition and generated TFL in proof
   provenance.
3. Turn the translated rules and examples into a conformance corpus, preserving
   decidability or completeness claims only for the exact source fragment that establishes
   them.
4. Differentially compare translated execution with the equivalent direct TFL programs and
   expose any TFL inference that goes beyond the selected Moss fragment as such.

**Acceptance:** every covered member of the 2026 hierarchy can be written or imported,
translated, queried, and explained without changing core TFL semantics; the adapter never
advertises unsupported generalized quantifiers or relative constructions.

## Milestone III — Add answer generation without corrupting TFL semantics

### Phase 17 — Declarations and the finite program domain

1. Define optional declarations for singular objects, terms, and relation names while
   preserving declaration-free core programs.
2. Build a symbol table from declarations and occurrences, with deterministic naming and
   duplicate/conflict diagnostics.
3. Expose the finite set of queryable named objects and relations through the runtime.
4. Specify whether quoted names, primes, case, and singular markers denote the same or
   different symbols.

**Acceptance:** the compiler produces one deterministic domain catalog for every valid
program, and every catalog entry points back to its declarations or first occurrence.

### Phase 18 — Query-variable semantic contract

1. Design variables as query-only placeholders first; they do not become new TFL terms or
   alter the truth conditions of stored propositions.
2. Define grounding, repeated variables, anonymous variables, answer ordering,
   de-duplication, finite-domain scope, and the result of an incomplete ground check.
3. Specify how a binding is justified by the ground TFL proof it instantiates.
4. Freeze syntax only after ambiguity against existing term names and signs is ruled out.

**Acceptance:** a written operational specification and executable table of examples cover
every variable behavior before the evaluator accepts variable syntax.

### Phase 19 — Unary answer generation

1. Implement one-variable classification queries over the compiled finite domain.
2. Return positive, negative, both, and unresolved bindings separately; never discard a
   candidate merely because one proof attempt was incomplete.
3. Attach the ground proposition and proof metadata to every returned binding.
4. Add equivalence tests showing a variable query agrees with individually asking every
   possible ground query.

**Acceptance:** unary answer sets are complete relative to the declared finite domain and
the ground decision procedure’s stated completeness; any weaker guarantee is explicit in
the result.

### Phase 20 — Relational answer generation

1. Extend query variables to relational subjects and objects with more than one binding.
2. Implement deterministic join order, repeated-variable equality, projection, and
   duplicate removal.
3. Preserve relational orientation and the exact ground proof for each tuple.
4. Test converse-valid and converse-invalid relation forms so answer generation never
   assumes an illicit conversion.

**Acceptance:** finite relational queries return the same tuples as exhaustive ground
enumeration, including negative and unresolved cases, with reproducible ordering.

### Phase 21 — Query filters and answer projection

1. Add conjunction of query conditions, named projection, and equality/inequality filters
   over already-bound finite-domain variables.
2. Define evaluation when one condition is false, both, or unknown.
3. Produce a proof bundle that identifies which condition established or rejected each
   candidate tuple.
4. Add resource limits that return partial/incomplete metadata rather than truncated output
   presented as complete.

**Acceptance:** multi-condition queries have compositional four-state semantics and expose
whether the returned answer set is complete.

## Milestone IV — A real programmable rule layer

### Phase 22 — Rule-layer boundary and semantics

1. Determine exactly which reusable rules cannot already be expressed as TFL
   propositions, using concrete unary, relational, and recursive examples.
2. Compare a TFL-native transformation layer with a conservative Datalog-style rule layer
   over TFL propositions; choose one and record what is gained and lost.
3. Define variables, safety, grounding, rule applicability, proof labeling, and interaction
   with explicit negative information.
4. Prove or test conservativity: a core-only program must retain its old results.

**Acceptance:** the rule extension has a precise model and operational semantics, a clear
surface distinction from core TFL, and no implementation until those artifacts agree.

### Phase 23 — Non-recursive derived rules

1. Parse, validate, and compile safe non-recursive rules under the Phase 22 contract.
2. Evaluate rules over finite bindings and feed derived TFL propositions into the ordinary
   inference kernel.
3. Record the rule instance, substitutions, and parent propositions in proof provenance.
4. Reject unsafe, ungroundable, or layer-mixing rules with source diagnostics.

**Acceptance:** non-recursive rules derive exactly the specified ground propositions;
removing the extension leaves all core-only behavior unchanged.

### Phase 24 — Recursion and fixed-point evaluation

1. Add positive recursion using a monotone least-fixed-point evaluator.
2. Detect strongly connected rule components and iterate only the affected component.
3. Guarantee termination over the finite program domain or return a resource-limit result
   that is explicitly incomplete.
4. Test transitive closure, mutual recursion, duplicate derivations, and proof cycles.

**Acceptance:** recursive results match a small independent fixed-point oracle; proof output
is finite and does not erase the recursive derivation path.

### Phase 25 — Contradictions and integrity constraints

1. Define the public four-state query contract: supported only, contradicted only, both,
   or neither, with incompleteness represented separately.
2. Audit the existing classical and indirect procedures against inconsistent programs and
   decide where execution is paraconsistent, where it is classical, and where the compiler
   must refuse.
3. Add explicit integrity constraints for program invariants and return all established
   violations with supporting proofs.
4. Make consistency status incremental and visible in the CLI, REPL, JSON, and embedding
   API.

**Acceptance:** no inconsistent program can produce a one-sided answer that hides known
support for the other side; every explosion-prone boundary is tested and documented.

## Milestone V — Programs larger than one file

### Phase 26 — Modules, imports, and namespaces

1. Define module names, exported declarations, private declarations, qualified names, and
   imports.
2. Resolve import paths relative to the importing file and an explicit project root; never
   search arbitrary ambient directories.
3. Detect missing imports, cycles, ambiguous names, and duplicate module identities with
   source diagnostics.
4. Preserve module and file provenance through every derived answer.

**Acceptance:** a multi-file program builds reproducibly from any working directory and
cannot change meaning because an unrelated file appears on the machine.

### Phase 27 — Project manifests and reproducible builds

1. Define the minimal project manifest for source roots, entry modules, language version,
   and declared external data.
2. Add `tfl build` and `tfl check` over a project dependency graph.
3. Fingerprint compiler version, language version, source files, and options in a build
   record.
4. Keep single-file execution manifest-free.

**Acceptance:** the same checked-out project produces the same compiled program and build
fingerprint on two clean runs; missing configuration never changes semantics silently.

### Phase 28 — Incremental sessions

1. Add an immutable compiled-program value plus a session layer for adding, retracting,
   and replacing source units.
2. Invalidate only symbols, rule components, query indexes, and proofs affected by a
   change.
3. Make REPL reload and embedding APIs use the same session mechanism.
4. Differentially compare incremental results with a fresh rebuild after randomized edit
   sequences.

**Acceptance:** every incremental state agrees with recompiling its current sources from
scratch, including after errors and retractions.

## Milestone VI — Explanations and debugging as language features

### Phase 29 — Stable proof objects and provenance

1. Define a versioned public proof schema covering core inference, rule instantiation,
   recursion, contradiction, and source provenance.
2. Separate the full machine proof from minimized display views; never mutate the proof to
   improve presentation.
3. Validate parent references, conclusions, and source identities before serialization.
4. Add proof replay for the supported kernel so a saved answer can be checked independently
   of the live session.

**Acceptance:** every supported answer has a schema-valid proof that replays to the claimed
ground proposition; unknown answers never carry fabricated proof support.

### Phase 30 — `why`, `why-not`, and proof debugging

1. Add `why` views that show the smallest available proof without claiming global
   minimality unless it is actually computed.
2. Add `why-not` analysis that distinguishes explicit contradiction, missing supporting
   links, outside-fragment input, exhausted limits, and genuinely open-world absence.
3. Let users inspect a rule, source statement, binding, or proof parent from the REPL.
4. Render the same explanation tree in human text and structured JSON.

**Acceptance:** for a curated set of failed queries, `why-not` identifies an actionable and
truthful reason without presenting heuristic suggestions as logical necessities.

### Phase 31 — Test assertions for TFL programs

1. Add source-level assertions for expected support, contradiction, both, neither,
   consistency, and answer sets.
2. Implement `tfl test` with file/line diagnostics and machine-readable results.
3. Isolate test declarations from runtime knowledge so tests cannot make themselves pass.
4. Add snapshot support for canonical answers and proofs with explicit schema versions.

**Acceptance:** example applications can carry deterministic regression tests that fail on
wrong logical results, changed completeness, or changed proof contracts.

## Milestone VII — Scale, integration, and ordinary developer tooling

### Phase 32 — Indexes and query planning

1. Measure the current compiler, ground queries, answer generation, and recursive rules on
   fixed representative workloads before optimizing.
2. Add indexes by symbol, proposition shape, relation position, and rule dependency only
   where measurements justify them.
3. Expose a deterministic query plan and per-stage work counts for debugging.
4. Differentially compare indexed and unindexed execution over generated programs.

**Acceptance:** indexed execution returns byte-for-byte equivalent logical results and proof
claims, with recorded improvement on at least one workload and no unsupported performance
claim.

### Phase 33 — Resource control and operational safety

1. Centralize limits for source size, nesting, compiled facts, rule groundings, recursion
   rounds, proof size, query work, and wall time where enforceable.
2. Distinguish an exceeded limit from logical unknown and include which limit was hit.
3. Add cancellation to long-running embedding and process requests without corrupting the
   session.
4. Fuzz source, project, query, and session boundaries for crashes and unbounded behavior.

**Acceptance:** every public operation terminates, returns, or can be cancelled under its
documented limit; the process remains usable after refusal or cancellation.

### Phase 34 — External data and stable embedding APIs

1. Define explicit, typed import of CSV and JSON records into declared TFL symbols without
   inventing classifications from field names.
2. Preserve row and field provenance in compiled facts and proofs.
3. Stabilize versioned OCaml and JSON APIs for compile, session, query, proof, and
   diagnostics operations.
4. Publish compatibility rules and reject unsupported protocol versions cleanly.

**Acceptance:** an external program can load declared data, run repeated queries in one
session, trace every result to its source record, and negotiate an API version.

### Phase 35 — Formatter and editor support

1. Add a semantics-preserving formatter with an idempotence and parse/print/parse property
   suite.
2. Implement editor diagnostics, hover readings, go-to-definition, and completion through
   the Language Server Protocol.
3. Keep the language server as a client of the compiler/runtime APIs rather than a second
   parser or evaluator.
4. Publish configurations for at least one editor without making an editor a runtime
   dependency.

**Acceptance:** formatting twice is identical to formatting once; editor results agree with
`tfl check`; no editor-only interpretation of the language exists.

## Milestone VIII — Prove what the language is actually good for and release it

### Phase 36 — Standard examples and libraries

1. Build small, tested examples for classification, family/organizational relations,
   full numerical quantities, free terms, modality, relevance, a synthetic profile,
   recursive reachability, contradiction diagnosis, and data import.
2. Add only reusable definitions that occur in at least two real examples to a versioned
   standard library.
3. Document each example from source through query, result state, proof, and limitation.
4. Ensure every example runs offline in CI with no model, account, or network dependency.

**Acceptance:** a new user can learn every version-1 feature from executable programs, and
the standard library contains no speculative abstractions without real use sites.

### Phase 37 — Comparative real-world application trials

1. Choose three bounded applications where TFL might plausibly matter: one
   classification-heavy knowledge base, one relational/recursive program, and one
   extension-heavy explanation system that genuinely exercises numerical, modal, or
   relevance reasoning.
2. Implement the same concrete outcomes in TFL and the closest established alternative,
   normally Datalog, Prolog, or a description-logic tool.
3. Compare expressiveness, source size, query clarity, explanation quality, correctness,
   maintenance under changes, and runtime using predefined tasks—not general impressions.
4. Record where TFL is uniquely helpful, merely competitive, and clearly worse. Do not
   turn a negative comparison into a marketing claim.

**Acceptance:** a self-contained report and reproducible programs support every claimed
advantage or conclude that no unique practical advantage was demonstrated.

### Phase 38 — Documentation, packaging, and version 1 release

1. Repeat the targeted primary-source search through a recorded release cutoff date and
   reapply Phase 6's admission test. Add and complete a roadmap phase for any newly mature,
   in-scope TFL extension, or record the exact reason it is not reasonably implementable in
   version 1.
2. Finish the language reference, tutorial, command reference, embedding guide, error
   reference, semantics/extension boundary, and migration/versioning policy.
3. Package `tfl` for a clean supported environment and verify install, uninstall, and a
   first program from outside the source tree.
4. Run the full unit, conformance, property, oracle, differential, fuzz, integration,
   example, and application suites; publish exact known limitations.
5. Tag version 1 only after the repository, package metadata, changelog, license, and
   release artifacts all name Horos consistently.

**Acceptance:** a clean machine can install TFL, complete the tutorial, run and test a
multi-file variable-and-recursion program, use every stable profile, inspect its proof, and
reproduce the published application comparisons. The source manifest has a release cutoff
date; all tests pass; all incomplete procedures and deferred candidates are plainly labeled.

---

## Version 1 completion checklist

Version 1 is complete only when all 38 phases are complete and the following are true:

- the language has a normative, versioned semantics and conformance suite;
- core TFL and every extension are distinguishable in source, runtime state, and proofs;
- Murphree numerical, admitted Szabolcsi/Peterson quantity, free-term, modal, relevance, and
  every published synthetic profile work independently and in every licensed combination;
- the documented monadic numerical fragment has a complete semantic decision procedure,
  while numerical-relational limits are stated separately and never hidden;
- the covered 2026 Moss natural-logic hierarchy translates to TFL with checked provenance
  and fragment-accurate decidability or completeness claims;
- `.tfl` files, projects, modules, imports, the CLI, REPL, formatter, tests, and editor
  diagnostics work together;
- ground, variable, relational, filtered, and recursive queries expose four-state truth and
  separate completeness metadata;
- every supported answer has source provenance and a replayable proof;
- contradictions, limits, malformed input, and internal errors cannot masquerade as
  ordinary false answers;
- a dated pre-release literature refresh has either incorporated every newly mature,
  in-scope TFL extension or documented why it falls outside the reasonable stable boundary;
- installation and embedding work outside the repository;
- executable real-world comparisons establish exactly what practical value was and was not
  demonstrated.
