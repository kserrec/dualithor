# Engine surface — failure taxonomy and the total API

**Status: implemented (PLAN 1.14, 2026-08-01).** `lib/tfl/safe.ml` is the total surface;
`test/test_safe.ml` holds the contract checks and the adversarial fuzz. The inventory below
is what `lib/tfl/` raises and how each refusal is classified.

## Why this exists

Everything downstream of Phase 4 feeds this engine text written by a language model. That
text will be wrong in every way text can be wrong: truncated mid-formula, using FOL
notation, using prose, nesting parentheses forty deep, or perfectly well-formed but outside
the fragment TFL decides. The router's whole claim (PLAN core claim 2) is that this
failure is a *clean mechanical signal* — so the failure has to be structured, total, and
stable, not an exception that escapes into the pipeline.

Three requirements follow:

1. **Classified.** Every refusal of an *input* falls into one of three classes, and the
   class is what the router branches on. (A fourth kind, `Internal`, classifies the engine
   rather than the input — see below.)
2. **Total.** The public entry points never raise. Not for malformed input, not for
   adversarial input, not for input that hits an internal limit.
3. **Bounded.** No input makes the engine run unboundedly. A refusal must arrive.

## The three classes

| class | means | router reading |
|---|---|---|
| `Lexical` | the input contains a character or token the notation has no reading for | not TFL text at all — the model emitted prose, FOL, or garbage |
| `Syntactic` | the tokens are legal but do not form a proposition | the model was aiming at TFL and missed — a candidate for one repair attempt |
| `Outside_fragment` | the input parses to a well-formed AST that the inference layer refuses | genuinely TFL, but not something this engine decides — escalate, never guess |

The split between the first two is exactly the tokenizer/parser boundary, which makes it
mechanical rather than a judgement call: `Safe.parse` runs the tokenizer alone first, so a
failure there is `Lexical` by construction and one from the parser proper is `Syntactic`.
Classification never reads the message text, so editing a message cannot silently
reclassify anything. The third is the one that matters for the paper:
it is the engine saying *I understood you and I still will not answer*, which is the
signal an FOL pipeline cannot produce.

`Outside_fragment` is **not** the same as the `Unknown` verdict. `Unknown` means the
argument was accepted, searched within fuel, and neither proved nor refuted (port-spec
§12). `Outside_fragment` means it was never searched. Both are non-answers; only the second
is a parse-level property, and collapsing them would destroy the router signal.

## Inventory: every refusal the engine raises today

### `Lexical` — `Notation.Parse_error` from the tokenizer

Each carries a 0-based `pos` into the source string.

| message | raised when |
|---|---|
| `Unexpected character '<c>'` | no token starts with that character |
| `Unexpected character '<c>' (quote the term to use non-ASCII names)` | same, for a non-ASCII character — the §16.4 narrowing, with the advisory that makes it actionable |
| `Term names must start with a letter` | a digit in name position |
| `Unclosed quote` | a `"` with no closing `"` |
| `Empty quoted term` | `""` |
| `Expected digits after '^' (quantity level)` | a `^` not followed by digits |

### `Syntactic` — `Notation.Parse_error` from the parser

| message | raised when |
|---|---|
| `Expected a sign (+, − or ±), found <tok>` | a signed term does not start with a sign |
| `Expected a term, found <tok>` | a sign is not followed by a term |
| `Expected ')', found <tok>` | an unclosed group |
| `Expected ']', found <tok>` | an unclosed propositional term |
| `Expected a proposition or statement term inside [ ], found <tok>` | `[…]` containing neither |
| `Expected a signed object or ')' after the relation term, found <tok>` | a malformed relational complex |
| `Expected end of input after the <what>, found <tok>` | trailing text after a complete production |
| `A wild sign (±) needs a proposition or relational-complex context` | a bare `(±T)` |
| `A quantity level cannot attach inside a bare signed group` | `(+T^1)` |

