# data/

- `raw/` — downloaded benchmark corpora (ProofWriter, FOLIO, …). **Gitignored:**
  they carry their own licenses and must never enter this MIT repo's history.
- `eval/` — filtered evaluation sets derived from `raw/`. Gitignored.
- `results/` — per-item baseline and pipeline results. Gitignored.
- `policybench/` — our own authored benchmark items; committed.

CI fails if any of the gitignored directories becomes tracked.
