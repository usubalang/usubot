(lang dune 2.8)

; Since we want to generate opam files we need to provide informations ;
(generate_opam_files true)

(name usubot)
(version dev)
(authors "Usuba developers")
(maintainers "Usuba developers")
(source (github usuba-lang/usuba))
; Not specifying bug_reports since it defaults to the github issue page
(homepage "https://usubalang.github.io/usuba/")
(documentation "https://usubalang.github.io/usuba/")

; Packages

(package
 (name usubot)
 (synopsis "Usuba")
 (description "\
TODO")
 (depends
  (ocaml (>= 4.10))
  (dune (>= 2.2))
   ; opium
  (lwt (>= 5.3.0))
  (cohttp-lwt (>= 2.5.4))
  (cohttp-lwt-unix (>= 2.5.4))
  (yojson (>= 1.7.0))
 )
)

(package
 (name bot-components)
 (synopsis "Building blocks to make your own bots")
 (depends
  (base (>= v0.14.0))
  (cohttp-lwt (>= 2.5.4))
  (cohttp-lwt-unix (>= 2.5.4))
  (cstruct (>= 5.0.0))
  (dune (>= 2.2))
  (eqaf (>= 0.7))
  (graphql_ppx (>= 1.2.0))
  (hex (>= 1.4.0))
  (ISO8601 (>= 0.2.0))
  (lwt (>= 5.3.0))
  (lwt_ssl (>= 1.1.3))
  (mirage-crypto (>= 0.8.7))
  (odoc (and (>= 1.5.2) :with-doc))
  (ssl (= 0.5.9))
  (stdio (>= v0.14.0))
  (toml (and (>= 6.0.0) (< 7.0.0)))
  (x509 (>= 0.11.2))
  (yojson (>= 1.7.0))
 )
)
