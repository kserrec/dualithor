# Security

Horos is currently a local OCaml library, a JSON-lines command process, and the
human-facing `tfl` command. It has no network server, authentication layer,
browser surface, or multi-user state. Its primary hostile-input boundary is
nevertheless real: formulas, JSON, paths, and source files may come from language
models, scripts, repositories, or future integrations and must be treated as
untrusted.

The repository also retains an optional OpenRouter translation client from the
earlier research system. Invoking that client sends supplied text to a hosted
model and uses a local API key; it is not part of the current core-language
runtime.

Report a vulnerability privately to `kserrec@gmail.com`. Do not put a live
credential or private corpus in a public issue. Ordinary non-sensitive defects
can use the repository's GitHub issue tracker.

## Security boundaries

Untrusted complete programs must enter through `Tfl.Runtime`; individual propositions may
enter through `Tfl.Safe`, and external process requests enter through `bin/tfl_cli.ml`.
They must not use the low-level parser and inference modules directly. Those low-level modules
remain available to trusted OCaml callers and do not independently promise
hostile-input resource isolation.

The guarded boundaries enforce these limits:

| Boundary | Limit | Refusal |
|---|---:|---|
| One JSON-lines request | 1,048,576 bytes | Protocol error with class `resource_limit`; the rest of the line is drained so later requests remain synchronized |
| One proposition source | 65,536 bytes | `resource_limit` |
| One argument | 1,024 premises and 1,048,576 combined source bytes | `resource_limit` attributed to `argument` |
| One program | 1,048,576 bytes total, 65,536 bytes per line, 10,000 physical lines, and 1,024 parsed propositions | `resource_limit` |
| One `.tfl` path | Opened target must be a regular file; read is capped at 1,048,576 bytes | `file` refusal for pipes, devices, sockets, and directories; `resource_limit` for excess bytes |
| Parser nesting | 64 open parentheses or brackets | `syntactic` refusal before recursive descent |
| Complete truth-table equivalence | 16 atoms, at most 8,388,608 estimated DNF bytes, and at most 8,388,608 estimated AST-node visits | Falls back to bounded, incomplete rewrite equivalence |

`Tfl.Safe` tokenizes accepted proposition text once, returns a structured
result instead of raising, and distinguishes `lexical`, `syntactic`,
`outside_fragment`, `resource_limit`, and unexpected `internal` failures.
The CLI reads incrementally rather than calling `input_line`, so its request
limit applies before JSON parsing or whole-line allocation.

Quoted names reject C0 and C1 controls, including terminal escape characters,
and Unicode bidirectional formatting controls. Independently, the human `tfl`
boundary visibly escapes controls, malformed bytes, bidi marks, and zero-width
formatting in every interpolated field. Operating-system filenames can therefore
be diagnosed without executing a terminal sequence or forging a second line.

The `.tfl` loader checks the path type, opens with nonblocking and close-on-exec
flags, then verifies the opened descriptor is still regular before reading. The
second check closes the type-check/open race for nonregular replacements; a FIFO
or symlink to one cannot wait for a writer before refusal.

## Secrets and repository data

- `OPENROUTER_API_KEY` belongs only in a local, owner-protected dotenv file.
  `.env`, `*.env`, `.env.*`, and `*.env.*` are ignored in every directory, and
  CI rejects any tracked dotenv filename. Tests, cached replies, and usage
  records must never contain the credential.
- Third-party benchmark corpora and cached model output stay under ignored
  data directories. CI checks that `data/raw/`, `data/results/`,
  `data/eval/`, and `data/cache/` remain ignored and untracked.
- The 2026-08-09 history scan found no credential-shaped value in tracked
  history and no tracked dotenv file.

## Build and dependency integrity

- The supported compiler line is OCaml `>= 4.14.4` and `< 5.0`. This
  excludes the audited OCaml 4.14.1 vulnerabilities OSEC-2026-01,
  OSEC-2026-04, and OSEC-2026-05.
- `horos.opam.locked` fixes the complete tested dependency graph, and CI
  installs it with `opam install --locked --with-test`. Every package reachable
  only through the retained translation client or test suite keeps its
  `with-test` filter in the transitive lock.
- A normal Horos install selects OCaml, Dune, `yojson`, and OCaml's base Unix
  support; it does not select Lwt, Cohttp, TLS, or Mirage Crypto. Those roughly
  70 packages remain available only for offline tests and manual development of
  the historical translation client.
