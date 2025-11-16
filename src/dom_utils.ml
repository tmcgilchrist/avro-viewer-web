(** DOM manipulation utilities for js_of_ocaml *)

open Js_of_ocaml

let document = Dom_html.document

let get_element_by_id id =
  Js.Opt.get
    (document##getElementById (Js.string id))
    (fun () -> failwith ("Element not found: " ^ id))

let get_input_value id =
  let elem = get_element_by_id id in
  match Js.Opt.to_option (Dom_html.CoerceTo.input elem) with
  | Some input -> Js.to_string input##.value
  | None -> ""

let set_input_value id value =
  let elem = get_element_by_id id in
  match Js.Opt.to_option (Dom_html.CoerceTo.input elem) with
  | Some input -> input##.value := Js.string value
  | None -> ()

let set_text_content id text =
  let elem = get_element_by_id id in
  elem##.textContent := Js.some (Js.string text)

let set_inner_html id html =
  let elem = get_element_by_id id in
  elem##.innerHTML := Js.string html

let show_element id =
  let elem = get_element_by_id id in
  (Js.Unsafe.coerce elem##.style)##.display := Js.string "block"

let hide_element id =
  let elem = get_element_by_id id in
  (Js.Unsafe.coerce elem##.style)##.display := Js.string "none"

let add_class elem class_name =
  elem##.classList##add (Js.string class_name)

let remove_class elem class_name =
  elem##.classList##remove (Js.string class_name)

let has_class elem class_name =
  Js.to_bool (elem##.classList##contains (Js.string class_name))

let create_element tag =
  document##createElement (Js.string tag)

let create_text text =
  (document##createTextNode (Js.string text) :> Dom.node Js.t)

let append_child parent child =
  ignore (parent##appendChild child)

let remove_all_children elem =
  while Js.Opt.test elem##.firstChild do
    Js.Opt.iter elem##.firstChild (fun child ->
      ignore (elem##removeChild child))
  done

let format_bytes bytes =
  let kb = 1024 in
  let mb = kb * 1024 in
  let gb = mb * 1024 in
  if bytes >= gb then
    Printf.sprintf "%.2f GB" (float_of_int bytes /. float_of_int gb)
  else if bytes >= mb then
    Printf.sprintf "%.2f MB" (float_of_int bytes /. float_of_int mb)
  else if bytes >= kb then
    Printf.sprintf "%.2f KB" (float_of_int bytes /. float_of_int kb)
  else
    Printf.sprintf "%d bytes" bytes

let format_number n =
  let rec add_commas s =
    if String.length s <= 3 then s
    else
      let len = String.length s in
      let first = String.sub s 0 (len - 3) in
      let last = String.sub s (len - 3) 3 in
      add_commas first ^ "," ^ last
  in
  add_commas (string_of_int n)

let log message =
  Firebug.console##log (Js.string message) [@alert "-deprecated"]

let log_error message =
  Firebug.console##error (Js.string message) [@alert "-deprecated"]

let log_debug fmt =
  Printf.ksprintf log fmt
