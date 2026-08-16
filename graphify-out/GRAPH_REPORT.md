# Graph Report - dualithor  (2026-08-16)

## Corpus Check
- 123 files · ~520,823 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3253 nodes · 6129 edges · 189 communities (187 shown, 2 thin omitted)
- Extraction: 46% EXTRACTED · 54% INFERRED · 0% AMBIGUOUS · INFERRED: 3285 edges (avg confidence: 0.5)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `43fba771`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- gen.ml
- check_inconsistent
- repl_input.ml
- test_fidelity_set.ml
- runtime.ml
- test_real_text_audit.ml
- test_safe.ml
- saturate
- safe.ml
- program.ml
- test_cli.ml
- validate
- test_differential.ml
- decide_equivalence
- test_tfl_command.ml
- call_once
- run_unit_tests
- smoke_backcheck.ml
- sample_real.ml
- read_prop
- test_prompts.ml
- sample_defs.ml
- runtime_json.ml
- corpus_gate
- tfl.js
- coverage_stats.ml
- tfl_cli.ml
- is_fixed_ref
- oracle.js
- refuses_special_file_within
- tfl_command.ml
- prop_to_json
- tfl.test.js
- print_proposition
- run_editing_reader
- infer.ml
- runtime.mli
- get
- test_conformance.ml
- test_program.ml
- run_fidelity.ml
- describe_human
- test_runtime.ml
- escape_terminal_field
- call
- candidates_of_with
- run_model
- score.ml
- check_equivalence
- length
- run_repl
- source.ml
- test_llm_client.ml
- test_relational.ml
- result_json.ml
- read_bounded
- tfl_verify.ml
- apply_simp
- tokenize
- finish
- TFL Core Mechanics Appendix
- canon_term
- test_source_file.ml
- read_streams
- store
- test_verify.ml
- load
- to_string
- count_prop
- source_file.mli
- parse
- notation.ml
- descriptor_target_is_open
- test
- with_terminal_control_temp
- test_translator.ml
- newer
- json_equal
- emit_failure
- validateProp
- ast.ml
- decode_numeric
- parse_repl_command
- compare_on
- query_term_detailed
- test_backcheck.ml
- compile_inner
- vocab_of
- passives
- classify
- Real-Text Sampling Protocol
- test_verify_cases.ml
- eval_rel
- semantics.ml
- backcheck.ml
- prompts.ml
- smoke_translate.ml
- TFL Command-Line Contract
- load
- Corrected Fidelity Re-run
- test_anaphora.ml
- outcome
- protect
- validate_utf8
- iter_models
- token_kind
- test_numerical.ml
- test_decide.ml
- Dualithor Security Model
- TFL Core 0.1 Contract
- test_schema.ml
- Second Annotator Packet
- parse_response
- Adversarial Novelty Check
- check_term_query
- translator.ml
- Core Program Operations
- model_of
- input_mode
- repl_command
- compile
- Rules as Code Literature Sweep
- Parser
- diagnostic_of_safe
- operation_method
- operation_method
- source_file.ml
- failure_kind
- source.mli
- check_eq
- smoke.ml
- read_request_line
- Phase 6 Extension Contract
- Six-Report Literature Synthesis
- Full Scope of Term-Functor Logic
- failure_kind
- error_class
- Selective Trust
- Related-Work Notes
- shim.js
- incompleteness
- incompleteness
- Build and Dependency Integrity
- cfr.ml
- t
- read_result
- Regulatory Fragment Coverage
- Controlled Natural Language Sweep
- Description Logic and Argumentation Sweep
- mode
- print_term
- evidence
- evidence
- llm_client.ml
- readable_orientation
- verdict
- echo_byte
- meth
- outcome
- translate
- decideEquivalence
- read_jsonl
- request_line
- delimiter_scan
- delimiter_scan_state
- Differential Harness
- test_env.ml
- consistency_status
- query_verdict
- consistency_status
- query_verdict
- deal
- Frozen Reference Correctness Gates
- str
- config.ml
- Surviving Novelty Claims
- lines
- test_score.ml
- Q: Why is to_string the strongest cross-community bridge?
- Q: What is the strongest legitimate bridge after filtering low-confidence name collisions?
- of_kind
- log_usage
- str
- equivalent
- check_argument
- unique_by_text
- length
- show_model
- must_parse

## God Nodes (most connected - your core abstractions)
1. `test` - 46 edges
2. `query_term_detailed` - 39 edges
3. `to_string` - 37 edges
4. `print_proposition` - 37 edges
5. `saturate` - 35 edges
6. `edit_terminal_line` - 34 edges
7. `tokenize` - 33 edges
8. `check_inconsistent` - 32 edges
9. `decide_equivalence` - 32 edges
10. `run_model` - 31 edges

## Surprising Connections (you probably didn't know these)
- `Annotation Task Description` --semantically_similar_to--> `Second Annotator Packet`  [INFERRED] [semantically similar]
  tfl-verify-descr.txt → data/fidelity/real/SECOND-ANNOTATOR-PACKET.md
- `Dualithor Semantic Commitments` --semantically_similar_to--> `Open-World Semantics`  [INFERRED] [semantically similar]
  PLAN.md → docs/core-language.md
- `Semantic Correctness Bar` --semantically_similar_to--> `Dualithor Semantic Commitments`  [INFERRED] [semantically similar]
  CLAUDE.md → PLAN.md
- `Phase 5 Product Boundary` --semantically_similar_to--> `Current Dualithor Product Status`  [INFERRED] [semantically similar]
  DUALITHOR-PHASE-5-HANDS-ON.html → README.md
- `Dependency Discipline` --semantically_similar_to--> `Build and Dependency Integrity`  [INFERRED] [semantically similar]
  CLAUDE.md → SECURITY.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Dualithor Core Contract Constellation** — architecture_dualithor_architecture, plan_dualithor_roadmap, readme_dualithor_overview, security_security_model, docs_command_line_tfl_command_line_contract, docs_core_language_core_0_1_contract [EXTRACTED 1.00]
