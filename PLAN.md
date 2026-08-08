# tfl-language: Project Plan

## Active decision — 2026-08-08

Build a complete, usable logic programming language based on term logic (TFL), using the
existing OCaml engine as the verified starting kernel.

This plan completely replaces the former regulatory-verification and human-study plans.
Those projects are discontinued. Their code, datasets, reports, and negative results stay in
the repository as historical evidence, but no old phase is active and `$next` must never
select work from an old roadmap. Git history preserves the superseded plan.

The repository and project are now named **`tfl-language`**. The language is called **TFL**
and its eventual human-facing executable is **`tfl`**.

No implementation phase in this plan has started.

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
   or refuse execution under a precisely documented consistency policy; Phase 14 fixes the
   final contract.
5. **`Unknown` is never advertised as a decision.** A bounded or incomplete search reports
   why it did not decide. Numerical and relational incompleteness stay explicit until a
   complete procedure actually exists.
6. **Every answer can carry provenance.** Derived results retain source location, rule,
   parents, and the exact formal proposition. English explanations supplement that formal
   record; they never replace it.
7. **No usefulness claims by intuition.** Claims about readability, concision,
   explainability, performance, or practical advantage require concrete comparisons in
   Phase 24.

Negation-as-failure and an implicit closed-world mode are not part of version 1. They can be
considered after version 1 only as an explicitly marked, stratified extension. This avoids
turning “not currently known” into “known not to be true” inside a language whose central
contract is open-world reasoning.

## Starting point

The repository already contains considerably more than a parser experiment:

- a Unicode and ASCII-compatible parser, canonical printer, and abstract syntax tree;
- categorical, relational, propositional-term, and numerical TFL representations;
- direct, indirect, relational, and consistency inference;
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
answer variables, a defined user-rule layer, recursion, modules, source-level diagnostics,
incremental evaluation, a debugger, data interfaces, editor tooling, packaging, and real
application evidence.

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

### Phase 1 — Freeze the core language contract ⏭ NEXT

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

### Phase 2 — Public program runtime

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

### Phase 3 — `.tfl` files and the human command line

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

### Phase 4 — Interactive shell

1. Add a REPL that loads a program once and accepts ground queries, term queries,
   consistency checks, equivalence checks, reload, help, and quit.
2. Preserve command history when the terminal supports it without making history support a
   runtime requirement.
3. Ensure malformed input returns to the prompt without losing the loaded program.
4. Add non-interactive transcript tests for the entire session protocol.

**Acceptance:** a user can explore and reload one program through a complete session; every
REPL operation has the same semantics and data as the program API.

### Phase 5 — Source spans and compiler diagnostics

1. Carry file, line, column, and source span from tokens through program entries,
   declarations, and query errors.
2. Report multiple independent compile errors in one run with the offending source line
   and a caret range.
3. Separate lexical, syntactic, name-resolution, outside-fragment, incomplete-search, and
   internal failures in both human and JSON forms.
4. Add malformed-file and Unicode-position regression cases.

**Acceptance:** every user-caused failure points to actionable source text; byte offsets are
never mislabeled as character columns; internal failures are never presented as bad user
input.

## Milestone II — Add answer generation without corrupting TFL semantics

### Phase 6 — Declarations and the finite program domain

1. Define optional declarations for singular objects, terms, and relation names while
   preserving declaration-free core programs.
2. Build a symbol table from declarations and occurrences, with deterministic naming and
   duplicate/conflict diagnostics.
3. Expose the finite set of queryable named objects and relations through the runtime.
4. Specify whether quoted names, primes, case, and singular markers denote the same or
   different symbols.

**Acceptance:** the compiler produces one deterministic domain catalog for every valid
program, and every catalog entry points back to its declarations or first occurrence.

### Phase 7 — Query-variable semantic contract

1. Design variables as query-only placeholders first; they do not become new TFL terms or
   alter the truth conditions of stored propositions.
2. Define grounding, repeated variables, anonymous variables, answer ordering,
   de-duplication, finite-domain scope, and the result of an incomplete ground check.
3. Specify how a binding is justified by the ground TFL proof it instantiates.
4. Freeze syntax only after ambiguity against existing term names and signs is ruled out.

**Acceptance:** a written operational specification and executable table of examples cover
every variable behavior before the evaluator accepts variable syntax.

### Phase 8 — Unary answer generation

1. Implement one-variable classification queries over the compiled finite domain.
2. Return positive, negative, both, and unresolved bindings separately; never discard a
   candidate merely because one proof attempt was incomplete.
3. Attach the ground proposition and proof metadata to every returned binding.
4. Add equivalence tests showing a variable query agrees with individually asking every
   possible ground query.

**Acceptance:** unary answer sets are complete relative to the declared finite domain and
the ground decision procedure’s stated completeness; any weaker guarantee is explicit in
the result.

### Phase 9 — Relational answer generation

1. Extend query variables to relational subjects and objects with more than one binding.
2. Implement deterministic join order, repeated-variable equality, projection, and
   duplicate removal.
