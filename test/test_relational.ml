(* 1.6 acceptance: unit tests for the relational layer, ported from
   engine/tfl.test.js — the D2 relational-derivation section (deferred from
   1.5 because saturate lacked Pass) and the D3 sections: passives with the
   symmetry guard, pronominalization, and indirect proof. The D3 oracle spot
   checks arrive with the oracle port (1.10). *)

open Tfl.Notation
open Tfl.Relational
open Harness

let expect_work_limit premises conclusion label =
  match Tfl.Safe.check ~premises ~conclusion with
  | Error
      {
        kind = Tfl.Safe.Resource_limit;
        where = Some "argument";
        message;
        _;
      } ->
      check
        (message = Tfl.Derive.work_limit_message Tfl.Derive.default_max_work)
        (label ^ ": wrong resource-limit message")
  | Error failure ->
      failwith
        (Printf.sprintf "%s: expected inference resource limit, got %s" label
           (Tfl.Safe.kind_name failure.kind))
  | Ok result ->
      failwith
        (Printf.sprintf "%s: expected inference resource limit, got %s" label
           (verdict_name result))

let semantically_entails premises conclusion =
  Semantics.counter_model ~max_n:4 ~cap:2_000_000
    (List.map p premises) (p conclusion)
  = None

let () =
  (* Relational derivations (deferred from 1.5) *)
  test "the horse's head: tautology premise + cancellation in-complex"
    (fun () ->
      let r = arg [ "−Horse+Animal" ] "−(Head+Horse)+(Head+Animal)" in
      check (verdict_name r = "valid") ("verdict " ^ verdict_name r);
      check (List.mem "It" (proof_rules r)) "expected the tautology move";
      check (List.mem "DON" (proof_rules r)) "expected a DON step");
  test "donating a whole complex" (fun () ->
      expect_verdict
        [ "−Boy+(Lov+Girl)"; "−Girl+(Adm−Teacher)" ]
        "−Boy+(Lov+(Adm−Teacher))" "valid" "complex donation");
  test "nested faster-than donation" (fun () ->
      expect_verdict
        [ "−Horse+(Faster+Dog)"; "−Dog+(Faster+Cat)" ]
        "−Horse+(Faster+(Faster+Cat))" "valid" "nested donation");
  test "relational with wild singular host (Ada reads documents)" (fun () ->
      expect_verdict
        [ "±Ada*+(Reads+Manuscript)"; "−Manuscript+Document" ]
        "±Ada*+(Reads+Document)" "valid" "wild singular host");
  test "undistributed middle inside a complex is not derived" (fun () ->
      expect_verdict
        [ "+Critic+(Praises+Film)"; "+Film+Masterpiece" ]
        "+Critic+(Praises+Masterpiece)" "unknown" "undistributed middle");
  test "two distributed occurrences never cancel" (fun () ->
      expect_work_limit
        [ "+Editor−(Rejects+Manuscript)"; "−Manuscript+Submission" ]
        "+Editor−(Rejects+Submission)" "distributed pair");
  test "illicit process in a complex is not derived; the sound conclusion is"
    (fun () ->
      let premises = [ "+Donor+(Funds+Charity)"; "−Charity+Nonprofit" ] in
      expect_verdict premises "+Donor+(Funds−Nonprofit)" "unknown" "illicit";
      expect_verdict premises "+Donor+(Funds+Nonprofit)" "valid" "sound");
  test "net + under a double denial is substitutable" (fun () ->
      expect_verdict
        [ "+Student−(Reads−Manuscript)"; "−Manuscript+Document" ]
        "+Student−(Reads−Document)" "valid" "double denial");

  (* Passive mechanics and the symmetry guard *)
  test
    "passive mechanics: participants swap, signs travel, roles land in the head"
    (fun () ->
      match passives (p "−Philosopher+(Teaches+Student)") with
      | r :: _ ->
          check
            (print_proposition r.p_prop = "+Student+(Teaches₂₁−Philosopher)")
            ("got " ^ print_proposition r.p_prop);
          let back = passives r.p_prop in
          check
            (List.exists
               (fun x ->
                 print_proposition x.p_prop = "−Philosopher+(Teaches+Student)")
               back)
            "passive of the passive should include the original"
      | [] -> failwith "no passives");
  test "symmetry guard: same quantity or a fixed participant is equivalent"
    (fun () ->
      List.iter
        (fun src ->
          check (List.for_all (fun r -> r.equivalent) (passives (p src))) src)
        [
          "+Man+(Lov+Woman)";
          "−Man+(Lov−Woman)";
          "±Brutus*+(Stabbed±Caesar*)";
          "−Philosopher+(Loves±Mary*)";
        ]);
  test "symmetry guard: mixed general quantities are the scope trap" (fun () ->
      List.iter
        (fun src ->
          check
            (List.for_all (fun r -> not r.equivalent) (passives (p src)))
            src)
        [ "−Senator+(Admires+Philosopher)"; "+Philosopher+(Teaches−Student)" ]);
  test "n-ary guard: every crossed pair must commute" (fun () ->
      check
        (List.for_all
           (fun r -> not r.equivalent)
           (passives (p "−S+(Gave+Rose+Girl)")))
        "mixed n-ary";
      check
        (List.for_all
           (fun r -> r.equivalent)
           (passives (p "+S+(Gave+Rose+Girl)")))
        "uniform n-ary");
  test "no passive without a relational predicate of + quality" (fun () ->
      check (passives (p "−Boy−(Lov+Coward)") = []) "negative quality";
      check (passives (p "−S+P") = []) "no relation");
  test "derive uses the guarded passive (Pass) and refuses the trap" (fun () ->
      let ok = arg [ "−Dog+(Sees−Cat)" ] "−Cat+(Sees₂₁−Dog)" in
      check (verdict_name ok = "valid") ("verdict " ^ verdict_name ok);
      check (List.mem "Pass" (proof_rules ok)) "expected a Pass step";
      expect_work_limit
        [ "−Philosopher+(Teaches+Student)" ]
        "+Student+(Teaches₂₁−Philosopher)" "the trap");
  test "the one-way scope entailment is semantic; expensive search is limited"
    (fun () ->
      check
        (semantically_entails
           [ "+Philosopher+(Teaches−Student)" ]
           "−Student+(Teaches₂₁+Philosopher)")
        "∃∀ ⊨ ∀∃";
      check
        (not (semantically_entails [ "−A+(R+B)" ] "+B+(R₂₁−A)"))
        "∀∃ ⊭ ∃∀";
      expect_work_limit
        [ "+Philosopher+(Teaches−Student)" ]
        "−Student+(Teaches₂₁+Philosopher)" "forward scope search";
      expect_work_limit [ "−A+(R+B)" ] "+B+(R₂₁−A)"
        "reverse scope search");

  (* Proterms and pronominalization *)
  test "proterms take wild quantity; general terms still cannot" (fun () ->
      Tfl.Infer.validate_prop (p "±Boy'+(Lov±Girl')");
      match Tfl.Infer.validate_prop (p "±Dog+Pet") with
      | () -> failwith "±Dog should be rejected"
      | exception Tfl.Infer.Engine_error _ -> ());
  test "pronominalization: the course example, verbatim" (fun () ->
      let used = Hashtbl.create 16 in
      (match pronominalize (p "+Boy+(Lov+Girl)") used with
      | Some pr ->
          check
            (print_proposition pr.pr_prop = "±Boy'+(Lov±Girl')")
            ("got " ^ print_proposition pr.pr_prop);
          check
            (List.map print_proposition pr.anchors
            = [ "±Boy'+Boy"; "±Girl'+Girl" ])
            "anchors"
      | None -> failwith "no pronominalization");
      (* fresh primes each time — different witnesses are never conflated *)
      match pronominalize (p "+Boy+(Lov+Girl)") used with
      | Some pr2 ->
          check
            (print_proposition pr2.pr_prop = "±Boy''+(Lov±Girl'')")
            ("got " ^ print_proposition pr2.pr_prop)
      | None -> failwith "no second pronominalization");
  test "only particulars introduce witnesses" (fun () ->
      check (pronominalize (p "−Dog+Pet") (Hashtbl.create 4) = None) "A-form";
      check
        (pronominalize (p "−Bird−(Eats+Seed)") (Hashtbl.create 4) = None)
        "E-form");
  test "UDT subjects need no introduction; their objects still do" (fun () ->
      match pronominalize (p "±Ada*+(Reads+Manuscript)") (Hashtbl.create 4) with
      | Some pr ->
          check
            (print_proposition pr.pr_prop = "±Ada*+(Reads±Manuscript')")
            ("got " ^ print_proposition pr.pr_prop);
          check
            (List.map print_proposition pr.anchors
            = [ "±Manuscript'+Manuscript" ])
            "anchor"
      | None -> failwith "no pronominalization");
  test "anchors host universal donors" (fun () ->
      check
        (Tfl.Derive.derive
           [ p "±Cat'+Cat"; p "−Cat−(Fears+Dog)" ]
           (p "±Cat'−(Fears+Dog)"))
          .found
        "anchored donation");
  test "distributed proterm: a ± donor read as −" (fun () ->
      check
        (Tfl.Derive.derive
           [ p "±Owl'+(Watches±Mouse')"; p "±Mouse'+Rodent" ]
           (p "±Owl'+(Watches+Rodent)"))
          .found
        "wild donor");
  test "proterm co-denotation is what makes the categorical pair valid"
    (fun () ->
      expect_verdict [ "+M'+S"; "±M'+A" ] "+S+A" "valid" "co-denotation";
      expect_verdict [ "+M+S"; "+M+A" ] "+S+A" "invalid" "no co-denotation");

  (* Indirect proof *)
  test "the worked proof's argument: boys, girls, cowards" (fun () ->
      let res = arg [ "+Boy+(Lov+Girl)"; "−Boy−(Lov+Coward)" ] "+Girl−Coward" in
      check (verdict_name res = "valid") ("verdict " ^ verdict_name res);
      check (res.meth = Indirect) "method should be indirect";
      let rules = proof_rules res in
      check (List.mem "counterclaim" rules) "assumes the counterclaim";
      check
        (List.nth rules (List.length rules - 1) = "contradiction")
        "ends in contradiction";
      match res.proof with
      | Some pr ->
          let last = List.nth pr.lines (List.length pr.lines - 1) in
          check (last.text = "⊥") "closing text is ⊥"
      | None -> failwith "no proof");
  test "an indirect proof that needs the whole D3 stack" (fun () ->
      let res = arg [ "+Boy+(Lov−Girl)"; "+Girl+Rebel" ] "+Boy+(Lov+Rebel)" in
      check (verdict_name res = "valid") ("verdict " ^ verdict_name res);
      check (res.meth = Indirect) "method should be indirect";
      let rules = proof_rules res in
      List.iter
        (fun need ->
          check (List.mem need rules)
            (Printf.sprintf "expected a %s line, got %s" need
               (String.concat "," rules)))
        [ "Pron"; "Anchor"; "Pass"; "DON"; "contradiction" ]);
  test "Barbara falls to indirect proof too" (fun () ->
      let res = Tfl.Derive.indirect_proof [ p "−A+B"; p "−B+C" ] (p "−A+C") in
      check res.found "Barbara indirect";
      let last = List.nth res.lines (List.length res.lines - 1) in
      check (last.rule = "contradiction") "ends in contradiction");
  test "indirect proof does not overclaim" (fun () ->
      expect_verdict
        [ "+Boy+(Lov+Girl)"; "−Boy−(Lov+Coward)" ]
        "+Girl+Coward" "unknown" "no overclaim";
      check
        (not
           (Tfl.Derive.indirect_proof
              [ p "+Critic+(Praises+Film)"; p "+Film+Masterpiece" ]
              (p "+Critic+(Praises+Masterpiece)"))
             .found)
        "no false refutation");

  finish "relational unit tests"
