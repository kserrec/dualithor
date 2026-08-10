# TFL core language reference

| Contract metadata | Value |
|---|---|
| Version | `core-0.1` |
| Normative date | 2026-08-09 |
| Status | Normative for the inherited core implemented before the version-1 extension roadmap |

This document fixes the language that exists today. A future phase may extend or revise
it, but an implementation change does not silently change the language: the reference,
the conformance corpus, focused regression tests, and the required oracle gates must move
together.

The detailed operational algorithms in [port-spec.md](port-spec.md) are the mechanics
appendix to this reference. That appendix keeps its historical filename because it began
as the JavaScript-to-OCaml port contract. It is now subordinate to this public contract,
not to either implementation. The executable examples are
[`data/conformance/core-0.1.json`](../data/conformance/core-0.1.json). A disagreement among
these three artifacts is a contract defect to resolve explicitly; the current OCaml code
does not win merely because it is current.

## 1. Scope and layers

The `core-0.1` language consists of:

- plus-minus propositions over general terms, singular terms, and fixed proterms;
- negative, compound, relational, and propositional terms;
- the inherited level-1 through level-3 quantity notation and its sound but incomplete
  numerical argument rule;
- line-oriented programs with comments;
- ground proposition queries, term-description queries, consistency checks, and
  equivalence checks;
- canonical formal output, deterministic English display readings, certificates, and
  proof traces.

The following are not in `core-0.1`: answer variables, user-defined rules, recursion,
modules, imports, declarations, full Numerical Term Logic, modal logic, relevance logic,
free-term profiles, synthetic profiles, negation as failure, or an implicit closed-world
mode. Their roadmap presence does not make them accepted syntax or semantics.

Every existing construct belongs to one of these layers:

| Layer | Existing constructs |
|---|---|
| Core TFL syntax and inference | level-0 categorical, singular, compound, propositional-term, and relational forms; immediate and mediate rules |
| Inherited conservative extension | subject quantity levels 1 through 3 and the numerical sufficient-condition checker |
| Query-only operation | ground proposition query, term-description query, consistency query, equivalence query |
| Host/runtime feature | multi-line programs, `--` comments, bounded search, structured failures, canonical and English rendering |

English is always a display layer. A reading never determines a parse, canonical form,
verdict, or proof.

## 2. Propositions, signs, and existential commitment

A proposition has two signed terms:

```text
proposition = subject predicate
signed-term = sign term quantity-level?
sign        = + | − | ±
```

ASCII `-` is accepted for `−`; `+-` and `+−` are accepted for `±`. The printer emits
typographic `−` and `±`.

At level 0, the subject sign is quantity and the predicate sign is quality:

| Form | Notation | Meaning |
|---|---|---|
| A | `−S+P` | every S is P |
| E | `−S−P` | no S is P |
| I | `+S+P` | some S is P |
| O | `+S−P` | some S is not P |

General universal propositions have no existential import. `−S+P` is true when there are
no S things, and universal propositions alone cannot make a categorical set inconsistent.
Particular propositions assert a witness.

`±` is a wild quantity, not a third predicate quality. It is accepted only on a fixed
reference: a starred singular such as `Socrates*`, or a proterm whose name ends in one or
more primes such as `Boy'`. A fixed reference denotes one individual, so its universal
and particular readings coincide. A predicate sign is always `+` or `−`.

A proterm is a constant. The prime does not bind the name to an antecedent, nearest or
otherwise. `Boy'` inherits nothing from `Boy`; an explicit proposition such as
`±Boy'+Boy` is required to connect them. The proof search may create fresh proterms during
indirect proof, but it also creates explicit anchor propositions for them.

## 3. Terms and concrete syntax

The abstract grammar is:

```text
term = Atom(name, singular)
     | Neg(term)
     | Compound(signed-term, signed-term, ...)
     | Rel(head, signed-term, ...)
     | PropTerm(proposition | bare-atom)
```

