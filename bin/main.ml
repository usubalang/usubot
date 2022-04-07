open Lwt
open Cohttp
open Cohttp_lwt_unix
open Parser_bot_infos
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
    if bot_infos.bot_infos.Bot_infos.debug then Format.eprintf "%s@." body;
    response
  in
  Server.create
    ~mode:(`TCP (`Port bot_infos.port))
    (Server.make ~callback () ~conn_closed:(fun _ ->
         Format.printf "Callback handled@."))

let pp_hex ppf s =
  String.iter (fun c -> Format.fprintf ppf "%X" (Char.code c)) s

let pp_list ?(pp_sep = Format.pp_print_cut) ?(left = "[") ?(right = "]") pp ppf
    l =
  Format.fprintf ppf "%s%a%s" left Format.(pp_print_list ~pp_sep pp) l right

let pp_string ppf s = Format.fprintf ppf "%s" s

let () =
  (* RNG seeding: https://github.com/mirage/mirage-crypto#faq *)
  Mirage_crypto_rng_lwt.initialize ();
  let bot_infos = Parser_bot_infos.get_bot_infos () in
  Format.printf "Starting server. Diff time: %.0f@."
    bot_infos.bot_infos.diff_dates
(* Lwt_main.run (server bot_infos) *)
