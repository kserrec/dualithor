(lang dune 3.6)

(name tfl-language)

(generate_opam_files true)

(package
 (name tfl-language)
 (synopsis "A proof-producing logic programming language based on term logic (TFL)")
 (depends
  (ocaml
   (>= 4.14))
  dune
  (qcheck-core :with-test)
  yojson
  lwt
  cohttp-lwt-unix
  tls-lwt))
