open Bot_infos
open Cohttp
open Cohttp_lwt_unix
open Lwt

let f = Printf.sprintf

let input_all ci =
  let io_size = 65536 in
  let buffer = Buffer.create io_size in
  let rec add () =
    match Buffer.add_channel buffer ci io_size with
    | () -> add ()
    | exception End_of_file -> Buffer.contents buffer
  in
  add ()

let string_match ~regexp string =
  try
    let _ = Str.search_forward (Str.regexp regexp) string 0 in
    true
  with Stdlib.Not_found -> false

let headers ~bot_infos header_list =
  (Header.init () |> fun headers -> Header.add_list headers header_list)
  |> fun headers -> Header.add headers "User-Agent" bot_infos.name

let print_response (resp, body) =
  let code = resp |> Response.status |> Code.code_of_status in
  Lwt_io.printf "Response code: %d.\n" code >>= fun () ->
  if code < 200 && code > 299 then
    resp |> Response.headers |> Header.to_string
    |> Lwt_io.printf "Headers: %s\n"
    >>= fun () ->
    body |> Cohttp_lwt.Body.to_string >>= Lwt_io.printf "Body:\n%s\n"
  else Lwt.return_unit

let send_request ~bot_infos ~body ~uri header_list =
  let headers = headers header_list ~bot_infos in
  Client.post ~body ~headers uri >>= print_response

let handle_json action body =
  try
    let json = Yojson.Basic.from_string body in
    (* print_endline "JSON decoded."; *)
    Ok (action json)
  with
  | Yojson.Json_error err -> Error (f "Json error: %s\n" err)
  | Yojson.Basic.Util.Type_error (err, _) ->
      Error (f "Json type error: %s\n" err)

(* GitHub specific *)

let project_api_preview_header =
  [ ("Accept", "application/vnd.github.inertia-preview+json") ]

let app_api_preview_header =
  [ ("Accept", "application/vnd.github.machine-man-preview+json") ]

let github_header bot_infos =
  [ ("Authorization", "bearer " ^ github_token bot_infos) ]

let generic_get ~bot_infos relative_uri ?(header_list = []) json_handler =
  let uri = "https://api.github.com/" ^ relative_uri |> Uri.of_string in
  let headers = headers (header_list @ github_header bot_infos) ~bot_infos in
  Client.get ~headers uri
  >>= (fun (_response, body) -> Cohttp_lwt.Body.to_string body)
  >|= handle_json json_handler
