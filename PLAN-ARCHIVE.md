# Dualithor plan archive

Completed phases moved from PLAN.md. This file is the permanent delivery record;
entries are never condensed or reordered. Each entry keeps its completion evidence and
delivery details, while project-wide product, package, process, and protocol identity
renames are normalized to the current name. The live plan (PLAN.md) keeps a one-line
pointer to each entry.

---

### Maintenance phase — 2026-08-16 deterministic robustness timing checks ✅ COMPLETE

This maintenance phase pays the Phase 1 test debt exposed during the Phase 4 test audit.
The production cancellation search already had a deterministic 500,000-node budget, but
`test/test_safe.ml` tried to prove that bound indirectly with a one-second wall-clock limit.
The unchanged exact probe took 0.670–0.761 seconds across 20 isolated runs and
3.289–3.295 seconds across three runs under eight competing CPU workers, while returning
the same budget-limited certificate in every run. That establishes scheduler contention,
not an unbounded production search, as the cause of the flake. The first forced full-suite
run after repairing that one assertion exposed the same load-sensitive mechanism in the
generated argument check's per-call wall-clock guard.

1. Assert the documented production cancellation budget directly and retain both the
   budget-exhaustion certificate check and the small positive cancellation control.
2. Measure the safety suite's one-second work limits with process CPU time, which counts the
   work consumed by the single-threaded test process without counting time it was descheduled.
3. Run the focused safety suite and a forced full repository suite without moving to Phase 6.

**Acceptance:** `test_safe` proves the deterministic cancellation cap and still rejects any
individual parse, argument check, or compound inference that consumes more than one process
CPU second; all 14 focused contract checks and 102,000 generated adversarial inputs pass;
the forced full repository suite passes.

**Delivered:** only the test harness and planning record changed; inference, runtime, command,
and other production behavior are unchanged. The focused safety executable passed all 14
contract checks and 102,000 generated inputs. The forced full Dune suite passed, including
the six 1,000-iteration oracle suites and all 18 differential comparisons. Phase 6 remains
the next implementation phase and has not started.

---

### Maintenance phase — 2026-08-15 Dualithor identity cutover ✅ COMPLETE

This approved maintenance phase replaces the former public product, engine, package,
process, repository, and protocol identity with “Dualithor.” The TFL language name and the
human-facing `tfl` command remain unchanged.

1. Rename the Dune project and package, public OCaml libraries, installable engine command,
   runtime schema identifier, repository metadata, CI references, tests, and documentation.
2. Rename the hands-on guide without losing saved browser progress or invalidating the old
   local guide filename during the transition.
3. Verify the build, focused command and source-file suites, full repository suite, opam
   metadata, locked working-tree installation, installed commands outside the repository,
   and the guide in a real headless browser.
4. Rename the public GitHub repository and update the local `origin` remote.

**Acceptance:** active product surfaces consistently say Dualithor; TFL syntax, semantics,
and the `tfl` command are unchanged; the only retained former-name text is compatibility
data for the old guide; both installed commands work outside the build tree; all
verification is green; and the public repository is reachable as `kserrec/dualithor`.

**Delivered:** the package is `dualithor`, the public libraries are `dualithor.tfl` and
`dualithor.verify`, the engine executable is `dualithor`, and runtime replies identify schema
`dualithor-runtime-0.1`. The `tfl` command and every logical rule remain unchanged. The guide
is now `DUALITHOR-PHASE-5-HANDS-ON.html`; an old-filename compatibility link and a one-time
browser-storage migration preserve existing readers' progress. The checkout now lives at
`/home/serrecchia/Projects/dualithor`; an old-path compatibility link keeps active tools and
saved shell locations working during the transition. The public repository is
`https://github.com/kserrec/dualithor`, and local `origin` uses that destination.
The focused suites, forced clean-cache full Dune suite, both opam lints, locked path-pinned
install, outside-repository `tfl`/`dualithor` probes, JavaScript syntax check, and
headless-browser loads all passed.

---

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

**Follow-on security fix (2026-08-11 audit):** the maintenance work budget bounded the
argument/`query` search but not the `describe` (`query_term_detailed`) path, whose
candidate-subsumption step is quadratic in the collected candidate count — a count that
follows the program's proposition count, not the line cap. A legal ~9 KB program of ~1,000
same-subject facts therefore blocked the lockstep stream for ~6 seconds. The fix threads one
shared work budget through that path's main saturation and every pairwise `implies` search,
so exhaustion refuses as the public `resource_limit` in under a second and the stream stays
synchronized; generator-scale inputs stay far under the budget, so no differential-compared
result changed. Pinned by a `test/test_program.ml` regression; the 884,000-input differential
gate passed again with zero divergence. Recorded in SECURITY.md. Phase 6 remains next.

---

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
`dualithor-runtime-0.1` JSON-lines commands compile, query, describe, check consistency, and
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
rather than overclaiming non-entailment. The existing `dualithor` JSON-lines boundary shares
runtime serializers and remains byte-contract compatible. Focused loader, command,
runtime, program, process, and adversarial suites are green; the forced full suite and an
isolated-prefix install/query from outside the checkout are also green.

The post-delivery Phase 3 security audit found and fixed two hostile-path defects: human
output now renders terminal controls and malformed path bytes visibly, and the loader
rejects FIFOs, devices, sockets, directories, and symlinks to nonregular targets without
waiting for content. Repository guards now cover every dotenv filename variant. The
historical translation client's Lwt/Cohttp/TLS/Mirage graph is retained for tests and
manual development but filtered out of a normal Dualithor installation in both the generated
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
