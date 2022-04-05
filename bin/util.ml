let extract_url line =
  (* Don't use "{|" since \t will not be escaped and interpreted as \ and t *)
  let re = Str.regexp "[^ \t]+[ \t]+\\([^ \t]*\\)[ \t]+.*" in
  Str.replace_first re {|\1|} line

module SSet = Set.Make (String)

let extract_urls ci =
  let rec aux_parse acc =
    match input_line ci with
    | s -> aux_parse (SSet.add (extract_url s) acc)
    | exception End_of_file ->
        close_in ci;
        acc
  in
  aux_parse SSet.empty

let extract_remotes ci =
  let rec aux_parse acc =
    match input_line ci with
    | s -> aux_parse (SSet.add s acc)
    | exception End_of_file ->
        close_in ci;
        acc
  in
  aux_parse SSet.empty

let extract_user url =
  let re = Str.regexp {|https://github.com/\([^/]*\)/usuba|} in
  Str.replace_first re {|\1|} url
