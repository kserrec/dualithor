# Architecture

This document maps the Dualithor codebase for a developer taking ownership: the
components, how they layer, and the paths a request travels from input to
verdict. It complements — does not repeat — the normative contracts:

- [`README.md`](README.md) — what Dualithor is, how to build and run it.
- [`PLAN.md`](PLAN.md) — the authoritative roadmap and current phase.
- [`docs/core-language.md`](docs/core-language.md) — the normative `core-0.1`
  language reference; [`docs/port-spec.md`](docs/port-spec.md) is its mechanics
  appendix.
- [`docs/runtime-api.md`](docs/runtime-api.md) — the `Tfl.Runtime` API and
  `dualithor-runtime-0.1` JSON-lines contract.
- [`docs/command-line.md`](docs/command-line.md) — the `.tfl` file, human `tfl`
  command, REPL, and exit-status contract.
- [`docs/engine-surface.md`](docs/engine-surface.md) — the failure taxonomy and
  the total `Tfl.Safe` API.
- [`SECURITY.md`](SECURITY.md) — trust boundaries and hostile-input limits.

## What Dualithor is, in one paragraph

Dualithor is a proof-producing logic programming language based on **Term Functor
Logic (TFL)** — a term logic written in a plus/minus notation where, for
example, `−Man+Mortal` reads "every man is mortal". A TFL *program* states
facts, classifications, exclusions, and relations; a *query* asks what those
statements support. The engine answers with a verdict **and** the formal proof
or certificate that backs it. It is open-world: failure to prove something is
not proof of its negation, so results distinguish positive support, negative
support, both, neither, and an incomplete search. The implementation is OCaml;
a frozen JavaScript engine under `engine/` is kept only as a regression oracle
(see "The frozen reference" below).

The guiding constraint, from the README and CLAUDE.md: **never quietly turn TFL
into a differently spelled Prolog or Datalog.** Every extension must have its
own defined semantics, preserve existing verdicts, and name its contribution in
proof output.

## The shape of the system

Two installed executables sit on top of one library:

- **`tfl`** (`bin/tfl_command.ml`) — the human command line: `check`, `query`,
  `describe`, `render`, and an interactive `repl`, over UTF-8 `.tfl` files, with
  caret-marked source diagnostics. Add `--json` for a stable machine record.
- **`dualithor`** (`bin/tfl_cli.ml`) — a long-lived JSON-lines process: one request
  object per line of stdin, one reply object per line of stdout. This is the
  boundary a future pip-installable client wraps.

Both link the **`tfl` library** (`lib/tfl/`), the language kernel, plus small
support libraries in `bin/` for JSON encoding and terminal editing. A separate
**`tfl_verify`** library (`lib/verify/`) is a thin pipeline-facing wrapper used
by the `check` JSON command.

Nothing in the shipped executables makes a network call or spawns a process. A
normal install selects only Dune and `yojson`.

## The kernel: `lib/tfl/` module by module

The 13 modules form a strict dependency stack. Listed bottom-up; each depends
only on modules above it in this list. The parenthetical is the PLAN step it
was ported from.

**Data and positions (leaves, no engine dependencies)**

- **`ast.ml`** — the abstract syntax tree for the plus/minus notation: signs
  (`Plus | Minus | Wild`), terms (`Atom`, `Neg`, `Compound`, `Rel`, `PropTerm`),
  and propositions. The AST stores a sign variant; typographic-vs-ASCII spelling
  is the printer's job, not the tree's.
- **`source.ml`** *(has `.mli`)* — source positions and spans shared by the
  parser, compiler, runtime, and interfaces. Offsets and columns count **Unicode
  code points, never UTF-8 bytes**; spans are half-open (`start_pos` included,
  `end_pos` is the first position after the construct).

**Notation (1.3)**

- **`notation.ml`** — the tokenizer, parser, and printer. `tokenize` runs first
  and on its own, so a failure there is *lexical* by construction; the parser
  then consumes the token array, so its failures are *syntactic*. The printer
  produces the canonical spelling. Divergences from the JS reference are the
  recorded port-language decisions (ASCII-only bare-name letters; code-point
  error positions).

**Inference core (1.4–1.6)**

- **`infer.ml`** — canonical form (equality up to commutativity, associativity,
  double negation, and wild quantity), fragment validation, identity keys, node
  counts, the immediate inferences (obversion `EN`/`IN`, contraposition, the
  `It` tautology), and net-sign occurrence analysis. Canonical form is
  level-less: quantity levels live only on raw propositions.
- **`rules.ml`** — the mediate rewrite rules: term substitution at an occurrence
  path, `DON` (dictum de omni), `Simp`, and `Add`. Every result is canonical.