3. Preserve relational orientation and the exact ground proof for each tuple.
4. Test converse-valid and converse-invalid relation forms so answer generation never
   assumes an illicit conversion.

**Acceptance:** finite relational queries return the same tuples as exhaustive ground
enumeration, including negative and unresolved cases, with reproducible ordering.

### Phase 10 — Query filters and answer projection

1. Add conjunction of query conditions, named projection, and equality/inequality filters
   over already-bound finite-domain variables.
2. Define evaluation when one condition is false, both, or unknown.
3. Produce a proof bundle that identifies which condition established or rejected each
   candidate tuple.
4. Add resource limits that return partial/incomplete metadata rather than truncated output
   presented as complete.

**Acceptance:** multi-condition queries have compositional four-state semantics and expose
whether the returned answer set is complete.

## Milestone III — A real programmable rule layer

### Phase 11 — Rule-layer boundary and semantics

1. Determine exactly which reusable rules cannot already be expressed as TFL
   propositions, using concrete unary, relational, and recursive examples.
2. Compare a TFL-native transformation layer with a conservative Datalog-style rule layer
   over TFL propositions; choose one and record what is gained and lost.
3. Define variables, safety, grounding, rule applicability, proof labeling, and interaction
   with explicit negative information.
4. Prove or test conservativity: a core-only program must retain its old results.

**Acceptance:** the rule extension has a precise model and operational semantics, a clear
surface distinction from core TFL, and no implementation until those artifacts agree.

### Phase 12 — Non-recursive derived rules

1. Parse, validate, and compile safe non-recursive rules under the Phase 11 contract.
2. Evaluate rules over finite bindings and feed derived TFL propositions into the ordinary
   inference kernel.
3. Record the rule instance, substitutions, and parent propositions in proof provenance.
4. Reject unsafe, ungroundable, or layer-mixing rules with source diagnostics.

**Acceptance:** non-recursive rules derive exactly the specified ground propositions;
removing the extension leaves all core-only behavior unchanged.

### Phase 13 — Recursion and fixed-point evaluation

1. Add positive recursion using a monotone least-fixed-point evaluator.
2. Detect strongly connected rule components and iterate only the affected component.
3. Guarantee termination over the finite program domain or return a resource-limit result
   that is explicitly incomplete.
4. Test transitive closure, mutual recursion, duplicate derivations, and proof cycles.

**Acceptance:** recursive results match a small independent fixed-point oracle; proof output
is finite and does not erase the recursive derivation path.

### Phase 14 — Contradictions and integrity constraints

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

## Milestone IV — Programs larger than one file

### Phase 15 — Modules, imports, and namespaces

1. Define module names, exported declarations, private declarations, qualified names, and
   imports.
2. Resolve import paths relative to the importing file and an explicit project root; never
   search arbitrary ambient directories.
3. Detect missing imports, cycles, ambiguous names, and duplicate module identities with
   source diagnostics.
4. Preserve module and file provenance through every derived answer.

**Acceptance:** a multi-file program builds reproducibly from any working directory and
cannot change meaning because an unrelated file appears on the machine.

### Phase 16 — Project manifests and reproducible builds

1. Define the minimal project manifest for source roots, entry modules, language version,
   and declared external data.
2. Add `tfl build` and `tfl check` over a project dependency graph.
3. Fingerprint compiler version, language version, source files, and options in a build
   record.
4. Keep single-file execution manifest-free.

**Acceptance:** the same checked-out project produces the same compiled program and build
fingerprint on two clean runs; missing configuration never changes semantics silently.

### Phase 17 — Incremental sessions

1. Add an immutable compiled-program value plus a session layer for adding, retracting,
   and replacing source units.
2. Invalidate only symbols, rule components, query indexes, and proofs affected by a
   change.
3. Make REPL reload and embedding APIs use the same session mechanism.
4. Differentially compare incremental results with a fresh rebuild after randomized edit
   sequences.

**Acceptance:** every incremental state agrees with recompiling its current sources from
scratch, including after errors and retractions.

## Milestone V — Explanations and debugging as language features

### Phase 18 — Stable proof objects and provenance

1. Define a versioned public proof schema covering core inference, rule instantiation,
   recursion, contradiction, and source provenance.
2. Separate the full machine proof from minimized display views; never mutate the proof to
   improve presentation.
3. Validate parent references, conclusions, and source identities before serialization.
4. Add proof replay for the supported kernel so a saved answer can be checked independently
   of the live session.

**Acceptance:** every supported answer has a schema-valid proof that replays to the claimed
ground proposition; unknown answers never carry fabricated proof support.

### Phase 19 — `why`, `why-not`, and proof debugging

1. Add `why` views that show the smallest available proof without claiming global
   minimality unless it is actually computed.
2. Add `why-not` analysis that distinguishes explicit contradiction, missing supporting
   links, outside-fragment input, exhausted limits, and genuinely open-world absence.
3. Let users inspect a rule, source statement, binding, or proof parent from the REPL.
4. Render the same explanation tree in human text and structured JSON.

**Acceptance:** for a curated set of failed queries, `why-not` identifies an actionable and
truthful reason without presenting heuristic suggestions as logical necessities.

