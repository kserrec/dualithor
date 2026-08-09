# Security

TFL Language is currently a local OCaml library and a JSON-lines command
process. It has no network server, authentication layer, browser surface, or
multi-user state. Its primary hostile-input boundary is nevertheless real:
formulas and JSON may come from language models, files, pipes, or future
integrations and must be treated as untrusted.

The repository also retains an optional OpenRouter translation client from the
earlier research system. Invoking that client sends supplied text to a hosted
model and uses a local API key; it is not part of the current core-language
runtime.

Report a vulnerability privately to `kserrec@gmail.com`. Do not put a live
credential or private corpus in a public issue. Ordinary non-sensitive defects
can use the repository's GitHub issue tracker.

## Security boundaries

Untrusted text must enter through `Tfl.Safe` or `bin/tfl_cli.ml`, not through
the low-level parser and inference modules directly. Those low-level modules
remain available to trusted OCaml callers and do not independently promise
hostile-input resource isolation.

The guarded boundaries enforce these limits:

| Boundary | Limit | Refusal |
|---|---:|---|
| One JSON-lines request | 1,048,576 bytes | Protocol error with class `resource_limit`; the rest of the line is drained so later requests remain synchronized |
| One proposition source | 65,536 bytes | `resource_limit` |
| One argument | 1,024 premises and 1,048,576 combined source bytes | `resource_limit` attributed to `argument` |
| One program | 1,048,576 bytes total, 65,536 bytes per line, 10,000 physical lines, and 1,024 parsed propositions | `resource_limit` |
| Parser nesting | 64 open parentheses or brackets | `syntactic` refusal before recursive descent |
| Complete truth-table equivalence | 16 atoms, at most 8,388,608 estimated DNF bytes, and at most 8,388,608 estimated AST-node visits | Falls back to bounded, incomplete rewrite equivalence |

`Tfl.Safe` tokenizes accepted proposition text once, returns a structured
result instead of raising, and distinguishes `lexical`, `syntactic`,
`outside_fragment`, `resource_limit`, and unexpected `internal` failures.
The CLI reads incrementally rather than calling `input_line`, so its request
limit applies before JSON parsing or whole-line allocation.

Quoted names reject C0 and C1 controls, including terminal escape characters,
and Unicode bidirectional formatting controls. This prevents a future
human-facing terminal command from printing a name that executes a control
sequence or visually reverses the formal source.

## Secrets and repository data

- `OPENROUTER_API_KEY` belongs only in the gitignored `.env` file. The
  current local file is mode `0600`; a new checkout or copied secret file
  should preserve owner-only permissions. Tests, cached replies, and usage
  records must never contain the credential.
- Third-party benchmark corpora and cached model output stay under ignored
  data directories. CI checks that `data/raw/`, `data/results/`,
  `data/eval/`, and `data/cache/` remain ignored and untracked.
- The 2026-08-09 history scan found no credential-shaped value in tracked
  history and no tracked `.env` file.

## Build and dependency integrity

- The supported compiler line is OCaml `>= 4.14.4` and `< 5.0`. This
  excludes the audited OCaml 4.14.1 vulnerabilities OSEC-2026-01,
  OSEC-2026-04, and OSEC-2026-05.
- `tfl-language.opam.locked` fixes the complete tested dependency graph, and
  CI installs it with `opam install --locked`.
- Mirage Crypto 2.3.0 fixes OSEC-2026-14 and OSEC-2026-15. Until that release
  reaches the official opam index, the four interdependent Mirage Crypto
  packages are source-pinned to the peeled upstream v2.3.0 commit
  `00ed1238df988c6c109c753cedb87388d352a60c`. The version floors remain in
  `dune-project`; the temporary source pins can be removed after indexing.
- GitHub Actions are pinned to full immutable commit hashes, and the workflow
  token has only `contents: read`.
- The generated opam metadata passes `opam lint`. The locked graph and the
  repository build were both verified in an isolated OCaml 4.14.4 switch with
  Mirage Crypto 2.3.0.

The lockfile is a reviewed snapshot, not an instruction to ignore future
advisories. Updating a dependency requires regenerating the lockfile and
rerunning the dependency audit and full test gates.

## Accepted and unreachable risks

- `engine/` is the frozen JavaScript reference used by development-time
  differential tests. Production OCaml code does not execute it.
- The test shim launches a constant Node path with quoting and a fixed dispatch
  table. It is not reachable from the shipped OCaml library or JSON command.
- `find_cancellation` has a 500,000-node budget and may spend roughly 0.15
  seconds before omitting optional certificate decoration. The logical verdict
  is established before this search.
- The atomic consistency procedure contains a theoretical exponential split
  search. Repeated scaling probes through 30 disjoint universals and a
  25-link implication chain remained flat at the cancellation budget. Revisit
  this if a concrete slower input is found.
- Rewrite equivalence is intentionally incomplete. Exceeding a truth-table
  resource budget can therefore turn a complete comparison into a documented
  rewrite result, never into a false claim of completeness.

## Audit history

- **2026-07-30:** restricted the CI token to `contents: read`; identified and
  then bounded cancellation search.
- **2026-08-01:** added ignore and CI tracking guards for licensed corpora and
  cached model data; recorded parser and equivalence amplification risks.
- **2026-08-09:** audited the full working session and complete 70-package
  dependency graph. Fixed streaming request allocation, duplicate parser
  tokenization, proposition/program/argument size bounds, DNF output and work
  amplification, terminal-control names, public `resource_limit`
  serialization, non-object JSON crash handling, vulnerable compiler and
  crypto floors, the dependency lockfile, immutable Actions pins, local `.env`
  permissions, and stale security documentation. Revalidated the hardened port
  with all 18 differential gates (884,000 generated inputs plus the corpus) in
  the locked OCaml 4.14.4 switch. No secret exposure, command injection, path
  traversal, authentication/session defect, or HTML injection surface was
  found in the current reachable product.
