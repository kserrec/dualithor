// oracle.js — D2/D3 correctness oracle: finite-model semantics for the
// lab's TFL fragment, plus the fuzz harness comparing the engine's
// syntactic verdicts against semantic truth. Node-only.
//
//   node oracle.js            quick run (1000 iterations per suite)
//   node oracle.js -n 20000   the long haul
//
// Semantics (no existential import anywhere):
//   - a model is a domain {0..n-1}, a subset for every unary atom, a
//     singleton for every singular atom AND every proterm (fixed reference
//     denotes), and a (k+1)-ary relation for every relation-head base with
//     k objects; the empty domain is a model too, unless some singular or
//     proterm occurs — names need a world, nothing else does;
//   - term denotations: negation = complement, compounds intersect (a −
//     element intersects the complement), a relational complex (R s₁T₁ … )
//     denotes the x's related by R to the objects — + object = some T,
//     − object = every T, quantifiers read left to right (subject
//     position = widest scope); pairing subscripts on the head (Lov₂₁,
//     from the passive transformation) name the relation slot each
//     participant fills — roles come from the subscripts, scope from the
//     formula position;
//   - propositional terms [p] denote the whole domain when the inner
//     statement is true and ∅ otherwise (the singleton-universe pun);
//   - ±S+P: quantity + = some, − = every; wild ± = some (equivalent to
//     every on the singleton denotations ± is restricted to). Quality − =
//     "is not".
//
// The fuzz suites:
//   1. categorical exactness — checkArgument's P/Z verdict must equal
//      semantic entailment on random categorical arguments, proterms
//      included (this fragment claims a complete decision method);
//   2. rule-step soundness — every single rewrite the engine's rules
//      produce (DON, IN, Contrap, Simp, Add, It, guarded Pass) must be
//      semantically entailed by its parents, relational hosts included;
//   3. relational derivations — whenever derive() finds a proof, no small
//      model may satisfy the premises and refute the conclusion;
//   4. passive equivalence — every guard-approved passive must be a
//      semantic equivalence (both directions), and the two deterministic
//      scope traps from Course 2 L3 must have counter-models;
//   5. indirect-proof soundness — whenever indirectProof() refutes a
//      counterclaim, no small model may satisfy the premises and refute
//      the conclusion;
//   6. statement-model agreement (D4) — statementModel's one-world truth
//      value must match the finite-model semantics at n = 1 on every
//      assignment, and decideEquivalence's DNF verdict must match mutual
//      one-world entailment.

'use strict';

const TFL = require('./tfl.js');
const {
  Atom, Neg, Compound, Rel, PropTerm, ST, Prop,
  parseProposition, printProposition, canonProp, contradictory,
  checkArgument, derive, obverse, contrapositive,
  headRoles, isProtermName, passives, indirectProof,
  statementModel, decideEquivalence,
} = TFL;

const isFixedName = (t) => t.singular || isProtermName(t.name);

// ── Vocabulary extraction ─────────────────────────────────────────────────

function vocabOf(props) {
  const unary = new Set(), singular = new Set(), rels = new Map();
  const walkTerm = (t, asHead, arity) => {
    switch (t.type) {
      case 'atom':
        if (asHead) {
          const { base } = headRoles(t.name, arity);
          rels.set(`${base}/${arity}`, { name: base, arity });
        } else (isFixedName(t) ? singular : unary).add(t.name);
        return;
      case 'neg': return walkTerm(t.term, false, 0);
      case 'compound': return t.elements.forEach((e) => walkTerm(e.term, false, 0));
      case 'rel':
        walkTerm(t.head, true, t.objects.length + 1);
        return t.objects.forEach((o) => walkTerm(o.term, false, 0));
      case 'propterm':
        if (t.inner.type === 'prop') walkProp(t.inner);
        else unary.add(t.inner.name);
        return;
    }
  };
  const walkProp = (p) => { walkTerm(p.subject.term, false, 0); walkTerm(p.predicate.term, false, 0); };
  props.forEach(walkProp);
  return { unary: [...unary], singular: [...singular], rels: [...rels.values()] };
}

// ── Evaluation ────────────────────────────────────────────────────────────
// Denotations are bitmasks over the domain; relations are Sets of
// comma-joined tuples.

