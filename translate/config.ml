(* The three translator models under test (PLAN 2.2). Slugs looked up on
   OpenRouter 2026-08-01 and tier-matched — each vendor's balanced workhorse,
   not one flagship against another's budget model:
   - anthropic/claude-sonnet-5   $2 in / $10 out per Mtok
   - openai/gpt-5.6-terra        $1 in / $6 out (no plain "gpt-5.6" exists;
     Terra is the middle tier between Sol and Luna)
   - moonshotai/kimi-k3          $3 in / $15 out *)
let models =
  [ "anthropic/claude-sonnet-5"; "openai/gpt-5.6-terra"; "moonshotai/kimi-k3" ]

(* Cost ceiling for one run, in USD (PLAN 4.9). CLAUDE.md has asserted since
   2.1 that "the cost ceiling in config is enforced in code"; until now there
   was no ceiling anywhere.

   Enforced in llm_client.ml: the running total of *paid* calls — cache hits
   never reach the client and are never counted — is checked before each
   request, so a runaway loop overshoots by at most one call.

   Sized against what this project actually spends: the whole 4.5b fidelity run
   across three models was $0.54 and the largest smoke $0.035. Five dollars is
   roughly ten full runs — high enough never to interrupt honest work, low
   enough that a bug cannot spend real money before it stops. Raising it is a
   code change on purpose.

   It is only as good as OpenRouter's own accounting: a reply that arrives with
   no cost field cannot be counted, so the spend report names how many did. *)
let cost_ceiling_usd = 5.0
