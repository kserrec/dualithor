# Port specification: JS reference engine → OCaml

This document is the contract for the OCaml port (PLAN Phase 1). It was written by reading
`engine/tfl.js` (2,034 lines) in full. The JS engine is the executable specification: where
this document and the code disagree, **the code wins** — fix the document, never the code.
Every behavioral claim below is stated so the differential harness (PLAN 1.3) can check it.

Layer names D1–D9 below are the JS engine's own internal milestones (from the courseware it
was built for); they are kept as convenient labels for grouping, nothing more.

---

## 1. Notation accepted by the parser

Transcribed from the `tfl.js` header, verified against the tokenizer/parser code.

| Notation | Meaning |
|---|---|
| `−S+P`, `-S+P` | a proposition: (quantity sign)(subject term)(quality sign)(predicate term) |
| `+` `−` `-` `±` `+-` | signs: plus; minus (typographic U+2212 or ASCII); wild quantity (`±` or the ASCII alias `+-`) |
| `Socrates*`, `±s*` | singular terms carry a trailing star |
| `Boy'`, `A″`, `Girl′` | proterm primes: `′` → `'` and `″` → `''` are normalized into the name |
| `Wise`, `German_Shepherd`, `H2O`, `S₁₂` | bare term names: a Unicode letter, then letters, digits, `_`, subscript digits (`₀`–`₉`), primes. **No hyphens** — ASCII `-` and typographic `−` are always the minus sign, so `non-smoker` cannot lex as one term |
| `"non-smoker"`, `"head of a horse"` | quoted terms allow anything except the quote char and newline; may take a trailing `*` after the closing quote |
| `(−T)` | negative term (single minus-signed group) |
| `(+White+Horse)` | compound (conjunctive) term — first element signed; 2+ elements, all signed |
| `(Lov+Girl)`, `(Gave+Rose+Girl)`, `(Lov+(Adm−Teacher))` | relational complex — **unsigned** head term, then one or more signed objects; n-ary and nesting unbounded; objects may be wild: `(Lov±Mary*)` |
| `[p]`, `+[+A″+B]+[+A″+C]` | propositional terms wear square brackets; the content is a proposition or a bare statement term |
| `+V^2+C⁰` | quantity levels (TFL⁺): explicit `^` marker with ASCII digits, or superscript digits (`⁰`–`⁹`). Level 0 is classical some/every and is what the printer omits |

ASCII aliases exist so plain-keyboard input works: `-` for `−`, `+-` for `±`, `^n` for
superscript levels, `'`/`''` for `′`/`″`.

> **Port note (decided 2026-07-29):** the JS reference accepts any Unicode letter in bare
> names; the OCaml engine narrows bare-name letters to ASCII (quoted terms still carry
> arbitrary text). See hazard §16.4 for the full decision and its consequences.

### Tokenizer details a port must reproduce

Token kinds: `plus` `minus` `wild` `lparen` `rparen` `lbracket` `rbracket`
`name`(text, singular) `level`(value) `eof`. Each token carries `pos`, the 0-based index of
its first character in the source string. Whitespace (anything matching `\s`) is skipped.

- `+-` and `+−` lex as one `wild` token (a bare minus after `+` could never start a term —
  negative terms are parenthesized).
- Inside a bare name: `′` appends `'`; `″` appends `''`; **a double-quote `"` immediately
  following name characters also appends `''`** (so `A"` is read as `A″` — a quoted term
  can never directly follow a name). A quoted term only starts a token when `"` appears in
  token-start position.
- A trailing `*` immediately after a name (bare or quoted) sets `singular: true` and is
  consumed; it is not part of the name.
- Quoted terms: unclosed quote → ParseError `Unclosed quote` at the opening quote's
  position; empty `""` → ParseError `Empty quoted term`.
- `^` not followed by at least one ASCII digit → ParseError. Superscript digit runs
  accumulate a base-10 value.
- A leading ASCII digit → ParseError `Term names must start with a letter`. Any other
  unrecognized character → ParseError ``Unexpected character 'c'``.

## 2. AST

```
term  := Atom(name: string, singular: bool)
       | Neg(term)
       | Compound(elements: signed_term list)        (* 2+ elements when built by parser *)
       | Rel(head: term, objects: signed_term list)  (* head unsigned; 1+ objects *)
       | PropTerm(inner: prop | term)                (* term case: a bare Atom *)

signed_term (ST) := { sign: '+' | '-' | '±';  term;  level: int }   (* level ≥ 0, 0 = classical *)

prop := { subject: ST; predicate: ST }
```