function evalTerm(t, m) {
  switch (t.type) {
    case 'atom':
      if (isFixedName(t)) return 1 << m.singular[t.name];
      return m.unary[t.name];
    case 'neg':
      return m.full & ~evalTerm(t.term, m);
    case 'compound': {
      let mask = m.full;
      for (const el of t.elements) {
        const d = evalTerm(el.term, m);
        mask &= el.sign === '-' ? m.full & ~d : d;
      }
      return mask;
    }
    case 'rel': {
      if (t.head.type !== 'atom') throw new Error('oracle: only atomic relation heads are modeled');
      const arity = t.objects.length + 1;
      const { base, roles } = headRoles(t.head.name, arity);
      const rel = m.rels[`${base}/${arity}`];
      // Participant i (subject = 0, then objects) fills slot roles[i];
      // quantifiers still read left to right — roles never change scope.
      const check = (objIdx, tuple) => {
        if (objIdx === t.objects.length) return rel.has(tuple.join(','));
        const o = t.objects[objIdx];
        const den = evalTerm(o.term, m);
        const every = o.sign === '-';
        for (let y = 0; y < m.n; y++) {
          if (!(den & (1 << y))) continue;
          const next = tuple.slice();
          next[roles[objIdx + 1] - 1] = y;
          const hit = check(objIdx + 1, next);
          if (every && !hit) return false;
          if (!every && hit) return true;
        }
        return every; // ∀ over the empty denotation holds; ∃ fails
      };
      let mask = 0;
      for (let x = 0; x < m.n; x++) {
        const tuple = new Array(arity);
        tuple[roles[0] - 1] = x;
        if (check(0, tuple)) mask |= 1 << x;
      }
      return mask;
    }
    case 'propterm': {
      const truth = t.inner.type === 'prop'
        ? evalProp(t.inner, m)
        : evalTerm(t.inner, m) !== 0;
      return truth ? m.full : 0;
    }
  }
}

function evalProp(p, m) {
  const S = evalTerm(p.subject.term, m);
  const P = evalTerm(p.predicate.term, m);
  const test = (x) => (p.predicate.sign === '-' ? !(P & (1 << x)) : !!(P & (1 << x)));
  const every = p.subject.sign === '-';
  for (let x = 0; x < m.n; x++) {
    if (!(S & (1 << x))) continue;
    const hit = test(x);
    if (every && !hit) return false;
    if (!every && hit) return true;
  }
  return every; // no import: universals hold vacuously, particulars fail
}

// ── Model enumeration ─────────────────────────────────────────────────────

function* models(vocab, n, cap) {
  const full = (1 << n) - 1;
  const relSizes = vocab.rels.map((r) => Math.pow(n, r.arity));
  const total =
    Math.pow(n, vocab.singular.length) *
    Math.pow(2, vocab.unary.length * n) *
    relSizes.reduce((a, s) => a * Math.pow(2, s), 1);
  if (total > cap) {
    // Random sampling: sound for counter-model hunting, not exhaustive.
    for (let k = 0; k < cap; k++) yield randomModel(vocab, n);
    return;
  }
  const sing = {}, unary = {}, rels = {};
  function* fillSing(i) {
    if (i === vocab.singular.length) { yield* fillUnary(0); return; }
    for (let e = 0; e < n; e++) { sing[vocab.singular[i]] = e; yield* fillSing(i + 1); }
  }
  function* fillUnary(i) {
    if (i === vocab.unary.length) { yield* fillRel(0); return; }
    for (let mask = 0; mask <= full; mask++) { unary[vocab.unary[i]] = mask; yield* fillUnary(i + 1); }
  }
  function* fillRel(i) {
    if (i === vocab.rels.length) {
      yield { n, full, singular: { ...sing }, unary: { ...unary }, rels: { ...rels } };
      return;
    }
    const r = vocab.rels[i];
    const tuples = allTuples(n, r.arity);
    for (let mask = 0; mask < (1 << tuples.length); mask++) {
      const set = new Set();
      tuples.forEach((tu, b) => { if (mask & (1 << b)) set.add(tu.join(',')); });
      rels[`${r.name}/${r.arity}`] = set;
      yield* fillRel(i + 1);
    }
  }
  yield* fillSing(0);
}

function allTuples(n, arity) {
  if (arity === 0) return [[]];
  return allTuples(n, arity - 1).flatMap((t) => Array.from({ length: n }, (_, e) => t.concat(e)));
}