Parser-produced compounds contain at least two elements. Parser-produced relations contain
at least one signed object. A relation's unsigned head and its objects together determine
its arity.

### 3.1 Names

A bare name starts with an ASCII letter and continues with ASCII letters, digits, `_`,
ASCII primes, or subscript digits `₀` through `₉`. A name may not start with a digit.
Hyphens are signs, so a name such as `non-smoker` must be quoted.

Quoted names accept Unicode text except a double quote, C0 controls U+0000 through
U+001F, C1 controls U+007F through U+009F, and the bidirectional formatting controls
U+061C, U+200E, U+200F, U+202A through U+202E, and U+2066 through U+2069. Empty,
unclosed, and control-bearing quoted names are lexical errors. There is no escape syntax
inside a quoted name. A trailing `*` after a bare or quoted name makes it singular. A `*`
inside the quotes is name content, so general `"A*"` and singular `A*` are different terms
throughout inference.

Typographic `′` becomes one ASCII prime and `″` becomes two. For compatibility, a double
quote immediately following a bare-name character is also read as a double prime; a quote
in token-start position opens a quoted name. Non-ASCII names must be quoted.

Whitespace is insignificant inside a proposition. The accepted set is ASCII tab, line
feed, vertical tab, form feed, carriage return, and space; U+00A0; U+1680; U+2000 through
U+200A; U+2028; U+2029; U+202F; U+205F; U+3000; and U+FEFF. Error positions count Unicode
code points from zero, not UTF-8 bytes.

### 3.2 Negative and compound terms

`(−T)` is the negative term of T. `(+T)` and `(T)` are transparent grouping. A lone wild
group `(±T)` is illegal.

`(+White+Horse)` is a compound term. A `+` element contributes the named term; a `−`
element contributes its complement. A compound is one term, not a list of separate
individuals. Wild compound elements and quantity levels inside compounds are outside the
current inference fragment.

### 3.3 Relational terms

`(Lov+Girl)` is the unary-object relational term “loves some girl.”
`(Gave+Rose+Girl)` has two objects. Relations may nest, as in
`(Lov+(Adm−Teacher))`. An object sign is its quantity: `+` is existential, `−` is
universal, and `±` is permitted only for a fixed-reference object. Quantity levels on
relational objects are outside the current inference fragment.

Relation participants include the proposition subject followed by the relation objects.
A trailing subscript permutation on an atomic relation head records participant roles.
For arity `n`, a suffix is a role suffix only when it contains exactly `n` subscript
digits and is a permutation of `1..n`; otherwise it is part of the name. Identity order is
printed without a suffix. Inference-grade passive transformations are limited to at most
nine participants and only commute participant scope when their quantities match or a
participant is a fixed reference.

### 3.4 Propositional terms

Square brackets turn a proposition or one bare atom into a term:

```text
[p]
[+A''+B]
+[+A''+B]+[+A''+C]
```

The ordinary term-rewrite rules treat bracket interiors as opaque. The equivalence
operation has an additional one-member propositional semantics when every atom anywhere
inside both compared propositions is lowercase-initial ASCII, non-singular, and there are
no relations. Under that semantics, negative terms are Boolean negation, compounds are
signed conjunction, `−S+P` is implication, and `+S+P` is conjunction. This special
equivalence semantics does not turn lowercase propositions into general first-order
propositional logic elsewhere in the runtime.

### 3.5 Quantity levels

A level follows a signed term as `^n` or superscript digits. The printer omits level 0 and
prints nonzero levels as superscripts. The parser can represent any nonnegative level, but
the inference fragment accepts only these subject levels:

| Level | Required subject sign | Display quantity |
|---|---|---|
| 0 | `+`, `−`, or fixed-reference `±` | some/every |
| 1 | `+` | many |
| 2 | `+` | most |
| 3 | `+` | few, represented as the predominant complement |

The predicate level must be 0. A nonzero level is allowed only on a particular atomic
categorical subject for numerical decision. These levels are the inherited TFL+ fragment,
not the full Numerical Term Logic promised by later roadmap phases.

