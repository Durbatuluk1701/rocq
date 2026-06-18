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

let test_preserve_header_spacing _ =
  let input =
    "(************************************************************************)\n\
(* Copyright test *)\n\
(************************************************************************)\n\
(** File comment *)\n"
  in
  let expected =
    "(************************************************************************)\n\
(* Copyright test *)\n\
(************************************************************************)\n\
\n\
(** File comment *)\n"
  in
  assert_equal expected (normalize_output ~layout:default input);
  let glue_input = "(* block1 *)(** block2 *)\n" in
  let glue_expected = "(* block1 *)\n\n(** block2 *)\n" in
  assert_equal glue_expected (normalize_output ~layout:default glue_input)

let test_default_layout _ =
  let policy = default.policy in
  assert_equal 2 policy.block_indent;
  assert_equal 2 policy.proof_indent;
  assert_equal true policy.compact;
  assert_equal 4 policy.signature_break_indent;
  assert_equal 2 policy.body_break_indent;
  assert_equal Format_policy.IfAuto policy.if_layout;
  assert_equal HeaderPreserve default.header_style;
  assert_equal Format_policy.NotationInline policy.notation_style;
  assert_equal Format_policy.InductiveAuto policy.inductive_style;
  assert_equal Format_policy.ModuleAuto policy.module_style;
  assert_equal Format_policy.CommentPreserve policy.comment_style;
  assert_equal false default.project_auto;
  assert_equal 80 (proof_margin default)

let test_proof_margin_override _ =
  let layout = { default with proof_margin = Some 60; margin = 80 } in
  assert_equal 60 (proof_margin layout)

let suite =
  "rocqformat_layout" >:::
    [ "max_indent_of_margin" >:: test_max_indent_of_margin
    ; "normalize_trailing_whitespace" >:: test_normalize_trailing_whitespace
    ; "normalize_final_newline" >:: test_normalize_final_newline
    ; "normalize_blank_lines" >:: test_normalize_blank_lines
    ; "normalize_empty" >:: test_normalize_empty
    ; "preserve_header_spacing" >:: test_preserve_header_spacing
    ; "default_layout" >:: test_default_layout
    ; "proof_margin_override" >:: test_proof_margin_override
    ]

let () = run_test_tt_main suite
