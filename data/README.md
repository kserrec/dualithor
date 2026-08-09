# data/

- `conformance/` — committed, language-neutral executable examples for the normative TFL
  contracts. `core-0.1.json` is checked by `test/test_conformance.ml`.
- `fidelity/` — legacy translation-study inputs and audit artifacts retained as historical
  evidence; it is not an active product track.
- `raw/` — downloaded benchmark corpora (ProofWriter, FOLIO, …). **Gitignored:**
  they carry their own licenses and must never enter this MIT repo's history.
- `eval/` — filtered evaluation sets derived from `raw/`. Gitignored.
- `results/` — per-item baseline and pipeline results. Gitignored.
- `policybench/` — our own authored benchmark items; committed.

CI fails if any of the gitignored directories becomes tracked.
