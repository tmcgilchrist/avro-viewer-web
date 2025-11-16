(** Test data generator using QCheck for realistic Avro files *)

open Avro_simple
open QCheck

(** Utility functions *)

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

(** Sample data types *)
type user = {
  id: int;
  name: string;
  email: string;
  age: int;
  active: bool;
  balance: float;
  tags: string array;
  created_at: int64;
}

type event = {
  event_id: string;
  user_id: int;
  event_type: string;
  timestamp: int64;
  metadata: (string * string) list;
}

(** QCheck generators *)

let alphanumeric_string =
  let open Gen in
  string_size ~gen:(char_range 'a' 'z') (int_range 5 15)

let email_gen =
  let open Gen in
  let* username = alphanumeric_string in
  let* domain = oneofl ["example.com"; "test.com"; "demo.org"; "sample.net"] in
  return (username ^ "@" ^ domain)

let name_gen =
  let open Gen in
  let first_names = [|"Alice"; "Bob"; "Charlie"; "Diana"; "Eve"; "Frank"; "Grace"; "Henry"|] in
  let last_names = [|"Smith"; "Johnson"; "Williams"; "Brown"; "Jones"; "Garcia"; "Miller"; "Davis"|] in
  let* first = oneofa first_names in
  let* last = oneofa last_names in
  return (first ^ " " ^ last)

let tags_gen =
  let open Gen in
  let tag_options = [|"premium"; "active"; "verified"; "new"; "vip"; "trial"|] in
  array_size (int_range 0 3) (oneofa tag_options)

let uuid_gen =
  let open Gen in
  let hex_char = oneofl ['0';'1';'2';'3';'4';'5';'6';'7';'8';'9';'a';'b';'c';'d';'e';'f'] in
  let* chars = list_repeat 32 hex_char in
  let s = String.concat "" (List.map (String.make 1) chars) in
  (* Format as UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx *)
  let formatted = Printf.sprintf "%s-%s-%s-%s-%s"
    (String.sub s 0 8)
    (String.sub s 8 4)
    (String.sub s 12 4)
    (String.sub s 16 4)
    (String.sub s 20 12) in
  return formatted

let user_gen =
  let open Gen in
  let* id = int_range 1 1000000 in
  let* name = name_gen in
  let* email = email_gen in
  let* age = int_range 18 80 in
  let* active = bool in
  let* balance = float_range 0.0 10000.0 in
  let* tags = tags_gen in
  (* Last 10 years: from Nov 2014 to Nov 2024 *)
  (* Unix timestamp for Nov 16, 2014 00:00:00 UTC: 1416096000 *)
  (* Unix timestamp for Nov 16, 2024 23:59:59 UTC: 1731801599 *)
  let* created_at_int = int_range 1416096000 1731801599 in
  (* Convert to milliseconds for consistency with timestamp fields *)
  let created_at = Int64.mul (Int64.of_int created_at_int) 1000L in
  return { id; name; email; age; active; balance; tags; created_at }

let event_type_gen =
  Gen.oneofl ["login"; "logout"; "purchase"; "view"; "click"; "signup"; "update_profile"]

let metadata_gen =
  let open Gen in
  let* key_count = int_range 0 5 in
  list_repeat key_count (pair alphanumeric_string alphanumeric_string)

let event_gen =
  let open Gen in
  let* event_id = uuid_gen in
  let* user_id = int_range 1 10000 in
  let* event_type = event_type_gen in
  let* timestamp_int = int_range 1609459200 1704067200 in
  let timestamp = Int64.of_int timestamp_int in
  let* metadata = metadata_gen in
  return { event_id; user_id; event_type; timestamp; metadata }

(** Avro codecs *)

let user_codec =
  let open Codec in
  record (Type_name.simple "User")
    (fun id name email age active balance tags created_at ->
      { id; name; email; age; active; balance; tags; created_at })
  |> field "id" int (fun u -> u.id)
  |> field "name" string (fun u -> u.name)
  |> field "email" string (fun u -> u.email)
  |> field "age" int (fun u -> u.age)
  |> field "active" boolean (fun u -> u.active)
  |> field "balance" double (fun u -> u.balance)
  |> field "tags" (array string) (fun u -> u.tags)
  |> field "created_at" long (fun u -> u.created_at)
  |> finish