### Phase 20 — Test assertions for TFL programs

1. Add source-level assertions for expected support, contradiction, both, neither,
   consistency, and answer sets.
2. Implement `tfl test` with file/line diagnostics and machine-readable results.
3. Isolate test declarations from runtime knowledge so tests cannot make themselves pass.
4. Add snapshot support for canonical answers and proofs with explicit schema versions.

**Acceptance:** example applications can carry deterministic regression tests that fail on
wrong logical results, changed completeness, or changed proof contracts.

## Milestone VI — Scale, integration, and ordinary developer tooling

### Phase 21 — Indexes and query planning

1. Measure the current compiler, ground queries, answer generation, and recursive rules on
   fixed representative workloads before optimizing.
2. Add indexes by symbol, proposition shape, relation position, and rule dependency only
   where measurements justify them.
3. Expose a deterministic query plan and per-stage work counts for debugging.
4. Differentially compare indexed and unindexed execution over generated programs.

**Acceptance:** indexed execution returns byte-for-byte equivalent logical results and proof
claims, with recorded improvement on at least one workload and no unsupported performance
claim.

### Phase 22 — Resource control and operational safety

1. Centralize limits for source size, nesting, compiled facts, rule groundings, recursion
   rounds, proof size, query work, and wall time where enforceable.
2. Distinguish an exceeded limit from logical unknown and include which limit was hit.
3. Add cancellation to long-running embedding and process requests without corrupting the
   session.
4. Fuzz source, project, query, and session boundaries for crashes and unbounded behavior.

**Acceptance:** every public operation terminates, returns, or can be cancelled under its
documented limit; the process remains usable after refusal or cancellation.

### Phase 23 — External data and stable embedding APIs

1. Define explicit, typed import of CSV and JSON records into declared TFL symbols without
   inventing classifications from field names.
2. Preserve row and field provenance in compiled facts and proofs.
3. Stabilize versioned OCaml and JSON APIs for compile, session, query, proof, and
   diagnostics operations.
4. Publish compatibility rules and reject unsupported protocol versions cleanly.

**Acceptance:** an external program can load declared data, run repeated queries in one
session, trace every result to its source record, and negotiate an API version.

### Phase 24 — Formatter and editor support

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

## Milestone VII — Prove what the language is actually good for and release it

### Phase 25 — Standard examples and libraries

1. Build small, tested examples for classification, family/organizational relations,
   recursive reachability, contradiction diagnosis, and data import.
2. Add only reusable definitions that occur in at least two real examples to a versioned
   standard library.
3. Document each example from source through query, result state, proof, and limitation.
4. Ensure every example runs offline in CI with no model, account, or network dependency.

**Acceptance:** a new user can learn every version-1 feature from executable programs, and
the standard library contains no speculative abstractions without real use sites.

### Phase 26 — Comparative real-world application trials

1. Choose three bounded applications where TFL might plausibly matter: one
   classification-heavy knowledge base, one relational/recursive program, and one
   explanation-heavy rule system.
2. Implement the same concrete outcomes in TFL and the closest established alternative,
   normally Datalog, Prolog, or a description-logic tool.
3. Compare expressiveness, source size, query clarity, explanation quality, correctness,
   maintenance under changes, and runtime using predefined tasks—not general impressions.
4. Record where TFL is uniquely helpful, merely competitive, and clearly worse. Do not
   turn a negative comparison into a marketing claim.

**Acceptance:** a self-contained report and reproducible programs support every claimed
advantage or conclude that no unique practical advantage was demonstrated.

### Phase 27 — Documentation, packaging, and version 1 release

1. Finish the language reference, tutorial, command reference, embedding guide, error
   reference, semantics/extension boundary, and migration/versioning policy.
2. Package `tfl` for a clean supported environment and verify install, uninstall, and a
   first program from outside the source tree.
3. Run the full unit, conformance, property, oracle, differential, fuzz, integration,
   example, and application suites; publish exact known limitations.
4. Tag version 1 only after the repository, package metadata, changelog, license, and
   release artifacts all name `tfl-language` consistently.

**Acceptance:** a clean machine can install TFL, complete the tutorial, run and test a
multi-file variable-and-recursion program, inspect its proof, and reproduce the published
application comparisons. All tests pass and all incomplete procedures are plainly labeled.

---

## Version 1 completion checklist

Version 1 is complete only when all 27 phases are complete and the following are true:

- the language has a normative, versioned semantics and conformance suite;
- core TFL and every extension are distinguishable in source, runtime state, and proofs;
- `.tfl` files, projects, modules, imports, the CLI, REPL, formatter, tests, and editor
  diagnostics work together;
- ground, variable, relational, filtered, and recursive queries expose four-state truth and
  separate completeness metadata;
- every supported answer has source provenance and a replayable proof;
- contradictions, limits, malformed input, and internal errors cannot masquerade as
  ordinary false answers;
- installation and embedding work outside the repository;
- executable real-world comparisons establish exactly what practical value was and was not
  demonstrated.
