(************************************************************************)
(* Unit tests for Rocqformat_layout. *)

open OUnit2
module Layout = Rocqformat_lib__Rocqformat_layout
open Layout

let test_max_indent_of_margin _ =
  assert_equal 51 (max_indent_of_margin 80);
  assert_equal 70 (max_indent_of_margin 100)

let test_normalize_trailing_whitespace _ =
  assert_equal "foo\n" (normalize_output "foo  \t  ");
  assert_equal "foo\n" (normalize_output "foo")

let test_normalize_final_newline _ =
  assert_equal "x\n" (normalize_output "x");
  assert_equal "x\n" (normalize_output "x\n")

let test_normalize_blank_lines _ =
  assert_equal "a\n\nb\n" (normalize_output "a\n\n\n\nb\n\n");
  assert_equal "a\n\nb\n" (normalize_output "a\n\n\nb")

let test_normalize_empty _ =
  assert_equal "" (normalize_output "")

let suite =
  "rocqformat_layout" >:::
    [ "max_indent_of_margin" >:: test_max_indent_of_margin
    ; "normalize_trailing_whitespace" >:: test_normalize_trailing_whitespace
    ; "normalize_final_newline" >:: test_normalize_final_newline
    ; "normalize_blank_lines" >:: test_normalize_blank_lines
    ; "normalize_empty" >:: test_normalize_empty
    ]

let () = run_test_tt_main suite