## 4. Programs and comments

A program is UTF-8 text interpreted one line at a time. After whitespace is trimmed, each
nonblank line contains one proposition. Two adjacent ASCII or typographic minus signs
outside a name begin a comment through the end of that line. `--` inside a quoted name is
name content, not a comment.

Low-level program parsing collects independent per-line lexical or syntactic errors and
retains the other successfully parsed lines. Parsing does not validate inference-fragment
restrictions; the operation that consumes the program does that. `Tfl.Program` can therefore
represent a partial parse for tooling, but `Tfl.Runtime.compile` is the production boundary:
it returns an abstract executable program only when every source line parses and validates.
This compile boundary is a host/runtime layer over `core-0.1`, not new logical syntax.

The Phase 3 filesystem boundary accepts only paths with the case-sensitive `.tfl` suffix
that resolve to regular filesystem files, and only well-formed UTF-8 bytes. Named pipes,
devices, sockets, and directories are file-input failures; the loader does not wait for or
read from them. It does not normalize a regular file before compilation.
Located statements and diagnostics use one-based physical lines and one-based Unicode
code-point columns in the original line, including leading whitespace; columns are never
UTF-8 byte offsets or display-dependent tab stops. A malformed UTF-8 sequence is a lexical
file error. These file and location rules are host/runtime behavior over `core-0.1`, not
additional logical syntax. The complete command contract is in
[command-line.md](command-line.md).

## 5. Validation and structured failure

Parsing and inference validation are separate:

- `lexical`: the tokenizer cannot assign a token, including a forbidden unquoted
  non-ASCII name;
- `syntactic`: valid tokens do not form the required proposition, or nesting exceeds 64;
- `outside_fragment`: a proposition parses but the requested inference procedure does not
  support its shape;
- `resource_limit`: otherwise valid-shaped input exceeds a public size or work budget;
- `internal`: an unexpected implementation defect reached the total boundary.

These are failures, not logical verdicts. An `outside_fragment` result does not mean
`invalid`, `false`, or `unknown`. The total `Tfl.Safe` boundary catches exceptions and
returns these records. It checks nesting before recursive parsing and attributes a bad
premise or conclusion to that exact input.

Current validation restrictions are exact:

- compound elements may not be wild or levelled;
- relational objects may not be levelled, and a wild object must be fixed;
- a proposition predicate may not be wild or levelled;
- a subject level must be 0 through 3, and a nonzero level requires `+`;
- a wild subject must be fixed;
- the numerical procedure additionally requires atomic categorical sides and forbids wild
  subjects;
- the term-description and equivalence operations reject every nonzero level.

## 6. Printing and canonical identity

Two normalizations must not be confused.

1. **Canonical source spelling** is `print(parse(source))`: compact notation,
   typographic signs, superscript levels, normalized primes, and quotes exactly where a
   name needs them. It preserves the parsed tree.
2. **Inference canonical form** is the identity used for proof search and de-duplication.
   It additionally applies the equivalences below and then prints the result.

Inference canonicalization:

- removes double term negation;
- recursively canonicalizes a compound, flattens a positively signed nested compound,
  collapses a singleton, and sorts elements by their printed UTF-8 byte strings;
- normalizes fixed-reference relational objects to `±`;
- removes identity relation-role suffixes;
- canonicalizes propositions inside propositional terms;
- normalizes a fixed-reference subject to `±`;
- converts I forms and E forms by placing the lexically smaller term first; A and O forms
  do not convert.

The inherited canonicalizer drops quantity levels. Numerical arguments are routed to the
numerical procedure before inference canonicalization, including levels recursively nested
inside proposition terms, so this does not change their current verdict. A nested level
outside the atomic numerical fragment is refused rather than compared through canonical
identity. Canonical identity must not be used to compare levelled propositions. This is an
implementation limit, not a claim that “most” and “some” mean the same thing.