- **Regulatory Sampling Correction Trail** — data_fidelity_real_protocol_real_text_sampling_protocol, data_fidelity_real_protocol_2_definitional_text_protocol, data_fidelity_real_correction_protocol_2026_08_11_sentence_order_correction, data_fidelity_real_erratum_2026_08_11_regulatory_coverage_erratum, data_fidelity_real_criteria_real_text_labeling_criteria [EXTRACTED 1.00]
- **Auditable Neurosymbolic Verification** — docs_related_work_notes_logic_lm, docs_related_work_notes_linc, docs_scope_and_predictions_selective_trust, docs_lit_sweep_2026_08_01_sweep_3_description_logic_argumentation_owl_explanation [INFERRED 0.75]
- **Correction and Evidentiary Honesty Chain** — docs_fidelity_report_2026_08_01_instrument_defects, docs_fidelity_report_2026_08_02_corrected_fidelity_rerun, docs_fidelity_report_2026_08_02_v2_invalid_run_exclusion, docs_regulatory_reaudit_pass_1_2026_08_08_accepted_set_reaudit, docs_lit_sweep_2026_08_01_sweep_5_primary_source_verification_primary_source_corrections [INFERRED 0.75]
- **Fragment Discipline and Totality** — docs_coverage_report_2026_08_02_regulatory_fragment_coverage, docs_engine_surface_tfl_safe_total_api, docs_expressiveness_literature_decidability_preserving_extensions, docs_runtime_api_completeness_contract [INFERRED 0.85]
- **Phase 5 Public Product Surface** — plan_archive_phases_1_through_5_delivery, dualithor_phase_5_hands_on_phase_5_field_guide, docs_command_line_tfl_command_line_contract, docs_core_language_core_0_1_contract, readme_current_product_status [INFERRED 0.95]

## Communities (189 total, 2 thin omitted)

### Community 0 - "gen.ml"
Cohesion: 0.05
Nodes (102): char_range, complex, gate, side, On_predicate, On_subject, obj, oneof_weighted (+94 more)

### Community 1 - "check_inconsistent"
Cohesion: 0.05
Nodes (68): bump, dfs, first_unsat, flat, is_fixed_key, add_count, all_zero, atom_key (+60 more)

### Community 2 - "repl_input.ml"
Cohesion: 0.05
Nodes (59): clear_echo, create_echo_state, create_editor_buffer, create_history, create_navigation, create_output_budget, default_editing_reader, echo_state (+51 more)

### Community 3 - "test_fidelity_set.ml"
Cohesion: 0.08
Nodes (24): has, no_sharing, show, check, concat, create, dup, exists (+16 more)

### Community 4 - "runtime.ml"
Cohesion: 0.06
Nodes (51): cancellation_of_internal, certificate_of_internal, complete, consistency_evidence, consistency_profile, consistency_status_of_internal, equivalence_profile, evidence_of_decision (+43 more)

### Community 5 - "test_real_text_audit.ml"
Cohesion: 0.11
Nodes (18): nth_opt, audit_path, definitions_path, html_packet_path, markdown_packet_path, check, Harness, iter (+10 more)

### Community 6 - "test_safe.ml"
Cohesion: 0.07
Nodes (50): kind_of, props, cancellation_probe, cases, deep_nesting, fuzz_bytes, fuzz_check, fuzz_deep (+42 more)

### Community 7 - "saturate"
Cohesion: 0.08
Nodes (50): allow, add, blit, check_argument, consume_work, create_work_budget, default_max_work, derive (+42 more)

### Community 8 - "safe.ml"
Cohesion: 0.07
Nodes (46): add_premises, argument_budget, check, depth_failure, failure, guard, kind_name, max_argument_bytes (+38 more)

### Community 9 - "program.ml"
Cohesion: 0.07
Nodes (32): end_of_name, end_of_quote, consistency, equivalence_decision, equivalent_entry, line_code, line_code_with_start, max_dnf_bytes (+24 more)

### Community 10 - "test_cli.ml"
Cohesion: 0.06
Nodes (44): close_in, create_process, exchange, in_channel_of_descr, refusal_class, string_of_bool, check, checks (+36 more)

### Community 11 - "validate"
Cohesion: 0.13
Nodes (24): is_nan, abbrev, array_field, bad, confidence_field, float_of_int, ignore, index_opt (+16 more)

### Community 12 - "test_differential.ml"
Cohesion: 0.07
Nodes (41): b, expect_pinned, expect_reached, arbitrary_tally, corpus_exempted, corpus_prop_pin, corpus_prop_skips, corpus_term_pin (+33 more)

### Community 13 - "decide_equivalence"
Cohesion: 0.05
Nodes (51): eval_p, eval_t, is_empty, is_whitespace, cps_to_string, decide_equivalence, equivalents, add_char (+43 more)

### Community 14 - "test_tfl_command.ml"
Cohesion: 0.06
Nodes (40): assert_safe, member, choose, Command_status, get_temp_dir_name, retain, bool_field, check_json_fields (+32 more)

### Community 15 - "call_once"
Cohesion: 0.14
Nodes (19): catch, code_of_status, post, retry, sleep, status, thunk, call_once (+11 more)

### Community 16 - "run_unit_tests"
Cohesion: 0.09
Nodes (36): expect_code, prop_eq, term_eq, parse_proposition, as_signed, atom, contains, corpus (+28 more)

### Community 17 - "smoke_backcheck.ml"
Cohesion: 0.07
Nodes (26): flagged, map2, batch, judge_model, known_bad, check, exit, filter (+18 more)

### Community 18 - "sample_real.ml"
Cohesion: 0.07
Nodes (29): json_escape, add_char, add_string, Cfr, close_out_noerr, code, concat_map, contents (+21 more)

### Community 19 - "read_prop"
Cohesion: 0.08
Nodes (33): proposition_of_ast, capitalize_ascii, introduce, is_given, base_name, ends_in_relation, explain_proof, lowercase (+25 more)

### Community 20 - "test_prompts.ml"
Cohesion: 0.08
Nodes (35): pred, Prompts, String.contains, all_signed, contains, covers, every_signed, every_term (+27 more)

### Community 21 - "sample_defs.ml"
Cohesion: 0.07
Nodes (32): candidates, d1, d2, load, Cfr, close_out_noerr, concat_map, contains (+24 more)

