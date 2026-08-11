# Horos

Horos is an in-development, proof-producing logic programming language based on Term
Functor Logic (TFL), implemented in OCaml. Its name comes from the ancient Greek word for
“term.”

The project is being rebuilt around the language that was already hiding inside the former
TFL-Verify research system. The existing engine can parse TFL, decide supported fragments,
run multi-line programs, answer ground proposition and term queries, check consistency,
compare propositions for equivalence, and return proofs or certificates. The new work is to
turn that kernel into a complete language product: `.tfl` files, a human command line, a
REPL, answer variables, a defined rule and recursion layer, modules, diagnostics,
provenance, debugging, data interfaces, editor support, packaging, and real application
comparisons.

**Current status (2026-08-11):** Phases 1 through 5 are complete. The inherited core has a
[normative language reference](docs/core-language.md), a 26-case executable conformance
corpus, and a [total public runtime](docs/runtime-api.md) that compiles whole programs and
exposes every existing operation through OCaml and JSON-lines interfaces. The installable
[`tfl` command](docs/command-line.md) now checks UTF-8 `.tfl` files, runs ground and term
queries, renders propositions, and keeps one compiled file available in an interactive
shell with query, description, consistency, equivalence, and safe reload operations. Tokens,
compiled statements, file-backed entries, and query failures now carry half-open Unicode
code-point spans; human diagnostics show the offending source and caret range, while JSON
retains the same structured span and failure class. Phase 6, locking the published extension
sources, semantics, and profiles, is next.
[PLAN.md](PLAN.md) is the only active plan; it
completely supersedes the old regulatory-verification product and proposed human study.

## What TFL is intended to provide

TFL programs state classifications, exclusions, facts, relations, and rules. Queries ask
what those statements support. The language is open-world: failure to prove something is
not automatically proof that it is false. Results will distinguish positive support,
negative support, support for both sides, lack of support for either side, and an incomplete
search. Supported answers will retain their formal proof and source provenance.

The project will not quietly turn TFL into a differently spelled Prolog or Datalog. Any
query-variable or recursive-rule layer must have defined semantics, must preserve existing
core behavior, and must identify its contribution in proof output. Practical value is also
not assumed: the roadmap ends with concrete comparative applications that record where TFL
is uniquely useful, merely competitive, or worse.

## Existing correctness evidence

The OCaml kernel agrees with the frozen JavaScript reference on 884,000 generated inputs
plus the reference corpus. Its categorical core is also checked against a finite-model
oracle and a 62-case literature audit, and its total guarded API has survived 102,000
adversarial inputs.

Those results are strong evidence for the implementation behavior they cover, not a claim
of formal verification. The shared oracle does not model TFL quantity levels, relational
search is incomplete and may return `Unknown`, and the numerical layer can certify some
valid arguments but cannot decide invalidity in general. These limits remain explicit in
the new language contract.

## Build and test

The project requires [opam](https://opam.ocaml.org/) with OCaml 4.14.4. The supported
compiler range is the security-fixed 4.14 line (`>=4.14.4` and `<5.0`). Node 18 or newer
is required only for development-time differential tests against the frozen JavaScript
reference.

```bash
opam install . --deps-only --with-test --locked
opam exec -- dune build
opam exec -- dune test
```

`--with-test` deliberately installs the larger offline test and retained legacy-translation
development graph. A normal Horos package installation selects no Lwt, Cohttp, TLS, or
Mirage Crypto dependency; the shipped `tfl` and `horos` commands have no network client.

Save a program such as this as `knowledge.tfl`:

```text
±Socrates*+Man
−Man+Mortal
```

The human command works from any directory after installation:

```bash
tfl check knowledge.tfl
tfl query knowledge.tfl '±Socrates*+Mortal'
tfl describe knowledge.tfl 'Socrates*'
tfl render '−Man+Mortal'
tfl repl knowledge.tfl
```

Add `--json` to a one-shot command to request a stable `tfl-cli-0.1` machine record;
`tfl repl --json FILE.tfl` instead emits a `tfl-repl-0.1` JSON-lines session stream. The
separate `horos` executable remains the long-lived JSON-lines engine boundary. For example:

```bash
printf '%s\n' '{"cmd":"query","program":"+-Socrates*+Man\n-Man+Mortal","query":"+-Socrates*+Mortal"}' | opam exec -- dune exec bin/tfl_cli.exe
```

## Repository layout

- `PLAN.md` — the authoritative language roadmap and acceptance checks.
- `docs/core-language.md` — the normative `core-0.1` syntax, semantics, result, and limits
  reference; `docs/port-spec.md` is its detailed mechanics appendix.
- `docs/runtime-api.md` — the total OCaml runtime and `horos-runtime-0.1` JSON contract.
- `docs/command-line.md` — `.tfl` file, human command, REPL, JSON/session mode,
  diagnostic-location, and exit-status contracts.
- `data/conformance/core-0.1.json` — language-neutral normative examples checked by the
  test suite.
- `lib/tfl/` — syntax, inference, program, rendering, and safety kernel.
- `lib/verify/` — the current proof-trace verification API, retained as a foundation.
- `bin/` — the current JSON-lines process boundary.
- `test/` — unit, core conformance, literature, oracle, differential, and robustness
  suites.
- `engine/` — the frozen JavaScript reference inherited from the original implementation.
- `translate/`, `router/`, `bench/`, `analysis/`, and much of `data/` and `docs/` — legacy
  research artifacts. They remain for provenance but are not active product tracks.

The project is MIT licensed.
