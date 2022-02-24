open Lwt
open Cohttp
open Cohttp_lwt_unix
open Parser_bot_info
open Bot_components

let server bot_infos =
  let callback _conn req body =
    Cohttp_lwt.Body.to_string body >>= fun body ->
    let body, response =
      match
        GitHub_subscriptions.receive_github
          ~secret:bot_infos.github_webhook_secret (Request.headers req) body
      with
      | Ok (_, PullRequestUpdated (action, pr_info)) ->
          Handlers.handle_pull_request_updated action pr_info bot_infos
      | Ok (_, UnsupportedEvent s) ->
          let body = Helpers.(f "No action taken: %s" s) in
          (body, Server.respond_string ~status:`OK ~body ())
      | Ok _ ->
          let body =
            "No action taken: event or action is not yet supported.\n\
             If you'd like this event to be supported, please open an issue on \
             the bot-components github page"
          in
          (body, Server.respond_string ~status:`OK ~body ())
      | Error ("Webhook signed but with wrong signature." as e) ->
          Stdio.print_string e;
          let body = Helpers.f "Error: %s" e in
          ( body,
            Server.respond_string ~status:(Code.status_of_code 401) ~body () )
      | Error e ->
          let body = Helpers.f "Error: %s" e in
          ( body,
            Server.respond_string ~status:(Code.status_of_code 400) ~body () )
    in
    Format.printf "%s@." body;
    response
  in
  Server.create
    ~mode:(`TCP (`Port bot_infos.port))
    (Server.make ~callback () ~conn_closed:(fun _ ->
         Format.eprintf "Connection closed@."))

let () =
  (* RNG seeding: https://github.com/mirage/mirage-crypto#faq *)
  Mirage_crypto_rng_lwt.initialize ();
  let bot_infos = Parser_bot_info.get_bot_infos () in
  Format.printf "Starting server.@.";
  Lwt_main.run (server bot_infos)