let seed = 20260704;
// Use the LCG's high bits: with a power-of-two modulus the low bits are
// (nearly) periodic, and a rigid rand(2)/rand(3) call pattern then loops
// through a handful of formulas instead of sampling the space.
const rand = (k) => (seed = (seed * 1103515245 + 12345) & 0x7fffffff, (seed >>> 16) % k);

function randomModel(vocab, n) {
  const full = (1 << n) - 1;
  const m = { n, full, singular: {}, unary: {}, rels: {} };
  for (const s of vocab.singular) m.singular[s] = rand(n);
  for (const u of vocab.unary) m.unary[u] = rand(full + 1);
  for (const r of vocab.rels) {
    const set = new Set();
    for (const tu of allTuples(n, r.arity)) if (rand(2)) set.add(tu.join(','));
    m.rels[`${r.name}/${r.arity}`] = set;
  }
  return m;
}

// Search for a counter-model: all premises true, conclusion false.
// Returns the model, or null if none exists up to maxN (exhaustive within
// cap models per size).
function counterModel(premises, conclusion, { maxN = 3, cap = 300000 } = {}) {
  const vocab = vocabOf([...premises, conclusion]);
  // n = 0 is a real model when nothing denotes: no existential import
  // anywhere, the world included. (With singulars/proterms in the
  // vocabulary, fillSing yields nothing at n = 0 — names need a world.)
  for (let n = 0; n <= maxN; n++) {
    for (const m of models(vocab, n, cap)) {
      if (premises.every((p) => evalProp(p, m)) && !evalProp(conclusion, m)) return m;
    }
  }
  return null;
}

const entails = (premises, conclusion, opts) => counterModel(premises, conclusion, opts) === null;

const consistent = (props, { maxN = 3, cap = 300000 } = {}) => {
  const vocab = vocabOf(props);
  for (let n = 0; n <= maxN; n++) {
    for (const m of models(vocab, n, cap)) {
      if (props.every((p) => evalProp(p, m))) return true;
    }
  }
  return false;
};

// ── Random formula generation ─────────────────────────────────────────────

// Fixed-reference vocabulary: a singular and a proterm — both denote
// singletons, both take ±.
const FIXED = [{ name: 's', singular: true }, { name: "t'", singular: false }];
const randFixedAtom = () => {
  const f = FIXED[rand(FIXED.length)];
  return Atom(f.name, f.singular);
};

// Atomic-categorical: atoms under 0–2 negations, singular and proterm
// subjects and predicates included — the fragment where the engine claims
// a complete decision.
function randomAtomicTerm(atoms) {
  const t = rand(6) === 0 ? randFixedAtom() : Atom(atoms[rand(atoms.length)]);
  const negs = rand(4) === 0 ? 1 + rand(2) : 0;
  let out = t;
  for (let i = 0; i < negs; i++) out = Neg(out);
  return out;
}

function randomCategoricalProp(atoms) {
  const subject = rand(4) === 0
    ? ST('±', randFixedAtom())
    : ST(rand(2) ? '+' : '-', randomAtomicTerm(atoms));
  const predicate = ST(rand(2) ? '+' : '-', randomAtomicTerm(atoms));
  return Prop(subject, predicate);
}

function randomRelationalProp(atoms, relName) {
  const obj = () => {
    if (rand(3) === 0) return ST('±', randFixedAtom());
    return ST(rand(2) ? '+' : '-', Atom(atoms[rand(atoms.length)]));
  };
  const complex = (depth) => Rel(Atom(relName),
    [rand(6) === 0 && depth > 0 ? ST(rand(2) ? '+' : '-', complex(depth - 1)) : obj()]);
  const side = (allowRel) =>
    allowRel && rand(2) ? ST(rand(2) ? '+' : '-', complex(1))
                        : ST(rand(2) ? '+' : '-', Atom(atoms[rand(atoms.length)]));
  const subject = rand(4) === 0
    ? ST('±', randFixedAtom())
    : side(rand(4) === 0);
  return Prop(subject.sign === '±' ? subject : ST(subject.sign, subject.term), side(true));
}

// ── Fuzz suites ───────────────────────────────────────────────────────────