### `Outside_fragment` — `Infer.Engine_error`

These fire *after* a successful parse. Two sub-groups, and the distinction is worth keeping
in mind when reading a router trace: the first is the standing fragment definition, the
second is a guard on a specific decision procedure.

**Fragment validation** (`Infer.validate_prop`, run at the head of every public decision):

| message | raised when |
|---|---|
| `± cannot sign a compound element (it marks quantity, not quality)` | `±` inside a compound |
| `± cannot sign a predicate (quality is + or −; write the quantity wild on the subject)` | `±` on a predicate |
| `wild quantity (±) requires a singular or proterm subject` | `±` on a general subject |
| `wild quantity (±) requires a singular term or proterm` | same, on a relational object |
| `a quantity level attaches only to the subject, not the predicate` | a level on a predicate |
| `a quantity level attaches only to a categorical subject, not a compound element` | a level inside a compound |
| `a quantity level attaches only to a categorical subject, not a relational object` | a level on a relational object |
| `quantity level must be 0 (some/every), 1 (many), 2 (most) or 3 (few)` | a level outside 0–3 |
| `a nonzero quantity level marks an intermediate quantifier and needs a particular (+) subject` | a level on a universal |

**Procedure guards** (the input is a legal proposition; the *procedure* does not apply):

| message | raised by |
|---|---|
| `quantity levels are supported only in categorical (atomic) syllogisms` | `Decide.check_argument`, when a level rides a non-categorical argument |
| `a wild ± subject has no quantity-level reading; use + (particular) or − (universal)` | the numerical decision |
| `numerical sides must be atomic` | the numerical decision's side coefficients |
| `the inconsistency check requires an atomic-categorical set` | `Decide.check_inconsistent` |
| `"what is …?" saturation is a level-0 query; ask a numerical syllogism as an argument (premises ⊢ conclusion) instead` | `Program.query_term` |
| `the immediate rules (obversion, contraposition) are defined at level 0; a numerical quantifier has no equivalence neighbourhood here` | `Program.equivalents` |
| `equivalence is decided at level 0; numerical quantifiers are compared only through the decision method` | `Program.decide_equivalence` |

The second group is easy to miss because fragment-shaped test generators never reach it —
the 1.12 arbitrary-shapes gate found it by feeding `checkArgument` a levelled subject with a
compound predicate. Both engines raise it identically.

## The fourth kind: `Internal`

There is a fourth failure kind, `Internal`, and it is deliberately **not** one of the three
router classes: it classifies the engine, not the input. The router must never treat "the
engine broke" as "this input is outside the fragment" — one is a bug to fix, the other an
escalation to make, and folding them together would let a defect hide inside an expected
outcome. It exists so the API can be total without a crash ever being *reported* as a
refusal, and the fuzz run below is the evidence it never fires. (A deviation from PLAN
1.14(a)'s three-class list, logged 2026-08-01.)

`Internal` covers:

- **Internal invariants** (`assert false` in `derive.ml`, `decide.ml`, `relational.ml`).
  These mark states the type system cannot rule out but the code establishes — a proof line
  index that must exist, a term already checked to be an atom. They are bugs if reached,
  never a classification of the input.
- **`Stack_overflow`.** Now unreachable through `Safe`: nesting in this notation is exactly
  bracket nesting, so `Safe.parse` measures depth from the token stream *before* any
  recursion and refuses past `max_depth` (64) with a `Syntactic` failure. Sixty-four is far
  past anything a real formula reaches and far below what any tree walk in the engine can
  take. (Port-spec §16.5: the JS reference dies with a `RangeError` here; that divergence is
  now a deliberate, structured refusal.)

**Bounded work.** `find_cancellation`'s universal-re-use search was uncapped (4^u nodes;
measured ×4 growth per premise, 1.9s at 11 universals and ~days at 20 — LOG 2026-07-30
audit). It now carries a 500,000-node budget, shared across the whole call, and reports no
cancellation when the budget runs out. That is verdict-safe by construction: the closure
decides the verdict *before* the search runs, and the cancellation only decorates the
certificate. The search stays complete through 9 re-usable universals. **This is the one
deliberate behavioural deviation of the OCaml engine from the frozen JS reference**, which
is uncapped (dev-only there, never exposed). The differential gates never reach the budget —
their generated sets are far too small — so the divergence is real but unobserved by them;
`test/test_safe.ml` pins it directly.

