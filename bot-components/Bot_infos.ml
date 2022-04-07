type t = {
  gitlab_token : string;
  github_pat : string;
  github_install_token : string option;
  name : string;
  email : string;
  domain : string;
  app_id : int;
  debug : bool;
  diff_dates : float;
}

let github_token bot_info =
  match bot_info.github_install_token with
  | Some t -> t
  | None -> bot_info.github_pat

let pp ppf t =
  Format.fprintf ppf
    "{gitlab_token: %s;@ github_pat: %s;@ github_install_token: %s;@ name: \
     %s;@ email: %s;@ domain: %s;@ app_id: %d@ diff dates: %.0f@,\
     }"
    t.gitlab_token t.github_pat (github_token t) t.name t.email t.domain
    t.app_id t.diff_dates
