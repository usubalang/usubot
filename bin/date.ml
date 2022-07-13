open Cohttp
open Cohttp_lwt_unix

let month_to_int = function
  | "Jan" -> 0
  | "Feb" -> 1
  | "Mar" -> 2
  | "Apr" -> 3
  | "May" -> 4
  | "Jun" -> 5
  | "Jul" -> 6
  | "Aug" -> 7
  | "Sept" -> 8
  | "Oct" -> 9
  | "Nov" -> 10
  | "Dec" -> 11
  | s ->
      failwith (Format.sprintf "Wrong month format: %s is not a valid month" s)

let parse_github_date date =
  (* Date format: Thu, 07 Apr 2022 15:03:32 GMT *)
  Scanf.sscanf date "%s@, %02d %s %d %d:%d:%d %s"
    (fun _ tm_mday tm_mon tm_year tm_hour tm_min tm_sec _ ->
      Unix.
        {
          tm_sec;
          tm_min;
          tm_hour;
          tm_mday;
          tm_mon = month_to_int tm_mon;
          tm_year = tm_year - 1900;
          tm_wday = 0 (* not used by mktime *);
          tm_yday = 0 (* not used by mktime *);
          tm_isdst = false (* not used by mktime *);
        })

let mk_time utm timezone =
  Unix.putenv "TZ" "UTC";
  let res = Unix.mktime utm in
  Unix.putenv "TZ" timezone;
  res

let date timezone =
  let resp, _body =
    Lwt_main.run (Client.get (Uri.of_string "https://api.github.com/"))
  in
  let ut_local = Unix.time () in
  let code = resp |> Response.status |> Code.code_of_status in
  Format.printf "Response code: %d@." code;
  let date =
    resp |> Response.headers |> fun h -> Header.get h "Date" |> Option.get
  in
  let tm_github = parse_github_date date in
  let ut_github, _ = mk_time tm_github timezone in
  ut_github -. ut_local
