open Lwt
open Cohttp
open Cohttp_lwt_unix
open Parser_bot_info
open Bot_components

let server bot_info =
  let callback _conn req body =
    Cohttp_lwt.Body.to_string body >>= fun body ->
    let body, response =
      match
        GitHub_subscriptions.receive_github
          ~secret:bot_info.github_webhook_secret (Request.headers req) body
      with
      | Ok (_, PullRequestUpdated (action, pr_info)) ->
          Handlers.handle_pull_request_updated action pr_info bot_info
      | Ok _ -> ("", Server.respond_string ~status:`OK ~body ())
      | Error e ->
          let status =
            Code.status_of_code
              (if e = "Webhook signed but with wrong signature." then 401
              else 400)
          in
          let body = Helpers.f "Error: %s" e in
          (body, Server.respond_string ~status ~body ())
    in
    if bot_info.bot_info.Bot_info.debug then Format.eprintf "%s@." body;
    response
  in
  Server.create
    ~mode:(`TCP (`Port bot_info.port))
    (Server.make ~callback () ~conn_closed:(fun _ ->
         Format.eprintf "Connection closed@."))

let () =
  (* RNG seeding: https://github.com/mirage/mirage-crypto#faq *)
  Mirage_crypto_rng_lwt.initialize ();
  let bot_info = Parser_bot_info.get_bot_info () in
  Format.printf "Starting server.@.";
  Lwt_main.run (server bot_info)
