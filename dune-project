(lang dune 3.6)

(name tfl-language)

(authors "Kyle Serrecchia <kserrec@gmail.com>")
(maintainers "Kyle Serrecchia <kserrec@gmail.com>")
(license MIT)
(homepage https://github.com/kserrec/tfl-verify)
(bug_reports https://github.com/kserrec/tfl-verify/issues)
(source
 (github kserrec/tfl-verify))

(generate_opam_files true)

(package
 (name tfl-language)
 (synopsis "A proof-producing logic programming language based on term logic (TFL)")
 (depends
  (ocaml
   (and
    (>= 4.14.4)
    (< 5.0)))
  dune
  (qcheck-core :with-test)
  yojson
  lwt
  cohttp-lwt-unix
  tls-lwt
  ;; TLS reaches these packages transitively. Keep the fixed security release
  ;; in the solver contract while the exact temporary source pins live in the
  ;; generated opam template.
  (mirage-crypto (>= 2.3.0))
  (mirage-crypto-rng (>= 2.3.0))
  (mirage-crypto-pk (>= 2.3.0))
  (mirage-crypto-ec (>= 2.3.0))))
