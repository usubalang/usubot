val get_installation_token :
  bot_infos:Bot_infos.t ->
  key:Mirage_crypto_pk.Rsa.priv ->
  owner:string ->
  repo:string ->
  (string * float, string) result Lwt.t

val get_installations :
  bot_infos:Bot_infos.t ->
  key:Mirage_crypto_pk.Rsa.priv ->
  (string list, string) result Lwt.t