## The total API (`Tfl.Safe`)

```
type failure_kind = Lexical | Syntactic | Outside_fragment | Internal

type failure = {
  kind    : failure_kind;
  message : string;        (* the engine's own text, unmodified *)
  pos     : int option;    (* 0-based index into the source; parse failures only *)
  where   : string option; (* "premise 2" | "conclusion" | "argument" *)
}

val kind_name     : failure_kind -> string
val parse         : ?where:string -> string -> (Ast.prop, failure) result
val parse_all     : string -> string list -> (Ast.prop list, failure) result
val check         : premises:string list -> conclusion:string
                 -> (Decide.result, failure) result
val parse_program : string -> (Program.parsed_program, failure) result
```

(An earlier revision of this table listed a `describe` helper that was never
implemented; removed 2026-08-01.)

`parse_program` (added in PLAN 3.1) closes the gap 1.14 left open: the depth cap
lived only in `Safe.parse`, so the program-loading path could still exhaust the
stack — measured as a hard `Stack_overflow` at 200k nesting levels. The wrapper
checks bracket depth per line, pre-parse, on the same comment-stripped text the
program parser reads, and names the offending line (`where = "line N"`).
Per-line syntax errors remain collected in the returned program's `errors`
field, exactly as the underlying `Program.parse_program` reports them; programs
are loaded through this wrapper and nowhere else.

`check` validates each proposition under its own label before deciding, so a fragment
refusal names the premise that caused it rather than the argument as a whole —
`check_argument` validates its whole input at the head, which would otherwise lose the
attribution. A refusal about the argument itself (a quantity level with no categorical
route, an inconsistency check on a non-categorical set) is labelled `argument`.

- **Never raises.** Every exception above — including `Stack_overflow` and any escaping
  `assert false` — is caught at this boundary and returned. An escaping assertion is a bug
  to be fixed, but it must not be a crash in the pipeline.
- **Never hangs.** Every search is bounded by explicit fuel (port-spec §16.6), and 1.14(d)
  adds the missing cap.
- **Message text is the engine's own**, unmodified, so a trace stays greppable against the
  source.
- **Classification is a function of where the failure came from**, not of its text, so
  message edits cannot silently reclassify.

## Evidence

`test/test_safe.ml`, run 2026-08-01: **102,000 adversarial inputs** — 30,000 random byte
strings (invalid UTF-8 and control characters included), 20,000 random notation-token
strings, 30,000 truncations of printed formulas (cut on byte indices, so UTF-8 sequences
are sliced in half), 10,000 inputs nested 1–3,000 levels deep in both bracket flavours
balanced and unbalanced, 2,000 pathological lengths (names and token runs up to 20,000
characters), and 10,000 `check` calls over garbage premises and conclusions.

No escaping exception, no `Internal` failure, and **no case slower than 0.036s** against a
one-second bound — the slowest was a 39KB input. Eight contract checks cover the
classification boundaries directly, including the depth cap admitting 60 levels and
refusing 200, and the capped cancellation search returning in under a second on the audit's
20-universal probe while still decorating an ordinary three-premise certificate.

---

## The anaphora resolution policy

*Settled 2026-08-02 (PLAN 5.2). Pinned by `test/test_anaphora.ml`, 18 checks.*

### Why the question is load-bearing

Pratt-Hartmann's handbook chapter puts a knife-edge inside the fragment this engine
occupies (`expressiveness-literature.md` §1.3):

