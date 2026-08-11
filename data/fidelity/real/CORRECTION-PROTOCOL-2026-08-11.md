# Sentence-order correction protocol — 2026-08-11

This is a **post-discovery correction record**, not a preregistration. It was
written after the sentence-order defect was found and after the 2026-08-02
samples and report already existed. It preserves the original protocols and
artifacts while defining the corrected deterministic extraction run.

## Verified defect

`bench/cfr.ml` accumulated sentence slices by prepending them to a list. Its
final expression was:

```ocaml
List.rev_map String.trim !out |> List.rev
```

`List.rev_map` already restored the slices to source order while trimming them.
The final `List.rev` reversed them again. Paragraphs stayed in document order,
but sentences inside each multi-sentence paragraph entered the candidate pool
in reverse order. Because the protocol samples every *k*-th candidate, the bug
also changed which sentences were selected.

The live implementation now ends with `List.rev_map String.trim !out`. A focused
test pins source order. Explicit legacy helpers retain the old reversal solely
to reproduce the historical files.

## What stays fixed

The correction changes no research choice and introduces no new filter:

- the six eCFR XML snapshots and snapshot date are unchanged;
- paragraph extraction, tag removal, entity decoding, marker removal, protected
  abbreviations, and the candidate filter are unchanged;
- the three normative sources, D1 section selection, and D2 parts are unchanged;
- the per-source targets and deterministic every-*k*-th rule are unchanged;
- there is still no upper sentence-length limit and no deduplication.

Only sentence order within each paragraph changes to the document order required
by `PROTOCOL.md`.

## Corrected run

From the repository root, with the original raw XML snapshots in `data/raw/`:

```sh
opam exec -- dune exec bench/sample_real.exe
opam exec -- dune exec bench/sample_defs.exe
```

These commands write:

- `sample-corrected-2026-08-11.jsonl`: 60 normative sentences, 20 per source;
- `sample-defs-corrected-2026-08-11.jsonl`: 50 definitional sentences, with the
  same source-level counts as the original run.

Compared by exact sentence text, 22 of 60 normative rows and 30 of 50
definitional rows also occur in the historical samples. The remaining 58 rows
are different. An old label must never be transferred merely because a row has
the same identifier.

The discontinued regulatory-coverage project has not labeled the corrected
samples, so this correction produces **no corrected coverage percentage**. Any
future measurement must create separately dated labels and a separate report.

## Historical reproduction

The frozen 2026-08-02 samples remain at `sample.jsonl` and
`sample-defs.jsonl`. They can be reproduced explicitly:

```sh
opam exec -- dune exec bench/sample_real.exe -- --legacy
opam exec -- dune exec bench/sample_defs.exe -- --legacy
```

Regeneration on 2026-08-11 left their bytes unchanged:

```text
fe023a4a34df2fd982e8fe764853c5f4256670a7e84812cd1a37878b516c5f82  sample.jsonl
6f4c88a93100800a2c9606e69562e019e292ca9dacaf109f98ae57d06c32b2f6  sample-defs.jsonl
```

See `ERRATUM-2026-08-11.md` for the status of the historical labels, report,
and claims.
