(* 1.2 acceptance: parser/printer unit tests ported from engine/tfl.test.js
   (the HTML-printer tests are courseware-only and not ported — spec §13),
   plus the round-trip property parse (print p) = p at 10k QCheck cases each
   for propositions and terms. The JS file's seeded random-AST round-trip is
   subsumed by the QCheck properties. *)

open Tfl.Ast
open Tfl.Notation

(* ── Tiny test harness, mirroring the JS file's ─────────────────────────── *)

open Harness

(* AST shorthands mirroring the JS constructors. *)
let atom ?(singular = false) name = Atom { name; singular }
let st ?(level = 0) sign term = { sign; term; level }
let prop subject predicate = { subject; predicate }
let rel head objects = Rel { head; objects }

let prop_to src expected =
  let got = parse_proposition src in
  check (prop_eq got expected)
    (Printf.sprintf "%s parsed to %s, expected %s" src (print_proposition got)
       (print_proposition expected))

let term_to src expected =
  let got = parse_term src in
  check (term_eq got expected)
    (Printf.sprintf "%s parsed to %s, expected %s" src (print_term got)
       (print_term expected))

let contains hay needle =
  let nh = String.length hay and nn = String.length needle in
  let rec go i = i + nn <= nh && (String.sub hay i nn = needle || go (i + 1)) in
  go 0

(* Assert that [parser src] raises a positioned Parse_error whose message
   mentions [msg_part]. *)
let fails_with ?(parser = fun s -> ignore (parse_proposition s)) src msg_part =
  match parser src with
  | () -> failwith (Printf.sprintf "%S should have raised Parse_error" src)
  | exception Parse_error { message; pos; _ } ->
      check (pos >= 0) "Parse_error should carry a position";
      check
        (contains message msg_part)
        (Printf.sprintf "message %S should include %S" message msg_part)
  | exception e ->
      failwith
        (Printf.sprintf "expected Parse_error, got %s" (Printexc.to_string e))

let as_signed s = ignore (parse_signed_term s)

(* ── Corpus (verbatim from tfl.test.js) ─────────────────────────────────── *)

let corpus =
  [
    "−S+P";
    "−S−P";
    "+S+P";
    "+S−P";
    "−Mammal+Mortal";
    "+Philosopher+Wise";
    "+Student−Diligent";
    "−(−Mammal)+(−Dog)";
    "+(−P)−(−S)";
    "−(−p)−(−q)";
    "−(−p)+q";
    "±Socrates*+Wise";
    "±MarkTwain*+SamuelClemens*";
    "+Twain*+Humorist";
    "−Man+(Lov+Woman)";
    "−Man+(Lov±Mary*)";
    "±John*+(Lov±Mary*)";
    "+Man−(Lov+Woman)";
    "−Boy+(Lov+(Adm−Teacher))";
    "−(Head+Horse)+(Head+Horse)";
    "−Student+(Reads+Book)";
    "+Philosopher+(Admires±Socrates*)";
    "±Caesar*+(Conquered±Gaul*)";
    "±Boy'+(Lov±Girl')";
    "±Boy'+Boy";
    "±Girl'+Coward";
    "+[+A''+B]+[+A''+C]";
    "−[+A'+B]+[+A'+C]";
    "+[p]+[q]";
    "−(+White+Horse)+Gentle";
    "+\"non-smoker\"+P";
    "−\"head of a horse\"+Thing";
    "+V^2+C^0";
    "+V²+C⁰";
    "−B'₁+S₁₂";
    "+p+q";
    "−p−q";
  ]

(* ── Ported unit tests ──────────────────────────────────────────────────── *)

let run_unit_tests () =
  (* Atoms and names *)
  test "single-letter terms" (fun () ->
      prop_to "−S+P" (prop (st Minus (atom "S")) (st Plus (atom "P"))));
  test "word terms" (fun () ->
      prop_to "−Dog + Mammal"
        (prop (st Minus (atom "Dog")) (st Plus (atom "Mammal"))));
  test "underscores and digits in names" (fun () ->
      prop_to "−German_Shepherd+H2O"
        (prop (st Minus (atom "German_Shepherd")) (st Plus (atom "H2O"))));
  test "subscript digits are name characters" (fun () ->
      term_to "S₁₂" (atom "S₁₂"));
  test "names cannot start with a digit" (fun () ->
      fails_with "+2Fast+P" "must start with a letter");
  test "lowercase statement terms" (fun () ->
      prop_to "−p+q" (prop (st Minus (atom "p")) (st Plus (atom "q"))));

  (* Signs and aliases *)
  test "ASCII minus aliases typographic minus" (fun () ->
      check
        (prop_eq (parse_proposition "-S+P") (parse_proposition "−S+P"))
        "-S+P should equal −S+P");
  test "wild quantity sign" (fun () ->
      prop_to "±Socrates*+Wise"
        (prop
           (st Wild (atom ~singular:true "Socrates"))
           (st Plus (atom "Wise"))));
  test "+- is the ASCII alias for ±" (fun () ->
      check
        (prop_eq
           (parse_proposition "+-Socrates*+Wise")
           (parse_proposition "±Socrates*+Wise"))
        "+- should equal ±");
  test "all four categorical forms" (fun () ->
      prop_to "−S+P" (prop (st Minus (atom "S")) (st Plus (atom "P")));
      (* A *)
      prop_to "−S−P" (prop (st Minus (atom "S")) (st Minus (atom "P")));
      (* E *)
      prop_to "+S+P" (prop (st Plus (atom "S")) (st Plus (atom "P")));
      (* I *)
      prop_to "+S−P" (prop (st Plus (atom "S")) (st Minus (atom "P")))
      (* O *));

  (* Singulars and proterms *)
  test "singular star" (fun () ->
      term_to "Twain*" (atom ~singular:true "Twain"));
  test "identity statement with two singulars" (fun () ->
      prop_to "+Twain*+Clemens*"
        (prop
           (st Plus (atom ~singular:true "Twain"))
           (st Plus (atom ~singular:true "Clemens"))));
  test "proterm prime is part of the name" (fun () ->
      term_to "Boy'" (atom "Boy'"));
  test "typographic prime normalizes to ASCII" (fun () ->
      check (term_eq (parse_term "Girl′") (parse_term "Girl'")) "Girl′ = Girl'");
  test "double prime normalizes to two ASCII primes" (fun () ->
      check (term_eq (parse_term "A″") (parse_term "A''")) "A″ = A''");
  test "prime then subscript (paired proterms)" (fun () ->
      term_to "B'₁" (atom "B'₁"));
  test "double-quote after a name char is a double prime" (fun () ->
      check (term_eq (parse_term "A\"") (atom "A''")) "A\" should be A''");
  test "wild proterm proposition (indirect proof line)" (fun () ->
      prop_to "±Boy'+(Lov±Girl')"
        (prop
           (st Wild (atom "Boy'"))
           (st Plus (rel (atom "Lov") [ st Wild (atom "Girl'") ]))));

  (* Signed terms *)
  test "parse_signed_term handles sign + any term" (fun () ->
      let s = parse_signed_term "−(Head+Horse)" in
      check (s.sign = Minus) "sign should be Minus";
      check (s.level = 0) "level should be 0";
      check
        (term_eq s.term (rel (atom "Head") [ st Plus (atom "Horse") ]))
        "term should be (Head+Horse)");
  test "parse_signed_term rejects unsigned and trailing input" (fun () ->
      fails_with ~parser:as_signed "Dog" "Expected a sign";
      fails_with ~parser:as_signed "+Dog+P" "Expected end of input");

  (* Quoted terms *)
  test "quoted term with spaces" (fun () ->
      prop_to "−\"head of a horse\"+Thing"
        (prop (st Minus (atom "head of a horse")) (st Plus (atom "Thing"))));
  test "hyphens split bare names, so non-smoker must be quoted" (fun () ->
      fails_with "+non-smoker+P" "Expected end of input";
      prop_to "+\"non-smoker\"+P"
        (prop (st Plus (atom "non-smoker")) (st Plus (atom "P"))));
  test "quoted singular" (fun () ->
      term_to "\"the number 7\"*" (atom ~singular:true "the number 7"));
  test "unclosed quote" (fun () -> fails_with "+\"oops+P" "Unclosed quote");
  test "empty quoted term" (fun () -> fails_with "+\"\"+P" "Empty quoted term");
  test "quoted terms reject terminal control sequences" (fun () ->
      fails_with "+\"red\x1b[31m\"+P" "Control and bidirectional";
      fails_with "+\"carriage\rreturn\"+P" "Control and bidirectional");
  test "unsafe bare characters are named without replaying the control" (fun () ->
      let expect_code src code =
        match parse_proposition src with
        | _ -> failwith "an unsafe character should have been refused"
        | exception Parse_error { message; _ } ->
            check (contains message code) "the diagnostic should name its code";
            check
              (not (contains message src))
              "the diagnostic must not replay the unsafe character"
      in
      expect_code "\x1b" "U+001B";
      expect_code "\u{202E}" "U+202E");
  test "quoted terms reject bidirectional display overrides" (fun () ->
      fails_with "+\"safe\u{202E}txt\"+P" "Control and bidirectional";
      fails_with "+\"safe\u{2066}txt\"+P" "Control and bidirectional");
  test "ordinary quoted Unicode remains legal" (fun () ->
      prop_to "+\"élève sérieux\"+P"
        (prop (st Plus (atom "élève sérieux")) (st Plus (atom "P"))));

  (* Negative and compound terms *)
  test "negative term" (fun () -> term_to "(−T)" (Neg (atom "T")));
  test "obversion shape" (fun () ->
      prop_to "−(−Y)+(−X)"
        (prop (st Minus (Neg (atom "Y"))) (st Plus (Neg (atom "X")))));
  test "double negation nests" (fun () ->
      term_to "(−(−wise))" (Neg (Neg (atom "wise"))));
  test "(+T) is transparent" (fun () ->
      check (term_eq (parse_term "(+T)") (atom "T")) "(+T) should be T");
  test "plain grouping parens are transparent" (fun () ->
      check (term_eq (parse_term "(T)") (atom "T")) "(T) should be T");
  test "compound conjunctive term" (fun () ->
      prop_to "−(+White+Horse)+Gentle"
        (prop
           (st Minus
              (Compound [ st Plus (atom "White"); st Plus (atom "Horse") ]))
           (st Plus (atom "Gentle"))));
  test "compound may mix signs" (fun () ->
      term_to "(+Rich−Happy)"
        (Compound [ st Plus (atom "Rich"); st Minus (atom "Happy") ]));
  test "bare wild group is an error" (fun () ->
      fails_with "−X+(±Y)" "wild sign");

  (* Relational complexes *)
  test "basic relational complex" (fun () ->
      prop_to "−Man+(Lov+Woman)"
        (prop
           (st Minus (atom "Man"))
           (st Plus (rel (atom "Lov") [ st Plus (atom "Woman") ]))));
  test "relational with wild singular object" (fun () ->
      prop_to "−Man+(Lov±Mary*)"
        (prop
           (st Minus (atom "Man"))
           (st Plus (rel (atom "Lov") [ st Wild (atom ~singular:true "Mary") ]))));
  test "n-ary relational complex" (fun () ->
      term_to "(Gave+Rose+Girl)"
        (rel (atom "Gave") [ st Plus (atom "Rose"); st Plus (atom "Girl") ]));
  test "nested relational complex" (fun () ->
      prop_to "−Boy+(Lov+(Adm−Teacher))"
        (prop
           (st Minus (atom "Boy"))
           (st Plus
              (rel (atom "Lov")
                 [ st Plus (rel (atom "Adm") [ st Minus (atom "Teacher") ]) ]))));
  test "the horse's head" (fun () ->
      prop_to "−(Head+Horse)+(Head+Horse)"
        (prop
           (st Minus (rel (atom "Head") [ st Plus (atom "Horse") ]))
           (st Plus (rel (atom "Head") [ st Plus (atom "Horse") ]))));
  test "negative quality on a relational predicate" (fun () ->
      prop_to "+Man−(Lov+Woman)"
        (prop
           (st Plus (atom "Man"))
           (st Minus (rel (atom "Lov") [ st Plus (atom "Woman") ]))));
  test "relation head may itself be a negative term" (fun () ->
      term_to "((−Lov)+Woman)"
        (rel (Neg (atom "Lov")) [ st Plus (atom "Woman") ]));

  (* Propositional terms *)
  test "bare statement term in brackets" (fun () ->
      term_to "[p]" (PropTerm (Inner_term (atom "p"))));
  test "propositional term with full proposition" (fun () ->
      term_to "[+A''+B]"
        (PropTerm
           (Inner_prop (prop (st Plus (atom "A''")) (st Plus (atom "B"))))));
  test "conjunction of propositional terms" (fun () ->
      prop_to "+[+A''+B]+[+A''+C]"
        (prop
           (st Plus
              (PropTerm
                 (Inner_prop (prop (st Plus (atom "A''")) (st Plus (atom "B"))))))
           (st Plus
              (PropTerm
                 (Inner_prop (prop (st Plus (atom "A''")) (st Plus (atom "C"))))))));
  test "conditional of propositional terms" (fun () ->
      prop_to "−[+A'+B]+[+A'+C]"
        (prop
           (st Minus
              (PropTerm
                 (Inner_prop (prop (st Plus (atom "A'")) (st Plus (atom "B"))))))
           (st Plus
              (PropTerm
                 (Inner_prop (prop (st Plus (atom "A'")) (st Plus (atom "C"))))))));
  test "unclosed bracket" (fun () -> fails_with "+[+p+q+r" "Expected ']'");

  (* Quantity levels *)
  test "explicit ^ levels" (fun () ->
      prop_to "+V^2+C^0"
        (prop (st ~level:2 Plus (atom "V")) (st ~level:0 Plus (atom "C"))));
  test "superscript levels" (fun () ->
      check
        (prop_eq (parse_proposition "+V²+C⁰") (parse_proposition "+V^2+C^0"))
        "superscripts should equal ^ levels");
  test "level 0 is the classical default" (fun () ->
      check
        (prop_eq (parse_proposition "+V^0+C^0") (parse_proposition "+V+C"))
        "^0 should equal no level");
  test "printer omits level 0, prints superscripts otherwise" (fun () ->
      check
        (print_proposition (parse_proposition "+V^2+C^0") = "+V²+C")
        "should print +V²+C";
      check
        (print_proposition (parse_proposition "+V+C") = "+V+C")
        "should print +V+C");
  test "bare ^ without digits" (fun () ->
      fails_with "+V^+C" "Expected digits after '^'");

  (* Whitespace — the literal carries NBSP (U+00A0) and thin space (U+2009),
     matching the JS test's bytes *)
  test "whitespace is insignificant (incl. nbsp)" (fun () ->
      check
        (prop_eq
           (parse_proposition "−S \u{00A0} + \u{2009} P")
           (parse_proposition "−S+P"))
        "unicode spaces should be skipped");

  (* Parse errors carry positions *)
  test "empty input" (fun () -> fails_with "" "Expected a sign");
  test "dangling sign" (fun () -> fails_with "−S+" "Expected a term");
  test "missing predicate" (fun () -> fails_with "−S" "Expected a sign");
  test "term alone is not a proposition" (fun () ->
      fails_with "Dog" "Expected a sign");
  test "trailing garbage" (fun () ->
      fails_with "−S+P+Q" "Expected end of input");
  test "unclosed paren" (fun () -> fails_with "−Man+(Lov+Woman" "Expected ')'");
  test "star cannot attach to a group" (fun () ->
      fails_with "+(Lov+Girl)*+P" "Unexpected character");
  test "error position points at the offender (code-point index)" (fun () ->
      match parse_proposition "−S+P+Q" with
      | _ -> failwith "should have raised"
      | exception Parse_error { pos; _ } ->
          check (pos = 4) (Printf.sprintf "pos should be 4, got %d" pos));
  test "tokens and parsed propositions retain half-open code-point spans"
    (fun () ->
      let source = "　+-\"É\"*+P" in
      let tokens = tokenize source in
      (match Array.to_list tokens with
      | [ wild; quoted; plus; predicate; eof ] ->
          check
            (wild.pos = 1 && wild.end_pos = 3)
            "the two-code-point ASCII wild alias has one token span";
          check
            (quoted.pos = 3 && quoted.end_pos = 7)
            "a quoted singular name span includes quotes and star";
          check (plus.pos = 7 && plus.end_pos = 8) "the predicate sign span";
          check
            (predicate.pos = 8 && predicate.end_pos = 9)
            "the predicate name span";
          check
            (eof.pos = 9 && eof.end_pos = 9)
            "end of input is a zero-width span"
      | _ -> failwith "unexpected token sequence");
      let located = parse_proposition_located source in
      check
        (located.range.start_offset = 1 && located.range.end_offset = 9)
        "the parsed proposition excludes leading whitespace and reaches the \
         last token");
  test "parse errors retain the complete offending-token range" (fun () ->
      match parse_proposition "−S+P+LongName" with
      | _ -> failwith "should have raised"
      | exception Parse_error { pos; end_pos; _ } ->
          check
            (pos = 4 && end_pos = 5)
            "the unexpected sign, not the following name, is the offending \
             token");

  (* Printer round-trips *)
  test "corpus round-trip: parse ∘ print ∘ parse is identity" (fun () ->
      List.iter
        (fun src ->
          let ast = parse_proposition src in
          let printed = print_proposition ast in
          check
            (prop_eq ast (parse_proposition printed))
            (Printf.sprintf "round-trip failed for %s → %s" src printed))
        corpus);

  (* Printer details *)
  test "printer emits typographic minus and compact spacing" (fun () ->
      check
        (print_proposition (parse_proposition "-S + P") = "−S+P")
        "should print −S+P";
      check
        (print_proposition (parse_proposition "+-s* + P") = "±s*+P")
        "should print ±s*+P");
  test "printer quotes non-bare names only" (fun () ->
      check
        (is_bare_name "Wise" && is_bare_name "Boy'" && is_bare_name "S₁₂")
        "bare names should be bare";
      check
        ((not (is_bare_name "non-smoker"))
        && not (is_bare_name "head of a horse"))
        "quote-needing names should not be bare";
      check (print_term (atom "non-smoker") = "\"non-smoker\"") "quoted print";
      check (print_term (atom "Wise") = "Wise") "bare print")

(* ── Round-trip properties (PLAN 1.2 acceptance: ≥10k cases) ────────────── *)

let round_trip_prop =
  QCheck2.Test.make ~count:10_000
    ~name:"parse (print p) = p for generated propositions"
    ~print:print_proposition Gen.prop_gen (fun p ->
      prop_eq (parse_proposition (print_proposition p)) p)

let round_trip_term =
  QCheck2.Test.make ~count:10_000
    ~name:"parse (print t) = t for generated terms" ~print:print_term
    Gen.term_gen (fun t -> term_eq (parse_term (print_term t)) t)

let () =
  run_unit_tests ();
  summarize "notation unit tests";
  let qcheck_failures =
    QCheck_base_runner.run_tests ~verbose:true
      [ round_trip_prop; round_trip_term ]
  in
  exit (if exit_code () <> 0 || qcheck_failures <> 0 then 1 else 0)
