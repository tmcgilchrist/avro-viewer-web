(** File upload and Avro parsing *)

open Js_of_ocaml
open Js_of_ocaml_lwt

(* Ensure codecs are registered *)
let () =
  (* Register null codec *)
  Avro_simple.Codec_null.register ();
  (* Register deflate codec *)
  Avro_simple.Codec_deflate.register ()

(** Convert Avro Value.t to Yojson.Safe.t *)
let rec value_to_yojson (value : Avro_simple.Value.t) : Yojson.Safe.t =
  match value with
  | Null -> `Null
  | Boolean b -> `Bool b
  | Int i -> `Int i
  | Long l -> `Intlit (Int64.to_string l)
  | Float f -> `Float f
  | Double d -> `Float d
  | Bytes b -> `String (Bytes.to_string b)  (* Could be base64 encoded *)
  | String s -> `String s
  | Array arr -> `List (Array.to_list arr |> List.map value_to_yojson)
  | Map pairs -> `Assoc (List.map (fun (k, v) -> (k, value_to_yojson v)) pairs)
  | Record fields -> `Assoc (List.map (fun (k, v) -> (k, value_to_yojson v)) fields)
  | Enum (_idx, symbol) -> `String symbol
  | Union (_idx, v) -> value_to_yojson v
  | Fixed b -> `String (Bytes.to_string b)

let read_file_as_bytes (file : File.file Js.t) : bytes Lwt.t =
  let promise, resolver = Lwt.wait () in
  let reader = new%js File.fileReader in

  reader##.onload := Dom.handler (fun _ ->
    (* reader##.result is File.file_any
       When using readAsArrayBuffer, the result is an arrayBuffer
       We use CoerceTo to safely convert *)
    Js.Opt.case (File.CoerceTo.arrayBuffer reader##.result)
      (fun () ->
        Lwt.wakeup_exn resolver (Failure "Failed to read file as ArrayBuffer");
        Js._false)
      (fun array_buffer ->
        let typed_array = new%js Typed_array.uint8Array_fromBuffer array_buffer in
        let length = typed_array##.length in
        let bytes_result = Bytes.create length in
        for i = 0 to length - 1 do
          let byte_val = Js.Optdef.get (Typed_array.get typed_array i) (fun () -> 0) in
          Bytes.set bytes_result i (Char.chr byte_val)
        done;
        Lwt.wakeup resolver bytes_result;
        Js._false)
  );

  reader##.onerror := Dom.handler (fun _ ->
    Lwt.wakeup_exn resolver (Failure "Error reading file");
    Js._false
  );

  reader##readAsArrayBuffer file;
  promise

let parse_avro_file file_data =
  try
    Dom_utils.log_debug "Parsing Avro file (%d bytes)" (Bytes.length file_data);

    (* Create a codec for generic value reading - we'll use the writer schema later *)
    let codec = {
      Avro_simple.Codec.schema = Avro_simple.Schema.Null;
      encode = (fun _value _output -> ());
      decode = (fun _input ->
        (* We can't know the schema until we read the header, so we'll fail here *)
        (* This will be replaced by proper generic decoding below *)
        failwith "Should not call decode before reading header"
      )
    } in

    (* Create a container reader from bytes *)
    let reader = Avro_simple.Container_reader.of_bytes file_data ~codec () in

    (* Get the schema from the reader *)
    let schema = Avro_simple.Container_reader.writer_schema reader in
    let schema_json =
      Avro_simple.Schema_json.to_json schema
      |> Yojson.Basic.to_string
    in

    (* Get metadata including codec *)
    let metadata = Avro_simple.Container_reader.metadata reader in
    let codec_name =
      try
        List.assoc "avro.codec" metadata
      with Not_found -> "null"
    in

    (* Create a proper codec with the actual schema *)
    let resolved_schema = match Avro_simple.Resolution.resolve_schemas schema schema with
      | Ok rs -> rs
      | Error _ -> failwith "Failed to resolve schema with itself"
    in
    let value_codec = {
      Avro_simple.Codec.schema = schema;
      encode = (fun _value _output -> ());
      decode = (fun input -> Avro_simple.Decoder.decode_value resolved_schema input)
    } in

    (* Create a new reader with the proper codec *)
    Avro_simple.Container_reader.close reader;
    let reader = Avro_simple.Container_reader.of_bytes file_data ~codec:value_codec () in

    (* Read all records as JSON *)
    let records =
      Avro_simple.Container_reader.to_seq reader
      |> Seq.map value_to_yojson
      |> List.of_seq
    in

    let record_count = List.length records in

    Dom_utils.log_debug "Parsed %d records with codec: %s" record_count codec_name;

    (* Close the reader *)
    Avro_simple.Container_reader.close reader;

    Ok (schema, schema_json, codec_name, records)
  with
  | e ->
      let msg = Printexc.to_string e in
      Dom_utils.log_error ("Parse error: " ^ msg);
      Error msg

let handle_file (file : File.file Js.t) =
  let filename = Js.to_string file##.name in
  let filesize = file##.size in

  Dom_utils.log_debug "Processing file: %s (%d bytes)" filename filesize;

  (* Show loading indicator *)
  Dom_utils.hide_element "upload-area";
  Dom_utils.show_element "loading";

  let%lwt file_data = read_file_as_bytes file in

  (* Parse Avro file *)
  match parse_avro_file file_data with
  | Ok (schema, schema_json, codec, records) ->
      let record_count = List.length records in

      (* Update app state *)
      let file_info = {
        App_state.name = filename;
        size = filesize;
        compression = codec;
        total_records = record_count;
      } in
      App_state.set_file_info file_info;
      App_state.set_schema schema;
      App_state.set_records records;

      (* Update file info panel *)
      Dom_utils.set_input_value "info-filename" filename;
      Dom_utils.set_input_value "info-filesize" (Dom_utils.format_bytes filesize);
      Dom_utils.set_input_value "info-compression" codec;
      Dom_utils.set_input_value "info-count" (Dom_utils.format_number record_count);

      (* Display schema in JSON view *)
      Schema_viewer.display_schema_json schema_json;

      (* Display schema fields *)
      Schema_viewer.display_schema_fields schema_json;

      (* Display records *)
      Record_table.refresh ();

      (* Show panels *)
      Dom_utils.hide_element "loading";
      Dom_utils.show_element "file-info";
      Dom_utils.show_element "schema-panel";
      Dom_utils.show_element "filter-panel";
      Dom_utils.show_element "records-panel";

      Dom_utils.log (Printf.sprintf "Successfully loaded %d records" record_count);
      Lwt.return_unit

  | Error msg ->
      (* Show error *)
      Dom_utils.hide_element "loading";
      Dom_utils.set_text_content "error-message" msg;
      Dom_utils.show_element "error-display";
      Dom_utils.show_element "upload-area";
      Lwt.return_unit

let setup_file_input () =
  let file_input = Dom_utils.get_element_by_id "file-input" in

  (* Handle file selection *)
  let handler = Dom_html.handler (fun event ->
    Js.Opt.iter event##.target (fun target ->
      Js.Opt.iter (Dom_html.CoerceTo.input target) (fun input ->
        let files = input##.files in
        if files##.length > 0 then
          Js.Opt.iter (files##item 0) (fun file ->
            (* Update file name display *)
            Dom_utils.set_text_content "file-name" (Js.to_string file##.name);

            (* Process file asynchronously *)
            Lwt.async (fun () -> handle_file file)
          )
      )
    );
    Js._true
  ) in

  Js.Opt.iter (Dom_html.CoerceTo.input file_input) (fun input ->
    input##.onchange := handler
  )

let setup_drag_drop () =
  let upload_area = Dom_utils.get_element_by_id "upload-area" in

  (* Prevent default drag behaviors *)
  let prevent_default event =
    Dom.preventDefault event;
    Js._false
  in

  upload_area##.ondragover := Dom_html.handler prevent_default;
  upload_area##.ondragenter := Dom_html.handler (fun event ->
    Dom_utils.add_class upload_area "dragover";
    prevent_default event
  );

  upload_area##.ondragleave := Dom_html.handler (fun event ->
    Dom_utils.remove_class upload_area "dragover";
    prevent_default event
  );

  upload_area##.ondrop := Dom_html.handler (fun (event : Dom_html.dragEvent Js.t) ->
    Dom.preventDefault event;
    Dom_utils.remove_class upload_area "dragover";

    (* Get dropped files *)
    let dt = event##.dataTransfer in
    let files = dt##.files in
    if files##.length > 0 then
      Js.Opt.iter (files##item 0) (fun file ->
        (* Update file name display *)
        Dom_utils.set_text_content "file-name" (Js.to_string file##.name);

        (* Process file *)
        Lwt.async (fun () -> handle_file file)
      );
    Js._false
  )

let initialize () =
  setup_file_input ();
  setup_drag_drop ();
  Dom_utils.log "File upload handlers initialized"