### Community 22 - "runtime_json.ml"
Cohesion: 0.12
Nodes (34): cancellation_json, certificate_json, compile_fields, completeness_json, consistency_fields, describe_fields, equivalence_fields, evidence_json (+26 more)

### Community 23 - "corpus_gate"
Cohesion: 0.16
Nodes (15): corpus_gate, extract_js_strings, add_char, concat, contents, create, dirname, length (+7 more)

### Community 24 - "tfl.js"
Cohesion: 0.17
Nodes (29): applyAdd(), applyDON(), applySimp(), canonProp(), canonTerm(), checkInconsistent(), collectNames(), contrapositive() (+21 more)

### Community 25 - "coverage_stats.ml"
Cohesion: 0.09
Nodes (28): all_blockers, ceiling, defs, is_ambient, is_strict, close_in_noerr, concat, filter (+20 more)

### Community 26 - "tfl_cli.ml"
Cohesion: 0.13
Nodes (26): runtime_failure_json, runtime_success, cmd_compile, cmd_consistency, cmd_describe, cmd_equivalence, cmd_query, commands (+18 more)

### Community 27 - "is_fixed_ref"
Cohesion: 0.21
Nodes (20): compare_proof, is_fixed_ref, check_program_consistency, orientations, slot_quantity, proof_to_json, comma_boundary, diff_consistency_narration (+12 more)

### Community 28 - "oracle.js"
Cohesion: 0.18
Nodes (28): allTuples(), consistent(), counterModel(), entails(), evalProp(), evalTerm(), FIXED, fuzzCategoricalExactness() (+20 more)

### Community 29 - "refuses_special_file_within"
Cohesion: 0.16
Nodes (15): sleepf, descriptor_is_closed_on_exec, executable, execv, _exit, fork, gettimeofday, ignore (+7 more)

### Community 30 - "tfl_command.ml"
Cohesion: 0.11
Nodes (27): cli_schema, diagnostic, emit_repl_safe_failure, equivalence_presentation, equivalence_status, extract_json, hex, input_diagnostic (+19 more)

### Community 31 - "prop_to_json"
Cohesion: 0.19
Nodes (29): prop_to_json, equivalents_to_json, query_answers_to_json, compare_check_argument, count, diff_arbitrary_args, diff_args, diff_ast (+21 more)

### Community 32 - "tfl.test.js"
Cohesion: 0.09
Nodes (19): EngineError, isBareName(), ParseError, printHtmlTerm(), printTerm(), termEq(), assert, {
  Atom, Neg, Compound, Rel, PropTerm, ST, Prop,
  termEq, propEq, ParseError,
  parseProposition, parseTerm, parseSignedTerm,
  printTerm, printProposition, isBareName,
  printHtmlTerm, printHtmlProposition,
} (+11 more)

### Community 33 - "print_proposition"
Cohesion: 0.09
Nodes (48): body, draw, generate1, idx, int, print_proposition, assignment, fail (+40 more)

### Community 34 - "run_editing_reader"
Cohesion: 0.13
Nodes (27): chdir, dup2, exec_tfl, input_result_json, close, close_out_noerr, execv, exit (+19 more)

### Community 35 - "infer.ml"
Cohesion: 0.11
Nodes (31): canon_prop, contradictory, contrapositive, engine_error, flip_sign, Ast, iter, not (+23 more)

### Community 36 - "runtime.mli"
Cohesion: 0.07
Nodes (26): cancellation, certificate, check_consistency, compile, completeness, consistency_result, consistency_status_name, describe (+18 more)

### Community 37 - "get"
Cohesion: 0.17
Nodes (15): get, load, assoc_opt, close_in_noerr, getenv_opt, go, index_opt, input_line (+7 more)

### Community 38 - "test_conformance.ml"
Cohesion: 0.14
Nodes (20): from_file, check_proof_shape, consistency_method_name, contract, expected_proof, J, json_field, json_optional_string (+12 more)

### Community 39 - "test_program.ml"
Cohesion: 0.08
Nodes (25): Program, fido, asg, check, chr, concat, exists, failwith (+17 more)

### Community 40 - "run_fidelity.ml"
Cohesion: 0.11
Nodes (22): abort_on_ceiling, argument, batch_size, call, decline, items_path, exit, failwith (+14 more)

### Community 41 - "describe_human"
Cohesion: 0.12
Nodes (25): completeness_text, consistency_human, consistency_presentation, consistency_status, describe_human, describe_presentation, describe_status, emit_repl_operation (+17 more)

### Community 42 - "test_runtime.ml"
Cohesion: 0.09
Nodes (24): sprintf, work_limit_message, compile_ok, has_evidence, check, check_consistency, compile, concat (+16 more)

### Community 43 - "escape_terminal_field"
Cohesion: 0.15
Nodes (24): add_byte_escape, add_code_point_escape, code_point_at, escape_terminal_field, is_terminal_format_control, add_char, add_string, add_substring (+16 more)

### Community 44 - "call"
Cohesion: 0.09
Nodes (23): close_process, open_process, quote, call, default_path, expect_json, assoc_opt, failwith (+15 more)

### Community 45 - "candidates_of_with"
Cohesion: 0.17
Nodes (12): candidates_of, candidates_of_legacy_reversed, candidates_of_with, decode, concat_map, fold_left, map, first (+4 more)

### Community 46 - "run_model"
Cohesion: 0.11
Nodes (21): attempted, empty_tally, check, close_out_noerr, concat, filteri, for_all, fprintf (+13 more)

### Community 47 - "score.ml"
Cohesion: 0.09
Nodes (40): bind, common_prefix, counts_as_correct, drops_one_character, empty_env, entails, env, exactly_equal (+32 more)

### Community 48 - "check_equivalence"
Cohesion: 0.24
Nodes (21): equal, is_none, is_some, check_argument_error, check_argument_evidence, check_consistency, check_equivalence, check_focus_views (+13 more)

### Community 49 - "length"
Cohesion: 0.18
Nodes (19): contains, filteri, find, go, incr, index_from_opt, length, max (+11 more)

