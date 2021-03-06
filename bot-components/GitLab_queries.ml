open Cohttp_lwt_unix
open Lwt
open Bot_infos

let get_build_trace ~bot_infos ~project_id ~build_id =
  let uri =
    "https://gitlab.com/api/v4/projects/" ^ Int.to_string project_id ^ "/jobs/"
    ^ Int.to_string build_id ^ "/trace"
    |> Uri.of_string
  in
  let gitlab_header = [ ("Private-Token", bot_infos.gitlab_token) ] in
  let headers = Utils.headers gitlab_header ~bot_infos in
  Client.get ~headers uri >>= fun (_response, body) ->
  Cohttp_lwt.Body.to_string body