function fuzzCategoricalExactness(iters, log) {
  const atoms = ['A', 'B', 'C'];
  let mismatches = 0, valids = 0;
  for (let k = 0; k < iters; k++) {
    const nPrem = 1 + rand(3);
    const premises = Array.from({ length: nPrem }, () => randomCategoricalProp(atoms));
    const conclusion = randomCategoricalProp(atoms);
    const verdict = checkArgument(premises, conclusion).verdict; // 'valid' | 'invalid'
    // Counter-model domains: each particular needs at most one witness, so
    // n = 4 comfortably covers 1–3 premises plus the denied conclusion.
    const semantic = entails(premises, conclusion, { maxN: 4, cap: 400000 });
    if (verdict === 'valid') valids++;
    if ((verdict === 'valid') !== semantic) {
      mismatches++;
      log(`  MISMATCH engine=${verdict} semantic=${semantic ? 'valid' : 'invalid'}`);
      premises.forEach((p) => log(`    premise    ${printProposition(p)}`));
      log(`    conclusion ${printProposition(conclusion)}`);
      if (mismatches >= 5) break;
    }
  }
  return { mismatches, note: `${valids}/${iters} valid` };
}

// Compound-bearing categorical props so Simp's conjunct-drops and Add's
// compound intros face the oracle too.
function randomCompoundProp(atoms) {
  const compound = () => Compound(Array.from({ length: 2 + rand(2) }, () =>
    ST(rand(3) ? '+' : '-', randomAtomicTerm(atoms))));
  const side = () => rand(2) ? ST(rand(2) ? '+' : '-', compound())
                             : ST(rand(2) ? '+' : '-', randomAtomicTerm(atoms));
  return Prop(side(), side());
}

function fuzzStepSoundness(iters, log) {
  const atoms = ['A', 'B'];
  let bad = 0, steps = 0;
  for (let k = 0; k < iters; k++) {
    const roll = rand(3);
    const gen = () => roll === 0
      ? randomRelationalProp(atoms, 'R')
      : roll === 1
        ? randomCompoundProp(atoms)
        : randomCategoricalProp(atoms);
    const a = gen(), b = gen();
    let results;
    try {
      results = [
        { p: obverse(a), parents: [a] },
        { p: contrapositive(a), parents: [a] },
        ...TFL.applySimp(a).map((p) => ({ p, parents: [a] })),
        ...passives(a).filter((r) => r.equivalent)
                      .map((r) => ({ p: canonProp(r.prop), parents: [a] })),
        ...TFL.applyDON(a, b).map((p) => ({ p, parents: [a, b] })),
        ...TFL.applyDON(b, a).map((p) => ({ p, parents: [a, b] })),
        ...TFL.applyAdd(a, b).map((p) => ({ p, parents: [a, b] })),
        { p: TFL.tautology(a.subject.term), parents: [] },
      ].filter((r) => r.p);
    } catch { continue; } // generator occasionally builds engine-invalid props
    for (const { p, parents } of results) {
      steps++;
      if (!entails(parents, p, { maxN: 3, cap: 60000 })) {
        bad++;
        log(`  UNSOUND step: ${parents.map(printProposition).join(' , ')} ⊢ ${printProposition(p)}`);
        if (bad >= 5) return { mismatches: bad, note: `${steps} steps` };
      }
    }
  }
  return { mismatches: bad, note: `${steps} steps checked` };
}

function fuzzRelationalDerivations(iters, log) {
  const atoms = ['A', 'B'];
  let proved = 0, bad = 0;
  for (let k = 0; k < iters; k++) {
    const premises = [
      randomRelationalProp(atoms, 'R'),
      randomRelationalProp(atoms, 'R'),
    ];
    const conclusion = randomRelationalProp(atoms, 'R');
    let proof;
    try { proof = derive(premises, conclusion, { maxLines: 120 }); }
    catch { continue; }
    if (!proof.found) continue;
    proved++;
    const counter = counterModel(premises, conclusion, { maxN: 3, cap: 120000 });
    if (counter) {
      bad++;
      log('  UNSOUND derivation:');
      premises.forEach((p) => log(`    premise    ${printProposition(p)}`));
      log(`    conclusion ${printProposition(conclusion)}`);
      proof.lines.forEach((l) => log(`    ${l.n}. ${l.text}  [${l.rule}${l.parents.length ? ' ' + l.parents.join(',') : ''}]`));
      if (bad >= 3) break;
    }
  }
  return { mismatches: bad, note: `${proved} proofs found in ${iters} tries` };
}

