(************************************************************************)
(*         *      The Rocq Prover / The Rocq Development Team           *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

(** Layout configuration for [rocqformat]: formatter parameters, print policy,
    and file-level output normalization. *)

type header_style =
  | HeaderPreserve
  | HeaderCompact

type t = {
  margin : int;
  max_indent : int;
  max_boxes : int;
  box_level : int;
  extra_blank_line : bool;
  continue_on_error : bool;
  proof_margin : int option;
  policy : Format_policy.t;
  header_style : header_style;
  project_file : string option;
  project_auto : bool;
}

let rocqformat_policy =
  { Format_policy.default with
    Format_policy.notation_style = Format_policy.NotationInline;
    comment_style = Format_policy.CommentPreserve;
  }

let default = {
  margin = 80;
  max_indent = 50;
  max_boxes = 10000;
  box_level = 0;
  extra_blank_line = true;
  continue_on_error = false;
  proof_margin = None;
  policy = rocqformat_policy;
  header_style = HeaderPreserve;
  project_file = None;
  project_auto = false;
}

let max_indent_of_margin margin =
  max (64 * margin / 100) (margin - 30)

let proof_margin layout =
  Option.default layout.margin layout.proof_margin

let update_policy layout f =
  { layout with policy = f layout.policy }

let apply_globals layout =
  Topfmt.set_margin (Some layout.margin);
  Topfmt.set_depth_boxes (Some layout.max_boxes);
  Constrextern.set_max_depth (Some layout.max_boxes)

let configure_formatter layout fmt =
  Format.pp_set_margin fmt layout.margin;
  Format.pp_set_max_indent fmt layout.max_indent;
  Format.pp_set_max_boxes fmt layout.max_boxes;
  Format.pp_set_ellipsis_text fmt "..."

let apply_format_policy layout =
  let policy = { layout.policy with proof_margin = proof_margin layout } in
  Format_policy.active := policy;
  Pp.preserve_comment_body := Format_policy.preserve_comments ()

let to_vernac_layout layout : Vernac.format_layout =
  let policy = layout.policy in
  { box_level = layout.box_level;
    extra_blank_line = layout.extra_blank_line;
    continue_on_error = layout.continue_on_error;
    block_indent = policy.block_indent;
    proof_indent = policy.proof_indent;
    proof_margin = proof_margin layout;
    compact = policy.compact;
  }

(** Post-process formatted output to restore blank lines between glued comment
    blocks. The vernacular driver does not yet track this spacing explicitly. *)
let replace_all ~from ~to_ s =
  let len_from = String.length from in
  let buf = Buffer.create (String.length s + 16) in
  let rec loop i =
    if i > String.length s - len_from then
      Buffer.add_substring buf s i (String.length s - i)
    else if String.equal (String.sub s i len_from) from then (
      Buffer.add_string buf to_;
      loop (i + len_from))
    else (
      Buffer.add_char buf s.[i];
      loop (i + 1))
  in
  loop 0;
  Buffer.contents buf

let preserve_header_spacing replacements s =
  List.fold_left (fun s (from, to_) -> replace_all ~from ~to_ s) s replacements

let header_spacing_replacements = [
  (")\n(** ", ")\n\n(** ");
  ("*)(** ", "*)\n\n(** ");
  (")\n(* File", ")\n\n(* File");
]

(** Normalize formatted text: trim trailing whitespace, ensure a single final
    newline, and collapse runs of more than two blank lines. *)
let normalize_output ?(layout=default) s =
  let s =
    match layout.header_style with
    | HeaderPreserve -> preserve_header_spacing header_spacing_replacements s
    | HeaderCompact -> s
  in
  let len = String.length s in
  let rec trim_end i =
    if i <= 0 then 0
    else match s.[i - 1] with
    | ' ' | '\t' | '\r' | '\n' -> trim_end (i - 1)
    | _ -> i
  in
  let end_pos = trim_end len in
  let s = if end_pos = len then s else String.sub s 0 end_pos in
  let buf = Buffer.create (String.length s + 1) in
  let len = String.length s in
  let rec loop i blank_run =
    if i >= len then ()
    else if s.[i] = '\n' then begin
      let blank_run = blank_run + 1 in
      if blank_run <= 2 then Buffer.add_char buf '\n';
      loop (i + 1) blank_run
    end else begin
      Buffer.add_char buf s.[i];
      loop (i + 1) 0
    end
  in
  loop 0 0;
  let content = Buffer.contents buf in
  if content = "" then content
  else if content.[String.length content - 1] <> '\n'
  then content ^ "\n"
  else content
