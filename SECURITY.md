# Security

TFL-Verify is a research system: an OCaml library that decides term-logic arguments, plus
(from Phase 2) a pipeline that sends text to a hosted language model and records the
results. It has no server, no authentication, and no multi-user state, so most of the
usual web threat model does not apply. What it does have is a **parser and decision
engine fed by language-model output** — untrusted text by construction — and, from Phase
6, an API key and cached spend records on disk.

Reporting a problem: open a GitHub issue, or mail the address in `CITATION.cff` once it
exists. There is no embargo process; this is a research tool, not a service.

## What we protect

1. **The API key.** `OPENROUTER_API_KEY` lives in `.env`, which is gitignored. Result
   files and `data/usage.jsonl` carry token counts, costs and model ids — never
   credentials.
2. **The repository's history.** Third-party benchmark corpora (ProofWriter, FOLIO,
   LogicBench, …) carry their own licences and must never be committed to this MIT repo.
   `data/raw/`, `data/results/` and `data/eval/` are gitignored, and CI fails if an
   ignore rule is dropped or a corpus file becomes tracked. Our own authored data
   (`data/policybench/`) is ours and is committed deliberately.
3. **Bounded work on hostile input.** The engine must not hang or exhaust memory on
   anything a language model can emit. `Tfl.Safe` is the total entry point: it never
   raises, classifies every refusal, and caps nesting depth (PLAN 1.14,
   `docs/engine-surface.md`). Everything downstream of the translation layer must call
   the engine through it.

## Known trust decisions

Recorded so future audits do not re-litigate them. Each says what the exposure is, why
it is acceptable today, and what would change that.

### Accepted, by design

- **The JS reference engine ships in the repo.** `engine/` is ~200 KB of frozen
  JavaScript, vendored permanently as the port's executable specification. It is
  dev-time only: nothing in the OCaml library or the pipeline executes it, and the
  differential harness that does is a test. Kept because reproducing the port's
  verification requires it.
- **`engine/shim.js` spawns Node from the test harness.** Its command is built with
  `Filename.quote` around a constant path, and its dispatch table is prototype-safe.
  Test-only; never shipped or reachable from the library.
- **The 2-SAT split search in `check_inconsistent` is exponential on paper.** No slow
  instance has been constructible. Scaled 2026-08-01 to 30 disjoint universals and a
  25-long implication chain: flat at ~0.15s, and that 0.15s is the cancellation budget
  below, not the search. Would need revisiting if a slow instance is ever found.
- **The cancellation budget costs a constant ~0.15s.** `find_cancellation` explores up to
  500,000 nodes before giving up (PLAN 1.14d), so any inconsistent set with roughly ten
  or more universals pays that in full. Deliberate: the alternative was an uncapped
  4^u search measured at days. Certificate decoration only — verdicts are decided before
  it runs.

### Deferred to Phase 8.4, where they become reachable

Both are inherited from the frozen reference (verified against it), both are unreachable
through `Tfl.Safe` today, and both become real when the CLI and Python client expose the
library directly or someone wraps it in a service.

- **`decide_equivalence` can be made to run for ~33 minutes by a ~160-byte input.**
  `statement_model` caps a proposition at 16 atoms, but `decide_equivalence` then
  enumerates every assignment of the *union* of both propositions' atoms, uncapped — up
  to 2³². Measured ×4 per two atoms added: 0.80s at 2²¹, 3.59s at 2²³, 15.68s at 2²⁵.
  Fix: cap the union and fall back to the rewrite method.
- **The parser allocates roughly 120× the input size.** `Notation.decode` builds a cons
  list of every code point (24 bytes per character) before converting to an array, and
  `Safe.parse` decodes the source twice. Measured: 20 MB in, 2.4 GB allocated, 1.38 GB
  peak heap; time stays linear at ~0.35 s/MB. A ~100 MB input would want ~7 GB and be
  killed. Fix: decode into a pre-sized array in one pass and let `Safe.parse` reuse the
  tokens it already built.

### Planned as release hygiene (Phase 8.5)

- **opam dependencies are unpinned** and **GitHub Actions are pinned to mutable major
  tags** (`actions/checkout@v4`, `ocaml/setup-ocaml@v3`). Acceptable while the repo is
  pre-release and CI only builds and tests with a read-only token; pinning lands with the
  rest of release hygiene.

## Audit history

- **2026-07-30** — first full audit. Fixed: CI token narrowed to `contents: read`. Found
  and deferred: the uncapped `find_cancellation` search (landed as PLAN 1.14d). Hygiene
  sweep clean.
- **2026-08-01** — second full audit. Fixed: `data/raw/`, `data/results/` and
  `data/eval/` gitignored with a CI guard, closing a gap where CLAUDE.md promised a
  protection that did not exist. Deferred: the two 8.4 items above. Re-verified: no
  secrets in the working tree or in git history, CI is `on: push` with no
  `pull_request_target`, four well-known opam dependencies with no install scripts, zero
  npm dependencies.
