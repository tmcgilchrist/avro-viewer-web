(** Main entry point for Avro Viewer Web Application *)

open Js_of_ocaml

let setup_error_handler () =
  let error_close = Dom_utils.get_element_by_id "error-close" in
  error_close##.onclick := Dom_html.handler (fun _ ->
    Dom_utils.hide_element "error-display";
    Js._false
  )

let initialize_app () =
  Dom_utils.log "=== Avro Viewer Initializing ===";

  (* Force Avro module initialization to register codecs *)
  (* This ensures the `let () = init_codecs ()` in avro.ml gets executed *)
  let codecs = Avro_simple.Codec_registry.list () in
  Dom_utils.log (Printf.sprintf "Registered codecs: %s" (String.concat ", " codecs));

  (* Initialize all components *)
  File_upload.initialize ();
  Schema_viewer.initialize ();
  Record_table.initialize ();
  Filter_panel.initialize ();
  setup_error_handler ();

  Dom_utils.log "=== Avro Viewer Ready! ===";

  (* Show welcome message in console *)
  Firebug.console##log (Js.string "") [@alert "-deprecated"];
  Firebug.console##log (Js.string "╔═══════════════════════════════════════════╗") [@alert "-deprecated"];
  Firebug.console##log (Js.string "║     Avro Viewer - Pure OCaml Web App      ║") [@alert "-deprecated"];
  Firebug.console##log (Js.string "║   Built with avro-simple + js_of_ocaml   ║") [@alert "-deprecated"];
  Firebug.console##log (Js.string "╚═══════════════════════════════════════════╝") [@alert "-deprecated"];
  Firebug.console##log (Js.string "") [@alert "-deprecated"];
  Firebug.console##log (Js.string "✓ Upload an .avro file to get started") [@alert "-deprecated"]

let () =
  (* Wait for DOM to be ready *)
  Dom_html.window##.onload := Dom_html.handler (fun _ ->
    initialize_app ();
    Js._false
  )
