(** Application state management *)

open Avro_simple

type file_info = {
  name: string;
  size: int;
  compression: string;
  total_records: int;
}

type t = {
  mutable file_info: file_info option;
  mutable schema: Schema.t option;
  mutable current_page: int;
  mutable page_size: int;
  mutable filter: string option;
  mutable all_records: Yojson.Safe.t list;  (* Cached records for filtering *)
}

let state = {
  file_info = None;
  schema = None;
  current_page = 1;
  page_size = 50;
  filter = None;
  all_records = [];
}

let set_file_info info =
  state.file_info <- Some info

let get_file_info () =
  state.file_info

let set_schema schema =
  state.schema <- Some schema

let get_schema () =
  state.schema

let set_records records =
  state.all_records <- records

let get_records () =
  state.all_records

(* Parse and evaluate filter expressions like "age >= 30" or "name = Alice" *)
let parse_filter_expr expr =
  (* Trim whitespace *)
  let expr = String.trim expr in

  (* Try to match: field op value *)
  let operators = [">="; "<="; "!="; "="; ">"; "<"] in

  let rec try_operators ops =
    match ops with
    | [] -> None
    | op :: rest ->
        (try
          let idx = String.index_from expr 0 (String.get op 0) in
          let field = String.trim (String.sub expr 0 idx) in
          let remaining = String.sub expr idx (String.length expr - idx) in
          if String.length remaining >= String.length op &&
             String.sub remaining 0 (String.length op) = op then
            let value = String.trim (String.sub remaining (String.length op)
                                     (String.length remaining - String.length op)) in
            Some (field, op, value)
          else
            try_operators rest
        with _ -> try_operators rest)
  in
  try_operators operators

let compare_values op v1 v2 =
  (* Try numeric comparison first *)
  try
    let n1 = float_of_string v1 in
    let n2 = float_of_string v2 in
    match op with
    | "=" -> n1 = n2
    | "!=" -> n1 <> n2
    | ">" -> n1 > n2
    | "<" -> n1 < n2
    | ">=" -> n1 >= n2
    | "<=" -> n1 <= n2
    | _ -> false
  with _ ->
    (* Fall back to string comparison *)
    match op with
    | "=" -> v1 = v2
    | "!=" -> v1 <> v2
    | ">" -> v1 > v2
    | "<" -> v1 < v2
    | ">=" -> v1 >= v2
    | "<=" -> v1 <= v2
    | _ -> false

let evaluate_filter record filter_expr =
  match parse_filter_expr filter_expr with
  | None ->
      (* If can't parse as expression, fall back to substring search *)
      let json_str = Yojson.Safe.to_string record in
      let json_lower = String.lowercase_ascii json_str in
      let filter_lower = String.lowercase_ascii filter_expr in
      let rec contains haystack needle pos =
        if pos > String.length haystack - String.length needle then false
        else if String.sub haystack pos (String.length needle) = needle then true
        else contains haystack needle (pos + 1)
      in
      if String.length filter_lower = 0 then true
      else contains json_lower filter_lower 0
  | Some (field, op, value) ->
      (* Extract field value from record *)
      let open Yojson.Safe.Util in
      try
        let field_value = member field record in
        let field_str = match field_value with
          | `String s -> s
          | `Int i -> string_of_int i
          | `Intlit s -> s
          | `Float f -> string_of_float f
          | `Bool b -> string_of_bool b
          | `Null -> "null"
          | _ -> Yojson.Safe.to_string field_value
        in
        compare_values op field_str value
      with _ -> false

let get_filtered_records () =
  match state.filter with
  | None -> state.all_records
  | Some filter_expr ->
      List.filter (fun record -> evaluate_filter record filter_expr) state.all_records

let get_page_records () =
  let filtered = get_filtered_records () in
  let start_idx = (state.current_page - 1) * state.page_size in
  let end_idx = min (start_idx + state.page_size) (List.length filtered) in
  let rec take n lst =
    match n, lst with
    | 0, _ | _, [] -> []
    | n, x :: xs -> x :: take (n - 1) xs
  in
  let rec drop n lst =
    match n, lst with
    | 0, _ -> lst
    | _, [] -> []
    | n, _ :: xs -> drop (n - 1) xs
  in
  drop start_idx filtered |> take (end_idx - start_idx)

let set_current_page page =
  state.current_page <- max 1 page

let get_current_page () =
  state.current_page

let get_total_pages () =
  let filtered = get_filtered_records () in
  let total = List.length filtered in
  (total + state.page_size - 1) / state.page_size

let next_page () =
  let total_pages = get_total_pages () in
  if state.current_page < total_pages then
    state.current_page <- state.current_page + 1

let prev_page () =
  if state.current_page > 1 then
    state.current_page <- state.current_page - 1

let set_filter filter_expr =
  state.filter <- if filter_expr = "" then None else Some filter_expr;
  state.current_page <- 1  (* Reset to first page on filter change *)

let clear_filter () =
  state.filter <- None;
  state.current_page <- 1

let get_filter () =
  state.filter

let reset () =
  state.file_info <- None;
  state.schema <- None;
  state.current_page <- 1;
  state.filter <- None;
  state.all_records <- []
