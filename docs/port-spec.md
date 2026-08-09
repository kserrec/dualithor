# TFL core mechanics appendix

This is the detailed operational appendix to the normative
[core language reference](core-language.md). It began as the contract for porting the
frozen JavaScript engine to OCaml, which explains the filename and historical function
names. As of contract `core-0.1`, neither implementation silently overrides this appendix.
A disagreement with the public reference or executable conformance corpus is a contract
defect that must be resolved explicitly.

Historical comparisons with `engine/tfl.js` remain because they explain compatibility
choices. The authoritative current choices are the ones stated here and in
`core-language.md`.

---

## 1. Notation accepted by the parser

The accepted concrete notation is:

| Notation | Meaning |
|---|---|
| `−S+P`, `-S+P` | a proposition: (quantity sign)(subject term)(quality sign)(predicate term) |
| `+` `−` `-` `±` `+-` | signs: plus; minus (typographic U+2212 or ASCII); wild quantity (`±` or the ASCII alias `+-`) |
| `Socrates*`, `±s*` | singular terms carry a trailing star |
| `Boy'`, `A″`, `Girl′` | proterm primes: `′` → `'` and `″` → `''` are normalized into the name |
| `Wise`, `German_Shepherd`, `H2O`, `S₁₂` | bare term names: an ASCII letter, then ASCII letters, digits, `_`, subscript digits (`₀`–`₉`), primes. **No hyphens** — ASCII `-` and typographic `−` are always the minus sign, so `non-smoker` cannot lex as one term |
| `"non-smoker"`, `"head of a horse"` | quoted terms allow ordinary Unicode except the quote character, C0/C1 controls, and bidirectional formatting controls; may take a trailing `*` after the closing quote |
| `(−T)` | negative term (single minus-signed group) |
| `(+White+Horse)` | compound (conjunctive) term — first element signed; 2+ elements, all signed |
| `(Lov+Girl)`, `(Gave+Rose+Girl)`, `(Lov+(Adm−Teacher))` | relational complex — **unsigned** head term, then one or more signed objects; n-ary and nesting unbounded; objects may be wild: `(Lov±Mary*)` |
| `[p]`, `+[+A″+B]+[+A″+C]` | propositional terms wear square brackets; the content is a proposition or a bare statement term |
| `+V^2+C⁰` | quantity levels (TFL⁺): explicit `^` marker with ASCII digits, or superscript digits (`⁰`–`⁹`). Level 0 is classical some/every and is what the printer omits |

ASCII aliases exist so plain-keyboard input works: `-` for `−`, `+-` for `±`, `^n` for
superscript levels, `'`/`''` for `′`/`″`.

Non-ASCII names remain expressible through quoted terms.

### Tokenizer details

Token kinds: `plus` `minus` `wild` `lparen` `rparen` `lbracket` `rbracket`
`name`(text, singular) `level`(value) `eof`. Each token carries `pos`, the 0-based index of
its first Unicode code point in the source string. The fixed whitespace set listed in
`core-language.md` is skipped.

- `+-` and `+−` lex as one `wild` token (a bare minus after `+` could never start a term —
  negative terms are parenthesized).
- Inside a bare name: `′` appends `'`; `″` appends `''`; **a double-quote `"` immediately
  following name characters also appends `''`** (so `A"` is read as `A″` — a quoted term
  can never directly follow a name). A quoted term only starts a token when `"` appears in
  token-start position.
- A trailing `*` immediately after a name (bare or quoted) sets `singular: true` and is
  consumed; it is not part of the name.
- Quoted terms: unclosed quote → ParseError `Unclosed quote` at the opening quote's
  position; empty `""` → ParseError `Empty quoted term`; C0/C1 or bidirectional
  formatting control → lexical ParseError at that control.
- `^` not followed by at least one ASCII digit → ParseError. Superscript digit runs
  accumulate a base-10 value.
- A leading ASCII digit → ParseError `Term names must start with a letter`. Any other
  unrecognized printable character → ParseError ``Unexpected character 'c'``. Unsafe
  terminal or bidirectional controls are named as `Unexpected unsafe character U+NNNN`
  without replaying the character in the diagnostic.

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
- Error messages are specific and positional; implementations must reproduce their
  classification and Unicode-code-point position exactly.