// Suite 4: passive equivalence. Deterministic scope traps from Course 2
// L3 first — the mixed-sign passives must have counter-models — then fuzz:
// every guard-approved passive must be model-equivalent to its source.
function fuzzPassiveEquivalence(iters, log) {
  let bad = 0, equivs = 0, traps = 0;
  // Course 2 L3's own trap pairs, in explicit pairing-subscript form.
  // ∀∃ vs ∃∀: one direction of each pair may still be a valid entailment
  // (∃∀ does entail ∀∃) — what must fail is the equivalence.
  for (const [active, naive] of [
    ['−A+(R+B)', '+B+(R₂₁−A)'],
    ['+A+(R−B)', '−B+(R₂₁+A)'],
  ]) {
    const a = parseProposition(active), q = parseProposition(naive);
    if (entails([a], q, { maxN: 3, cap: 120000 }) &&
        entails([q], a, { maxN: 3, cap: 120000 })) {
      bad++;
      log(`  SCOPE TRAP MISSED: ${active} is model-equivalent to ${naive}`);
    }
    const marked = passives(a).find((r) => TFL.propKey(r.prop) === TFL.propKey(q));
    if (!marked || marked.equivalent) {
      bad++;
      log(`  GUARD FAILURE: passive of ${active} not flagged as non-equivalent`);
    }
  }
  // Fuzz: 1–2 objects so the n-ary crossing guard is exercised too.
  const atoms = ['A', 'B'];
  for (let k = 0; k < iters; k++) {
    const obj = () => rand(3) === 0
      ? ST('±', randFixedAtom())
      : ST(rand(2) ? '+' : '-', Atom(atoms[rand(atoms.length)]));
    const nObj = 1 + rand(2);
    const rel = Rel(Atom('R'), Array.from({ length: nObj }, obj));
    const subject = rand(3) === 0
      ? ST('±', randFixedAtom())
      : ST(rand(2) ? '+' : '-', Atom(atoms[rand(atoms.length)]));
    const p = Prop(subject, ST('+', rel));
    let results;
    try { results = passives(p); } catch { continue; }
    for (const r of results) {
      if (!r.equivalent) { traps++; continue; }
      equivs++;
      // maxN 2 keeps arity-3 relations enumerable; the ∀∃/∃∀ scope
      // separations all show up by two elements.
      if (!entails([p], r.prop, { maxN: 2, cap: 60000 }) ||
          !entails([r.prop], p, { maxN: 2, cap: 60000 })) {
        bad++;
        log(`  NOT EQUIVALENT: ${printProposition(p)} vs ${printProposition(r.prop)}`);
        if (bad >= 5) return { mismatches: bad, note: `${equivs} equivalences` };
      }
    }
  }
  return { mismatches: bad, note: `${equivs} equivalences, ${traps} guarded off` };
}

// Suite 5: indirect-proof soundness — a found refutation of the
// counterclaim must mean genuine entailment (Skolemization soundness,
// checked model-theoretically).
function fuzzIndirectProofs(iters, log) {
  const atoms = ['A', 'B'];
  let proved = 0, bad = 0;
  for (let k = 0; k < iters; k++) {
    const premises = [
      randomRelationalProp(atoms, 'R'),
      randomRelationalProp(atoms, 'R'),
    ];
    const conclusion = randomRelationalProp(atoms, 'R');
    let proof;
    try { proof = indirectProof(premises, conclusion, { maxLines: 150 }); }
    catch { continue; }
    if (!proof.found) continue;
    proved++;
    const counter = counterModel(premises, conclusion, { maxN: 3, cap: 120000 });
    if (counter) {
      bad++;
      log('  UNSOUND indirect proof:');
      premises.forEach((p) => log(`    premise    ${printProposition(p)}`));
      log(`    conclusion ${printProposition(conclusion)}`);
      proof.lines.forEach((l) => log(`    ${l.n}. ${l.text}  [${l.rule}${l.parents.length ? ' ' + l.parents.join(',') : ''}]`));
      if (bad >= 3) break;
    }
  }
  return { mismatches: bad, note: `${proved} refutations found in ${iters} tries` };
}