- **`relational.ml`** — the relational layer: orientations, the passive
  transformation with its symmetry guard, and pronominalization (Skolemization
  for indirect proof).

**Search and decision (1.5, 1.8)**

- **`derive.ml`** — proof search. `saturate` is the shared forward-chaining core:
  it seeds a board with facts and tautologies, applies the unary and binary
  rules to a fixed line/size cap, and extracts ancestry into a proof. Line order
  is deterministic and mirrors the JS engine exactly (the differential harness
  compares whole proofs). It carries a **deterministic work budget** measured in
  term-node visits (`consume_work` / `Work_limit_exceeded`) so a wide-compound
  input cannot make candidate construction run unbounded between lines.
- **`decide.ml`** — the argument checker. For the atomic-categorical fragment it
  runs the **P/Z inconsistency closure** (complete there); for leveled inputs it
  runs the numerical decision (`TFL⁺`, which can certify validity but not
  general invalidity); otherwise it runs direct and indirect derivation. One
  shared work budget spans the four searches for a single argument.

**Programs and rendering (1.7, 1.9)**

- **`program.ml`** — whole programs and their operations: `parse_program`, the
  `?` term query (`query_term_detailed`) and proposition query (`query_prop`),
  program consistency, the `?=` equivalence comparison, and the one-world
  statement model. This is where multi-line facts become an answerable program.
- **`render.ml`** — deterministic English readings of terms, propositions, and
  proofs. **This module is authoritative over English; the JS reference is
  not** — the frozen engine stays authoritative on verdicts forever, but several
  of its English readings are wrong. Readings are verdict-safe by construction
  (English decides nothing) but the strings are still a contract.

**The two public boundaries**

- **`safe.ml`** — the **total** public surface (`Tfl.Safe`). Everything hostile
  enters here: these functions never raise, always return a structured failure,
  and never run unboundedly. `guard` wraps every post-parse engine call and maps
  what the engine *should not* raise — `Infer.Engine_error` →
  `outside_fragment`, `Derive.Work_limit_exceeded` → `resource_limit`,
  everything else → `internal` — onto the failure taxonomy in
  `docs/engine-surface.md`. Failure *class* comes from *where* the exception was
  raised, never from message text.
- **`runtime.ml`** *(has `.mli`)* — the stable production API (`Tfl.Runtime`).
  It compiles a whole program into stable records, attaches completeness
  metadata and proof support to every operation (`query`, `describe`,
  `check_consistency`, `equivalent`), and guards each engine call through
  `Safe.guard`. This is the layer a caller programs against.

**File loading**

- **`source_file.ml`** *(has `.mli`)* — the `.tfl` loader and its diagnostics.
  It enforces the `.tfl` suffix, opens the path non-blocking and close-on-exec,
  verifies the target is a regular file **both before and after opening** (the
  second check closes the type-check/open race for a swapped FIFO or device),
  reads to the program-source byte cap, validates UTF-8, and compiles through
  `Runtime.compile`, carrying source spans into every diagnostic.

## The executables: `bin/`

- **`tfl_cli.ml`** (`dualithor`) — reads one request line at a time with a byte cap
  applied *before* JSON parsing (so an oversized line is refused without
  allocating it), dispatches the `cmd` field to a command table, and **never
  crashes or exits non-zero on bad input** — every failure is a JSON reply. An
  oversized line is drained so the stream stays synchronized for the next
  request.
- **`tfl_command.ml`** (`tfl`) — the human command. It escapes terminal control
  characters, bidirectional marks, and zero-width formatting in every
  interpolated field (paths, names, English), so a hostile filename cannot clear
  the terminal or forge a diagnostic line. Renders both human text (with caret
  ranges) and, under `--json`, a `tfl-cli-0.1` record.
- **`command_status.ml`** / **`runtime_json.ml`** (library `tfl_cli_support`) —
  shared exit-status mapping and JSON encoders for runtime records, used by both
  executables.
- **`repl_input.ml`** (library `tfl_repl_support`) — the REPL's optional
  in-memory line editor with history, kept private to the human command so the
  `dualithor` process boundary never acquires an interactive-terminal component. It
  falls back to a bounded plain reader on pipes and dumb terminals.

## `lib/verify/`

- **`tfl_verify.ml`** — one call, `check ~premises ~conclusion` on plain
  strings, returning one total result record and JSON in both directions. It is
  the surface the `check` command and the legacy translation pipeline use. It
  preserves the **`Unknown` ≠ `Invalid`** contract: `Invalid` is exact and comes
  only from the complete level-0 P/Z method; `Unknown` means bounded search
  found neither side.

