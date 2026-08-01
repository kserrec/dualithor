# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

TFL-Verify: an OCaml system that verifies LLM outputs using term logic (TFL) — translate
natural language into TFL's plus-minus notation, check it symbolically, route on fragment
membership. Deliverables: an open-source system and an arXiv/workshop paper. The goal is
adding to knowledge and making things work better; there is no commercial angle.

Everything here is public (MIT). `PLAN.md` is the canonical plan — read the current phase
before doing nontrivial work. `LOG.md` records decisions and surprises; deviations from the
plan get a one-line rationale there.

**Naming convention:** the logic is called "term logic" or just "TFL" everywhere — code,
comments, docs, commits. The spelled-out name "Term Functor Logic" appears only where the
literature name matters: the README's first line, the paper, CITATION.cff, and outreach.
The word "functor" is otherwise banned from this repo, because in OCaml it means a module
functor — a construct we also avoid in the code unless there is a compelling concrete
need, both for simplicity and to keep the word from ever being ambiguous here.

## Commands

```bash
opam exec -- dune build              # build the OCaml project
opam exec -- dune test               # full suite: units, paper cases, differential, oracle smoke (~4 min)

# The two long gates. Both are required after any change to OCaml engine logic.
opam exec -- dune exec test/test_oracle.exe -- -n 20000      # six fuzz suites vs the semantics (~25 min)
opam exec -- dune exec test/test_differential.exe -- -mass   # 884k inputs vs the JS reference (~13 min)

node engine/tfl.test.js              # JS reference engine test suite (201 asserts)
node engine/oracle.js -n 20000       # JS reference semantic fuzz gate (~2h; consulted, not required)
```

The opam switch is `default` (system OCaml 4.14.1); `opam exec --` supplies the
environment, so no shell setup is needed. `dune test` caches results — use
`--force` when you need to see the counts again.

## Correctness bar

The engine's job is to *certify validity* — a wrong verdict poisons the paper and anything
built on it. The bar is absolute:

- `engine/` (the JavaScript reference) is **frozen**: never extended, never "fixed," only
  consulted. It is the executable specification for the OCaml port.
- Before the differential handover (PLAN 1.12): every port step ends differential-clean
  against the JS reference.
- After the handover: any change touching OCaml engine logic lands only with the unit
  suite, the ported oracle (20k iterations), and the paper-cases suite all green. A red
  oracle is a stop-everything event: report to Kyle, do not patch around it.
- Engine verdict semantics never change silently.

## Engineering principles

- **Lean; never over-engineer.** Build the smallest thing that satisfies the current PLAN
  step. No abstraction before the second concrete use. No config systems, plugin points,
  frameworks, or "flexibility" nobody asked for. Deleting code is a feature.
- **Dependencies must earn their place.** Default is to write it ourselves. Take a
  dependency only when it is (a) a security-hardened surface we must not hand-roll
  (TLS/HTTP), (b) a spec with real depth where self-writing would be silly under time
  constraints, or (c) extremely common and well-vetted. Current approved set, each with
  its reason: `yojson` (JSON parsing is our security boundary with LLM output; well-vetted),
  `cohttp` + TLS stack (never hand-roll TLS), `qcheck` (property testing with shrinking;
  standard). Anything beyond these needs a one-line justification in LOG.md before it's
  added. Dev-only conveniences count as dependencies too.
- **Tests follow features, and every test earns its keep.** Write the feature for the
  current PLAN step first; then write tests in response to the real failure modes that
  feature introduced — a test should name the threat it guards against, not restate the
  implementation. No coverage-chasing filler. The standing suites (unit tests,
  paper-cases, oracle, differential harness) exist because they each answer a real threat:
  wrong verdicts.
- **Honest results, always.** Benchmark numbers are reported as measured. Negative results
  go in the paper's limitations, never in the trash.

## Public-repo hygiene

- No secrets, ever. `OPENROUTER_API_KEY` lives in `.env` (gitignored). Nothing odd or
  opaque in the tree: no unexplained binaries, no encoded blobs, no private notes.
- Keys never leak into logs: `data/usage.jsonl` and result files carry tokens/costs/ids,
  never credentials.
- **Never commit benchmark datasets.** `data/raw/` is gitignored; ProofWriter/FOLIO/etc.
  carry their own licenses. Checked-in fixtures are tiny excerpted slices for tests only.
  Our own authored data (policybench) is ours and is committed.
- LLM spend: all calls cached to disk keyed by (model, item) — never re-spend on an
  identical call; the cost ceiling in config is enforced in code and spend is reported
  after every run.

## Workflow

- One PLAN step per commit, message prefixed with the step id (`1.4: …`). Each step ends
  with its acceptance check passing.
- If a step turns out ambiguous or bigger than a single pass mid-execution, stop and ask
  Kyle rather than guessing.
- OCaml style: `ocamlformat` defaults, small plain modules, variants + exhaustive `match`
  everywhere — the compiler's exhaustiveness check is this project's code review.
