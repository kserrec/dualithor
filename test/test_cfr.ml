open Harness

let first = "Alpha eligible people receive public benefits."
let second = "Beta eligible people retain public coverage."
let source = first ^ " " ^ second

let () =
  test "sentence splitting preserves source order" (fun () ->
      check
        (Bench.Cfr.split_sentences source = [ first; second ])
        "the live splitter reversed sentences within a paragraph");

  test "the legacy splitter reproduces the historical reversal" (fun () ->
      check
        (Bench.Cfr.split_sentences_legacy_reversed source = [ second; first ])
        "the frozen 2026-08-02 sampling behavior is no longer reproducible");

  test "candidate extraction uses the live source-order splitter" (fun () ->
      let body = "<P>" ^ source ^ "</P>" in
      check
        (Bench.Cfr.candidates_of body = [ first; second ])
        "candidate extraction did not preserve paragraph sentence order";
      check
        (Bench.Cfr.candidates_of_legacy_reversed body = [ second; first ])
        "legacy candidate extraction did not preserve the historical reversal");

  test "protected abbreviations do not create false boundaries" (fun () ->
      let text =
        "A U.S.C. citation remains within this sentence. Next rules apply."
      in
      check
        (Bench.Cfr.split_sentences text
        = [
            "A U.S.C. citation remains within this sentence.";
            "Next rules apply.";
          ])
        "a protected abbreviation created an extra sentence");

  finish "cfr extraction"
