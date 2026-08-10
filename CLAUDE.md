# CLAUDE.md

Guidance for coding agents working in this repository.

## What this is

Horos is an OCaml implementation of a proof-producing logic programming language
based on term logic (TFL). The existing parser, inference engine, program operations,
renderer, and correctness harness are the language kernel. The active job is to build the
complete language described in `PLAN.md` without silently replacing TFL semantics with
those of another logic language.

`PLAN.md` is the only authoritative roadmap. Read its active decision, semantic
commitments, execution rules, and current phase before nontrivial work. The former
regulatory-verification and human-study roadmaps are discontinued; legacy translation,
benchmark, and research assets remain historical evidence and are not selectable work.
`LOG.md` records earlier decisions and surprises and should not be rewritten to make the
old project look as though it never existed.

`docs/core-language.md` is the normative contract for the inherited `core-0.1` language;
`docs/port-spec.md` is its detailed mechanics appendix, and
`data/conformance/core-0.1.json` is its executable, language-neutral example corpus. An
implementation disagreement with those artifacts is a contract defect, not an implicit
language change. `docs/runtime-api.md` specifies the total `Tfl.Runtime` production API and
the `horos-runtime-0.1` JSON-lines boundary. `docs/command-line.md` specifies UTF-8 `.tfl`
files, the human `tfl` executable, `tfl-cli-0.1`, diagnostic locations, and exit statuses.

**Naming convention:** the project is Horos, the repository and package are `horos`; the
language is TFL; the eventual human executable is `tfl`. In ordinary code and documentation, call the logic
“term logic” or “TFL.” Spell out the literature name only where it adds needed context,
because “functor” otherwise means an unrelated OCaml module construct.

## Commands

```bash
opam exec -- dune build
opam exec -- dune test
opam exec -- dune exec test/test_conformance.exe
opam exec -- dune exec test/test_runtime.exe
opam exec -- dune exec test/test_source_file.exe
opam exec -- dune build bin/tfl_command.exe
opam exec -- dune exec test/test_tfl_command.exe

# Both long gates are required after a change to existing OCaml inference behavior.
opam exec -- dune exec test/test_oracle.exe -- -n 20000
opam exec -- dune exec test/test_differential.exe -- -mass

node engine/tfl.test.js
node engine/oracle.js -n 20000
```

The local `default` opam switch uses system OCaml 4.14.1 and is a development convenience,
not a supported release environment. Package and CI verification use the security-fixed
OCaml 4.14.4 contract. `opam exec --` supplies the selected environment. `dune test`
caches results; use `--force` when a real rerun is required.

## Semantic and correctness bar

- Existing verdict semantics never change silently. A changed result requires an explicit
  language decision, documentation, focused regression cases, the 20,000-case OCaml oracle
  gate, and the 884,000-input differential gate wherever the frozen reference applies.
- `Unknown` is not false or invalid. An incomplete procedure says why it abstained.
- Core TFL, conservative logical extensions, query-only syntax, and runtime features remain
  distinguishable in implementation, documentation, and proof provenance.
- Contradictory support cannot be hidden behind whichever proof the runtime found first.
- `engine/` is frozen. It is a regression oracle for inherited behavior, not a place to add
  new language features or manufacture agreement.
- New features require their own independent semantics and tests. English readings are a
  display aid, never the authority for a formal result.

## Engineering principles

- Implement exactly one PLAN phase per pass. If it is too large for one pass, split the
  phase in the plan before changing code.
- Build the smallest complete implementation of the current phase. Do not add plugin
  systems, generalized frameworks, configuration, or abstractions without a current use.
- A dependency must earn its place. Keep `yojson` for the JSON boundary and `qcheck` for
  property testing. The Cohttp/TLS graph exists only for tests and manual development of
  the retained legacy translation client; it must not enter the normal installed Horos
  runtime. Any new dependency needs a real use site and a one-line cost/reason record
  before it is added.
- Tests protect concrete threats: a wrong verdict, hidden incompleteness, changed proof,
  unsafe input, nondeterministic build, or interface drift. Do not add coverage filler.
- Public operations are total and bounded. User mistakes, resource limits, and internal
  defects are different result classes.
- Preserve legacy evidence unless a named phase explicitly migrates or removes it. Never
  rewrite negative results or historical documents to improve the new project narrative.

## Public-repository hygiene

- No secrets, private notes, unexplained binaries, or encoded blobs are committed.
- `.env`, every `*.env`, `.env.*`, and `*.env.*` variant, licensed benchmark corpora,
  model caches, and raw external datasets remain untracked under their existing rules.
- New version-1 examples and tests run offline with no account, model, API key, or network
  dependency.

## Workflow

- `$next` selects the first incomplete phase whose dependencies are complete, implements
  it, verifies it, marks it complete in `PLAN.md`, and stops.
- Each phase ends with its stated acceptance check and a descriptive commit that names the
  phase.
- If a semantic choice is ambiguous, stop with the competing meanings and their concrete
  consequences rather than choosing by convenience.
- OCaml style is plain modules, small functions, variants, and exhaustive matches. Use the
  compiler to make invalid states difficult to represent.
