# TFL command-line reference

| Contract metadata | Value |
|---|---|
| Human executable | `tfl` |
| Machine-output schema | `tfl-cli-0.1` |
| Interactive-stream schema | `tfl-repl-0.1` |
| Introduced | 2026-08-10 |
| Language contract | `core-0.1` |

The `tfl` executable is the human-facing interface for one complete TFL source file and
for an interactive session over that file. It is separate from the long-lived `horos`
JSON-lines process documented in [runtime-api.md](runtime-api.md). The interfaces call the
same total `Tfl.Runtime` operations and cannot change a logical result.

## `.tfl` source files

A source path must have the case-sensitive `.tfl` suffix and resolve to a regular
filesystem file. Named pipes, devices, sockets, and directories are rejected as file input
without reading content or waiting for a pipe writer; a symbolic link is accepted only
when its opened target is regular. Regular-file bytes must be well-formed UTF-8 and fit the
existing one-mebibyte program-source limit. The file contains the same line-oriented
`core-0.1` program accepted by `Tfl.Runtime.compile`: after surrounding whitespace and a
trailing `--` comment are removed, every nonblank physical line is one proposition.
Imports, declarations, query syntax, and commands are not source-file syntax in this
phase.

Locations are stable across every `tfl` command:

- lines and columns are one-based;
- columns count Unicode code points in the original physical line, not UTF-8 bytes;
- indentation remains part of the location even though the parser ignores it;
- a tab is one source code point, not a display-dependent number of terminal columns;
- line feed separates physical lines; a carriage return before line feed is accepted as
  ordinary language whitespace.

The loader rejects malformed UTF-8 before compilation and reports the first malformed byte
at the line and code-point column where decoding fails. Compilation remains all-or-nothing:
every independently malformed line is reported, and no executable program is returned
from only the valid subset.

## Commands

The machine-output flag may appear once anywhere after `tfl`. Without it, output is plain
text intended for a terminal.

```text
tfl check [--json] FILE.tfl
tfl query [--json] FILE.tfl PROPOSITION
tfl describe [--json] FILE.tfl TERM
tfl render [--json] PROPOSITION
tfl repl [--json] FILE.tfl
tfl [--json] --help
```

`PROPOSITION` and `TERM` are each one operating-system argument. Shell users must quote an
expression when it contains spaces or shell-significant characters.

`--help` and `-h` print the command reference and exit successfully. With `--json`, help is
a successful `help` operation whose `usage` field contains the same reference text.

Human output keeps only the command's own line breaks raw. Control characters from an
interpolated path, diagnostic, or language value are rendered visibly: ASCII controls and
malformed bytes use `\xNN`, while C1, Unicode bidirectional, and zero-width formatting
controls use `\u{NNNN}`. Ordinary well-formed UTF-8 remains unchanged. A hostile filename
therefore cannot clear or retitle the terminal, create a terminal hyperlink, or forge
another output line.

### `check`

`check` loads and compiles the whole file. Success reports the number of executable
statements. This is a syntax, fragment, resource, and compilation check; a logically
inconsistent but well-formed program is not thereby a compile failure.

### `query`

`query` asks whether one ground proposition follows from the compiled file.

- `yes` means the requested proposition has sound support and exits successfully, even
  when the wider procedure is not complete.
- a complete `no` means the contradictory proposition has sound support and the complete
  method establishes logical non-entailment.
- an incomplete `no` still carries sound support for the contradictory, but it does not
  establish that positive support is absent. It therefore uses incomplete-search status.
- a complete `unknown` means neither side follows under the complete atomic-categorical
  procedure. This is open-world non-entailment, not falsity.
- an incomplete `unknown` means the current numerical or bounded search did not decide and
  uses the distinct incomplete-search exit status.

Human output names the method and its completeness. Structured output retains the full
runtime query record, including formal and English forms, evidence, and the explicit
completeness object.

### `describe`

`describe` asks what follows about one term. Every displayed answer has a derivation, but
the current bounded term-saturation procedure does not promise that the returned answer
set is exhaustive. The command therefore exits with incomplete-search status even when it
prints supported answers. Structured output retains every answer and proof.

### `render`

`render` parses one proposition and prints its deterministic English display reading plus
canonical source spelling. It does not load a file or make an inference. English remains a
display aid and never determines the formal parse or a verdict.

### `repl`

`repl` loads and compiles the file once, then keeps that immutable compiled program for a
complete interactive session. The initial load is all-or-nothing and has the same file,
UTF-8, compile, and location behavior as `check`. These commands are accepted one per
physical input line:

```text
query PROPOSITION
describe TERM
consistency
equivalence LEFT <=> RIGHT
reload
help
quit
```

`query`, `describe`, `consistency`, and `equivalence` call the corresponding
`Tfl.Runtime` operation directly. `<=>` is REPL command syntax, not TFL syntax; it separates
the two complete propositions supplied to `equivalence`. `reload` reads the original path
again and replaces the session program only after the entire new file loads and compiles.
A failed reload reports every diagnostic and retains the last valid compiled program.

