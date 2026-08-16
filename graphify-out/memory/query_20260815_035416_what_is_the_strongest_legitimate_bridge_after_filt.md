---
type: "query"
date: "2026-08-15T03:54:16.215275+00:00"
question: "What is the strongest legitimate bridge after filtering low-confidence name collisions?"
contributor: "graphify"
outcome: "useful"
source_nodes: ["run_repl", "main", "parse_repl_command", "run_repl_query", "run_repl_describe", "run_repl_consistency", "run_repl_equivalence", "emit_repl_result", "emit_repl_failure"]
---

# Q: What is the strongest legitimate bridge after filtering low-confidence name collisions?

## Answer

Expanded from the query via graph vocabulary: [architecture, calls, confidence, correctness, filter, name, relations, source, structural, verification]. Using current production OCaml nodes under bin/, lib/, and translate/, removing .mli interfaces, self-loops, all edges below EXTRACTED confidence 1.0, and all defines edges, run_repl at bin/tfl_command.ml:L725 is the strongest legitimate flow bridge by betweenness centrality at 0.004732. It has 15 verified call edges, including main to run_repl, and run_repl to parse_repl_command, run_repl_query, run_repl_describe, run_repl_consistency, run_repl_equivalence, load_or_fail, reload_repl, emit_repl_result, and emit_repl_failure. These cross from REPL Command Execution into REPL Command Parsing, Human Command Presentation, and TFL Command Runner. The source from lines 725-807 confirms the control flow. tokenize has broader distinct-community reach but lower betweenness at 0.003494, so run_repl is the direct answer under the bridge metric.

## Outcome

- Signal: useful

## Source Nodes

- run_repl
- main
- parse_repl_command
- run_repl_query
- run_repl_describe
- run_repl_consistency
- run_repl_equivalence
- emit_repl_result
- emit_repl_failure