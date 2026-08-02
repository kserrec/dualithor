(* PLAN 4.2 — the translation prompt.

   One system prompt teaching the notation, plus the few-shot pairs. Three
   decisions worth keeping in view:

   - **No verdicts anywhere.** The model is asked to translate, never to judge
     an argument. Showing it a valid/invalid example would invite it to reason
     to the answer and then fit a formula to it, which is exactly the confound
     the fidelity claim (PLAN claim 1) has to avoid.
   - **ASCII in, typographic out.** Every few-shot uses the plain-keyboard
     aliases `-` for `−` and `+-` for `±`, so a model never has to emit
     typographic signs; the parser accepts both and the printer normalizes.
     The one exception is the pairing subscripts of a passive (`Lov₂₁`), which
     have no ASCII alias in the notation.
   - **Forms sourced from the verdict-verified cases.** Every formula below is
     a proposition from `test/paper_cases.ml` — the arguments hand-checked
     against Sommers & Englebretsen — with English attached, or a
     term-structure instance of one. So the shapes we teach are shapes the
     engine is known to decide correctly, not shapes invented here. *)

(* ── Few-shot pairs ───────────────────────────────────────────────────────
   Sixteen pairs spanning the four categorical forms, singulars, negative and
   compound and quoted terms, relationals (universal, particular, universal
   object, nested, passive), and two numerical levels. `test_prompts.ml`
   asserts both that every formula parses and that this coverage is still here.

   Sixteen, not the 10–15 PLAN 4.2 sized: the level-3 pair was added 2026-08-02
   to correct a taught error (see the comment on it below), and dropping a
   working pair to stay inside the range would have traded proven coverage for
   it. *)

