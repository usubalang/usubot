open Bot_components
open GitHub_types
open Cohttp_lwt_unix
open Parser_bot_info
open Lwt

let time branch =
  let command =
    Helpers.f
      "cd ~/ocamlbot-testing && git fetch && git checkout %s && dune exec \
       program 1> /dev/null 2> output &&cd -"
      branch
  in
  let _ex = Sys.command command in
  let ci = open_in "/home/mattias/ocamlbot-testing/output" in
  let r = Str.regexp "Ran in \\([0-9.]+\\)" in
  let time = input_line ci |> Str.replace_first r "\\1" |> Float.of_string in
  close_in ci;
  time

let handle_pull_request_updated action info bot_infos =
  match action with
  | PullRequestOpened | PullRequestSynchronized | PullRequestReopened ->
      let body =
        Helpers.f "Pull Request Opened/Synchronized: @[<v 0>%a@]"
          GitHub_types.(pp_pull_request_info pp_issue_info)
          info
      in
      let time_base = time info.base.branch.name in
      let time_head = time info.head.branch.name in
      let b = time_head > time_base in
      let text, summary =
        if b then
          ( Helpers.f
              "Your program ran in %f while the main branch runs in %f, you \
               should investigate the origin of this slowing"
              time_head time_base,
            "Branch is slower than main" )
        else
          ( Helpers.f
              "Your program ran in %f while the main branch runs in %f, \
               congrats on being faster!"
              time_head time_base,
            "Branch is faster than main" )
      in
      (* let state = if b then STATE_FAILURE else STATE_PENDING in *)
      let conclusion = if b then FAILURE else SUCCESS in
      (* GitHub_installations.action_as_github_app ~bot_info:bot_infos.bot_infos *)
      (*   ~key:bot_infos.github_private_key ~owner:info.issue.issue.owner *)
      (*   ~repo:info.issue.issue.repo *)
      (*   (GitHub_mutations.post_and_report_comment ~id:info.issue.id *)
      (*      ~message:text) *)
      (* |> Lwt.async; *)
      let github_repo_full_name =
        info.issue.issue.owner ^ "/" ^ info.issue.issue.repo
      in
      (* GitHub_installations.action_as_github_app ~bot_info:bot_infos.bot_infos *)
      (*   ~key:bot_infos.github_private_key ~owner:info.issue.issue.owner *)
      (*   ~repo:info.issue.issue.repo *)
      (*   (GitHub_mutations.send_status_check *)
      (*      ~repo_full_name:github_repo_full_name ~commit:info.head.sha ~state *)
      (*      ~url:info.head.branch.repo_url ~context:"Testing" *)
      (*      ~description:"Random description") *)
      (* |> Lwt.async; *)
      (fun () ->
        GitHub_queries.get_repository_id ~bot_info:bot_infos.bot_infos
          ~owner:info.issue.issue.owner ~repo:info.issue.issue.repo
        >>= function
        | Error e -> Lwt_io.printf "No repo id: %s\n" e
        | Ok repo_id ->
            GitHub_installations.action_as_github_app
              ~bot_info:bot_infos.bot_infos ~key:bot_infos.github_private_key
              ~owner:info.issue.issue.owner ~repo:info.issue.issue.repo
              (GitHub_mutations.create_check_run ~name:github_repo_full_name
                 ~repo_id ~head_sha:info.head.sha ~conclusion ~status:COMPLETED
                 ~title:"Benchmarks" ~details_url:info.head.branch.repo_url
                 ~summary ~text ())
              ())
      |> Lwt.async;
      (body, Server.respond_string ~status:`OK ~body ())
  | PullRequestClosed ->
      let body = "Nothing to do for a Pull Request closing" in
      (body, Server.respond_string ~status:`OK ~body ())
