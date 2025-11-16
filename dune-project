(lang dune 3.11)
(name avro_viewer_web)
(version 0.1.0)

(generate_opam_files true)

(source (github tmcgilchrist/avro-simple))
(license MIT)
(authors "Tim McGilchrist")
(maintainers "timmcgil@gmail.com")

(package
 (name avro_viewer_web)
 (synopsis "Browser-based Avro file viewer using js_of_ocaml")
 (description "A web application for viewing and exploring Avro container files, built with pure OCaml and compiled to JavaScript. Features streaming support for large files, schema inspection, and real-time filtering.")
 (depends
  (ocaml (>= 5.0))
  (dune (>= 3.11))
  (js_of_ocaml (>= 5.0))
  (js_of_ocaml-ppx (>= 5.0))
  js_of_ocaml-lwt
  yojson
  avro-simple
  dream
  (qcheck (and :with-test (>= 0.20)))
  (qcheck-core :with-test)))
