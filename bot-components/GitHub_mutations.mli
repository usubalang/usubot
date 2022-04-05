open GitHub_types

val mv_card_to_column :
  bot_infos:Bot_infos.t -> mv_card_to_column_input -> unit Lwt.t

val post_comment :
  bot_infos:Bot_infos.t ->
  id:id ->
  message:string ->
  (string, string) result Lwt.t

val report_on_posting_comment : (string, string) result -> unit Lwt.t

val post_and_report_comment :
  bot_infos:Bot_infos.t -> id:id -> message:string -> unit Lwt.t

val close_pull_request : bot_infos:Bot_infos.t -> pr_id:id -> unit Lwt.t
(** Given the infos and  *)

val merge_pull_request :
  bot_infos:Bot_infos.t ->
  ?merge_method:merge_method ->
  ?commit_headline:string ->
  ?commit_body:string ->
  pr_id:id ->
  unit ->
  unit Lwt.t

val create_check_run :
  bot_infos:Bot_infos.t ->
  ?conclusion:check_conclusion ->
  name:string ->
  repo_id:id ->
  head_sha:string ->
  status:check_run_status ->
  details_url:string ->
  title:string ->
  ?text:string ->
  summary:string ->
  ?external_id:string ->
  unit ->
  unit Lwt.t

val update_check_run :
  bot_infos:Bot_infos.t ->
  check_run_id:id ->
  repo_id:id ->
  conclusion:check_conclusion ->
  ?details_url:string ->
  title:string ->
  ?text:string ->
  summary:string ->
  unit ->
  unit Lwt.t

val reflect_pull_request_milestone :
  bot_infos:Bot_infos.t -> issue_closer_info -> unit Lwt.t

val add_labels :
  bot_infos:Bot_infos.t -> labels:id list -> pr_id:id -> unit Lwt.t

val remove_labels :
  bot_infos:Bot_infos.t -> labels:id list -> pr_id:id -> unit Lwt.t

val update_milestone : bot_infos:Bot_infos.t -> string -> issue -> unit Lwt.t
val remove_milestone : bot_infos:Bot_infos.t -> issue -> unit Lwt.t

val send_status_check :
  bot_infos:Bot_infos.t ->
  repo_full_name:string ->
  commit:string ->
  state:status_state ->
  url:string ->
  context:string ->
  description:string ->
  unit Lwt.t

val add_pr_to_column :
  bot_infos:Bot_infos.t -> pr_id:int -> column_id:int -> unit Lwt.t
