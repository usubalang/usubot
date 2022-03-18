open Bot_components
open Cmdliner

type infos = {
  bot_infos : Bot_components.Bot_info.t;
  mappings : (string, string) Base.Hashtbl.t * (string, string) Base.Hashtbl.t;
  port : int;
  github_private_key : Mirage_crypto_pk.Rsa.priv;
  github_webhook_secret : string;
  github_access_token : string;
  gitlab_webhook_secret : string;
  daily_schedule_secret : string;
  benchs : string;
  main_repo : string;
}

let absolute_path file =
  let ci = Unix.open_process_in (Format.sprintf "cd %s; pwd" file) in
  let l = input_line ci in
  close_in ci;
  l

let pp ppf t =
  Format.fprintf ppf
    "{ bot_infos : %a;@ port : %d;@ github_webhook_secret : %s;@ \
     github_access_token : %s;@ daily_schedule_secret : %s;@,\
     }"
    Bot_info.pp t.bot_infos t.port t.github_webhook_secret t.github_access_token
    t.daily_schedule_secret

let toml_file =
  let doc = "TOML file containing all the necessary bot infos" in
  let inf = Arg.(info [] ~docv:"FILE" ~doc) in
  Arg.(required & pos ~rev:true 0 (some string) None & inf)

let debug =
  let doc = "Output debug infos" in
  let inf = Arg.(info [ "debug"; "d" ] ~doc) in
  Arg.(flag & inf)

let path =
  let doc = "File containing the private key for GitHub" in
  let inf = Arg.(info [ "key_path"; "k" ] ~docv:"FILE" ~doc) in
  Arg.(value & opt (some string) None & inf)

let benchs =
  let doc = "Directory containing all the benchs" in
  let inf = Arg.(info [ "benchs"; "b" ] ~docv:"FILE" ~doc) in
  Arg.(value & opt string "~/benchmarks" & inf)

let main_repo =
  let doc = "Directory containing the usuba repo" in
  let inf = Arg.(info [ "usuba"; "u" ] ~docv:"FILE" ~doc) in
  Arg.(value & opt string "~/usuba" & inf)

let main toml_file path benchs main_repo debug =
  let toml_data = Config.toml_of_file toml_file in
  let port = Config.port toml_data in
  let gitlab_access_token = Config.gitlab_access_token toml_data in
  let github_access_token = Config.github_access_token toml_data in
  let github_webhook_secret = Config.github_webhook_secret toml_data in
  let gitlab_webhook_secret = Config.gitlab_webhook_secret toml_data in
  let daily_schedule_secret = Config.daily_schedule_secret toml_data in
  let bot_name = Config.bot_name toml_data in
  let github_private_key =
    match path with
    | None -> Config.github_private_key ()
    | Some path -> Config.github_private_key ~path ()
  in
  let app_id = Config.github_app_id toml_data in

  let benchs = absolute_path benchs in
  let main_repo = absolute_path main_repo in

  `Ok
    {
      bot_infos =
        Bot_components.Bot_info.
          {
            github_pat = github_access_token;
            github_install_token = None;
            gitlab_token = gitlab_access_token;
            name = bot_name;
            email = Config.bot_email toml_data;
            domain = Config.bot_domain toml_data;
            app_id;
            debug;
          };
      mappings = Config.make_mappings_table toml_data;
      port;
      github_private_key;
      github_webhook_secret;
      github_access_token;
      gitlab_webhook_secret;
      daily_schedule_secret;
      benchs;
      main_repo;
    }

let parse_infos =
  let main =
    Term.(ret (const main $ toml_file $ path $ benchs $ main_repo $ debug))
  in

  let doc = "Start the bot with the given config file." in
  let man =
    [
      `S Manpage.s_bugs;
      `P "You can open an issue on: https://github.com/mattiasdrp/usubot/issues";
      `S Manpage.s_authors;
      `Pre "CURRENT AUTHORS\n   mattiasdrp\n";
    ]
  in

  let infos = Cmd.info "usubot" ~version:"dev" ~doc ~man in
  Cmd.v infos main

let get_bot_infos () =
  match Cmdliner.Cmd.(eval_value parse_infos) with
  | Ok infos -> (
      match infos with
      | `Ok infos ->
          Format.printf "@[<v 1>%a@." pp infos;
          infos
      | `Help | `Version -> exit Cmd.Exit.ok)
  | Error e ->
      exit
        (match e with
        | `Exn -> Cmd.Exit.internal_error
        | `Parse -> Cmd.Exit.cli_error
        | `Term -> 1)
