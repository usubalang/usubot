open Bot_components
open GitHub_types
open Cohttp_lwt_unix
open Parser_bot_info
open Lwt

let time bot_info branch =
  let benchs = bot_info.benchs in
  (* Go in usuba main repo and checkout the branch *)
  (* The script will take care of building usubac *)
  let command =
    Helpers.f "cd %s && git fetch && git checkout %s && git pull"
      bot_info.main_repo branch
  in
  if bot_info.bot_info.Bot_info.debug then Format.eprintf "%s..." command;
  let ex = Sys.command command in
  if bot_info.bot_info.Bot_info.debug then
    Format.eprintf " ended with %d exit status@." ex;
  (* Go in the benchmarks repo and run the script *)
  let time_start = Unix.gettimeofday () in
  let command = Helpers.f "cd %s && ./bench_perfs.pl 1> output" benchs in
  Format.printf "%s... " command;
  let ex = Sys.command command in
  let time_end = Unix.gettimeofday () in
  let time = time_end -. time_start in
  if bot_info.bot_info.Bot_info.debug then
    Format.eprintf " ended with %d exit status@." ex;
  let ci = open_in (Helpers.f "%s/output" benchs) in
  let content = really_input_string ci (in_channel_length ci) in
  close_in ci;
  (time, content)

let handle_termination bot_infos (info : issue_info pull_request_info) =
  Sys.Signal_handle
    (fun signal ->
      let message =
        Format.sprintf
          "Bot received %d signal and could not end properly. Please restart \
           the job"
          signal
      in
      GitHub_installations.action_as_github_app ~bot_info:bot_infos.bot_info
        ~key:bot_infos.github_private_key ~owner:info.issue.issue.owner
        ~repo:info.issue.issue.repo
        (GitHub_mutations.post_and_report_comment ~id:info.issue.id ~message)
      |> Lwt.async;
      exit signal)

let handle_pull_request_updated action info bot_info =
  match action with
  | PullRequestOpened | PullRequestSynchronized | PullRequestReopened ->
      Sys.(set_signal sigint (handle_termination bot_info info));
      Sys.(set_signal sigterm (handle_termination bot_info info));
      let body =
        Helpers.f "Pull Request Opened/Synchronized: @[<v 0>%a@]"
          GitHub_types.(pp_pull_request_info pp_issue_info)
          info
      in
      if bot_info.bot_info.Bot_info.debug then
        Format.eprintf "Starting timing of %s at: %a@." info.base.branch.name
          Helpers.pp_date
          Unix.(time () |> gmtime);
      let time_base, content_base = time bot_info info.base.branch.name in
      if bot_info.bot_info.Bot_info.debug then
        Format.eprintf "  Time: %f@.Starting timeing of %s at: %a@." time_base
          info.head.branch.name Helpers.pp_date
          Unix.(time () |> gmtime);
      let time_head, content_head = time bot_info info.head.branch.name in
      if bot_info.bot_info.Bot_info.debug then
        Format.eprintf "  Time: %f@." time_head;
      let b = time_head > time_base in
      let outputs =
        Helpers.f "@[<v 2>%s benchs:@,%s@]@.@[<v 2>%s benchs:@,%s@]@."
          info.base.branch.name content_base info.head.branch.name content_head
      in
      let text, summary =
        if b then
          ( Helpers.f
              "Your program ran in %f while the main branch runs in %f, you \
               should investigate the origin of this slowing.@.%s@."
              time_head time_base outputs,
            "Branch is slower than main" )
        else
          ( Helpers.f
              "Your program ran in %f while the main branch runs in %f, \
               congrats on being faster!@.%s@."
              time_head time_base outputs,
            "Branch is faster than main" )
      in
      (* let state = if b then STATE_FAILURE else STATE_PENDING in *)
      let conclusion = if b then FAILURE else SUCCESS in
      let github_repo_full_name =
        info.issue.issue.owner ^ "/" ^ info.issue.issue.repo
      in
      (* GitHub_installations.action_as_github_app ~bot_info:bot_info.bot_info *)
      (*   ~key:bot_info.github_private_key ~owner:info.issue.issue.owner *)
      (*   ~repo:info.issue.issue.repo *)
      (*   (GitHub_mutations.send_status_check *)
      (*      ~repo_full_name:github_repo_full_name ~commit:info.head.sha ~state *)
      (*      ~url:info.head.branch.repo_url ~context:"Testing" *)
      (*      ~description:"Random description") *)
      (* |> Lwt.async; *)
      (fun () ->
        GitHub_queries.get_repository_id ~bot_info:bot_info.bot_info
          ~owner:info.issue.issue.owner ~repo:info.issue.issue.repo
        >>= function
        | Error e -> Lwt_io.printf "No repo id: %s\n" e
        | Ok repo_id ->
            if bot_info.bot_info.Bot_info.debug then
              Format.eprintf "Starting github actions at: %a@." Helpers.pp_date
                Unix.(time () |> gmtime);
            GitHub_installations.action_as_github_app
              ~bot_info:bot_info.bot_info ~key:bot_info.github_private_key
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
