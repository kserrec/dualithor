---
type: "query"
date: "2026-08-15T03:27:10.306301+00:00"
question: "Why is to_string the strongest cross-community bridge?"
contributor: "graphify"
outcome: "corrected"
correction: "Treat bin_runtime_json_to_string as a narrow UTF-8-safe JSON serialization adapter. Its apparent broad centrality comes from terminal-name collisions among unrelated OCaml to_string functions."
source_nodes: ["to_string", "json_with_valid_utf8", "escape_invalid_utf8", "out", "output_json"]
---

# Q: Why is to_string the strongest cross-community bridge?

## Answer

Expanded from the original query via graph vocabulary: [string, output, json, fidelity, audit, cli, schema, llm, notation, source, verification]. The node bin_runtime_json_to_string at bin/runtime_json.ml:L39 has graph degree 38 because 37 stored incident edges include one self-loop, which counts twice. Of those stored edges, 34 are INFERRED at confidence 0.5. Source verification shows only bin/tfl_cli.ml:L20 and bin/tfl_command.ml:L113 actually call Runtime_json.to_string. The other 32 inferred calls resolve unrelated functions such as Printexc.to_string, Yojson.Safe.to_string, Yojson.Safe.Util.to_string, Cohttp_lwt.Body.to_string, and Bytes.to_string to the same node. The extracted self-loop at bin/runtime_json.ml:L39 is also false: the wrapper calls Yojson.Safe.to_string, not itself. The real trace is bin/tfl_cli.out and bin/tfl_command.output_json to Runtime_json.to_string to json_with_valid_utf8 to escape_invalid_utf8. Therefore the cross-community ranking is a graph extraction artifact, not an architectural property of Horos.

## Outcome

- Signal: corrected
- Correction: Treat bin_runtime_json_to_string as a narrow UTF-8-safe JSON serialization adapter. Its apparent broad centrality comes from terminal-name collisions among unrelated OCaml to_string functions.

## Source Nodes

- to_string
- json_with_valid_utf8
- escape_invalid_utf8
- out
- output_json