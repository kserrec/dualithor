(* The three translator models under test (PLAN 2.2). Slugs looked up on
   OpenRouter 2026-08-01 and tier-matched — each vendor's balanced workhorse,
   not one flagship against another's budget model:
   - anthropic/claude-sonnet-5   $2 in / $10 out per Mtok
   - openai/gpt-5.6-terra        $1 in / $6 out (no plain "gpt-5.6" exists;
     Terra is the middle tier between Sol and Luna)
   - moonshotai/kimi-k3          $3 in / $15 out *)
let models =
  [ "anthropic/claude-sonnet-5"; "openai/gpt-5.6-terra"; "moonshotai/kimi-k3" ]
