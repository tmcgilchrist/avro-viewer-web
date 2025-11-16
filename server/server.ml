(** Dream web server for Avro Viewer *)

let read_file path =
  try
    let ic = open_in path in
    let length = in_channel_length ic in
    let content = really_input_string ic length in
    close_in ic;
    Some content
  with _ ->
    Printf.eprintf "Failed to read file: %s\n%!" path;
    None

let handler =
  Dream.router [

    (* Serve the main HTML page *)
    Dream.get "/" (fun _ ->
      match read_file "static/index.html" with
      | Some content -> Dream.html content
      | None -> Dream.html "<h1>Error: Could not load index.html</h1>");

    (* Serve JavaScript *)
    Dream.get "/main.bc.js" (fun _ ->
      match read_file "_build/default/src/main.bc.js" with
      | Some content ->
          Dream.respond
            ~headers:[("Content-Type", "application/javascript")]
            content
      | None ->
          Dream.empty `Not_Found);

    (* Serve CSS *)
    Dream.get "/style.css" (fun _ ->
      match read_file "static/style.css" with
      | Some content ->
          Dream.respond
            ~headers:[("Content-Type", "text/css")]
            content
      | None ->
          Dream.empty `Not_Found);

    (* Serve sample Avro files *)
    Dream.get "/static/**" (fun request ->
      let path = Dream.target request in
      let file_path = "." ^ path in
      match read_file file_path with
      | Some content ->
          Dream.respond
            ~headers:[("Content-Type", "application/octet-stream")]
            content
      | None ->
          Dream.empty `Not_Found);

  ]

let () =
  Dream.run ~port:8080
  @@ Dream.logger
  @@ handler