### Community 50 - "run_repl"
Cohesion: 0.18
Nodes (22): emit_repl_failure, emit_repl_result, file_field, load_or_fail, loaded_fields, loaded_summary, length, load (+14 more)

### Community 51 - "source.ml"
Cohesion: 0.14
Nodes (21): find_start, decoded_width, get_utf_8_uchar, incr, index_from_opt, length, codepoint_length, line_text (+13 more)

### Community 52 - "test_llm_client.ml"
Cohesion: 0.11
Nodes (21): regexp_string, search_forward, attempts_of, C, check, checks, is_body, is_fatal (+13 more)

### Community 53 - "test_relational.ml"
Cohesion: 0.12
Nodes (21): Relational, expect_work_limit, check, concat, create, exists, failwith, for_all (+13 more)

### Community 54 - "result_json.ml"
Cohesion: 0.18
Nodes (17): advisory, cancellation_to_json, certificate_to_json, consistency_to_json, decision_record_to_json, decision_to_json, line_to_json, find (+9 more)

### Community 55 - "read_bounded"
Cohesion: 0.14
Nodes (21): after_open, after_stat, error_message, fstat, close_noerr, file_failure, add_subbytes, close (+13 more)

### Community 56 - "tfl_verify.ml"
Cohesion: 0.11
Nodes (26): error_class_of, check, error_info, gloss_of_prop, meth_name, f, failwith, filter_map (+18 more)

### Community 57 - "apply_simp"
Cohesion: 0.15
Nodes (20): can_be_plus, iteri, ref, rev, walk, occurrences, term_key, apply_add (+12 more)

### Community 58 - "tokenize"
Cohesion: 0.09
Nodes (30): cp_to_string, decode, is_ascii_digit, is_ascii_letter, is_bare_name, is_name_char, is_name_start, is_subscript_digit (+22 more)

### Community 59 - "finish"
Cohesion: 0.14
Nodes (17): arg, exit_code, failed, finish, gate, check_argument, compare, eprintf (+9 more)

### Community 60 - "TFL Core Mechanics Appendix"
Cohesion: 0.11
Nodes (20): Engine Surface, Engine Failure Taxonomy, No Anaphora Resolution Policy, Public Resource Limits, Tfl.Safe Total API, TFL Canonical Form, Exact-String Rendering Contract, Forward-Chaining Proof Search (+12 more)

### Community 61 - "canon_term"
Cohesion: 0.15
Nodes (19): canon_term, head_roles, is_proterm_name, make_head_name, add_string, add_utf_8_uchar, compare, concat_map (+11 more)

### Community 62 - "test_source_file.ml"
Cohesion: 0.14
Nodes (19): mkfifo, rename, symlink, check, close_out, failwith, file_exists, Harness (+11 more)

### Community 63 - "read_streams"
Cohesion: 0.14
Nodes (20): search, contains, event, add_char, add_subbytes, contents, create, get_utf_8_uchar (+12 more)

### Community 64 - "store"
Cohesion: 0.14
Nodes (19): string, to_hex, dir, find, key, mkdir_quietly, close_in_noerr, close_out_noerr (+11 more)

### Community 65 - "test_verify.ml"
Cohesion: 0.14
Nodes (19): case, check_roundtrip, glossed, check, concat, for_all, Harness, init (+11 more)

### Community 66 - "load"
Cohesion: 0.18
Nodes (12): take, chunks, load, close_in_noerr, failwith, go, input_line, length (+4 more)

### Community 67 - "to_string"
Cohesion: 0.11
Nodes (20): add_byte_escape, escape_invalid_utf8, json_with_valid_utf8, add_char, add_string, add_substring, code, contents (+12 more)

### Community 68 - "count_prop"
Cohesion: 0.13
Nodes (18): generate, prop, signed, count_prop, counts, coverage, Ast, check (+10 more)

### Community 69 - "source_file.mli"
Cohesion: 0.11
Nodes (18): diagnostic, failure_kind, File, Incomplete_search, Internal, Lexical, Name_resolution, Outside_fragment (+10 more)

### Community 70 - "parse"
Cohesion: 0.16
Nodes (18): cmd_check, cmd_parse, cmd_render, error, handle, assoc_opt, check, f (+10 more)

### Community 71 - "notation.ml"
Cohesion: 0.13
Nodes (35): close_paren, advance, at_end, fail_at, is_sign, level_add, located, make_state (+27 more)

### Community 72 - "descriptor_target_is_open"
Cohesion: 0.22
Nodes (9): closedir, opendir, readdir, descriptor_target_is_open, concat, find_opt, scan, stat (+1 more)

### Community 73 - "test"
Cohesion: 0.18
Nodes (17): f, incr, test, expect_not_valid, indirect, invalid, meth_name, check (+9 more)

### Community 74 - "with_terminal_control_temp"
Cohesion: 0.18
Nodes (18): executable, json_records, close_out, concat, file_exists, filter, map, open_out_bin (+10 more)

### Community 75 - "test_translator.ml"
Cohesion: 0.15
Nodes (16): abs, classify_one, expect, check, concat, failwith, Harness, hd (+8 more)

### Community 76 - "newer"
Cohesion: 0.20
Nodes (10): erase_editor_code_point, code, find, max, nth, value, newer, older (+2 more)

### Community 77 - "json_equal"
Cohesion: 0.21
Nodes (12): for_all2, json_equal, Ast, compare, float_of_int, length, map, sort (+4 more)

### Community 78 - "emit_failure"
Cohesion: 0.21
Nodes (16): emit_failure, emit_result, failure_json, human_diagnostic, exit, exit_code, flush, iter (+8 more)

### Community 79 - "validateProp"
Cohesion: 0.23
Nodes (19): answer(), checkArgument(), checkExpression(), checkProgramConsistency(), derive(), explainProof(), indirectProof(), numericalDecision() (+11 more)

### Community 80 - "ast.ml"
Cohesion: 0.12
Nodes (15): prop, propterm_inner, Inner_prop, Inner_term, sign, Minus, Plus, Wild (+7 more)

