open Bot_infos

let generic_retry ~bot_infos ~url_part =
  let uri =
    "https://gitlab.com/api/v4/" ^ url_part ^ "/retry" |> Uri.of_string
  in
  let gitlab_header = [ ("Private-Token", bot_infos.gitlab_token) ] in
  Utils.send_request ~body:Cohttp_lwt.Body.empty ~uri gitlab_header ~bot_infos

let retry_job ~bot_infos ~project_id ~build_id =
  generic_retry ~bot_infos
    ~url_part:
      ("projects/" ^ Int.to_string project_id ^ "/jobs/"
     ^ Int.to_string build_id)
