(** Filter panel for record filtering *)

open Js_of_ocaml

let apply_filter filter_expr =
  App_state.set_filter filter_expr;
  Record_table.refresh ();
  Dom_utils.log_debug "Filter applied: %s" filter_expr

let clear_filter () =
  App_state.clear_filter ();
  Dom_utils.set_input_value "filter-input" "";
  Record_table.refresh ();
  Dom_utils.log "Filter cleared"

let setup_filter_controls () =
  (* Apply button *)
  let apply_button = Dom_utils.get_element_by_id "filter-apply" in
  apply_button##.onclick := Dom_html.handler (fun _ ->
    let filter_expr = Dom_utils.get_input_value "filter-input" in
    apply_filter filter_expr;
    Js._false
  );

  (* Clear button *)
  let clear_button = Dom_utils.get_element_by_id "filter-clear" in
  clear_button##.onclick := Dom_html.handler (fun _ ->
    clear_filter ();
    Js._false
  );

  (* Filter input - apply on Enter key *)
  let filter_input = Dom_utils.get_element_by_id "filter-input" in
  Js.Opt.iter (Dom_html.CoerceTo.input filter_input) (fun input ->
    input##.onkeypress := Dom_html.handler (fun event ->
      if event##.keyCode = 13 then begin (* Enter key *)
        let filter_expr = Js.to_string input##.value in
        apply_filter filter_expr;
        Js._false
      end else
        Js._true
    )
  )

let initialize () =
  setup_filter_controls ();
  Dom_utils.log "Filter panel initialized"
