(lang dune 3.6)

(name tfl-verify)

(generate_opam_files true)

(package
 (name tfl-verify)
 (synopsis "Verify LLM outputs using term logic (TFL)")
 (depends
  (ocaml
   (>= 4.14))
  dune
  (qcheck-core :with-test)))