- Mirage Crypto 2.3.0 fixes OSEC-2026-14 and OSEC-2026-15. Until that release
  reaches the official opam index, the four interdependent Mirage Crypto
  packages used by the development-only network graph are source-pinned to the
  peeled upstream v2.3.0 commit
  `00ed1238df988c6c109c753cedb87388d352a60c`. The test-only version floors remain
  in `dune-project`; the temporary source pins can be removed after indexing.
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
- A regular file can still wait on an unavailable network filesystem. Phase 33
  owns enforceable wall-time and cancellation controls; the Phase 3 hardening
  closes the immediately exploitable local FIFO/device case without claiming a
  portable filesystem deadline that OCaml 4.14 cannot enforce safely here.

## Audit history

- **2026-08-11:** audited the `f0da18c` maintenance delta and re-swept the full
  reachable product. Confirmed the new inference work budget is correctly wired
  to the public `resource_limit` class on both the `Tfl.Safe` and `Tfl.Runtime`
  boundaries, with live hostile probes (a 69-byte and a width-20,000 compound
  refused in well under a second on `query` and `consistency`, the stream
  recovering afterward). Found and fixed one real resource-exhaustion defect the
  maintenance budget missed: the `describe` operation's candidate-subsumption
  step is quadratic in the collected candidate count, and that count follows the
  program's proposition count rather than the line cap, so a legal ~9 KB program
  of ~1,000 same-subject facts ran the lockstep stream for ~6 seconds of CPU.
  The fix threads a single shared work budget through `query_term_detailed`'s
  main saturation and every pairwise `implies` search, so exhaustion now refuses
  as `resource_limit` in under a second and the stream stays synchronized;
  generator-scale inputs (≤5 candidates) stay far under the 8,000,000-node
  budget, so no differential-compared result changed. Pinned by a
  `test/test_program.ml` regression that fails if either saturation loses the
  shared budget, and by a `test/test_cli.ml` process-boundary gate (added in the
  same-day test audit) that fails if a dense-program `describe` is answered
  instead of refused as `resource_limit`. No secret, command-injection,
  path-traversal, network, or CI exposure was found; the legacy OpenRouter client
  remains dev-only and TLS-verified.
  A test audit the same day falsified the invariant-guarding suites (work-budget,
  request-size, terminal escaping, regular-file, and verdict tests) — every
  mutation was caught — and found no worthless or wrong-target test.
- **2026-07-30:** restricted the CI token to `contents: read`; identified and
  then bounded cancellation search.
- **2026-08-01:** added ignore and CI tracking guards for licensed corpora and
  cached model data; recorded parser and equivalence amplification risks.
- **2026-08-10:** audited the Phase 2 delta (the `Tfl.Runtime` production API,
  the `horos-runtime-0.1` JSON-lines commands, and the Horos rename) with live
  hostile-input probes: million-level JSON nesting, oversized requests,
  premise floods under the request cap, terminal-control and invalid UTF-8
  bytes in program text, saturation-heavy term descriptions, and over-deep
  query nesting. Every probe was refused with the documented class and the
  process stayed synchronized; invalid bytes are replaced with U+FFFD before
  any echo, so replies remain valid UTF-8 JSON. Confirmed `unknown` never
  carries fabricated support, engine refusals classify as `outside_fragment`
  rather than `internal`, the package rename left CI's pinned, read-only,
  path-based workflow intact, and the commit adds no secret or stale-name
  leak. No new finding; no code change required.
- **2026-08-10:** audited the Phase 3 `.tfl` loader and human command. Concrete
  hostile filenames proved raw ESC/newline terminal injection, and a named-pipe
  probe proved that `open_in_bin` could wait indefinitely before the documented
  byte bound began. Fixed both boundaries with visible field escaping and a
  nonblocking, descriptor-verified regular-file loader; added direct FIFO,
  symlink, control-path, malformed-byte, and invalid-path regressions. Expanded
  dotenv ignores and CI tracking guards to every naming variant. Moved the
  legacy Lwt/Cohttp/TLS/Mirage graph behind `with-test` throughout the generated
  manifest and transitive lock, leaving the installed commands network-free.
  The locked dependency solve, full forced suite, opam lint, and an
  isolated-prefix install/check/query all passed under OCaml 4.14.4.
- **2026-08-10:** mutation-audited the Phase 3 regression tests after the
  security fixes. Ten deliberately invalid boundary changes initially survived:
  install-name drift, removal of nonblocking/close-on-exec/post-open checks,
  unbounded file reading, wrong output streams, truncated diagnostics, duplicate
  machine flags, incomplete control escaping, uppercase suffix acceptance,
  regular-symlink refusal, and internal-status misclassification. Added
  deterministic regressions for every case plus a clean non-test installation
  job that rejects any dependency beyond Dune and `yojson` before installing and
  invoking the public `tfl` executable outside the checkout.
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
