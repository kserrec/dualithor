# Missing-premise priority audit — 2026-08-08

## Verdict

**Retire the novelty claim and do not build Phase 6.1 as a research contribution.**
Sommers and Englebretsen published the essential method in 2000: represent the omitted
premise as an unknown signed proposition, write the algebraic equation required for a valid
syllogism, and solve for the omitted premise by subtracting the stated material from the
conclusion. The proposed headline—closed-form TFL enthymeme completion rather than
guess-and-check—therefore does not have priority.

## Primary source inspected

Fred Sommers and George Englebretsen, *An Invitation to Formal Reasoning: The Logic of
Terms* (Ashgate, 2000; Routledge reissue, 2016), Chapter 5, §3, "Enthymemes," printed
pp. 118–122. The publisher's official preview confirms the authorship, edition metadata,
chapter title, section title, and page range:
<https://api.pageplace.de/preview/DT0400.9781351958615_A29558100/preview-9781351958615_A29558100.pdf>.

The relevant pages were read from a local 275-page scan that is not committed because it
is copyrighted. Its SHA-256 digest is
`c111955697b5f18c36dc8e27c490b7e67fcbe264d3b5a8422d9f113c703e55e0`.

## What the book establishes

- Page 118 defines an enthymeme as an argument with an omitted premise and gives an
  existential-import repair.
- Page 119 presents a one-premise argument with a stated conclusion, determines from the
  regularity condition that the omitted premise must be universal, and represents it as
  an unknown signed expression.
- Pages 119–120 place that unknown into the validity equation, isolate it by subtracting
  the known premise from the conclusion, normalize the resulting signed terms, and insert
  the recovered English premise into the completed argument. The book explicitly describes
  the operation as solving for the missing premise.
- Pages 120–121 treat two omitted premises. The authors introduce two unknowns, reduce the
  syllogistic equation, enumerate four algebraically admissible premise pairs, and select
  the pair whose statements are true.
- Page 121 follows with exercises asking the reader to recover missing premises.

This is not merely the general observation that enthymemes exist, nor Mozes's later
database feature that suggests rules by an unspecified mechanism. It is the specific
algebraic recovery operation the project proposed to claim.

## Comparison with the proposed contribution

| Proposed TFL-Verify claim | Published book method | Priority result |
|---|---|---|
| Introduce an unknown missing premise | Introduces an unknown signed premise | Occupied |
| Derive it from the conclusion and stated premises | Writes the validity equation | Occupied |
| Compute it by algebraic subtraction | Isolates the unknown by subtraction and normalization | Occupied |
| Handle more than one omission | Solves a two-unknown case with multiple candidate pairs | Occupied in principle |
| Return an English premise | Reconstructs the completed argument in English | Occupied |

The repository's proposed implementation added engineering details: executable OCaml,
structured refusal outside the categorical fragment, verification of each suggestion by
rerunning the completed argument, and explicit handling of reusable universal premises.
Those could form a useful implementation or a narrowly proved generalization. They do not
rescue the broad novelty claim, and the project has no evidence that the narrower
multiplicity result is important enough or unoccupied enough to justify building it.

## Disposition

1. Cancel the former Phase 6.1 implementation. The frozen JavaScript reference's bounded
   search remains reference material; it is not ported or promoted.
2. Never claim that TFL-Verify invented algebraic, closed-form, or search-free
   missing-premise recovery.
3. Never present a recovered formal premise as the real-world reason a person was denied
   eligibility. It is only a proposition sufficient to complete a derivation; truth,
   relevance, and evidentiary availability are separate questions.
4. Reconsider the feature only as an engineering request from actual users or after a new
   priority audit supports a sharply narrower theorem. It is not part of the current
   go/no sprint.

## Correction to the 2026-08-01 sweep

The earlier sweep concluded that no publication stated the subtraction method because no
primary book text had been available during that pass. That negative was an access gap,
not evidence of absence. The canonical source was already listed in the repository but
had not been read. The corrected lesson is procedural: a novelty negative in this project
cannot survive when the canonical book has not been inspected.