## 7. Inference and proof objects

Every proof line has a one-based number, canonical proposition text, a rule label, and
one-based parent line numbers. A refutation ends with a synthetic `⊥` line whose rule is
`contradiction` and whose parents are the clashing lines.

The level-0 rewrite rules are:

- `IN` — obversion: flip predicate quality and negate the predicate term;
- `Contrap` — contraposition, only for A and O forms;
- `It` — seed the non-existential tautology `−T+T` for every mentioned term;
- `DON` — dictum de omni: a universal `−M+D` may replace a positive occurrence of M by D;
  a negative predicate donates its negated term;
- `Simp` — remove one conjunct at a positive compound occurrence and extract particular
  subject or positive-predicate self-statements;
- `Add` — introduce a same-subject positive compound predicate when the reusable premise
  is universal or fixed-wild;
- `Pass` — apply only a scope-preserving relational passive;
- `Pron` and `Anchor` — introduce and explicitly type fresh witnesses during refutation.

The mechanics appendix fixes occurrence polarity, substitutions, rule outputs, passive
role permutations, and pronominalization exactly. Relation heads and proposition-term
interiors are opaque to `DON` and `Simp` substitution.

Direct and indirect search use deterministic forward saturation. The default board limit
is 400 lines. A derived proposition is also refused when its term-node size exceeds the
largest input by the search slack, normally 8. Direct search tries the requested goal.
Indirect search adds its contradictory as a `counterclaim`, introduces explicit witnesses,
and refutes the set. Search order and proof ancestry are part of the reproducible proof
shape.

## 8. Exact decision procedures

### 8.1 Atomic-categorical P/Z decision

A proposition is atomic categorical when each side reduces to one atom under zero or more
term negations. On a level-0 atomic-categorical argument, the P/Z closure is a complete
decision procedure under this reference's no-existential-import semantics.

Universals contribute an implication and its contrapositive. Particulars contribute
witness points. Every fixed reference contributes a denoting point. Implication
satisfiability uses propagation plus case splits; points forced to share a positive fixed
reference merge. The premises entail the conclusion exactly when adding the conclusion's
contradictory makes a point unsatisfiable.

A valid P/Z result may include a closure certificate. Its optional algebraic cancellation
is display decoration only. Cancellation search has a shared 500,000-node budget, tries at
most 256 wild-reading combinations, and reuses each universal at most three times. Failure
to produce the decoration does not weaken or change the closure verdict.

### 8.2 Non-atomic proof search

Outside the atomic-categorical fragment, the runtime tries in this order:

1. direct derivation of the conclusion;
2. indirect refutation of its counterclaim;
3. direct derivation of the conclusion's contradictory;
4. indirect refutation of that contradictory;
5. abstain.

The first two successes return `valid`; the next two return `contradicted`; no success
returns `unknown`. This procedure is sound when it succeeds and incomplete when it does
not.

The current checker stops after finding support for the requested conclusion. It does not
also search for support for its contradictory, so an inconsistent program can hide
two-sided support behind the first result. The separate consistency operation can expose
some such contradictions, but the public four-state `both` contract is not implemented
in `core-0.1`. Code must not describe the current checker as paraconsistent or four-valued.

### 8.3 Numerical sufficient-condition procedure

If any proposition has a nonzero level anywhere in its term tree, the entire argument
routes to the numerical procedure. It accepts only atomic categorical propositions with no
wild subject. It checks three conditions:

1. the signed algebraic sum of all premise term occurrences equals the conclusion;
2. the number of particular premises equals the number of particular conclusions, which
   is zero or one;
3. the conclusion level does not exceed the greatest premise level carried by a premise
   whose particular subject is the same canonical term as the conclusion subject.

All three conditions establish `valid`. Failure of any condition establishes only
`unknown`. The procedure never returns `invalid`: it is a sound but incomplete rule set,
not a semantic decision procedure. It returns its three booleans and the carried and
conclusion levels as a decision record, not a derivation proof.

