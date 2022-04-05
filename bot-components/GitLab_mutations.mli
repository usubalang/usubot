val retry_job :
  bot_infos:Bot_infos.t -> project_id:int -> build_id:int -> unit Lwt.t

val generic_retry : bot_infos:Bot_infos.t -> url_part:string -> unit Lwt.t