### Community 81 - "decode_numeric"
Cohesion: 0.19
Nodes (18): decode_numeric, json_escape, add_char, add_string, chr, code, contents, create (+10 more)

### Community 82 - "parse_repl_command"
Cohesion: 0.15
Nodes (15): command_and_argument, find_equivalence_delimiter, is_ascii_letter, is_bare_name_continuation, scan, sub, trim, parse_repl_command (+7 more)

### Community 83 - "compare_on"
Cohesion: 0.11
Nodes (20): call, check_one, compare_on, diff_parse_program, display_control_boundary, is_display_control_refusal, decode, eprintf (+12 more)

### Community 84 - "query_term_detailed"
Cohesion: 0.18
Nodes (14): implies, fold_left, node_count, any_level, compare, exists, filter, ignore (+6 more)

### Community 85 - "test_backcheck.ml"
Cohesion: 0.14
Nodes (14): j, outcome_name, check, failwith, Harness, length, outcome_of, printf (+6 more)

### Community 86 - "compile_inner"
Cohesion: 0.20
Nodes (10): compile_inner, failure_for_program_error, merge_failures, filter_map, compile, parse_program, rev_append, sprintf (+2 more)

### Community 87 - "vocab_of"
Cohesion: 0.16
Nodes (15): size, counter_model, entails, eval_prop, for_all, fst, iter, mem (+7 more)

### Community 88 - "passives"
Cohesion: 0.10
Nodes (27): fresh, is_witness, collect_names, Ast, create, filter_map, fold_left, incr (+19 more)

### Community 89 - "classify"
Cohesion: 0.19
Nodes (15): classify, index_by_nl, match_key, add_char, contents, create, filter_map, find_opt (+7 more)

### Community 90 - "Real-Text Sampling Protocol"
Cohesion: 0.19
Nodes (14): Authored-Corpus Real-Text Gap, Corrected Unlabeled Sample Run, Reversed Sentence-Order Defect, Sentence-Order Correction Protocol, Strict and Ambient Deontic Readings, Real-Text Labeling Criteria, Invalidated Historical Coverage Results, Regulatory Coverage Erratum (+6 more)

### Community 91 - "test_verify_cases.ml"
Cohesion: 0.24
Nodes (13): class_name, expect, expect_error, invalid, check, concat, Harness, init (+5 more)

### Community 92 - "eval_rel"
Cohesion: 0.18
Nodes (14): lnot, eval_rel, eval_term, lookup, assoc_opt, check, copy, exists (+6 more)

### Community 93 - "semantics.ml"
Cohesion: 0.21
Nodes (12): all_tuples, key_of, append, Ast, concat_map, filter, init, string_of_int (+4 more)

### Community 94 - "backcheck.ml"
Cohesion: 0.11
Nodes (21): check, judgement, max_tokens, complete, concat, failwith, find, find_opt (+13 more)

### Community 95 - "prompts.ml"
Cohesion: 0.23
Nodes (13): few_shots, concat, length, map, mapi, sprintf, notation, output_contract (+5 more)

### Community 96 - "smoke_translate.ml"
Cohesion: 0.19
Nodes (12): exit, for_all, iter, kind_name, print_endline, print_newline, printf, run (+4 more)

### Community 97 - "TFL Command-Line Contract"
Cohesion: 0.27
Nodes (12): Project Graphify Workflow, Dualithor Architecture, Dualithor Agent Guidance, Command Exit-Status Contract, Structured CLI Output Contract, TFL Command-Line Contract, Structured Failure Taxonomy, Dualithor Phase 5 Field Guide (+4 more)

### Community 98 - "load"
Cohesion: 0.18
Nodes (12): load, mem, close_in_noerr, from_string, go, input_line, iter, open_in (+4 more)

### Community 99 - "Corrected Fidelity Re-run"
Cohesion: 0.18
Nodes (12): Translation-Fidelity Measurement, Gold-Set Caveat, Disclosed Instrument Defects, Translation Fidelity, Bounded Fidelity Claim, Corrected Fidelity Re-run, Corrected Translation-Fidelity Re-run, Gold Set Is Not Innocent (+4 more)

### Community 100 - "test_anaphora.ml"
Cohesion: 0.18
Nodes (12): check, checks, entails, failwith, incr, map, not, printf (+4 more)

### Community 101 - "outcome"
Cohesion: 0.50
Nodes (4): outcome, Agrees, Disagrees, Partial

### Community 102 - "protect"
Cohesion: 0.20
Nodes (10): close_in_noerr, in_channel_length, open_in_bin, really_input_string, read_file, exit_code, run, name (+2 more)

### Community 103 - "validate_utf8"
Cohesion: 0.20
Nodes (11): check_suffix, load_with_hooks, get_utf_8_uchar, line_text, not, scan, to_int, utf_decode_is_valid (+3 more)

### Community 104 - "iter_models"
Cohesion: 0.25
Nodes (11): fill_rels, fill_sing, fill_unary, exhaustive_upto, iter_models, f, float_of_int, go (+3 more)

### Community 105 - "token_kind"
Cohesion: 0.18
Nodes (11): token_kind, Tok_eof, Tok_lbracket, Tok_level, Tok_lparen, Tok_minus, Tok_name, Tok_plus (+3 more)

### Community 106 - "test_numerical.ml"
Cohesion: 0.20
Nodes (10): numerical_decision, conditions, check, Decide, failwith, Harness, not, Notation (+2 more)

### Community 107 - "test_decide.ml"
Cohesion: 0.11
Nodes (18): check, expect_verdict, failwith, not, sprintf, verdict_name, invalid, check (+10 more)

### Community 108 - "Dualithor Security Model"
Cohesion: 0.22
Nodes (10): Request-to-Verdict Flow, Total Public Boundaries, Bounded Non-Atomic Proof Search, Core 0.1 Known Limits, Numerical Sufficient-Condition Procedure, Numerical Unknown Correction, Correctness Maintenance Repairs, Accepted and Unreachable Risks (+2 more)

### Community 109 - "TFL Core 0.1 Contract"
Cohesion: 0.31
Nodes (10): TFL Kernel Dependency Stack, Semantic Correctness Bar, Canonical Source and Inference Identity, TFL Core 0.1 Contract, Open-World Semantics, Plus-Minus Propositions, TFL Proof Objects, Atomic-Categorical P/Z Decision (+2 more)