let few_shots : (string * string) list =
  [
    (* A, E, I, O — the four categorical forms *)
    ("Every horse is an animal.", "-Horse+Animal");
    ("No dog is a cat.", "-Dog-Cat");
    ("Some boy is tall.", "+Boy+Tall");
    ("Some student is not an athlete.", "+Student-Athlete");
    (* A singular subject takes the wild sign: for one individual, "every" and
       "some" say the same thing. *)
    ("Socrates is wise.", "+-Socrates*+Wise");
    (* Term structure: negative, compound, quoted *)
    ("Every non-smoker is healthy.", "-(-Smoker)+Healthy");
    ("Every white horse is a horse.", "-(+White+Horse)+Horse");
    ("Every stay-at-home parent is busy.", "-\"stay-at-home parent\"+Busy");
    (* Relationals: the object's own sign carries its quantity *)
    ("Every man loves some woman.", "-Man+(Lov+Woman)");
    ("Some boy loves some girl.", "+Boy+(Lov+Girl)");
    ("Some boy loves every girl.", "+Boy+(Lov-Girl)");
    ("Every head of a horse is a head of an animal.",
     "-(Head+Horse)+(Head+Animal)");
    ("Mary loves John.", "+-Mary*+(Lov+-John*)");
    ("Some girl is loved by some boy.", "+Girl+(Lov\xe2\x82\x82\xe2\x82\x81+Boy)");
    (* TFL⁺ quantity levels. ^1 many and ^2 most read straight off the sign;
       ^3 does not, and the 2026-08-02 correction is why both are taught. Level
       3 marks the predominant *complement*, so `few S are P` needs the MINUS
       predicate sign — `+Voter^3-Radical` reads "few voter is radical". Taught
       with a worked pair because the rule alone was what failed: the prompt
       said only "^3 few", and all three models duly wrote `+S^3+P` for a
       `few S are P` sentence. *)
    ("Most voters are conservatives.", "+Voter^2+Conservative");
    ("Few voters are radicals.", "+Voter^3-Radical");
  ]

(* ── Declining a sentence ─────────────────────────────────────────────────
   The router claim (PLAN claim 2) rests on this half of the contract: a
   sentence the notation cannot carry must come back declined, not forced into
   a formula that drops what it could not express. These four name the
   families the fragment genuinely misses — tense, arithmetic over quantities,
   defaults/generics with exceptions, and propositional connectives between
   whole clauses. *)

let untranslatable_examples : (string * string) list =
  [
    ("The train left before the bell rang.",
     "temporal ordering — the notation has no tense or event structure");
    ("At least three of the five directors approved.",
     "counting over a fixed set — quantity levels are coarse (many/most/few), \
      not numeric thresholds");
    ("Birds normally fly, but penguins do not.",
     "a default with an exception — the notation has no defeasible reading");
    ("If the alarm sounds then the door locks.",
     "a conditional between whole clauses, not a relation between terms");
  ]

(* ── The system prompt ────────────────────────────────────────────────────
   Built from the lists above so what we test is what we send. *)

let render_pairs pairs =
  String.concat "\n"
    (List.map (fun (nl, tfl) -> Printf.sprintf "  %s  ->  %s" nl tfl) pairs)

let render_declines pairs =
  String.concat "\n"
    (List.map (fun (nl, why) -> Printf.sprintf "  %s  ->  declined: %s" nl why)
       pairs)

let notation =
  {|A proposition is four parts with no spaces:

  (quantity sign)(subject term)(quality sign)(predicate term)

  -S+P   every S is P          -S-P   no S is P
  +S+P   some S is P           +S-P   some S is not P

Signs. Write `-` for minus and `+-` for the wild sign (the typographic `−` and
`±` are accepted too, but you never need them). There are no other operators:
no quantifiers, no variables, no connectives.

Terms.
  Boy, German_Shepherd, H2O    a bare name: a letter, then letters, digits or _
  "stay-at-home parent"        quote any name with spaces, hyphens or
                               punctuation. A hyphen is ALWAYS the minus sign,
                               so `non-smoker` must be written (-Smoker) or
                               "non-smoker".
  Socrates*                    a trailing * marks an individual, not a class
  (-Smoker)                    a negative term: not a smoker
  (+White+Horse)               a compound term: white AND a horse
  (Lov+Girl)                   a relational complex: an unsigned relation name,
                               then its objects, each with its own sign.
                               `-Boy+(Lov+Girl)` = every boy loves some girl;
                               `+Boy+(Lov-Girl)` = some boy loves every girl.
                               Objects may nest: (Lov+(Adm-Teacher)).
                               A passive uses pairing subscripts on the
                               relation name: (Lov₂₁+Boy) = loved by some boy.
  Voter^2                      a quantity level on the subject term: ^1 many,
                               ^2 most, ^3 few. Omit it for plain some/every.
                               ^3 is the exception: it marks the predominant
                               COMPLEMENT, so its polarity is flipped.
                               `+S^3-P` = few S are P.
                               `+S^3+P` = few S are NOT P.
                               Levels 1 and 2 do not flip: `+S^2+P` = most S
                               are P.

How to translate.
1. Read the sentence's own surface form. Subject term first, predicate second,
   in the order the English says them. Do not rearrange a sentence into a
   logically equivalent one — the point of this notation is that the formula
   mirrors the sentence.
2. Keep the verb of a relation as the relation name, in a short stem form
   (loves -> Lov, admires -> Adm), so the same verb is always the same name.
3. Use one proposition per sentence. If a sentence needs two, it does not
   belong in the notation — decline it.
4. Never invent structure the sentence does not have, and never drop structure
   it does have. If part of the meaning will not survive, decline the
   sentence: a declined sentence is a useful answer here, a lossy formula is
   not.|}

let output_contract =
  {|Answer with one JSON object and nothing else — no prose, no markdown fence:

{"translations":   [{"nl": "...", "tfl": "...", "confidence": 0.0}],
 "untranslatable": [{"nl": "...", "reason": "..."}]}

Every sentence you were given appears in exactly one of the two arrays, with
its `nl` copied verbatim, and `translations` keeps the order it was given in.
`confidence` is a number from 0 to 1: how sure you are the formula says what
the sentence says.|}

let system : string =
  String.concat "\n\n"
    [
      "You translate English sentences into term logic (TFL), a variable-free \
       notation in which a formula keeps the shape of the sentence it came \
       from.";
      notation;
      "Examples:\n" ^ render_pairs few_shots;
      "Sentences to decline, and why:\n" ^ render_declines untranslatable_examples;
      output_contract;
    ]

(* ── The user message ─────────────────────────────────────────────────────
   Sentences arrive numbered so a model that loses one is visible in the reply
   rather than silently short. *)

let user (sentences : string list) : string =
  let numbered =
    List.mapi (fun i s -> Printf.sprintf "%d. %s" (i + 1) s) sentences
  in
  Printf.sprintf
    "Translate each of these %d sentences. Return the JSON object described \
     above and nothing else.\n\n%s"
    (List.length sentences)
    (String.concat "\n" numbered)