## 9. Public result vocabulary

The argument checker returns one of these verdicts:

| Result | Exact contract |
|---|---|
| `valid` | The conclusion follows by complete P/Z closure, a sound numerical sufficient condition, a direct proof, or an indirect refutation. It does not promise that the premises are independently consistent. |
| `invalid` | Only the complete level-0 atomic-categorical P/Z procedure returns this. It means there is a model of the premises in which the conclusion is false. |
| `contradicted` | After failing to prove the requested conclusion in the incomplete non-atomic search, the checker proved its contradictory. It does not assert that both sides were checked exhaustively. |
| `unknown` | The bounded non-atomic search found neither side, or a numerical sufficient condition failed. It never means false or invalid. |

An error is outside this verdict set.

“Complete” describes a procedure's authority to turn failure to find support into a
negative conclusion. It does not describe proof length or whether a successful proof is
trustworthy. P/Z argument decision is complete. Numerical and non-atomic derivation
decision are incomplete even when they return a sound positive proof.

The low-level `Decide.result` does not expose a `complete` field. The production
`Tfl.Runtime` record exposes both the method and explicit `{ complete; reason }` metadata;
callers of lower-level trusted modules must still use the method distinction above.

## 10. Program operations

### 10.1 Ground proposition query

A ground program query returns:

- `yes` when the query is supported;
- `no` when its contradictory is supported;
- `unknown` when neither side is established.

For an atomic-categorical program, the operation checks both sides with complete P/Z
decision. Its `unknown` is therefore a complete open-world answer: neither proposition
follows. For a non-atomic or numerical program, `unknown` can instead be procedural
incompleteness. `Tfl.Runtime` carries this distinction directly in its completeness record.

### 10.2 Term-description query

“What is T?” saturates the program with `IN`, `Contrap`, `Simp`, and `DON`, but not `Add`
or `Pass`. It omits tautologies, keeps only answers about T, removes answers entailed by a
stronger retained answer under the unary rules, then sorts by descending term-node size
and canonical text. The default board limit is 300 lines, with size slack 6. The operation
rejects levels. The production runtime attaches the extracted derivation to every returned
answer and marks the whole answer set incomplete with reason `bounded-term-saturation`; it
must not be advertised as complete beyond what its bounded rule set establishes.

### 10.3 Consistency

The consistency record has `consistent`, `complete`, and `numerical` fields:

- atomic categorical: `complete=true`; `consistent` is an exact result;
- non-atomic: a found refutation gives `consistent=false, complete=false`; no refutation
  gives `consistent=true, complete=false`, which means only “no contradiction found”;
- any nonzero level: `consistent=true, complete=false, numerical=true`, meaning numerical
  consistency is not implemented.

The low-level Boolean `consistent=true` must always be read together with `complete`. It is
not a claim of consistency when `complete=false`; the production runtime reports that case
as `undetermined` instead of `consistent`.

### 10.4 Equivalence

For two eligible purely propositional forms whose combined union contains one through
sixteen lowercase ASCII atoms, equivalence is decided completely by a truth table only
when its estimated DNF is at most 8,388,608 bytes and evaluation is at most 8,388,608
AST-node visits. The result method is `dnf`, and its rows record the satisfying
assignments of the left input. Inputs that exceed the atom, output, or evaluation budget
use the bounded rewrite method instead.

All other level-0 forms use a breadth-first closure of the left proposition under
obversion and contraposition, with conversion and double negation absorbed by canonical
form and a 64-node cap. A found `rewrite` path is a sound equivalence witness. A missing
path is not a complete proof of non-equivalence.

## 11. English readings

Readings are deterministic audit text, not semantics. The mechanics appendix gives every
branch. The central rules are:

- general names are lowercased; singular names retain case; a proterm reads “that …”;
- a negative term is prefixed `non-`;
- compound elements are joined by spaces because the compound is one term;
- relation objects read `some`, `every`, or no quantity for fixed-wild;
- a level-0 fixed-reference proposition is oriented with that reference as grammatical
  subject when conversion licenses it; numerical propositions never convert for display;