### Community 110 - "test_schema.ml"
Cohesion: 0.14
Nodes (18): Schema, full, check, contains, f, failwith, go, Harness (+10 more)

### Community 111 - "Second Annotator Packet"
Cohesion: 0.24
Nodes (10): Regulatory Blocker Taxonomy, Independent Annotation Form, Independent Annotation Validation, Offline Versioned Answer Export, Minimal Candidate Filter, Independent Annotation Requirement, One-Proposition Fidelity Decision, Second Annotator Packet (+2 more)

### Community 112 - "parse_response"
Cohesion: 0.18
Nodes (12): detail, fatal, index, tok, api_key, float_of_int, from_string, length (+4 more)

### Community 113 - "Adversarial Novelty Check"
Cohesion: 0.22
Nodes (10): Decidability-Preserving Extensions, Expressiveness Literature, General Transitive Relations Boundary, Modal-Temporal Fusion, TFL+ Numerical-Layer Correctness Threat, LLM Term-Logic Novelty Claim Refuted, Modal-Temporal Novelty Claim Is Partial, Non-FOL Fidelity Novelty Claim Refuted (+2 more)

### Community 114 - "check_term_query"
Cohesion: 0.24
Nodes (11): check_term_query, corpus_path, corpus_relative_path, concat, find_opt, kind_name, map, parse_term (+3 more)

### Community 115 - "translator.ml"
Cohesion: 0.20
Nodes (9): item, max_tokens, float_of_int, fold_left, length, Syntax, parse_rate, run (+1 more)

### Community 116 - "Core Program Operations"
Cohesion: 0.28
Nodes (9): Legacy Provenance Boundary, Protected Dev and Eval Split, Translation Fidelity Gold Set, Layered Fidelity Scoring, Dualithor Data Layout, TFL REPL Contract, TFL Source-File Contract, Core Program Operations (+1 more)

### Community 117 - "model_of"
Cohesion: 0.22
Nodes (9): assoc, filteri, subset, go, int_bound, int_range, length, return (+1 more)

### Community 118 - "input_mode"
Cohesion: 0.22
Nodes (9): choose_input_mode, input_mode, Editing_terminal, Piped, Plain_terminal, getenv_opt, not, is_terminal (+1 more)

### Community 119 - "repl_command"
Cohesion: 0.22
Nodes (9): repl_command, Repl_consistency, Repl_describe, Repl_empty, Repl_equivalence, Repl_help, Repl_query, Repl_quit (+1 more)

### Community 120 - "compile"
Cohesion: 0.29
Nodes (7): compile, locate_statement, map, of_list, split_on_char, Runtime.compile, Runtime.statements

### Community 121 - "Rules as Code Literature Sweep"
Cohesion: 0.22
Nodes (9): Rules-as-Code Authoring Bottleneck, Catala, Defeasible-Logic Toolchain, LegalRuleML, LLM Legal Autoformalization, Rules as Code Literature Sweep, Defeasible-Logic Layer Recommendation, Structured Argumentation (+1 more)

### Community 122 - "Parser"
Cohesion: 0.61
Nodes (9): Parser(), atEnd(), closeParen(), fail(), parseGroup(), parseSigned(), parseTermInner(), tokenText() (+1 more)

### Community 123 - "diagnostic_of_safe"
Cohesion: 0.28
Nodes (9): int_of_string_opt, column_at, diagnostic_of_safe, line_at, line_number, length, sub, value (+1 more)

### Community 124 - "operation_method"
Cohesion: 0.22
Nodes (9): operation_method, Bounded_saturation, Derivation, DNF, Indirect, Numerical, PZ, Refutation_search (+1 more)

### Community 125 - "operation_method"
Cohesion: 0.22
Nodes (9): operation_method, Bounded_saturation, Derivation, DNF, Indirect, Numerical, PZ, Refutation_search (+1 more)

### Community 126 - "source_file.ml"
Cohesion: 0.22
Nodes (9): For_testing, kind_name, load, loaded, path, runtime, statement, statements (+1 more)

### Community 127 - "failure_kind"
Cohesion: 0.22
Nodes (9): failure_kind, File, Incomplete_search, Internal, Lexical, Name_resolution, Outside_fragment, Resource_limit (+1 more)

### Community 128 - "source.mli"
Cohesion: 0.22
Nodes (8): codepoint_length, line_text, located, position, range, span, span_of_range, span_on_line

### Community 129 - "check_eq"
Cohesion: 0.31
Nodes (8): check_eq, Harness, Notation, p, Render, reads, reads_term, t

### Community 130 - "smoke.ml"
Cohesion: 0.22
Nodes (8): complete, exit, for_all, print_endline, printf, run, sprintf, trim

### Community 131 - "read_request_line"
Cohesion: 0.25
Nodes (8): add_char, contents, create, input_char, length, read, ref, read_request_line

### Community 132 - "Phase 6 Extension Contract"
Cohesion: 0.29
Nodes (8): One Phase per Pass Workflow, Phase 5 Product Boundary, Missing-Premise Priority Refutation, Phases 1 Through 5 Delivery, Phase 6 Extension Contract, Published TFL Extension Target, Version 1 Milestone Sequence, Current Dualithor Product Status

### Community 133 - "Six-Report Literature Synthesis"
Cohesion: 0.25
Nodes (8): Literature Sweep Index and Synthesis, Six-Report Literature Synthesis, coNP-Complete Input/Output Logic, Linear-Time Defeasible Logic, Polynomial Simple Temporal Networks, Primary-Source Corrections, Primary-Source Verification Sweep, Ross's Paradox Sub-claim Refutation

### Community 134 - "Full Scope of Term-Functor Logic"
Cohesion: 0.25
Nodes (8): Adverbial Modification, Identity and Definite Descriptions, Missing-Premise Algorithm, Full Scope of Term-Functor Logic, Missing-Premise Priority Audit, Missing-Premise Suggestion, Missing-Premise Novelty Correction, Sommers Missing-Premise Priority