Malformed operations and unknown commands are recoverable: the shell reports the failure
and reads the next command without changing the loaded program. `quit` and end-of-input
finish a normally initialized session successfully. In a human terminal, `Ctrl-C` cancels
the current input line and leaves the program loaded; `Ctrl-D` on an empty line ends the
session.

When standard input and standard output are terminals and `TERM` does not declare a `dumb`
terminal, the shell enables a small built-in line editor. Up and down arrows navigate up to
the newest 100 nonblank commands, with adjacent duplicates stored once and 16,777,216 total
command bytes retained. History exists only in editing terminals and only in memory for the
current process: TFL source and queries are never written to a history file. If the terminal
does not support this mode, the shell falls back to ordinary bounded line input. No
line-editing library or optional executable is required. Piped and JSON sessions retain no
history.

Piped sessions suppress the `tfl> ` prompt, which makes a transcript deterministic; every
input line is limited to 1,048,576 bytes and an oversized line is drained before the next
command is read. Interactive rendering also has a 16,777,216-byte output budget per input
line. If repeated redraw operations cross that ceiling, the shell discards the current line,
reports a `resource_limit`, and returns to a clean prompt. This keeps correct wrapped-line
redraws without permitting one edited line to produce quadratic unbounded output.

With `--json`, the session is a JSON-lines stream under `tfl-repl-0.1`. It emits one
`ready` record after the initial load, one record for every nonblank command, and one
`quit` record. Successful runtime operations reuse the exact proposition, term, method,
completeness, support, proof, certificate, truth-table, and rewrite encodings from
`horos-runtime-0.1`. Every record has `command_status` and `command_exit_status`; these
describe that command's logical or operational outcome but do not terminate the session.
For example, a malformed query has command status `input-failure`, then the next input line
is still processed. The REPL process itself exits `0` on `quit` or end-of-input. A failure
to initialize the file occurs before the stream exists, uses the ordinary `tfl-cli-0.1`
failure record, and exits with status `2` or `4`.

## Exit statuses

| Status | Name | Meaning |
|---:|---|---|
| `0` | `success` | The file checked, rendering succeeded, or a query received positive support. |
| `1` | `logical-non-entailment` | A complete query method established the contradictory or found support for neither side. |
| `2` | `input-failure` | Usage, path, suffix, file-read, UTF-8, compile, query, term, or proposition input failed. |
| `3` | `incomplete-search` | The requested result or answer set was not decided exhaustively by the current bounded procedure. |
| `4` | `internal-failure` | An unexpected implementation failure reached the command boundary. This is a defect, not user input or a logical result. |

An operation can produce useful output with a nonzero status. In particular, `describe`
can return supported answers with status `3`, and `query` can return an exact open-world
`unknown` with status `1`. Inside a successfully initialized REPL these values are recorded
as per-command outcomes while the process remains available; only initialization and an
unexpected process-level failure determine the REPL process exit status.

## Structured output

`--json` emits exactly one compact JSON object and no human prose. Every object contains:

```json
{
  "ok": true,
  "schema": "tfl-cli-0.1",
  "operation": "query",
  "status": "success",
  "exit_status": 0
}
```

Every structured record, including a handled failure, is written to standard output and
leaves standard error empty. Outside a REPL, human successes and help use standard output,
while human input, file, usage, and internal failures use standard error. A human REPL is
one dialogue, so successful results and recoverable command diagnostics both use standard
output; an initialization failure still uses standard error. This separation lets scripts
parse machine output without merging diagnostic streams.

Successful operations add their corresponding stable runtime fields. File-backed
operations also add `file`; `check` statement records add one-based `line` and `column`.
Query and description results use the same proposition, completeness, support, proof, and
evidence encodings as `horos-runtime-0.1`.

Machine output is always well-formed UTF-8. Valid UTF-8 text is unchanged; if an
operating-system string contains a malformed byte, that byte is represented visibly as the
four ASCII characters `\xNN`, with uppercase hexadecimal digits. The raw path bytes are
still used for filesystem access; this display encoding exists only at the JSON boundary.

Failures set `ok` to `false` and contain an `errors` array. Each error has `class`,
`message`, `source`, `line`, and `column`; a field is JSON `null` only when no source
location applies. For one-shot commands, the process exit status and the JSON
`exit_status` field always agree. REPL stream records instead use `command_exit_status`,
whose deliberately different session behavior is specified above.

The command does not require an account, network connection, or model. File reading, UTF-8
validation, argument parsing, terminal escaping, and exit classification use OCaml's
standard distribution; `yojson`, already required by the existing process boundary,
serializes explicit machine mode. The retained legacy translation client and its
Lwt/Cohttp/TLS dependency graph are test/development-only package dependencies and are not
selected by a normal Horos installation.
