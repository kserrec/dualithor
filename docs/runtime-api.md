# Horos public runtime API

| Contract metadata | Value |
|---|---|
| Schema | `horos-runtime-0.1` |
| Introduced | 2026-08-09 |
| OCaml module | `Tfl.Runtime` |
| Process | `horos` (`bin/tfl_cli.exe` in the source tree) |

This is the production boundary for executing a complete `core-0.1` TFL program. The
lower-level `Tfl.Program` module deliberately retains partial parses for tooling and
conformance work; callers executing untrusted program text use this runtime instead.

## Complete-program compilation

`Tfl.Runtime.compile` accepts one UTF-8, line-oriented program and returns an abstract
compiled value only when every nonblank, non-comment line parses and passes the standing
core-fragment validation. It never returns a value containing only the valid subset of a
malformed source. Independent bad lines are returned together as `Tfl.Safe.failure` records
and retain their `line N` attribution.

The compiled value is abstract. `Tfl.Runtime.statements` exposes immutable source records
containing the line number, comment-stripped source, canonical source spelling, inference
canonical form, and deterministic English reading. A caller cannot construct a partially
validated runtime program by filling a public record itself.

Every operation is total: it returns `Ok` or a classified `Tfl.Safe.failure`, and no parser,
validation, inference, or rendering exception crosses the boundary. Existing byte, line,
nesting, proposition-count, proof-search, and equivalence-work limits still apply.

## Operations and records

The API exposes all operations implemented by the inherited program kernel:

| Operation | OCaml function | Result |
|---|---|---|
| Compile | `compile source` | abstract program plus stable statement views |
| Ground proposition query | `query program source` | `yes`, `no`, or `unknown`; method, completeness, and support |
| Term description | `describe program source` | deterministic strongest answers, each with its derivation |
| Consistency | `check_consistency program` | `consistent`, `inconsistent`, or `undetermined`; method, completeness, and evidence |
| Equivalence | `equivalent ~left ~right` | Boolean result, method, completeness, and truth-table or rewrite evidence |

A proposition view always contains three distinct fields:

- `tfl`: canonical source spelling, preserving the parsed proposition;
- `canonical`: the current inference identity;
- `english`: deterministic display text, which never determines a result.

Proof lines contain a one-based number, canonical TFL (or `⊥`), English reading, rule name,
and one-based parent numbers. Other evidence variants retain P/Z closure certificates,
numerical-condition records, equivalence rewrite paths, or truth-table rows. These are
stable runtime records; the fully versioned, replayable cross-extension proof schema remains
the separate Phase 29 deliverable.

## Completeness

Every logical result carries `{ complete; reason }`. `complete` describes the decision
procedure, not confidence in a successful proof.

| Method | Complete? | Incomplete reason when applicable |
|---|---:|---|
| Atomic categorical P/Z query or consistency | yes | — |
| Numerical sufficient-condition query | no | `numerical-rule-set` |
| Non-atomic ground search | no | `bounded-search` |
| Term description | no | `bounded-term-saturation` |
| Non-atomic consistency search | no | `bounded-refutation` |
| Numerical consistency | no | `numerical-consistency-unavailable` |
| Eligible propositional truth table | yes | — |
| Immediate-rule equivalence | no | `bounded-rewrite` |

Consequently, an atomic `unknown` is a complete open-world result: neither side follows.
A non-atomic or numerical `unknown` remains procedural incompleteness. Consistency uses
`undetermined`, rather than a bare `true`, when an incomplete search found no contradiction.

## JSON-lines process

Each request is one JSON object on one physical input line. Newline characters inside a
program are JSON escapes. Each request receives exactly one response, including malformed
programs and runtime failures; a refusal cannot terminate the process or consume the next
request. Blank lines are ignored and receive no response.

Long-lived bidirectional callers must use request/reply lockstep: write one request, flush
it, and read its response before sending the next request. Writing an entire batch before
reading can fill both operating-system pipes when a proof or equivalence response is large,
leaving the engine blocked on output while its caller is blocked on input. Shell pipelines
are safe when the downstream process reads responses concurrently.

The Phase 2 commands are:

```json
{"cmd":"compile","program":"-Man+Animal\n+-Socrates*+Man"}
{"cmd":"query","program":"+-Socrates*+Man\n-Man+Mortal","query":"+-Socrates*+Mortal"}
{"cmd":"describe","program":"+-Socrates*+Man\n-Man+Mortal","term":"Socrates*"}
{"cmd":"consistency","program":"+-Socrates*+Man\n+-Socrates*-Man"}
{"cmd":"equivalence","left":"-Dog+Mammal","right":"-(−Mammal)+(−Dog)"}
```

Successful Phase 2 responses contain:

```json
{"ok":true,"schema":"horos-runtime-0.1","operation":"..."}
```

Compile or operation failures contain `ok:false`, the same schema, and an `errors` array.
Every error has `class`, `message`, `position`, and `where`; null means that field does not
apply. Malformed protocol JSON and missing or wrongly typed request fields remain protocol
errors rather than runtime records.

The older `check`, `parse`, and `render` commands remain available with their existing
response shapes. This preserves callers using the original argument-checking boundary while
the complete-program commands add the production runtime.