## Key flows

### 1. `tfl query knowledge.tfl '±Socrates*+Mortal'`

1. `tfl_command.main` parses argv, extracts `--json`, dispatches to `run_query`.
2. `Source_file.load` opens and validates the file (suffix, regular-file checks,
   byte cap, UTF-8), then `Runtime.compile` turns the text into a
   `Runtime.program` with per-statement source spans.
3. `Runtime.query program source` parses the query proposition through
   `Safe.parse_located`, then runs `Program.query_prop`, which calls
   `Decide.check_argument`. `check_argument` picks a method — P/Z closure for the
   atomic-categorical fragment, else `Derive.derive` / `Derive.indirect_proof`
   under a shared work budget — and returns a verdict with its proof.
4. `Runtime` wraps the result with a verdict, method name, completeness, and
   support proof; `tfl_command` prints it as human text (with `Render`'s English)
   or a `tfl-cli-0.1` JSON record, and exits with the status code for the
   verdict.

### 2. `{"cmd":"query","program":"…","query":"…"}` through `dualithor`

`tfl_cli` reads the bounded request line, parses JSON, looks up `query` in its
command table, and calls the same `Runtime.query`. The difference from flow 1 is
only the boundary: input is a JSON field rather than a file, output is a single
JSON reply, and a malformed line becomes an `error` reply instead of a crash.
The engine path (`Runtime → Program → Decide → Derive`) is identical.

### 3. The hostile-input path

Any untrusted proposition or program reaches the engine only through `Tfl.Safe`
or `Tfl.Runtime`, never the low-level modules directly. `Safe.guard` /
`Runtime`'s internal guards convert every engine refusal into a typed failure
(`lexical`, `syntactic`, `outside_fragment`, `resource_limit`, `internal`) with
a source span. The size, nesting, premise-count, and work budgets that bound
this path are listed in `SECURITY.md`.

## The frozen reference and correctness gates

`engine/` holds the original JavaScript engine. **It is frozen**: production
OCaml never executes it, and no new language feature is added there. It exists
so the OCaml port can be checked against it:

- **Differential gate** (`test/test_differential.ml`) — 884,000 generated inputs
  plus the reference corpus, comparing whole verdicts and proofs against the JS
  engine through a Node shim. Run with `-mass`.
- **Oracle gate** (`test/test_oracle.ml`, `engine/oracle.js`) — the categorical
  core against a finite-model oracle, plus rule-step, relational, passive,
  indirect-proof, and statement-model fuzz suites. Run with `-n 20000`.
- **Conformance** (`test/test_conformance.ml`) — the language-neutral
  `data/conformance/core-0.1.json` corpus.
- **Robustness** (`test/test_safe.ml`) — the total `Safe` API under adversarial
  input and the work/size caps.
- **Process boundaries** (`test/test_cli.ml`, `test/test_tfl_command.ml`) — the
  `dualithor` and `tfl` executables driven as real processes.

A changed verdict is never silent: it requires an explicit language decision,
documentation, focused regressions, and both long gates (see CLAUDE.md's
semantic bar).

## Decisions and constraints worth knowing

- **The JS engine is authoritative on verdicts, `Render` is authoritative on
  English.** These two authorities are deliberately split.
- **`Unknown` is a first-class result, not a failure.** Relational search is
  incomplete, and the numerical layer cannot decide invalidity in general; both
  return `Unknown` rather than a wrong verdict.
- **The low-level modules do not promise hostile-input isolation.** Bounds live
  at the `Safe` / `Runtime` / `source_file` / CLI boundaries; trusted OCaml
  callers may use the kernel directly.
- **Code-point positions, not bytes.** Diagnostic locations count Unicode code
  points; they equal the JS reference's UTF-16 indices on all BMP input, which
  is all the differential corpus generates.
- **The `Cohttp`/`Lwt`/TLS graph is test-and-development only.** It exists for
  the retained legacy OpenRouter translation client under `translate/` and is
  excluded from a normal install by CI.

## Legacy and provenance

`translate/`, `router/`, `bench/`, `analysis/`, and much of `data/` and `docs/`
are artifacts of the former regulatory-verification research system. They are
retained for provenance — `LOG.md` records why — and are **not** selectable
work. `$next` and the active roadmap live entirely in `PLAN.md`.

## Where things stand

Phases 1–5 are complete (the language kernel, the total runtime, the `.tfl`
file and human command, the interactive shell, and source-span diagnostics).
Phase 6 — locking the published TFL extension sources, semantics, and profiles —
is next. `PLAN.md` is the single source of truth for status; this document does
not duplicate it.