// Suite 6: statement-model agreement (D4). A propositional statement's
// one-world truth (statementModel) must equal the finite-model semantics
// at n = 1, and decideEquivalence's DNF verdict must equal mutual n = 1
// entailment.
function randomStatementTerm(atoms) {
  let out = Atom(atoms[rand(atoms.length)]); // lowercase → statement atom
  const negs = rand(4) === 0 ? 1 + rand(2) : 0;
  for (let i = 0; i < negs; i++) out = Neg(out);
  if (rand(4) === 0) {
    const els = Array.from({ length: 2 + rand(2) }, () =>
      ST(rand(3) ? '+' : '-', Atom(atoms[rand(atoms.length)])));
    out = Compound(els);
  }
  return out;
}
function randomStatementProp(atoms) {
  return Prop(ST(rand(2) ? '+' : '-', randomStatementTerm(atoms)),
             ST(rand(2) ? '+' : '-', randomStatementTerm(atoms)));
}

// A 1-element model from a boolean assignment of the statement atoms.
function oneWorld(asg) {
  const unary = {};
  for (const k of Object.keys(asg)) unary[k] = asg[k] ? 1 : 0;
  return { n: 1, full: 1, singular: {}, unary, rels: {} };
}

function fuzzStatementModel(iters, log) {
  const atoms = ['p', 'q', 'r'];
  let bad = 0, checked = 0, eqChecked = 0;
  for (let k = 0; k < iters; k++) {
    const a = randomStatementProp(atoms);
    const ma = statementModel(a);
    if (!ma) continue;
    // (i) truth agreement across all assignments
    for (let m = 0; m < (1 << ma.atoms.length); m++) {
      const asg = {};
      ma.atoms.forEach((nm, i) => { asg[nm] = !!(m & (1 << i)); });
      checked++;
      if (ma.sat(asg) !== evalProp(a, oneWorld(asg))) {
        bad++;
        log(`  MODEL MISMATCH ${printProposition(a)} at ${JSON.stringify(asg)}`);
        if (bad >= 5) return { mismatches: bad, note: `${checked} evals` };
      }
    }
    // (ii) decideEquivalence DNF verdict vs mutual one-world entailment
    const b = randomStatementProp(atoms);
    const mb = statementModel(b);
    if (!mb) continue;
    const dec = decideEquivalence(a, b);
    if (dec.method !== 'dnf') continue;
    eqChecked++;
    const union = [...new Set([...ma.atoms, ...mb.atoms])];
    let same = true;
    for (let m = 0; m < (1 << union.length); m++) {
      const asg = {};
      union.forEach((nm, i) => { asg[nm] = !!(m & (1 << i)); });
      if (evalProp(a, oneWorld(asg)) !== evalProp(b, oneWorld(asg))) { same = false; break; }
    }
    if (dec.equivalent !== same) {
      bad++;
      log(`  EQUIV MISMATCH ${printProposition(a)} vs ${printProposition(b)}: engine=${dec.equivalent} semantic=${same}`);
      if (bad >= 5) return { mismatches: bad, note: `${checked} evals, ${eqChecked} equivs` };
    }
  }
  return { mismatches: bad, note: `${checked} evals, ${eqChecked} equivs checked` };
}

// ── CLI ───────────────────────────────────────────────────────────────────

if (require.main === module) {
  const nIdx = process.argv.indexOf('-n');
  const iters = nIdx >= 0 ? parseInt(process.argv[nIdx + 1], 10) : 1000;
  const log = console.log;
  let failed = 0;
  for (const [name, fn, scale] of [
    ['categorical exactness', fuzzCategoricalExactness, 1],
    ['rule-step soundness', fuzzStepSoundness, 1],
    ['relational derivation soundness', fuzzRelationalDerivations, 1],
    ['passive equivalence', fuzzPassiveEquivalence, 1],
    ['indirect-proof soundness', fuzzIndirectProofs, 1],
    ['statement-model agreement', fuzzStatementModel, 1],
  ]) {
    const t0 = Date.now();
    const { mismatches, note } = fn(Math.ceil(iters * scale), log);
    log(`${mismatches === 0 ? '✓' : '✗'} ${name}: ${mismatches} failures (${note}, ${((Date.now() - t0) / 1000).toFixed(1)}s)`);
    if (mismatches > 0) failed = 1;
  }
  process.exit(failed);
}

module.exports = { vocabOf, evalTerm, evalProp, models, counterModel, entails, consistent };