- levels read `many`, `most`, and `few`; level 3 reverses displayed predicate polarity;
- relational-subject and relational-predicate readings use a comma when otherwise their
  boundary would disappear.

Proof explanations summarize the given lines and either the last proved proposition or
the two clashing propositions before `⊥`. When a proof has no given line, its conclusion is
a standalone capitalized sentence rather than an empty `Because` clause. The formal proof
remains authoritative when a reading is awkward.

## 12. Known limits and bounds

These are implementation or procedure limits, not language truths:

| Area | Current limit | Required interpretation |
|---|---|---|
| Non-atomic inference | 400-line board and node-size slack | A miss is `unknown`, never `invalid`. |
| Numerical inference | Three sufficient conditions only | A failed condition is `unknown`; invalidity is undecided. |
| Numerical consistency | Not implemented | `consistent=true, complete=false, numerical=true` is an abstention. |
| Contradictory support | Argument checker returns the first supported side | No `both` result exists yet; check consistency separately and do not claim four-state behavior. |
| Term query | Restricted rules, 300 lines, no proof/completeness record | Returned descriptions are supported but not advertised exhaustive. |
| Truth-table equivalence | At most 16 atoms, 8,388,608 estimated DNF bytes, and 8,388,608 estimated AST-node visits | Any exceeded budget falls back to incomplete bounded rewrite search. |
| Rewrite equivalence | Immediate-rule closure, 64 nodes | A path proves equivalence; no path does not prove non-equivalence. |
| Relation passives | At most nine participants; guarded scope swaps | Unsupported transformations are not converse rules. |
| Canonical levels | Inference canonicalization erases levels | Never use the level-less key as numerical semantic equality. |
| Names | Bare ASCII only; quoted names have no quote escape and reject terminal/bidirectional controls | Quote ordinary non-ASCII or punctuation-bearing names; quotes and unsafe display controls are unrepresentable. |
| Nesting | Total boundary accepts at most 64 bracket levels | Deeper input is a syntactic refusal, not an internal crash. |
| Proposition source | 65,536 bytes through `Tfl.Safe` | Larger input is `resource_limit`, before token allocation. |
| Argument source | 1,024 premises and 1,048,576 combined bytes | Larger input is `resource_limit` attributed to the argument. |
| Program source | 1,048,576 bytes total, 65,536 bytes per line, 10,000 physical lines, and 1,024 parsed propositions | Larger input is `resource_limit`; ordinary per-line parse errors remain collectable. |
| JSON-lines protocol | 1,048,576 bytes per request line | The line is drained and refused as `resource_limit`; the next request remains readable. |
| Proof decoration | Cancellation has a 500,000-node budget | Missing cancellation never changes a P/Z verdict. |
| Source locations | Program entries retain only line and per-line code-point position | Full file spans and Unicode columns are not exposed. |
| Proterms | Constants, not bound pronouns | Core TFL has no cross-term or cross-sentence anaphora resolution. |

## 13. Executable conformance corpus

[`core-0.1.json`](../data/conformance/core-0.1.json) contains named examples for every
construct and operation required by `core-0.1`. Each case fixes:

- the language rule it demonstrates;
- one focus proposition's canonical source spelling, inference canonical form, and exact
  English reading;
- the operation and expected result;
- whether the operation is a complete decision procedure for that case;
- the certificate, numerical-decision, proof-rule, refutation, rewrite-path, truth-table,
  absent-proof, or currently-unexposed-proof shape.

The corpus is checked as data, not copied into test code. Run it with:

```bash
opam exec -- dune exec test/test_conformance.exe
```

The test rejects duplicate identifiers, malformed operations, unchecked program parse
errors, changed ordering, changed canonical forms or readings, wrong result vocabulary,
changed completeness classification, and changed proof shape.
