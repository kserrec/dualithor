# TFL command-line reference

| Contract metadata | Value |
|---|---|
| Human executable | `tfl` |
| Machine-output schema | `tfl-cli-0.1` |
| Introduced | 2026-08-10 |
| Language contract | `core-0.1` |

The `tfl` executable is the human-facing interface for one complete TFL source file. It is
separate from the long-lived `horos` JSON-lines process documented in
[runtime-api.md](runtime-api.md). The two interfaces call the same total `Tfl.Runtime`
operations and cannot change a logical result.

## `.tfl` source files

A source path must have the case-sensitive `.tfl` suffix. Its bytes must be well-formed
UTF-8 and must fit the existing one-mebibyte program-source limit. The file contains the
same line-oriented `core-0.1` program accepted by `Tfl.Runtime.compile`: after surrounding
whitespace and a trailing `--` comment are removed, every nonblank physical line is one
proposition. Imports, declarations, query syntax, and commands are not source-file syntax
in this phase.

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
tfl [--json] --help
```

`PROPOSITION` and `TERM` are each one operating-system argument. Shell users must quote an
expression when it contains spaces or shell-significant characters.

`--help` and `-h` print the command reference and exit successfully. With `--json`, help is
a successful `help` operation whose `usage` field contains the same reference text.

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
`unknown` with status `1`.

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
location applies. The process exit status and the JSON `exit_status` field always agree.

The command does not require an account, network connection, model, or new external
package. File reading, UTF-8 validation, argument parsing, and exit classification use the
OCaml standard library; `yojson`, already required by the existing process boundary,
serializes explicit machine mode.
