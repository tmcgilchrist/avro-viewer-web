(** Schema viewer component *)

open Js_of_ocaml

let display_schema_json schema_json =
  (* Pretty print JSON *)
  let formatted =
    try
      let json = Yojson.Safe.from_string schema_json in
      Yojson.Safe.pretty_to_string json
    with _ -> schema_json
  in
  Dom_utils.set_text_content "schema-display" formatted

let display_schema_fields schema_json =
  try
    let json = Yojson.Safe.from_string schema_json in
    let open Yojson.Safe.Util in

    (* Extract fields from record schema *)
    let fields =
      try member "fields" json |> to_list
      with _ -> []
    in

    (* Build table rows *)
    let table_body = Dom_utils.get_element_by_id "schema-fields-table" in
    Dom_utils.remove_all_children table_body;

    List.iter (fun field ->
      let field_name = member "name" field |> to_string_option |> Option.value ~default:"unknown" in
      let field_type =
        match member "type" field with
        | `String s -> s
        | `List types ->
            (* Union type - show as "null | type" for optional fields *)
            List.map to_string types |> String.concat " | "
        | `Assoc _ as obj ->
            (* Complex type - show just the type *)
            member "type" obj |> to_string_option |> Option.value ~default:"complex"
        | _ -> "unknown"
      in
      let is_optional =
        match member "type" field with
        | `List types -> List.mem "null" (List.map to_string types)
        | _ -> false
      in

      (* Create table row *)
      let tr = Dom_utils.create_element "tr" in

      let td_name = Dom_utils.create_element "td" in
      Dom_utils.append_child td_name (Dom_utils.create_text field_name);
      Dom_utils.append_child tr (td_name :> Dom.node Js.t);

      let td_type = Dom_utils.create_element "td" in
      let type_code = Dom_utils.create_element "code" in
      Dom_utils.append_child type_code (Dom_utils.create_text field_type);
      Dom_utils.append_child td_type (type_code :> Dom.node Js.t);
      Dom_utils.append_child tr (td_type :> Dom.node Js.t);

      let td_optional = Dom_utils.create_element "td" in
      let optional_text = if is_optional then "Yes" else "No" in
      Dom_utils.append_child td_optional (Dom_utils.create_text optional_text);
      Dom_utils.append_child tr (td_optional :> Dom.node Js.t);

      Dom_utils.append_child table_body (tr :> Dom.node Js.t)
    ) fields
  with e ->
    Dom_utils.log_error ("Error parsing schema fields: " ^ Printexc.to_string e)

let setup_tabs () =
  let tabs = Dom_html.document##querySelectorAll (Js.string ".tabs li") in

  for i = 0 to tabs##.length - 1 do
    Js.Opt.iter (tabs##item i) (fun tab ->
      tab##.onclick := Dom_html.handler (fun _ ->
        (* Remove active class from all tabs *)
        for j = 0 to tabs##.length - 1 do
          Js.Opt.iter (tabs##item j) (fun t ->
            Dom_utils.remove_class t "is-active"
          )
        done;

        (* Add active class to clicked tab *)
        Dom_utils.add_class tab "is-active";

        (* Get target tab pane *)
        Js.Opt.iter (tab##getAttribute (Js.string "data-tab")) (fun tab_id ->
          let tab_id_str = Js.to_string tab_id in

          (* Hide all tab panes *)
          let panes = Dom_html.document##querySelectorAll (Js.string ".tab-pane") in
          for k = 0 to panes##.length - 1 do
            Js.Opt.iter (panes##item k) (fun pane ->
              Dom_utils.remove_class pane "is-active";
              (Js.Unsafe.coerce pane##.style)##.display := Js.string "none"
            )
          done;

          (* Show selected pane *)
          let pane = Dom_utils.get_element_by_id tab_id_str in
          Dom_utils.add_class pane "is-active";
          (Js.Unsafe.coerce pane##.style)##.display := Js.string "block"
        );

        Js._false
      )
    )
  done

let initialize () =
  setup_tabs ();
  Dom_utils.log "Schema viewer initialized"
