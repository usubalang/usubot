open Bot_components
open GitHub_types
open Cohttp_lwt_unix
open Parser_bot_infos
open Lwt

let update_git_repo bot_info (info : issue_info pull_request_info) =
  let cmd_out =
    Unix.open_process_in
      (Helpers.f "cd %s && git remote 2>&1" bot_info.main_repo)
  in
  let remotes = Util.extract_remotes cmd_out in
  (match Unix.close_process_in cmd_out with
  | Unix.WEXITED 0 -> ()
  | _ -> Format.eprintf "Error while trying to get remotes@.");
  let remote = Util.extract_user info.head.branch.repo_url in
  (* Check that there's a remote corresponding to the branch repo url *)
  (* If there is no such remote, create one and fetch it *)
  if not (Util.SSet.mem remote remotes) then (
    let command =
      Helpers.f "cd %s && git remote add %s %s " bot_info.main_repo remote
        info.head.branch.repo_url
    in
    Format.eprintf "%s..." command;
    let ex = Sys.command command in
    Format.eprintf " ended with %d exit status@." ex);
  (* Whatever happens, fetch the remote *)
  let command = Helpers.f "cd %s && git fetch %s" bot_info.main_repo remote in
  Format.eprintf "%s..." command;
  let ex = Sys.command command in
  Format.eprintf " ended with %d exit status@." ex

let time bot_info branch =
  let benchs = bot_info.benchs in
  (* Go in usuba main repo and checkout the branch *)
  (* The script will take care of building usubac *)
  let command =
    Helpers.f "cd %s && git checkout %s && git pull" bot_info.main_repo branch
  in
  Format.eprintf "%s..." command;
  let ex = Sys.command command in
  Format.eprintf " ended with %d exit status@." ex;
  (* Go in the benchmarks repo and run the script *)
  let time_start = Unix.gettimeofday () in
  let command = Helpers.f "cd %s && ./bench_perfs.pl -q 1> output" benchs in
  Format.printf "%s... " command;
  let ex = Sys.command command in
  let time_end = Unix.gettimeofday () in
  let time = time_end -. time_start in
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
      GitHub_installations.action_as_github_app ~bot_infos:bot_infos.bot_infos
        ~key:bot_infos.github_private_key ~owner:info.issue.issue.owner
        ~repo:info.issue.issue.repo
        (GitHub_mutations.post_and_report_comment ~id:info.issue.id ~message)
      |> Lwt.async;
      exit signal)

let handle_pull_request_updated action info bot_infos =
  match action with
  | PullRequestOpened | PullRequestSynchronized | PullRequestReopened ->
      Sys.(set_signal sigint (handle_termination bot_infos info));
      Sys.(set_signal sigterm (handle_termination bot_infos info));
      update_git_repo bot_infos info;
      let body =
        Helpers.f "Pull Request Opened/Synchronized: @[<v 0>%a@]"
          GitHub_types.(pp_pull_request_info pp_issue_info)
          info
      in
      if bot_infos.bot_infos.Bot_infos.debug then
        Format.eprintf "Starting timing of %s at: %a@." info.base.branch.name
          Helpers.pp_date
          Unix.(time () |> gmtime);
      let time_base, content_base = time bot_infos info.base.branch.name in
      if bot_infos.bot_infos.Bot_infos.debug then
        Format.eprintf "  Time: %f@.Starting timing of %s at: %a@." time_base
          info.head.branch.name Helpers.pp_date
          Unix.(time () |> gmtime);
      let time_head, content_head = time bot_infos info.head.branch.name in
      if bot_infos.bot_infos.Bot_infos.debug then
        Format.eprintf "  Time: %f@." time_head;
      let b = time_head > time_base in
      let outputs =
        Helpers.f "@[<v 2>%s benchs:@,%S@]@.@[<v 2>%s benchs:@,%S@]@."
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
      let conclusion = if b then FAILURE else SUCCESS in
      let github_repo_full_name =
        info.issue.issue.owner ^ "/" ^ info.issue.issue.repo
      in
      (fun () ->
        GitHub_queries.get_repository_id ~bot_infos:bot_infos.bot_infos
          ~owner:info.issue.issue.owner ~repo:info.issue.issue.repo
        >>= function
        | Error e -> Lwt_io.printf "No repo id: %s\n" e
        | Ok repo_id ->
            if bot_infos.bot_infos.Bot_infos.debug then
              Format.eprintf "Starting github actions at: %a@." Helpers.pp_date
                Unix.(time () |> gmtime);
            GitHub_installations.action_as_github_app
              ~bot_infos:bot_infos.bot_infos ~key:bot_infos.github_private_key
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
