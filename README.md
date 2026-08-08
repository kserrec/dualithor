# tfl-language

An in-development, proof-producing logic programming language based on Term Functor Logic
(TFL), implemented in OCaml.

The project is being rebuilt around the language that was already hiding inside the former
TFL-Verify research system. The existing engine can parse TFL, decide supported fragments,
run multi-line programs, answer ground proposition and term queries, check consistency,
compare propositions for equivalence, and return proofs or certificates. The new work is to
turn that kernel into a complete language product: `.tfl` files, a human command line, a
REPL, answer variables, a defined rule and recursion layer, modules, diagnostics,
provenance, debugging, data interfaces, editor support, packaging, and real application
comparisons.

**Current status (2026-08-08):** the replacement roadmap is complete, but no implementation
phase has started. [PLAN.md](PLAN.md) is the only active plan. It completely supersedes the
old regulatory-verification product and proposed human study.

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

The project requires [opam](https://opam.ocaml.org/) with OCaml 4.14 or newer. Node 18 or
newer is required only for development-time differential tests against the frozen
JavaScript reference.

```bash
opam install . --deps-only --with-test
opam exec -- dune build
opam exec -- dune test
```

The current executable is still a JSON-lines engine boundary while the human-facing `tfl`
command is pending. For example:

```bash
printf '%s\n' '{"cmd":"check","premises":["-M+P","-S+M"],"conclusion":"-S+P"}' | opam exec -- dune exec bin/tfl_cli.exe
```

## Repository layout

- `PLAN.md` — the authoritative language roadmap and acceptance checks.
- `lib/tfl/` — syntax, inference, program, rendering, and safety kernel.
- `lib/verify/` — the current proof-trace verification API, retained as a foundation.
- `bin/` — the current JSON-lines process boundary.
- `test/` — unit, conformance precursor, literature, oracle, differential, and robustness
  suites.
- `engine/` — the frozen JavaScript reference inherited from the original implementation.
- `translate/`, `router/`, `bench/`, `analysis/`, and much of `data/` and `docs/` — legacy
  research artifacts. They remain for provenance but are not active product tracks.

The project is MIT licensed.
