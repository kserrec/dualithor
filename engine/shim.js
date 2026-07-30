// engine/shim.js — differential-harness endpoint (PLAN 1.3).
//
// Reads JSON lines {fn, args} on stdin and answers each with one JSON line:
//   {ok: <result>}                                  on success
//   {error: {name, message, pos}}                   on an engine-raised error
//     (pos only for ParseError; name is the error's constructor name)
//
// This is harness code, not part of the reference engine: tfl.js stays frozen
// and is only consulted. ASTs cross the pipe exactly as the JS engine shapes
// them ({type:'atom', name, singular}, {sign,term,level}, {type:'prop', …}),
// signs in ASCII form — the OCaml side serializes to the same shape.
'use strict';

const tfl = require('./tfl.js');
const readline = require('node:readline');

// Functions callable over the pipe, per port-spec §17. Args arrive as JSON
// values in call order; results are returned as-is (they are plain data).
const FNS = {
  // 1.2 — parse/print
  parseProposition: (src) => tfl.parseProposition(src),
  parseTerm: (src) => tfl.parseTerm(src),
  parseSignedTerm: (src) => tfl.parseSignedTerm(src),
  printProposition: (p) => tfl.printProposition(p),
  printTerm: (t) => tfl.printTerm(t),
  printSignedTerm: (st) => tfl.printSignedTerm(st),
  // 1.4 — core A
  canonProp: (p) => tfl.canonProp(p),
  canonTerm: (t) => tfl.canonTerm(t),
  contradictory: (p) => tfl.contradictory(p),
  obverse: (p) => tfl.obverse(p),
  contrapositive: (p) => tfl.contrapositive(p),
  // 1.5 — core B
  checkArgument: (premises, conclusion, opts) =>
    tfl.checkArgument(premises, conclusion, opts || {}),
  checkInconsistent: (props) => tfl.checkInconsistent(props),
  // 1.7 — programs, queries, equivalence
  queryProp: (programSrc, querySrc, opts) => {
    const program = tfl.parseProgram(programSrc).propositions.map((e) => e.prop);
    return tfl.queryProp(program, tfl.parseProposition(querySrc), opts || {});
  },
  decideEquivalence: (a, b, opts) => tfl.decideEquivalence(a, b, opts || {}),
  // 1.9 — NL rendering
  readProp: (p) => tfl.readProp(p),
};

const rl = readline.createInterface({ input: process.stdin, terminal: false });

rl.on('line', (line) => {
  let out;
  try {
    const { fn, args } = JSON.parse(line);
    if (!Object.prototype.hasOwnProperty.call(FNS, fn)) {
      throw new Error(`Unknown shim function: ${fn}`);
    }
    const result = FNS[fn](...args);
    out = { ok: result === undefined ? null : result };
  } catch (e) {
    out = {
      error: {
        name: e.constructor ? e.constructor.name : 'Error',
        message: String(e.message),
        pos: typeof e.pos === 'number' ? e.pos : null,
      },
    };
  }
  process.stdout.write(JSON.stringify(out) + '\n');
});