**ParseError**: carries `pos` (0-based index into source) and a message suffixed
`" (at position N)"`.

## 4. Printer

- `printTerm` / `printProposition` / `printST` emit the canonical concrete syntax:
  typographic `−` and `±`, compact spacing (no spaces at all), superscript levels with
  level 0 omitted.
- A name is printed bare iff `isBareName`: nonempty, starts with an ASCII letter, every
  char is an ASCII letter, digit, `_`, `'`, or subscript digit. Otherwise it is wrapped
  in double quotes (contents not escaped — a name containing `"` cannot round-trip; the
  tokenizer can't produce one).
- Round-trip contract: `parse (print x)` is structurally equal to `x` for every AST the
  parser can produce.
- `printHtmlTerm`/`printHtmlProposition`: same output with atom names HTML-escaped —
  **courseware-only and outside `core-0.1`** (§13).

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

**Canonical form is level-less** (verified 2026-07-30): every signed term is rebuilt
through the 2-arg `ST(sign, term)`, whose level defaults to 0 — so canonicalization
silently drops quantity levels (`propKey('+V²+C')` = `'+V+C'`). This is safe only because
`checkArgument` routes any nonzero level to `numericalDecision` *before* canonical form
matters. The level drop is a recorded limit, not numerical semantic equality.

`canonTerm`:
- `Neg(Neg t)` strips (DN); recursion first, so any even stack vanishes.
- Compounds: recursively canonicalize elements; a `+`-signed element that is itself a
  compound splices its elements in (Assoc); a **singleton** result collapses (a `-`
  singleton becomes `Neg`, canonicalized again); otherwise elements **sort by their printed
  form** (`printST`), using byte-wise UTF-8 string comparison.
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
- Line order (hence proof shape) is fully deterministic given this iteration order and is
  part of conformance output.

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
negations). The closure retains that structured triple as identity, so punctuation in a
legal quoted name cannot collide with a singular marker. Certificate text prefixes the
canonical printed atom with `+` or `-`. A `-`-signed predicate flips the predicate
literal's polarity.

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
The whole call shares a 500,000-node budget; exhausting it returns no decoration. Returns
`{particular, universals: [{prop, times>0}]}` or null. The verdict was already decided and
is unchanged by this result.

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
- Under the numerical method, satisfying all three conditions gives `valid`; failure gives
  `unknown` because the procedure is sound but incomplete and never establishes
  invalidity.
- **`unknown` ≠ `invalid`.** It means bounded derivation found neither side, or the
  numerical sufficient conditions did not establish the conclusion. It must never be
  collapsed into falsehood.

### `checkArgument premises conclusion opts`

Order of decision (opts `{maxLines, slack}` thread into the searches):
1. Any nonzero quantity level anywhere in any recursive term tree →
   `numericalDecision`; verdict `valid` if all conditions pass and `unknown` otherwise,
   method `numerical`, with the full `decision` record attached. A nested level therefore
   reaches the numerical fragment check and is refused when the whole argument is not
   atomic categorical; it is never erased by canonicalization first.
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