### Community 135 - "failure_kind"
Cohesion: 0.25
Nodes (8): failure_kind, Incomplete_search, Internal, Lexical, Name_resolution, Outside_fragment, Resource_limit, Syntactic

### Community 136 - "error_class"
Cohesion: 0.25
Nodes (8): error_class, Incomplete_search, Internal, Lexical, Name_resolution, Outside_fragment, Resource_limit, Syntactic

### Community 137 - "Selective Trust"
Cohesion: 0.29
Nodes (7): Coverage of Real Regulatory Text, Semantic-Density Bottleneck, Selective Prediction and Abstention, Belief-Bias Prediction, Coverage as the Governing Constraint, Scope and Predictions, Selective Trust

### Community 138 - "Related-Work Notes"
Cohesion: 0.29
Nodes (7): Sommers-Englebretsen Term-Logic Tradition, Claimed but Unimplemented TFL Constructions, LINC, Logic-LM, Natural-Logic Lineage, Related-Work Notes, Sommers-Englebretsen TFL Source System

### Community 139 - "shim.js"
Cohesion: 0.29
Nodes (5): FNS, oracle, readline, rl, tfl

### Community 140 - "incompleteness"
Cohesion: 0.29
Nodes (7): incompleteness, Bounded_refutation, Bounded_rewrite, Bounded_search, Bounded_term_saturation, Numerical_consistency_unavailable, Numerical_rule_set

### Community 141 - "incompleteness"
Cohesion: 0.29
Nodes (7): incompleteness, Bounded_refutation, Bounded_rewrite, Bounded_search, Bounded_term_saturation, Numerical_consistency_unavailable, Numerical_rule_set

### Community 142 - "Build and Dependency Integrity"
Cohesion: 0.47
Nodes (6): Dualithor Continuous Integration, Normal-Install Dependency Boundary, Repository Hygiene Gates, Dependency Discipline, Public Data Boundary, Build and Dependency Integrity

### Community 143 - "cfr.ml"
Cohesion: 0.27
Nodes (9): ends_protected, entities, has_lower, is_candidate, exists, filter, split_on_char, protected_abbrevs (+1 more)

### Community 144 - "t"
Cohesion: 0.33
Nodes (6): t, Incomplete_search, Input_failure, Internal_failure, Non_entailment, Success

### Community 145 - "read_result"
Cohesion: 0.33
Nodes (6): read_result, Display_limit, End_of_input, Interrupted, Line, Line_too_long

### Community 146 - "Regulatory Fragment Coverage"
Cohesion: 0.33
Nodes (6): Fragment-Extension Coverage Ceiling, Regulatory Fragment Coverage, Accepted-Set Re-audit, Provisional Coverage Effect, Regulatory Re-audit Gate, Regulatory Accepted-Set Re-audit

### Community 147 - "Controlled Natural Language Sweep"
Cohesion: 0.33
Nodes (6): Attempto Controlled English, Controlled-Natural-Language Usability, Controlled Natural Language Sweep, LLM-CNL Research Gap, OWL Verbalization, PENG and PENG-ASP

### Community 148 - "Description Logic and Argumentation Sweep"
Cohesion: 0.33
Nodes (6): Contestable Automated Decision-Making, Description Logic and Argumentation Sweep, OWL 2 EL, OWL Entailment Explanation, SNOMED CT, Matched-FOL Auditability Comparison

### Community 149 - "mode"
Cohesion: 0.40
Nodes (5): failwith, to_list, mode, Corrected, Legacy

### Community 150 - "print_term"
Cohesion: 0.29
Nodes (10): code, concat, map, string_of_int, to_seq, print_level, print_sign, print_signed_term (+2 more)

### Community 151 - "evidence"
Cohesion: 0.33
Nodes (6): evidence, Closure_certificate, Numerical_decision, Proof, Rewrite_path, Truth_table

### Community 152 - "evidence"
Cohesion: 0.33
Nodes (6): evidence, Closure_certificate, Numerical_decision, Proof, Rewrite_path, Truth_table

### Community 153 - "llm_client.ml"
Cohesion: 0.17
Nodes (12): disposition, Body, Fatal, Retry, ref, Syntax, Util, response (+4 more)

### Community 154 - "readable_orientation"
Cohesion: 0.33
Nodes (6): find_opt, not, value, readable_orientation, subject_is_relational, render

### Community 155 - "verdict"
Cohesion: 0.33
Nodes (6): verdict, Contradicted, Error, Invalid, Unknown, Valid

### Community 156 - "echo_byte"
Cohesion: 0.15
Nodes (20): append_editor_byte, echo_byte, expected_utf8_width, flush_echo, add_char, chr, flush, hd (+12 more)

### Community 157 - "meth"
Cohesion: 0.40
Nodes (5): meth, Derivation, Indirect, Numerical, PZ

### Community 158 - "outcome"
Cohesion: 0.40
Nodes (5): outcome, Absent, Declined, Translated, Unparseable

### Community 159 - "translate"
Cohesion: 0.40
Nodes (5): complete, find, return, user, translate

### Community 160 - "decideEquivalence"
Cohesion: 0.67
Nodes (4): fuzzStatementModel(), oneWorld(), decideEquivalence(), statementModel()

### Community 161 - "read_jsonl"
Cohesion: 0.15
Nodes (13): audit_rows, close_in_noerr, from_string, in_channel_length, input_line, open_in, open_in_bin, really_input_string (+5 more)

### Community 162 - "request_line"
Cohesion: 0.50
Nodes (4): request_line, End_of_input, Request, Request_too_large

### Community 163 - "delimiter_scan"
Cohesion: 0.50
Nodes (4): delimiter_scan, Many_delimiters, Missing_delimiter, Unique_delimiter

### Community 164 - "delimiter_scan_state"
Cohesion: 0.50
Nodes (4): delimiter_scan_state, Inside_bare_name, Inside_quoted_name, Outside_name

### Community 165 - "Differential Harness"
Cohesion: 0.50
Nodes (4): Differential Harness, Differential Report, Documented Engine Divergences, Handover Gate

