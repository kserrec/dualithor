(lang dune 3.6)

(name dualithor)

(authors "Kyle Serrecchia <kserrec@gmail.com>")
(maintainers "Kyle Serrecchia <kserrec@gmail.com>")
(license MIT)
(homepage https://github.com/kserrec/dualithor)
(bug_reports https://github.com/kserrec/dualithor/issues)
(source
 (github kserrec/dualithor))

(generate_opam_files true)

(package
 (name dualithor)
 (synopsis "A proof-producing logic programming language based on term logic (TFL)")
 (depends
  (ocaml
   (and
    (>= 4.14.4)
    (< 5.0)))
  dune
  (qcheck-core :with-test)
  yojson
  ;; The retained translation client is historical development code, not an
  ;; installed Dualithor runtime. Keep its network/TLS graph behind [with-test] so
  ;; a normal [tfl] installation has no network stack.
  (lwt :with-test)
  (cohttp-lwt-unix :with-test)
  (tls-lwt :with-test)
  ;; TLS reaches these packages transitively. Keep the fixed security release
  ;; in the development solver contract while the exact temporary source pins
  ;; live in the generated opam template.
  (mirage-crypto (and :with-test (>= 2.3.0)))
  (mirage-crypto-rng (and :with-test (>= 2.3.0)))
  (mirage-crypto-pk (and :with-test (>= 2.3.0)))
  (mirage-crypto-ec (and :with-test (>= 2.3.0)))))
