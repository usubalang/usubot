type t = {
  gitlab_token : string;
  github_pat : string;
  github_install_token : string option;
  name : string;
  email : string;
  domain : string;
  app_id : int;
  debug : bool;
}

val github_token : t -> string
val pp : Format.formatter -> t -> unit