| Fragment | Satisfiability | Thm |
|---|---|---|
| `TV+Rel+RA` — *restricted* anaphora: every pronoun bound to its **closest** permissible antecedent | NEXPTIME-complete | 15 |
| `TV+Rel+GA` — *general* anaphora: free co-indexing, subject only to binding theory | **UNDECIDABLE** | 16 |

Same sentences, same syntax; **only a different disambiguation policy.** The
undecidability proof is a grid/tiling encoding in six sentences, and its essential
ingredient is a co-indexed pronoun reaching back *past an intervening quantifier* — which
RA forbids and GA permits. Witness sentence: *"Every artist who admires a beekeeper hates
every carpenter who despises him."*

The engine has something called pronominalization, and the paper claims our fragment is
decidable where ACE is not. If that machinery implemented GA, the claim would be false and
the router claim's substrate — *TFL is a small decidable fragment, so parse failure is a
meaningful signal* — would go with it.

### The answer: no resolution policy at all

Neither RA nor GA. **A primed name is a constant.** `Boy′` denotes a single individual and
is related to nothing whatsoever — not to `Boy`, not to any antecedent, not by proximity
and not by co-indexing. The prime is a spelling convention that makes the atom a *fixed
reference* (`Infer.is_fixed_ref`), exactly as `*` does for a singular term, and that is its
entire effect: on a singleton denotation the all/some distinction collapses, so `±` is
admissible there and `+`/`−` mean the same thing. In the 1.10 model semantics a proterm is
assigned one domain element, in the same table as singulars.

Two independent pieces of evidence that no resolution is happening:

- **A proterm inherits nothing from the term it was primed from.** `±Boy′+Boy` — "that boy
  is a boy" — is not valid, and has a one-element countermodel where `Boy′` denotes element
  0 and `Boy` is empty. Any resolution policy would have linked them.
- **`pronominalize` records an explicit anchor.** Every witness it introduces comes with a
  stated `±T′+T` (port-spec §9). Nothing would need anchoring if the engine resolved the
  reference itself. That function is Skolemization for indirect proof — it *creates*
  constants for existential witnesses — and runs in the opposite direction from anaphora
  resolution, which consumes a pronoun and finds its antecedent.

### What follows, in both directions

**The decidability claim survives, but its justification changes.** We are strictly *below*
both RA and GA rather than between them: the ingredient the undecidability proof needs — a
pronoun whose referent co-varies with a quantified antecedent — is inexpressible. The
discriminating pair is pinned in the test: from "every artist admires that beekeeper" and
"that beekeeper is nice" it follows that every artist admires something nice, because there
is one beekeeper; from "every artist admires a beekeeper" and "some beekeeper is nice" it
does not, and the test exhibits the countermodel. The paper must therefore say **"our
fragment has no anaphora"**, never "we implement restricted anaphora" — the latter would
claim Thm 15's NEXPTIME expressiveness we do not have.

**And it is a coverage cost, to be reported as a limitation.** These are the same fact seen
from either side. Pratt-Hartmann's witness sentence cannot be translated faithfully at all:
to write *him* you need a term, and any term you write is either a general term (wrong — it
does not co-refer) or a proterm (wrong — it is one fixed individual for the whole formula).
Real regulatory text is full of such back-references, so 4.6 should expect them among the
`Outside_fragment` reasons and they belong in the paper's limitations beside the fragment's
other gaps.

### Evidence

`test/test_anaphora.ml`: 18 checks. Positives are carried by the engine's own verdicts where
the case is inside the categorical fragment and decisive; **every negative is carried by an
exhibited countermodel** from the 1.10 semantics, because outside the categorical fragment
the engine answers `Unknown` where the truth is "invalid" — an `Unknown` can never establish
a negative. The test pins that `Unknown`, too, so the incompleteness cannot quietly become a
verdict.
