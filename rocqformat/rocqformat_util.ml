(************************************************************************)
(* Shared helpers for rocqformat. *)

let read_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in ic)
    (fun () ->
      let len = in_channel_length ic in
      let buf = Bytes.create len in
      really_input ic buf 0 len;
      Bytes.to_string buf)

let dedup_paths paths =
  let seen = Hashtbl.create (List.length paths) in
  List.fold_left (fun acc path ->
      if Hashtbl.mem seen path then acc
      else (
        Hashtbl.add seen path true;
        path :: acc))
    [] paths
  |> List.rev

let with_format_session layout ~finally f =
  let old_policy = !Format_policy.active in
  let old_comments = !Pp.preserve_comment_body in
  Rocqformat_layout.apply_globals layout;
  Rocqformat_layout.apply_format_policy layout;
  Fun.protect
    ~finally:(fun () ->
      Format_policy.active := old_policy;
      Pp.preserve_comment_body := old_comments;
      finally ())
    f