### Community 166 - "test_env.ml"
Cohesion: 0.18
Nodes (10): putenv, temp_file, check, close_out, failwith, not, open_out, output_string (+2 more)

### Community 167 - "consistency_status"
Cohesion: 0.50
Nodes (4): consistency_status, Consistent, Inconsistent, Undetermined

### Community 168 - "query_verdict"
Cohesion: 0.50
Nodes (4): query_verdict, No, Unknown, Yes

### Community 169 - "consistency_status"
Cohesion: 0.50
Nodes (4): consistency_status, Consistent, Inconsistent, Undetermined

### Community 170 - "query_verdict"
Cohesion: 0.50
Nodes (4): query_verdict, No, Unknown, Yes

### Community 171 - "deal"
Cohesion: 0.25
Nodes (8): deal, filter, find_opt, iteri, make, map, to_list, outcome_of

### Community 172 - "Frozen Reference Correctness Gates"
Cohesion: 1.00
Nodes (3): Frozen Reference Correctness Gates, Dualithor Evidence Ladder, OCaml Port Verification

### Community 173 - "str"
Cohesion: 0.31
Nodes (11): id, mem, lowercase_ascii, map, to_list, nls_of, normalise, str (+3 more)

### Community 176 - "lines"
Cohesion: 0.18
Nodes (11): items, lines, close_in_noerr, filter_map, from_string, go, input_line, open_in (+3 more)

### Community 177 - "test_score.ml"
Cohesion: 0.31
Nodes (8): grade_name, expect, grade, check, Harness, iter, not, p

### Community 178 - "Q: Why is to_string the strongest cross-community bridge?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Why is to_string the strongest cross-community bridge?, Source Nodes

### Community 179 - "Q: What is the strongest legitimate bridge after filtering low-confidence name collisions?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: What is the strongest legitimate bridge after filtering low-confidence name collisions?, Source Nodes

### Community 180 - "of_kind"
Cohesion: 0.22
Nodes (9): arguments, declines, eval_ids, filter, split_on_char, of_kind, of_split, sentences (+1 more)

### Community 181 - "log_usage"
Cohesion: 0.40
Nodes (5): open_out_gen, time, log_usage, close_out_noerr, output_string

### Community 182 - "str"
Cohesion: 0.33
Nodes (9): audit_label, find, id, mem, failwith, find_opt, sprintf, str (+1 more)

### Community 183 - "equivalent"
Cohesion: 0.25
Nodes (8): guard_input, equivalent, parser, run, with_located_input, locate, line_text, span_of_range

### Community 184 - "check_argument"
Cohesion: 0.29
Nodes (8): check_argument, consistency_result_name, is_ground_query_complete, method_is_complete, mapi, not, verdict_name, Tfl.Decide.check_argument

### Community 185 - "unique_by_text"
Cohesion: 0.29
Nodes (7): label_of, count_labelled_in, create, filter, Hashtbl.mem, original_accepted, unique_by_text

### Community 186 - "length"
Cohesion: 0.60
Nodes (6): contains, count_occurrences, find_substring_from, go, length, sub

### Community 187 - "show_model"
Cohesion: 0.40
Nodes (5): pairs, concat, map, to_list, show_model

### Community 188 - "must_parse"
Cohesion: 0.50
Nodes (4): failwith, kind_name, sprintf, must_parse

## Knowledge Gaps
- **477 isolated node(s):** `entities`, `protected_abbrevs`, `normative`, `defs`, `row` (+472 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `to_string` connect `to_string` to `test_real_text_audit.ml`, `safe.ml`, `test_cli.ml`, `validate`, `call_once`, `run_unit_tests`, `runtime_json.ml`, `coverage_stats.ml`, `prop_to_json`, `run_editing_reader`, `infer.ml`, `call`, `str`, `test_llm_client.ml`, `log_usage`, `str`, `read_bounded`, `tfl_verify.ml`, `read_streams`, `test_verify.ml`, `parse`, `test`, `emit_failure`, `compare_on`, `load`, `protect`, `test_schema.ml`, `parse_response`?**
  _High betweenness centrality (0.173) - this node is a cross-community bridge._
- **Why does `test` connect `test` to `gen.ml`, `check_eq`, `test_fidelity_set.ml`, `test_real_text_audit.ml`, `test_safe.ml`, `test_tfl_command.ml`, `run_unit_tests`, `read_prop`, `test_prompts.ml`, `infer.ml`, `test_program.ml`, `test_runtime.ml`, `candidates_of_with`, `check_equivalence`, `test_score.ml`, `test_relational.ml`, `finish`, `test_source_file.ml`, `test_verify.ml`, `to_string`, `test_translator.ml`, `test_backcheck.ml`, `vocab_of`, `test_verify_cases.ml`, `test_numerical.ml`, `test_decide.ml`, `test_schema.ml`?**
  _High betweenness centrality (0.131) - this node is a cross-community bridge._
- **Why does `protect` connect `protect` to `store`, `read_jsonl`, `load`, `repl_input.ml`, `load`, `get`, `descriptor_target_is_open`, `with_terminal_control_temp`, `run_model`, `test_tfl_command.ml`, `lines`, `sample_real.ml`, `sample_defs.ml`, `log_usage`, `read_bounded`, `test_source_file.ml`, `coverage_stats.ml`, `tfl_command.ml`?**
  _High betweenness centrality (0.114) - this node is a cross-community bridge._
- **Are the 45 inferred relationships involving `test` (e.g. with `to_string` and `eprintf`) actually correct?**
  _`test` has 45 INFERRED edges - model-reasoned connections that need verification._
- **Are the 36 inferred relationships involving `query_term_detailed` (e.g. with `add` and `implies`) actually correct?**
  _`query_term_detailed` has 36 INFERRED edges - model-reasoned connections that need verification._
- **Are the 35 inferred relationships involving `to_string` (e.g. with `coverage_stats.ml` and `read_rows`) actually correct?**
  _`to_string` has 35 INFERRED edges - model-reasoned connections that need verification._
- **Are the 34 inferred relationships involving `print_proposition` (e.g. with `record` and `entails`) actually correct?**
  _`print_proposition` has 34 INFERRED edges - model-reasoned connections that need verification._