Signs are stored in ASCII form internally (`'-'` not `'−'`); the printer emits typographic
`−`/`±`. Structural equality (`termEq`/`stEq`/`propEq`) is plain recursive equality — OCaml's
derived structural `=` will match once the representation mirrors this.

## 3. Parser

Grammar (from the code, which matches the header comment):

```
proposition := signed signed EOF
signed      := sign term level?
sign        := '+' | '−' | '±'
term        := name | '(' group ')' | '[' prop-or-name ']'
group       := sign term                → Neg (−) / the term itself (+) / error (±)
             | sign term (sign term)+   → Compound
             | term                     → the term itself (plain grouping parens)
             | term (sign term)+        → Rel (unsigned head)
```

Three entry points, each requiring end-of-input after its production:
`parseProposition`, `parseTerm`, `parseSignedTerm`.

Notable rules:
- `(+T)` collapses to `T`; `(T)` collapses to `T`; `(−T)` is `Neg T`; a lone `(±T)` is a
  ParseError ("A wild sign (±) needs a proposition or relational-complex context").
- A level on the single element of a bare signed group — `(+T^1)` — is a ParseError.
- `[...]` contains either a full proposition (first token is a sign) or a single bare name;
  anything else is an error.
- Error messages are specific and positional; the port should reproduce the *classification
  and position* exactly. (The differential harness compares error presence and position;
  message texts should match too since they're few and fixed.)

**ParseError**: carries `pos` (0-based index into source) and a message suffixed
`" (at position N)"`.

## 4. Printer

- `printTerm` / `printProposition` / `printST` emit the canonical concrete syntax:
  typographic `−` and `±`, compact spacing (no spaces at all), superscript levels with
  level 0 omitted.
- A name is printed bare iff `isBareName`: nonempty, starts with a Unicode letter, every
  char is a name char (letter, digit, `_`, `'`, subscript digit). Otherwise it is wrapped
  in double quotes (contents not escaped — a name containing `"` cannot round-trip; the
  tokenizer can't produce one).
- Round-trip contract: `parse (print x)` is structurally equal to `x` for every AST the
  parser can produce.
- `printHtmlTerm`/`printHtmlProposition`: same output with atom names HTML-escaped —
  **courseware-only, not ported** (§13).

## 5. Engine-fragment validation

`validateProp` (and its helper `validateTerm`) gate every inference entry point. Violations
raise **EngineError** (distinct from ParseError — the input parsed but is outside the
inference fragment). Rules:

- A compound element may not be `±`-signed and may not carry a nonzero level.
- A relational object may not carry a nonzero level; a `±` object must be a **fixed
  reference** (see below).
- Inside `[...]`: a prop inner is validated recursively; a bare-term inner is not.
- The predicate of a proposition: level must be 0, sign must not be `±`.
- The subject: level must be 0–3; a nonzero level requires sign `+` (intermediate
  quantifiers are particular); a `±` subject must be a fixed reference.

**Fixed reference** (`isFixedRef`): an Atom that is singular (`*`) or a proterm — a name
ending in `'` (`isProtermName`). Fixed references get wild-quantity treatment: on a
singleton, some/every are the same claim.

Levels 0–3 mean: 0 some/every (classical), 1 many, 2 most, 3 few/predominant
(Castro-Manzano et al. 2018, Table 8). The parser accepts any level; validation caps at 3.

## 6. Canonical form

`canonTerm` / `canonProp` implement equality up to Com (conversion), Assoc, DN, and wild
quantity. All inference-facing functions push everything through canonical form; **the
canonical printed string is the identity key everywhere** (`propKey`, `termKey`).

`canonTerm`:
- `Neg(Neg t)` strips (DN); recursion first, so any even stack vanishes.
- Compounds: recursively canonicalize elements; a `+`-signed element that is itself a
  compound splices its elements in (Assoc); a **singleton** result collapses (a `-`
  singleton becomes `Neg`, canonicalized again); otherwise elements **sort by their printed
  form** (`printST`), JS `<`/`>` string comparison (see hazard §14.1).
- Rel: objects canonicalize; an object whose term is a fixed reference gets its sign
  normalized to `±`. The head canonicalizes; an Atom head whose trailing subscript run is
  the **identity pairing** for its arity gets the run stripped (bare head is canonical).
- PropTerm: prop inner → `canonProp`; bare-term inner left as-is.

`canonProp`:
- Both sides' terms canonicalize; a fixed-reference subject's sign normalizes to `±`.
- Conversion: I-forms (`+ _ + _`, with `±` counting as `+`) and E-forms (`− _ − _`, with
  `±` counting as `−`) commute. If the predicate term's key (`printTerm` of the canonical
  term) is **strictly less than** the subject's, swap sides; the new subject sign is `±` if
  the new subject term is fixed-reference, else the base sign (`+` for I, `-` for E); the
  new predicate sign is the base sign. An un-swapped commutable prop still normalizes its
  subject sign the same way.
- Non-commutable forms (A, O) pass through with signs intact.

`propKey p = printProposition (canonProp p)`; `termKey t = printTerm (canonTerm t)`;
`propEqUpTo` compares propKeys.

Size measures used for search fuel: `nodeCount` (atom 1; neg 1+inner; compound 1+Σ element
terms; rel 1+head+Σ object terms; propterm 2+inner where a prop inner counts
`propNodes = nodeCount subject.term + nodeCount predicate.term`). Note `propNodes` ignores
the ST wrappers — only the two term trees count.

## 7. Immediate inferences

All return canonical props. `flipSign`: `+`↔`-`, `±` stays `±`.

- **EN / `contradictory`**: flip both the quantity and quality signs. (Used for
  counterclaims; not itself an entailment.)
- **IN / `obverse`**: flip the quality sign and negate the predicate term.
- **Contrap / `contrapositive`**: defined only for A-forms (subject `-` or `±`, predicate
  `+`) and O-forms (subject `+` or `±`, predicate `-`); returns **null** otherwise.
  A: `−S+P → −(−P)+(−S)`; O: `+S−P → +(−P)−(−S)`.
- **It / `tautology`**: `t ↦ −T+T` ("every T is T" — safe with no existential import;
  `+T+T` would not be).

## 8. Occurrences, substitution, and the mediate rules

### Occurrences (the net-sign rule)

`occurrences p` walks both sides and lists every term position with:
`term`, `path` (`['subject'|'predicate', child indices…]`), `sign` (net sign: product of
governing signs, +1/−1), `ownWild` (the occurrence's own slot sign is `±`).

- Root: subject with sign −1 if subject sign is `-` else +1, ownWild iff `±`; predicate
  likewise (predicate `±` is excluded by validation; ownWild false).
- `Neg` flips the sign for its child. Compound elements: `-`-signed elements flip. Rel
  objects: `-`-signed flip, `±`-signed set ownWild.
- **Opaque positions**: relation heads and the inside of propositional terms are not
  descended into — the rules never substitute there.

`canBePlus occ = occ.ownWild || occ.sign = +1`.

### Substitution

`replaceAt p path newTerm fixSign` replaces the term at `path` and returns the canonical
result. A `±` slot **being substituted at** (path ends exactly there) is fixed to `fixSign`
— the wild resolution that produced the wanted net sign (under an odd number of governing
minuses only the universal reading puts the occurrence at net `+`; the JS fuzz oracle
caught a version that hard-coded `+`). `canonProp` restores `±` when the new term is itself
fixed-reference.

### DON (dictum de omni)

`donorReadings p`: a premise whose subject sign is **not** `+` (so `-` or `±` — the wild
uses its universal reading) donates: M = subject term; D = predicate term if predicate sign
`+`, else `canonTerm (Neg predicate.term)` (the obverse reading).

`applyDON donor host`: for each donor reading (skip if D's key equals M's), for each host
occurrence with `canBePlus` and key = M's key, produce
`replaceAt host occ.path D (occ.sign = 1 ? '+' : '-')`. Returns all results.

### Simp

`applySimp p`:
- For each net-`+`-capable occurrence of a **compound**: drop each conjunct in turn (a
  1-element remainder collapses: `-`-signed → `Neg`, else the bare term).
- If the subject sign is `+` or `±`: also emit `+S+S`; and if additionally the predicate
  sign is `+`: emit `+P+P`.

### Add

`applyAdd a b`: try both orders (x,y). Requires: same subject term key; both predicate
signs `+`; **y**'s subject sign `-` or `±`. Result: subject = x's subject (sign preserved),
predicate `+ (+Px +Py)` (canonicalization sorts the compound). Captures
`{−S+A, −S+B} ⊢ −S+(+A+B)` and `{+S+A, −S+B} ⊢ +S+(+A+B)`.

## 9. Relational layer

### Pairing subscripts

`headRoles name arity`: if the name ends in a subscript-digit run of length exactly
`arity` **and** that run is a permutation of 1..arity, split it off as `roles`; otherwise
the run is part of the name and roles default to the identity [1..arity].
`makeHeadName base roles` re-attaches the run unless it is the identity (bare head is
canonical). Arity = number of objects + 1 (the subject participates).

### The passive transformation

`passives p` returns all passives of a proposition, each tagged
`{prop, equivalent: bool, swapped: k}`. Only `equivalent: true` results are
inference-grade; the rest are the ∀∃/∃∀ scope traps.

- Orientation: `orientations p` yields the prop and, for I/E-forms (with a fixed-reference
  wild counting as either), its converse — both orientations are examined for a top-level
  relational predicate.
- Requirements per orientation: predicate sign `+`, predicate term a Rel, head an Atom,
  participants (objects+1) ≤ 9.
- For each object slot k: swap subject with object k; signs travel with their terms; the
  head records the participant permutation in pairing subscripts (swap roles[0] and
  roles[k]); the result is `Prop(newSubject, + Rel(head', objects'))`.
- **Symmetry guard**: `slotQuantity st = '±'` if the slot's term is fixed-reference else its
  sign; `scopeCommutes a b = (a = b) || a = '±' || b = '±'`. The swap is `equivalent` iff
  participant 0 commutes with participant k **and** with every participant strictly between
  them, and each of those middle participants commutes with k.
- Results dedupe by `propKey` across both orientations.

### Pronominalization (Skolemization; indirect proof only)

`pronominalize p used` — NOT an entailment (it introduces names); used only inside
`refuteSet` at setup. Returns `{prop, anchors}` or null.

- Universal statements (subject `-`) cannot be pronominalized.
- Witnesses are general atoms (not singular, not proterm) that the statement's existential
  force reaches: a `+` general-atom subject; and — through a `+` quality — atoms at `+`
  object slots (level 0) of relational complexes, nested rels included. Universal slots,
  negations, heads, bracket interiors: nothing. Singulars/proterms need no introduction.
- Each witness atom T is replaced by a fresh proterm T′ (append `'` until unused, checking
  both the `used` set and this call's own fresh names) at a `±` slot, with an **anchor**
  `±T′+T` recorded.
- Both orientations are attempted; the one fixing the most witnesses wins; its fresh names
  are added to `used`.

## 10. Proof search

### `saturate` — shared forward-chaining core

Fuel-bounded saturation shared by direct and indirect proof. Options: `maxLines` (default
400), `sizeCap` (skip any prop with `propNodes > sizeCap`), `rules` (optional Set
restricting rule names). Everything pushed must already be canonical; the dedup key is the
printed proposition.

- `push prop rule parents` → existing line's index if the key is known; null if over
  `sizeCap`; else appends `{prop, key, rule, parents}` and immediately runs `onNewLine`
  (which may set the stopping `hit`, including during setup).
- Main loop over lines i (stops on hit / maxLines): unary results of line i — `IN`
  (obverse), `Contrap` (contrapositive, skipping null), `Simp` (all `applySimp`), `Pass`
  (all `equivalent` passives, canonicalized) — then binary against every earlier line j<i:
  `DON` both directions, `Add`.
- Line order (hence proof shape) is fully deterministic given this iteration order — the
  port must reproduce it (see hazard §14.2).

### `derive premises goal` — direct derivation

Validates all props. `sizeCap = max(propNodes of premises and goal) + slack` (default 8).
Seeds: canonical premises (rule `premise`), then an It tautology line for **every term
occurring anywhere** in premises+goal (`mentionedTerms` — all occurrence subterms, deduped
by termKey in first-seen order). Hit: a line whose key equals the canonical goal's key.
Returns the goal's pruned ancestry via `extract`: `{found, lines}` where lines are
`{n, prop, text, rule, parents}` with 1-based numbers in original derivation order.

### `refuteSet entries` — refutation of a set

Entries are `{prop, rule}`. Same sizeCap scheme. Seeds: canonical entries; then for each
entry its pronominalization (a `Pron` line plus `Anchor` lines, parented on the entry);
then It lines. Hit: a new line whose **contradictory**'s key is already on the board (roots
= [other, new]). On success `extract` appends a synthetic closing line
`{text: '⊥', rule: 'contradiction', parents: the two clashing lines}` with `prop: null`.

### `indirectProof premises conclusion`

`refuteSet` on the premises (rule `premise`) plus the contradictory of the conclusion
(rule `counterclaim`). Sound by Skolemization; by PV a refuted counterclaim validates the
argument.

## 11. The categorical decision (P/Z via closure)

Scope: the **atomic-categorical fragment** — every side of every proposition is an atom
under zero or more negations (`isAtomicProp` via `coreLit` on the canonical term). On this
fragment the decision is COMPLETE (fuzz-verified against the finite-model oracle).

`checkInconsistent props` (throws EngineError outside the fragment) returns null when
consistent, else a certificate `{point, clash, cancellation}`.

Literals: `coreLit` reduces a term to `{name, singular, pol}` (pol = even number of
negations); key format `+Name` / `-Name` with `*` appended for singulars. A `-`-signed
predicate flips the predicate literal's polarity.

- Universals (subject `-` or `±`): contribute implications `sK → qK` and `¬qK → ¬sK`.
- Particulars (subject `+` or `±`): contribute a **point** — a set {sK, qK}. (A wild
  statement contributes both readings — exactly what wild quantity means on a singleton.)
- Every fixed-reference term occurring **anywhere** (all occurrences of every prop) seeds a
  point of its own containing its positive literal (names denote).
- Satisfiability of a point against the implications: unit propagation (an implication
  fires forward from its antecedent and contraposes backward), plus **genuine case splits**
  on the first unassigned implication antecedent — completeness needs the splits (closure
  alone misses forced literals like B in {B→¬B, ¬B→¬A, ¬A→B}; the JS fuzzer caught the
  closure-only version).
- Fixpoint: a point *forced* (2-SAT backbone: adding the negation is unsat) to carry a
  positive fixed-reference literal gains it explicitly; points sharing a positive
  fixed-reference literal merge (that named individual is one individual). Repeat to
  fixpoint.
- Inconsistent iff some point is unsatisfiable. The certificate reports that point's
  literals and, when present, a direct `clash` pair (a literal and its negation both in the
  point).

No existential import anywhere: general terms may be empty; with no particular and no name
there is no individual at all, so universals alone never clash.

### The P/Z cancellation display (`findCancellation`)

Best-effort certificate decoration; **the closure verdict stands either way** (the
cancellation also covers the display only, e.g. vacuous-subject corners cancel nothing).
Wild subjects try both readings (all combinations, capped at 256 combos; over the cap,
fall back to the all-`+`-reading resolution). For each resolution: pick each particular in
turn; search (DFS) over using each universal 0–3 times such that the algebraic sum of all
term occurrences is zero for every term key (`zOccurrences`: flatten each side through
negations with sign multiplication, subject/predicate occurrence sign from the ST sign).
Returns `{particular, universals: [{prop, times>0}]}` or null.

## 12. Verdicts: `checkArgument`, and the TFL⁺ numerical decision

### Verdict vocabulary

```
verdict : 'valid' | 'invalid' | 'contradicted' | 'unknown'
method  : 'PZ' | 'derivation' | 'indirect' | 'numerical'
```

- `PZ` verdicts (`valid`/`invalid`) are **complete** for atomic-categorical arguments —
  `invalid` genuinely means the conclusion does not follow.
- Outside that fragment the engine reports what proof search establishes within fuel:
  `valid` (direct derivation, else indirect proof), `contradicted` (the conclusion's
  contradictory is derivable — direct, else indirect), else **`unknown`**.
- **`unknown` ≠ `invalid`.** It means the bounded derivation search found neither a proof
  nor a refutation. This distinction is load-bearing for the whole project (the router's
  abstention semantics) and must never be collapsed.

### `checkArgument premises conclusion opts`

Order of decision (opts `{maxLines, slack}` thread into the searches):
1. Any nonzero quantity level anywhere → `numericalDecision`; verdict `valid`/`invalid`,
   method `numerical`, with the full `decision` record attached.
2. Premises + contradictory(conclusion) all atomic-categorical → counterclaim test:
   inconsistent → `{verdict:'valid', method:'PZ', certificate}`; consistent →
   `{verdict:'invalid', method:'PZ'}`.
3. `derive` → `{valid, derivation, proof}`.
4. `indirectProof` → `{valid, indirect, proof}`.
5. `derive` of the contradictory → `{contradicted, derivation, proof}`.
6. `indirectProof` of the contradictory → `{contradicted, indirect, proof}`.
7. `{verdict:'unknown', method:'derivation'}`.

### `numericalDecision premises conclusion` (TFL⁺)

Fragment: all props atomic-categorical; no `±` subjects (a level has no wild reading);
levels validated 0–3 by `validateProp`. Throws EngineError otherwise. Returns
`{valid, conditions: {sum, particular, level}, carriedLevel, conclusionLevel,
particularPremises, particularConclusions}` with `valid = sum && particular && level`:

- **(i) sum**: the algebraic sum of premise sides minus conclusion sides is zero per term
  key (`sideCoeff`: occurrence sign (− for `-`, else +) times the literal's negation
  parity; key includes the `*` for singulars).
- **(ii) particular**: number of `+`-subject premises equals number of `+`-subject
  conclusions (0 or 1).
- **(iii) level — the term-matched correction.** The literature's condition (iii) is "the
  conclusion's level does not exceed the maximum premise level". The engine implements a
  **stricter, term-matched** condition: a conclusion's nonzero level must be licensed by a
  premise whose own subject **is the conclusion's subject term** (`carriedLevel` = max
  level over `+`-subject premises with that subject termKey, else 0); the conclusion's
  level must be ≤ `carriedLevel`. Rationale: an intermediate quantity ("most", "many",
  "few") is carried by the term it quantifies — "most bakers are honest" says nothing
  about "most honest people" — so a level riding the middle term licenses nothing. This
  agrees with Castro-Manzano et al. 2018's own Tables 10–13 and with the finite-model
  semantics (att-3 with a "most" conclusion is invalid), and is a **deliberate, documented
  deviation** from the loose reading of the paper's condition (iii). The port must
  implement the term-matched version exactly.

  Worked discriminator (why term-matched, not "≤ max premise level"):
  - **att-1**: All M are P; **Most S** are M ⊢ Most S are P. The "most" rides S — the
    conclusion's own subject — so the conclusion's level 2 is licensed. Valid (and listed
    in the paper's Table 9, figure 1).
  - **att-3**: All M are P; **Most M** are S ⊢ Most S are P. Same letters, but the "most"
    rides the middle term M; nothing quantifies S beyond bare "some". The loose reading
    (conclusion level 2 ≤ max premise level 2) would wrongly pass it; term-matched gives
    carriedLevel 0 and rejects. Invalid (and absent from Table 9, figure 3).

  **Source verification (2026-07-29).** The engine was checked mechanically against the
  primary source (Castro-Manzano, Lozano-Cobos & Reyes-Cárdenas 2018, *BRAIN* 9(3)): all
  4,000 two-premise patterns (10 moods³ × 4 figures) agree exactly with the paper's
  Table 9 valid-pattern lists plus the 15 classically valid moods without existential
  import — zero mismatches; the four worked examples (Tables 10–13: kaa-1 invalid, akt-4
  invalid, bao-3 valid, ekg-2 valid) all reproduce; and the att-1/att-3 pair confirms the
  term-matched condition is what produces the agreement. See LOG.md; these cases feed the
  1.13 paper-cases suite.

## 13. Programs, queries, equivalence

### `parseProgram src`

Line-oriented; comments run from `--` (any mix of ASCII/typographic minus, two adjacent) to
end of line — two adjacent minuses can never occur in valid notation, since negative terms
are always parenthesized. Blank/comment-only lines are skipped. Returns
`{propositions: [{prop, text, line}], errors: [{line, message, pos}]}` — per-line
ParseErrors are collected, not thrown, so one bad line doesn't sink the rest. **Note:
`parseProgram` does not validate** — fragment validation happens in the query functions.

### `queryTerm program term opts` — "what is T?"

Throws EngineError if the program carries any nonzero level. Saturates on rules
{IN, Contrap, Simp, DON} only (never Add or Pass), maxLines 300 default, sizeCap =
max(program propNodes, nodeCount term) + slack (default 6), seeded with program facts +
It lines. Collects lines "about" the term: skip `It`-rule lines; find an orientation whose
subject termKey matches; drop the term's own tautology and its obverse; dedupe by propKey.
Then keeps only the **strongest**: drop any candidate an already-kept answer entails by the
unary rules alone (`implies`: tiny saturate, rules {IN, Contrap, Simp}, maxLines 60,
sizeCap max nodes+2), and evict kept answers the new candidate subsumes. Sort: `propNodes`
descending, then printed form ascending. Returns `[{prop, text}]`.

### `queryProp program query opts` — three-way verdict

`checkArgument(program, query)`: valid → `{verdict:'yes', support}`; contradicted →
`{verdict:'no', support}`. If the method was `PZ` and the verdict `invalid`, additionally
try `checkArgument(program, contradictory(query))`: valid → `no`. Else
`{verdict:'unknown'}`. (Relational `unknown` already tried the contradictory inside
`checkArgument`.)

### `checkProgramConsistency program opts`

- Any nonzero level → `{consistent: true, complete: false, numerical: true}` (numerical
  inconsistency is undefined in the source paper; report undecided).
- Atomic-categorical → closure decides: consistent → `{consistent: true, complete: true}`;
  else `{consistent: false, complete: true, certificate, proof}` (proof from `refuteSet`,
  null if the fueled search doesn't find one).
- Otherwise → `refuteSet`: found → `{consistent: false, complete: false, proof}`; else
  `{consistent: true, complete: false}` ("no contradiction found within fuel").

### `equivalents prop opts` / `decideEquivalence a b opts`

Both throw EngineError on nonzero levels.

`equivalents`: BFS closure of the canonical prop under the bidirectional immediate rules
`obverse` and `contrapositive` (conversion and DN are absorbed by canonical form, so the
closure is finite; node cap `maxNodes` default 64). Each entry:
`{prop, text, rule ('given' | last op name), reading, path}` — readings are the exact
strings `the statement itself`, `` its obverse ``-style one-step, or
`its <op> then <op> …`.

`decideEquivalence`: if **both** props have a `statementModel`, decide completely by truth
table over the union of atoms (sorted; bitmask enumeration, bit i = atom i) —
`{equivalent, method:'dnf', atoms, dnf}` where `dnf` lists each satisfying row of `a` as a
string of `+atom`/`−atom` (typographic minus) with true atoms first. Otherwise fall back to
the rewrite closure of `a`: `{equivalent, method:'rewrite', path | null}`.

`statementModel prop`: non-null only when the prop is purely propositional — every atom
lowercase-initial (`\p{Ll}`), non-singular; no relational complexes anywhere; 1–16 atoms.
Propterm inners recurse. Semantics: one-member universe — compound = signed conjunction;
universal `S → qual` (no import), particular `S ∧ qual`; quality `-` negates the
predicate's value.

## 14. NL rendering (exact-string contract)

The pipeline's back-translation check depends on **byte-exact deterministic rendering** —
the port must match these strings exactly (PLAN 1.9).

### `readTerm`

- Atom: strip trailing primes for display (`baseName`); singular → name as-is (proper
  name keeps case); proterm → `that <lowercased base>`; general → lowercased name.
- Neg → `non-<reading>`; compound → elements joined ` and `, `-`-signed as `non-…`.
- Rel → `<lowercased head reading> <objects>`, each object prefixed `every ` (−) /
  `some ` (+) / nothing (±), joined by spaces, trimmed.
- PropTerm(prop) → the reading wrapped in typographic double quotes `“…”`; bare inner →
  its reading.

### `readProp`

First re-orient so a fixed-reference term is the subject if any orientation allows
("Socrates is a man", not "some man is Socrates"). Then:

- Fixed-ref subject: relational predicate → `<who> <does not >?<rel reading>`; otherwise
  `<who> is [not ]<article?><reading>` — the article (`a `/`an ` by leading vowel of the
  rendered predicate, case-insensitive) appears only for a plain non-singular atom
  predicate.
- Universal subject (−): quality + → `every <S> <relTail pred false>`; quality − →
  `no <S> is <reading>` (or `no <S> <rel reading>` for a relational predicate).
- Particular subject with nonzero level (non-relational predicate): quantifier word
  `many`/`most`/`few`; **`few` inverts the English polarity** (`+S³+P` reads "few S are
  not P", `+S³−P` reads "few S are P" — few = predominant complement).
- Otherwise: `some <S> <relTail pred (quality = '-')>`.
- `relTail pred neg`: relational → `[does not ]<rel reading>`; else `is[ not] <reading>`.
  (Note: no article in general-subject readings — "every man is mortal thing"-style
  output is what the engine emits and what the port must reproduce.)

### `explainProof proof`

Null for missing/failed proofs. Given lines (`premise`/`fact`/`counterclaim` with a prop)
render as `Because <r1>, and <r2>, …`. A refutation (last line text `⊥`):
`Because …, it would follow that <clash1>, yet <clash2> — which is impossible.` (clash
lines resolved from the closing line's parents). Otherwise: `Because …, <last line>.`

### Numerical explanation (deferred with `answer` — see §15)

`numericalExplanation` and `levelName` are helpers of the Aristotelian `answer` layer and
are deferred with it.

## 15. Export inventory and port disposition

**Ported** (grouped by PLAN step):

| PLAN | Functions |
|---|---|
| 1.1 AST | `Atom Neg Compound Rel PropTerm ST Prop`, `termEq stEq propEq` |
| 1.2 parse/print | `tokenize` (internal), `parseProposition parseTerm parseSignedTerm`, `printTerm printProposition printSignedTerm isBareName`, `ParseError` |
| 1.4 core A | `EngineError validateProp canonTerm canonProp propKey termKey propEqUpTo contradictory obverse contrapositive tautology occurrences` |
| 1.5 core B | `applyDON applySimp applyAdd derive checkInconsistent checkArgument` |
| 1.6 relational | `isProtermName isFixedRef headRoles passives pronominalize indirectProof refuteSet` |
| 1.7 programs | `parseProgram queryTerm queryProp checkProgramConsistency equivalents decideEquivalence statementModel` |
| 1.8 numerical | `hasLevel numericalDecision` |
| 1.9 NL | `readTerm readProp explainProof` |

**Not ported** (courseware-only):
- `printHtmlTerm` / `printHtmlProposition` — HTML-escaping printers for the course DOM.
- `checkExpression` — exercise grading (transcribe/derive/premise modes).

**Deferred** unless a later phase needs them (Aristotelian database extras):
- `answer`, `strongerAnswer`, `possibility`, `suggestMissingPremise`, plus their private
  helpers `tacitCandidates`, `numericalExplanation`, `levelName`.

## 16. Port hazards — JS semantics the OCaml side must consciously match

1. **String ordering.** Canonical sorting (compound elements, conversion's side swap,
   `decideEquivalence` atom sort, `queryTerm` final sort) uses JS `<` — **UTF-16 code-unit
   order**. OCaml's byte-wise UTF-8 `String.compare` agrees with it on all BMP characters
   (both equal code-point order there) but diverges for astral-plane characters (UTF-16
   surrogates sort astral chars below U+E000..U+FFFF). Term names admit any `\p{L}` letter,
   astral included. **Decided (Kyle, 2026-07-29): the OCaml engine uses plain byte-wise
   UTF-8 comparison (code-point order) — no UTF-16 emulation.** Sort order never affects
   verdicts, only which equivalent canonical spelling wins. QCheck name generators stay
   inside the BMP so the differential corpus never straddles the divergence; the 1.12
   report documents the deliberate ordering difference. JS-isms live in the harness, never
   the engine.
2. **Iteration order is semantics.** JS `Map`/`Set` iterate in insertion order, and
   `Array.prototype.sort` is stable. Proof line order, It-line seeding order
   (`mentionedTerms`), point construction, and `queryTerm`'s answer order all inherit from
   this. The port must use order-preserving structures (or explicit ordering) wherever a
   Map/Set feeds output.
3. **Numbers.** Quantity levels are parsed with `parseInt` / digit accumulation into JS
   doubles; huge levels (>2^53, or ≥1e21 where `String(n)` goes scientific) lose
   round-trip fidelity in JS. Validation caps meaningful levels at 3; treat huge levels as
   out-of-contract (generators cap them; differential harness doesn't probe them).
4. **Unicode classes and case.** `isNameStart`/`isNameChar` use `\p{L}` and the
   lowercase-initial check uses `\p{Ll}`; `readTerm` uses full `toLowerCase()`. **Decided
   (Kyle, 2026-07-29): bare-name letters are ASCII-only in the OCaml engine — no Unicode
   tables dependency.** The notation's fixed non-ASCII symbols (−, ±, sub/superscripts,
   primes) are unaffected, and quoted terms still accept arbitrary text, so no expressive
   power is lost; the translation prompt (4.2) teaches quoting for non-ASCII names. A
   non-ASCII letter in bare-name position raises a `Lexical`-class error advising quoting
   (1.14 taxonomy). Renderer lowercasing and the `statementModel` lowercase-initial check
   are ASCII-only; differential corpora keep names ASCII; the residual divergences from
   the JS reference are documented in the differential report.
5. **Deep nesting.** The JS engine recurses freely; pathologically deep input dies with a
   stack-overflow `RangeError`, not a ParseError. The port's 1.14 `Safe` API must instead
   return a structured error (depth cap); before 1.14, differential fuzzing should cap
   generated depth so both engines stay in their sound range.
6. **Search fuel defaults.** `maxLines` 400 (saturate default) / 300 (`queryTerm`) / 60
   (`queryTerm.implies`); `slack` 8 (derive/refute) / 6 (`queryTerm`) / 2 (`implies`);
   `equivalents` node cap 64; passive participant cap 9; cancellation combo cap 256;
   universal reuse cap 3; `statementModel` atom cap 16; `tacitCandidates` atom cap 8
   (deferred). Identical fuel is required for verdict-level agreement on the relational
   fragment — an `unknown` is a function of fuel.

## 17. Verdict/result record shapes (for the differential shim)

```
checkArgument → { verdict, method }
  + method 'numerical'  : decision: {valid, conditions:{sum,particular,level},
                          carriedLevel, conclusionLevel, particularPremises,
                          particularConclusions}
  + method 'PZ' valid   : certificate: {point: [litKey…], clash: [k, ¬k] | null,
                          cancellation: {particular, universals:[{prop,times}]} | null}
  + search methods      : proof: {found, lines: [{n, prop, text, rule, parents}]}
checkInconsistent → null | certificate (as above)
queryProp → { verdict: 'yes'|'no'|'unknown', support? }
checkProgramConsistency → { consistent, complete, numerical?, certificate?, proof? }
decideEquivalence → { equivalent, method: 'dnf'|'rewrite', atoms?, dnf?, path? }
derive/refuteSet/indirectProof → { found, lines }
```

The shim (1.3) serializes these as JSON; ASTs serialize with their type tags exactly as the
JS objects are shaped (`{type:'atom', name, singular}` etc.), signs in ASCII form, so both
sides compare structurally.
