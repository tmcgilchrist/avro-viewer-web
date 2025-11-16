(** Record table with pagination *)

open Js_of_ocaml

let render_table_header fields =
  let thead = Dom_utils.get_element_by_id "table-header" in
  Dom_utils.remove_all_children thead;

  let tr = Dom_utils.create_element "tr" in

  List.iter (fun field_name ->
    let th = Dom_utils.create_element "th" in
    (* Right align the balance column header *)
    if field_name = "balance" then
      (Js.Unsafe.coerce th##.style)##.textAlign := Js.string "right";
    Dom_utils.append_child th (Dom_utils.create_text field_name);
    Dom_utils.append_child tr (th :> Dom.node Js.t)
  ) fields;

  Dom_utils.append_child thead (tr :> Dom.node Js.t)

let format_timestamp_ms timestamp_ms =
  (* JavaScript Date expects milliseconds since Unix epoch *)
  let timestamp_float = Int64.to_float timestamp_ms in
  let date = new%js Js.date_fromTimeValue (Js.number_of_float timestamp_float) in

  (* Format as DD/MM/YYYY HH:MM:SS *)
  let day = date##getDate in
  let month = date##getMonth + 1 in (* getMonth is 0-indexed *)
  let year = date##getFullYear in (* Get full 4-digit year *)
  let hours = date##getHours in
  let minutes = date##getMinutes in
  let seconds = date##getSeconds in

  Printf.sprintf "%02d/%02d/%04d %02d:%02d:%02d"
    day month year hours minutes seconds

let format_currency amount =
  (* Format as AUD currency with $ sign and 2 decimal places *)
  Printf.sprintf "$%.2f" amount

let format_value field_name value =
  match value with
  | `String s -> s
  | `Int i ->
      if field_name = "balance" then
        format_currency (float_of_int i)
      else
        string_of_int i
  | `Intlit s ->
      (* Check if this is a timestamp field (created_at, updated_at, etc.) *)
      if field_name = "created_at" || field_name = "updated_at" then
        (try
          let ts = Int64.of_string s in
          format_timestamp_ms ts
        with _ -> s)
      else if field_name = "balance" then
        (try
          let amount = float_of_string s in
          format_currency amount
        with _ -> s)
      else s
  | `Float f ->
      if field_name = "balance" then
        format_currency f
      else
        Printf.sprintf "%.2f" f
  | `Bool b -> string_of_bool b
  | `Null -> "null"
  | `List lst ->
      (* Display array items without brackets, just comma-separated *)
      let items = List.map (fun item ->
        match item with
        | `String s -> s
        | `Int i -> string_of_int i
        | `Intlit s -> s
        | `Float f -> string_of_float f
        | `Bool b -> string_of_bool b
        | `Null -> "null"
        | _ -> Yojson.Safe.to_string item
      ) lst in
      String.concat ", " items
  | `Assoc _ -> Yojson.Safe.to_string value

let render_record_row record =
  let tr = Dom_utils.create_element "tr" in

  (* Parse JSON record *)
  let open Yojson.Safe.Util in
  try
    let assoc = to_assoc record in
    List.iter (fun (key, value) ->
      let td = Dom_utils.create_element "td" in
      (* Right align the balance column *)
      if key = "balance" then
        (Js.Unsafe.coerce td##.style)##.textAlign := Js.string "right";
      let value_str = format_value key value in
      Dom_utils.append_child td (Dom_utils.create_text value_str);
      Dom_utils.append_child tr (td :> Dom.node Js.t)
    ) assoc;
    Some tr
  with e ->
    Dom_utils.log_error ("Error rendering record: " ^ Printexc.to_string e);
    None

let render_records records =
  let tbody = Dom_utils.get_element_by_id "table-body" in
  Dom_utils.remove_all_children tbody;

  (* Get field names from first record *)
  let fields =
    match records with
    | [] -> []
    | first :: _ ->
        let open Yojson.Safe.Util in
        try to_assoc first |> List.map fst
        with _ -> []
  in

  (* Render header *)
  if fields <> [] then render_table_header fields;

  (* Render rows *)
  List.iter (fun record ->
    match render_record_row record with
    | Some tr -> Dom_utils.append_child tbody (tr :> Dom.node Js.t)
    | None -> ()
  ) records

let update_pagination_info () =
  let current_page = App_state.get_current_page () in
  let total_pages = App_state.get_total_pages () in
  let filtered_count = List.length (App_state.get_filtered_records ()) in
  let page_records = App_state.get_page_records () in

  let start_idx = (current_page - 1) * App_state.state.page_size + 1 in
  let end_idx = start_idx + List.length page_records - 1 in

  (* Update "Showing X-Y of Z" text *)
  let showing_text =
    if filtered_count = 0 then "No records to display"
    else Printf.sprintf "Showing %s-%s of %s"
      (Dom_utils.format_number start_idx)
      (Dom_utils.format_number end_idx)
      (Dom_utils.format_number filtered_count)
  in
  Dom_utils.set_text_content "records-showing" showing_text;

  (* Update page info *)
  let page_text = Printf.sprintf "Page %d of %d" current_page total_pages in
  Dom_utils.set_text_content "page-info" page_text;

  (* Enable/disable pagination buttons *)
  let prev_button = Dom_utils.get_element_by_id "prev-page" in
  let next_button = Dom_utils.get_element_by_id "next-page" in

  Js.Opt.iter (Dom_html.CoerceTo.button prev_button) (fun btn ->
    btn##.disabled := Js.bool (current_page <= 1)
  );

  Js.Opt.iter (Dom_html.CoerceTo.button next_button) (fun btn ->
    btn##.disabled := Js.bool (current_page >= total_pages)
  )

let refresh () =
  let records = App_state.get_page_records () in
  render_records records;
  update_pagination_info ()

let setup_pagination () =
  (* Previous page button *)
  let prev_button = Dom_utils.get_element_by_id "prev-page" in
  prev_button##.onclick := Dom_html.handler (fun _ ->
    App_state.prev_page ();
    refresh ();
    Js._false
  );

  (* Next page button *)
  let next_button = Dom_utils.get_element_by_id "next-page" in
  next_button##.onclick := Dom_html.handler (fun _ ->
    App_state.next_page ();
    refresh ();
    Js._false
  )

let initialize () =
  setup_pagination ();
  Dom_utils.log "Record table initialized"
