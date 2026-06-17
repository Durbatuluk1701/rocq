(************************************************************************)
(* Library API smoke test: Rocqformat_lib.init / format_file / check_file. *)

open OUnit2

let cases_root =
  Filename.concat (Sys.getenv "PWD")
    "test-suite/misc/rocqformat/cases/basic"

let read_file path =
  let ic = open_in_bin path in
  let len = in_channel_length ic in
  let buf = Bytes.create len in
  really_input ic buf 0 len;
  close_in ic;
  Bytes.to_string buf

let test_init_idempotent _ctx =
  Rocqformat_lib.init ();
  Rocqformat_lib.init ()

let test_format_file_matches_golden _ctx =
  let input = Filename.concat cases_root "input.v" in
  let expected = Filename.concat cases_root "expected.v" in
  if not (Sys.file_exists input && Sys.file_exists expected) then
    skip_if true "basic case not found (run from repository root)"
  else
    let golden = read_file expected in
    let formatted = Rocqformat_lib.format_file input in
    assert_equal ~printer:(fun s -> s) golden formatted;
    assert_bool "check_file on formatted golden" (Rocqformat_lib.check_file expected)

let suite =
  "rocqformat_lib_api" >:::
    [ "init_idempotent" >:: test_init_idempotent
    ; "format_file_basic" >:: test_format_file_matches_golden
    ]

let () = run_test_tt_main suite
