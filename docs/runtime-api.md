# Dualithor public runtime API

| Contract metadata | Value |
|---|---|
| Schema | `dualithor-runtime-0.1` |
| Introduced | 2026-08-09 |
| Product and schema identity updated | 2026-08-15 |
| Source-span fields added | 2026-08-11 |
| OCaml module | `Tfl.Runtime` |
| Process | `dualithor` (`bin/tfl_cli.exe` in the source tree) |
| Human command | `tfl`, specified separately in [command-line.md](command-line.md) |

This is the production boundary for executing a complete `core-0.1` TFL program. The
lower-level `Tfl.Program` module deliberately retains partial parses for tooling and
conformance work; callers executing untrusted program text use this runtime instead.

## Complete-program compilation

`Tfl.Runtime.compile` accepts one UTF-8, line-oriented program and returns an abstract
compiled value only when every nonblank, non-comment line parses and passes the standing
core-fragment validation. It never returns a value containing only the valid subset of a
malformed source. Independent bad lines are returned together as `Tfl.Safe.failure` records
and retain their `line N` attribution, original physical source line, and half-open source
span. Parser-local `position`/`end_position` values remain zero-based Unicode code-point
offsets into the individual input for compatibility. The structured span is authoritative
across complete programs: its start and end positions contain one-based line and column
plus an explicitly named zero-based `codepoint_offset` into the complete input.

The compiled value is abstract. `Tfl.Runtime.statements` exposes immutable source records
containing the line number, original physical line, comment-stripped source, half-open
source span, canonical source spelling, inference canonical form, and deterministic English
reading. A file loader adds the exact path without changing the span. A caller cannot
construct a partially validated runtime program by filling a public record itself.

Every operation is total: it returns `Ok` or a classified `Tfl.Safe.failure`, and no parser,
validation, inference, or rendering exception crosses the boundary. Existing byte, line,
nesting, proposition-count, proof-search, and equivalence-work limits still apply.
Non-atomic saturation has an 8,000,000-term-node work budget; one argument shares it across
direct, indirect, and contradictory-side proof attempts. Exhaustion returns
`resource_limit` attributed to the operation, with no logical result, and does not invalidate
or mutate the compiled program.

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

Responses are always well-formed UTF-8. Yojson can accept a malformed byte inside a JSON
string, so the process represents each such byte in response display strings as the four
ASCII characters `\\xNN`, with uppercase hexadecimal digits, rather than replaying invalid
UTF-8 through a diagnostic's raw `source_line`.

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
{"ok":true,"schema":"dualithor-runtime-0.1","operation":"..."}
```

Compile or operation failures contain `ok:false`, the same schema, and an `errors` array.
Every error has `class`, `message`, `position`, `end_position`, `where`, `span`, and
`source_line`; null means that field does not apply. `position` and `end_position` are the
legacy half-open, zero-based Unicode code-point range in the individual parser input.
`span.start` and `span.end` each contain `line`, `column`, and `codepoint_offset`, so a byte
index cannot be mistaken for a character column. Lexical and syntactic parser failures
underline the offending token, including a zero-width end-of-input error; an
`outside_fragment` operation failure spans the complete parsed proposition or term.
`internal` failures deliberately carry no source excerpt because they classify an
implementation defect, not bad user input. Malformed protocol JSON and missing or wrongly
typed request fields remain protocol errors rather than runtime records.

The public diagnostic vocabulary keeps `lexical`, `syntactic`, `name_resolution`,
`outside_fragment`, `incomplete_search`, `resource_limit`, and `internal` distinct.
`name_resolution` is currently dormant because this language version has no declarations;
Phase 17 must use the shared source-span type when it adds them. A query that completes its
work budget but reaches an incomplete logical bound reports that abstention through the
result's `completeness` record. Exceeding the inference work budget is instead a
`resource_limit` operation failure, never disguised as `unknown` or non-entailment.

The older `check`, `parse`, and `render` commands remain available with their existing
response shapes. Their error records receive the same additive range metadata: the legacy
`pos` remains, while `end_pos`, `span`, and `source_line` carry the new boundary. This
preserves callers using the original argument-checking boundary while the complete-program
commands add the production runtime.

The one-shot human `tfl` commands are not a second JSON-lines request protocol. They load
one UTF-8 `.tfl` file, print terminal-oriented text by default, and emit one `tfl-cli-0.1`
record when the user requests `--json`. `tfl repl` instead loads the file once and accepts
plain interactive command lines; its optional `tfl-repl-0.1` JSON-lines output records one
result per command while keeping the session alive after handled failures. Both structured
surfaces reuse the serializers above so proof, completeness, and evidence records cannot
drift from this process boundary. The command grammar and session contract are specified
in [command-line.md](command-line.md).