- **(i) sum**: the algebraic sum of premise sides minus conclusion sides is zero per
  structured `(name, singular)` term identity (`sideCoeff`: occurrence sign (− for `-`,
  else +) times the literal's negation parity).
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
  deviation** from the loose reading of the paper's condition (iii). An implementation
  must use the term-matched version exactly.

  Worked discriminator (why term-matched, not "≤ max premise level"):
  - **att-1**: All M are P; **Most S** are M ⊢ Most S are P. The "most" rides S — the
    conclusion's own subject — so the conclusion's level 2 is licensed. Valid (and listed
    in the paper's Table 9, figure 1).
  - **att-3**: All M are P; **Most M** are S ⊢ Most S are P. Same letters, but the "most"
    rides the middle term M; nothing quantifies S beyond bare "some". The loose reading
    (conclusion level 2 ≤ max premise level 2) would wrongly pass it; term-matched gives
    carriedLevel 0 and fails the sufficient condition. The literature classifies the
    pattern as invalid, but this incomplete runtime returns `unknown` (it is absent from
    Table 9, figure 3).

  **Source verification (2026-07-29).** The engine was checked mechanically against the
  primary source (Castro-Manzano, Lozano-Cobos & Reyes-Cárdenas 2018, *BRAIN* 9(3)): all
  4,000 two-premise patterns (10 moods³ × 4 figures) agree exactly with the paper's
  Table 9 valid-pattern lists plus the 15 classically valid moods without existential
  import — zero condition mismatches; the four worked examples (Tables 10–13: kaa-1 and
  akt-4 fail their stated conditions, bao-3 and ekg-2 pass) all reproduce; and the
  att-1/att-3 pair confirms the term-matched condition. Runtime condition failure is
  surfaced as `unknown`. See LOG.md and the paper-cases suite.

## 13. Programs, queries, equivalence

### `parseProgram src`

Line-oriented; comments run from `--` (any mix of ASCII/typographic minus, two adjacent)
outside quoted or bare names to end of line. A `--` sequence inside a quoted term remains
name content. Blank/comment-only lines are skipped. Returns
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
`{verdict:'no', support}`. If the method was `PZ` or `numerical` and did not establish the
query, additionally try `checkArgument(program, contradictory(query))`: valid → `no`.
Else `{verdict:'unknown'}`. (Relational `unknown` already tried the contradictory inside
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

`decideEquivalence`: if **both** props have a `statementModel`, their combined union has
at most 16 atoms, their worst-case materialized DNF is at most 8,388,608 bytes, and their
estimated evaluation work is at most 8,388,608 AST-node visits, decide completely by truth
table over that union (sorted; bitmask enumeration, bit i = atom i) —
`{equivalent, method:'dnf', atoms, dnf}` where `dnf` lists each satisfying row of `a` as a
string of `+atom`/`−atom` (typographic minus) with true atoms first. Otherwise, including
when two individually eligible inputs exceed a cap only after union or output estimation,
fall back to the rewrite closure of `a`:
`{equivalent, method:'rewrite', path | null}`.

`statementModel prop`: non-null only when the prop is purely propositional — every atom
lowercase-initial ASCII, non-singular; no relational complexes anywhere; 1–16 atoms.
Propterm inners recurse. Semantics: one-member universe — compound = signed conjunction;
universal `S → qual` (no import), particular `S ∧ qual`; quality `-` negates the
predicate's value.

## 14. NL rendering (exact-string contract)

The audit surface depends on **byte-exact deterministic rendering**. Implementations must
match these strings exactly.

### `readTerm`

- Atom: strip trailing primes for display (`baseName`); singular → name as-is (proper
  name keeps case); proterm → `that <lowercased base>`; general → lowercased name.
- Neg → `non-<reading>`; compound → elements joined by one space, `-`-signed as
  `non-…`. A compound is one term, so the renderer does not insert `and`.
- Rel → `<lowercased head reading> <objects>`, each object prefixed `every ` (−) /
  `some ` (+) / nothing (±), joined by spaces, trimmed.
- PropTerm(prop) → the reading wrapped in typographic double quotes `“…”`; bare inner →
  its reading.

### `readProp`

At level 0, first re-orient so a fixed-reference term is the subject if any orientation
allows ("Socrates is a man", not "some man is Socrates"). A nonzero subject level blocks
conversion because it would erase and misstate the numerical quantity. Then:

- Fixed-ref subject: relational predicate → `<who> <does not >?<rel reading>`; otherwise
  `<who> is [not ]<article?><reading>` — the article (`a `/`an ` by leading vowel of the
  rendered predicate, case-insensitive) appears only for a plain non-singular atom
  predicate.
- Universal subject (−): quality + → `every <S> <relTail pred false>`; quality − →
  `no <S> is <reading>` (or `no <S> <rel reading>` for a relational predicate).
- Particular subject with nonzero level, including a relational predicate: quantifier word
  `many`/`most`/`few`; **`few` inverts the English polarity** — few = predominant
  complement. Exact strings (corrected 2026-07-30; `relTail` says "is", never "are"):
  `+S³+P` → `few s is not p`, `+S³−P` → `few s is p`.
- Otherwise: `some <S> <relTail pred (quality = '-')>`.
- `relTail pred neg`: relational → `[does not ]<rel reading>`; else `is[ not] <reading>`.
  When both the subject and predicate readings end or begin with relational text and no
  negative `does not` marks their boundary, insert `, ` between them. (No article appears
  in general-subject readings.)

### `explainProof proof`

Null for missing/failed proofs. Given lines (`premise`/`fact`/`counterclaim` with a prop)
render as `Because <r1>, and <r2>, …`. With no given lines, a successful conclusion is a
standalone capitalized sentence. A refutation (last line text `⊥`):
`Because …, it would follow that <clash1>, yet <clash2> — which is impossible.` (clash
lines resolved from the closing line's parents). Otherwise: `Because …, <last line>.`

### Numerical explanation (deferred with `answer` — see §15)

`numericalExplanation` and `levelName` are helpers of the Aristotelian `answer` layer and
are deferred with it.

## 15. Core implementation inventory

**Implemented in `core-0.1`** (historical PLAN numbers show when each group landed):

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

**Outside the language** (courseware-only):
- `printHtmlTerm` / `printHtmlProposition` — HTML-escaping printers for the course DOM.
- `checkExpression` — exercise grading (transcribe/derive/premise modes).

**Not part of `core-0.1`** (legacy database extras):
- `answer`, `strongerAnswer`, `possibility`, `suggestMissingPremise`, plus their private
  helpers `tacitCandidates`, `numericalExplanation`, `levelName`.

## 16. Determinism, representation, and bounds

1. **String ordering.** Canonical sorting, conversion, equivalence atom order, and final
   term-query order use byte-wise UTF-8 string comparison. This differs from the frozen
   JavaScript reference only on some non-BMP ordering cases and affects canonical spelling,
   not verdicts.
2. **Iteration order is observable.** Proof line order, tautology seeding, point
   construction, and answer order preserve first-seen insertion order. Implementations
   must use ordered structures or explicit order wherever those values become output.
3. **Quantity numbers saturate during tokenization.** Digit accumulation saturates at
   1,000,000,000 rather than overflowing. Validation accepts only levels 0 through 3.
4. **Names and case are ASCII at the bare-name boundary.** Fixed non-ASCII notation
   symbols remain accepted. Quoted names carry ordinary UTF-8 but reject quote,
   C0/C1 controls, and Unicode bidirectional formatting controls; display lowercasing is
   ASCII-only.
5. **Deep nesting is a structured refusal.** The total boundary rejects the 65th opening
   parenthesis or bracket as syntactic input before recursive descent.
6. **Search bounds are semantic metadata.** `maxLines` is 400 for ordinary saturation,
   300 for `queryTerm`, and 60 for its local implication checks. Size slack is 8 for
   derive/refute, 6 for `queryTerm`, and 2 for its implication checks. Equivalence has a
   64-node cap; passives have a nine-participant cap; cancellation has a 256-combination
   cap, three uses per universal, and 500,000 total search nodes; `statementModel` and the
   combined truth-table union have a 16-atom cap; truth-table materialization and
   evaluation each have an 8,388,608-unit budget. A non-atomic or numerical `unknown`
   retains these limits.
7. **The total boundary has byte and count budgets.** One proposition is at most 65,536
   bytes; one argument is at most 1,024 premises and 1,048,576 combined bytes; one program
   is at most 1,048,576 bytes, 65,536 bytes per line, 10,000 physical lines, and 1,024
   parsed propositions; one JSON-lines request is at most 1,048,576 bytes. Exceeding one is
   `resource_limit`, except that excessive bracket depth remains a syntactic refusal.

## 17. Verdict/result record shapes

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

The development differential shim serializes these records as JSON. AST objects carry
explicit type tags (`{type:'atom', name, singular}` and corresponding compound forms) and
store signs in ASCII form so structural comparison remains language-neutral.
