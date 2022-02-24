open Lwt

let installation_tokens : (string, string * float) Base.Hashtbl.t =
  Base.Hashtbl.create (module Base.String)

let action_with_new_installation_token ~bot_info ~key ~owner ~repo action () =
  (* Installation tokens expire after one hour, we stop using them after 40 minutes *)
  GitHub_app.get_installation_token ~bot_info ~key ~owner ~repo >>= function
  | Ok (install_token, expiration_date) ->
      let _ =
        Base.Hashtbl.add installation_tokens ~key:owner
          ~data:(install_token, expiration_date)
      in
      let bot_info : Bot_info.t =
        { bot_info with github_install_token = Some install_token }
      in
      action ~bot_info
  | Error _ ->
      (* If we cannot retrieve an installation token for the repository
         repo owned by owner, we execute the action with the github access token. *)
      action ~bot_info

let action_as_github_app ~bot_info ~key ~owner ~repo action
    (* Executes an action with an installation token if the repository has
       the GitHub app installed.
       Generates a new installation token if the existing one has expired. *)
      () =
  match Base.Hashtbl.find installation_tokens owner with
  | Some (install_token, expiration_date) ->
      if Base.Float.(expiration_date < Unix.time ()) then (
        Base.Hashtbl.remove installation_tokens owner;
        action_with_new_installation_token ~bot_info ~key ~owner ~repo action ())
      else
        let bot_info : Bot_info.t =
          { bot_info with github_install_token = Some install_token }
        in
        action ~bot_info
  | None -> (
      GitHub_app.get_installations ~bot_info ~key >>= function
      | Ok installs ->
          if ListLabels.exists installs ~f:(String.equal owner) then
            action_with_new_installation_token ~bot_info ~key ~owner ~repo
              action ()
          else action ~bot_info
      | Error _ -> action ~bot_info)