let event_codec =
  let open Codec in
  let metadata_codec = map string in
  record (Type_name.simple "Event")
    (fun event_id user_id event_type timestamp metadata ->
      { event_id; user_id; event_type; timestamp; metadata })
  |> field "event_id" string (fun e -> e.event_id)
  |> field "user_id" int (fun e -> e.user_id)
  |> field "event_type" string (fun e -> e.event_type)
  |> field "timestamp" long (fun e -> e.timestamp)
  |> field "metadata" metadata_codec (fun e -> e.metadata)
  |> finish

(** File generation *)

let generate_user_file ~output ~count ~compression () =
  Printf.printf "Generating %s records file: %s\n%!" (format_number count) output;

  let () = Avro.init_codecs () in

  (* Generate users *)
  let rng = Random.State.make_self_init () in
  let users = List.init count (fun _ ->
    Gen.generate1 ~rand:rng user_gen
  ) in

  (* Write to container file *)
  let writer = Container_writer.create
    ~path:output
    ~codec:user_codec
    ~compression
    ()
  in

  let start_time = Unix.gettimeofday () in

  List.iteri (fun i user ->
    Container_writer.write writer user;
    if (i + 1) mod 10000 = 0 then
      Printf.printf "  Written %s records...\n%!" (format_number (i + 1))
  ) users;

  Container_writer.close writer;

  let elapsed = Unix.gettimeofday () -. start_time in
  let file_size = (Unix.stat output).Unix.st_size in

  Printf.printf "✓ Complete!\n";
  Printf.printf "  Records: %s\n" (format_number count);
  Printf.printf "  File size: %s\n" (format_bytes file_size);
  Printf.printf "  Time: %.2fs\n" elapsed;
  Printf.printf "  Throughput: %s records/sec\n"
    (format_number (int_of_float (float_of_int count /. elapsed)))

let generate_event_file ~output ~count ~compression () =
  Printf.printf "Generating %s events file: %s\n%!" (format_number count) output;

  let () = Avro.init_codecs () in

  (* Generate events *)
  let rng = Random.State.make_self_init () in
  let events = List.init count (fun _ ->
    Gen.generate1 ~rand:rng event_gen
  ) in

  (* Write to container file *)
  let writer = Container_writer.create
    ~path:output
    ~codec:event_codec
    ~compression
    ()
  in

  let start_time = Unix.gettimeofday () in

  List.iteri (fun i event ->
    Container_writer.write writer event;
    if (i + 1) mod 10000 = 0 then
      Printf.printf "  Written %s records...\n%!" (format_number (i + 1))
  ) events;

  Container_writer.close writer;

  let elapsed = Unix.gettimeofday () -. start_time in
  let file_size = (Unix.stat output).Unix.st_size in

  Printf.printf "✓ Complete!\n";
  Printf.printf "  Records: %s\n" (format_number count);
  Printf.printf "  File size: %s\n" (format_bytes file_size);
  Printf.printf "  Time: %.2fs\n" elapsed;
  Printf.printf "  Throughput: %s records/sec\n"
    (format_number (int_of_float (float_of_int count /. elapsed)))

(** CLI *)

let () =
  let output = ref "test.avro" in
  let count = ref 10000 in
  let compression = ref "deflate" in
  let data_type = ref "user" in

  let spec = [
    ("--output", Arg.Set_string output, "Output file path (default: test.avro)");
    ("--count", Arg.Set_int count, "Number of records to generate (default: 10000)");
    ("--compression", Arg.Set_string compression, "Compression codec: null, deflate, snappy, zstandard (default: deflate)");
    ("--type", Arg.Set_string data_type, "Data type: user, event (default: user)");
  ] in

  let usage = "Usage: generate_test_data [options]" in
  Arg.parse spec (fun _ -> ()) usage;

  match !data_type with
  | "user" -> generate_user_file ~output:!output ~count:!count ~compression:!compression ()
  | "event" -> generate_event_file ~output:!output ~count:!count ~compression:!compression ()
  | _ ->
      Printf.eprintf "Error: Unknown data type '%s'. Use 'user' or 'event'\n" !data_type;
      exit 1
