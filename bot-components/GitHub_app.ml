open Base
open Cohttp_lwt_unix
open Lwt
open Utils

let github_headers token =
  [
    ("Content-Type", "application/json");
    ("accept", "application/vnd.github.machine-man-preview+json");
    ("authorization", "Bearer " ^ token);
  ]

let rs256_sign ~key ~data =
  (* Taken from https://github.com/mmaker/ocaml-letsencrypt *)
  let data = Cstruct.of_string data in
  let h = Mirage_crypto.Hash.SHA256.digest data in
  let pkcs1_digest = X509.Certificate.encode_pkcs1_digest_info (`SHA256, h) in
  Mirage_crypto_pk.Rsa.PKCS1.sig_encode ~key pkcs1_digest |> Cstruct.to_string

let base64 = Base64.encode ~pad:false ~alphabet:Base64.uri_safe_alphabet

(* The following functions are largely based on https://github.com/Schniz/reason-pr-labels *)
let make_jwt ~bot_infos ~key =
  let header = "{ \"alg\": \"RS256\" }" in
  let issuedAtf = Unix.time () in
  (if bot_infos.Bot_infos.debug then
   let open Unix in
   Caml.Format.eprintf "@[<v 1>--- make jwt ---@,issued at: %a@,exp: %a@."
     Helpers.pp_date (gmtime issuedAtf) Helpers.pp_date
     (gmtime (issuedAtf +. (60. *. 8.))));
  let issuedAt = Int.of_float issuedAtf in
  let payload =
    f "{ \"iat\": %d, \"exp\": %d, \"iss\": %d }" issuedAt
      (issuedAt + (60 * 8))
      bot_infos.Bot_infos.app_id
  in
  match (base64 header, base64 payload) with
  | Ok h, Ok p -> (
      let data = h ^ "." ^ p in
      match rs256_sign ~key ~data |> base64 with
      | Ok signature -> Ok (data ^ "." ^ signature)
      | Error (`Msg e) -> Error (f "Couldn't create JWT token: %s" e))
  | Error (`Msg e), _ | _, Error (`Msg e) ->
      Error (f "Couldn't create JWT token: %s" e)

let get ~bot_infos ~token ~url =
  Stdio.print_endline ("Making get request to " ^ url);
  let headers = headers ~bot_infos (github_headers token) in
  Client.get ~headers (Uri.of_string url) >>= fun (_response, body) ->
  Cohttp_lwt.Body.to_string body

let post ~bot_infos ~body ~token ~url =
  Stdio.print_endline ("Making post request to " ^ url);
  let headers = headers ~bot_infos (github_headers token) in
  let body =
    (match body with None -> "{}" | Some json -> Yojson.to_string json)
    |> Cohttp_lwt.Body.of_string
  in
  Cohttp_lwt_unix.Client.post ~body ~headers (Uri.of_string url)
  >>= fun (_response, body) -> Cohttp_lwt.Body.to_string body

let get_installation_token ~bot_infos ~owner ~repo ~jwt :
    (string * float, string) Result.t Lwt.t =
  get ~bot_infos ~token:jwt
    ~url:(f "https://api.github.com/repos/%s/%s/installation" owner repo)
  >>= (fun body ->
        try
          let json = Yojson.Basic.from_string body in
          let access_token_url =
            Yojson.Basic.Util.(json |> member "access_tokens_url" |> to_string)
          in
          post ~bot_infos ~body:None ~token:jwt ~url:access_token_url
          >|= Result.return
        with
        | Yojson.Json_error err -> Lwt.return_error (f "Json error: %s" err)
        | Yojson.Basic.Util.Type_error (err, _) ->
            Lwt.return_error (f "Json type error: %s" err))
  >|= Result.bind ~f:(fun resp ->
          try
            let json = Yojson.Basic.from_string resp in
            Ok
              (* Installation tokens expire after one hour, let's stop using them after 40 minutes *)
              ( Yojson.Basic.Util.(json |> member "token" |> to_string),
                Unix.time () +. (40. *. 60.) )
          with
          | Yojson.Json_error err -> Error (f "Json error: %s" err)
          | Yojson.Basic.Util.Type_error (err, _) ->
              Error (f "Json type error: %s" err))

let get_installation_token ~bot_infos ~key ~owner ~repo =
  match make_jwt ~bot_infos ~key with
  | Ok jwt -> get_installation_token ~bot_infos ~jwt ~owner ~repo
  | Error e -> Lwt.return (Error e)

let get_installations ~bot_infos ~key =
  match make_jwt ~key ~bot_infos with
  | Ok jwt -> (
      if bot_infos.Bot_infos.debug then
        Caml.Format.eprintf
          "@[<v 1>---Get Installations---@,@[<v 2>Get Installations JWT: %s@."
          jwt;
      get ~bot_infos ~token:jwt ~url:"https://api.github.com/app/installations"
      >|= fun body ->
      try
        let json = Yojson.Basic.from_string body in
        if bot_infos.Bot_infos.debug then
          Caml.Format.eprintf
            "@[<v 1>---Get Installations---@,@[<v 2>Body received:@, %a@."
            Yojson.Basic.pp json;
        let open Yojson.Basic.Util in
        Ok
          (json |> to_list
          |> List.map ~f:(fun json ->
                 json |> member "account" |> member "login" |> to_string))
      with
      | Yojson.Json_error err -> Error (f "Json error: %s" err)
      | Yojson.Basic.Util.Type_error (err, j) ->
          if bot_infos.Bot_infos.debug then
            Caml.Format.eprintf
              "@[<v 1>---Get Installations---@,@[<v 2>Json type error: %s@,%a@."
              err Yojson.Basic.pp j;
          Error (f "Json type error: %s" err))
  | Error e -> Lwt.return (Error e)
