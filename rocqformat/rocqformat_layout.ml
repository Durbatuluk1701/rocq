(************************************************************************)
(*         *      The Rocq Prover / The Rocq Development Team           *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

(** Layout policy for [rocqformat], mapping user-facing options to Rocq's
    pretty-printing parameters. *)

type t = {
  margin : int;
  max_indent : int;
  max_boxes : int;
  box_level : int;
  extra_blank_line : bool;
  continue_on_error : bool;
}

let default = {
  margin = 80;
  max_indent = 50;
  max_boxes = 10000;
  box_level = 0;
  extra_blank_line = true;
  continue_on_error = false;
}

let max_indent_of_margin margin =
  max (64 * margin / 100) (margin - 30)

let apply_globals layout =
  Topfmt.set_margin (Some layout.margin);
  Topfmt.set_depth_boxes (Some layout.max_boxes);
  Constrextern.set_max_depth (Some layout.max_boxes)

let configure_formatter layout fmt =
  Format.pp_set_margin fmt layout.margin;
  Format.pp_set_max_indent fmt layout.max_indent;
  Format.pp_set_max_boxes fmt layout.max_boxes;
  Format.pp_set_ellipsis_text fmt "..."

let to_vernac_layout layout : Vernac.format_layout =
  { box_level = layout.box_level
  ; extra_blank_line = layout.extra_blank_line
  ; continue_on_error = layout.continue_on_error
  }

(** Normalize formatted text: trim trailing whitespace, ensure a single
    final newline, and collapse runs of more than two blank lines. *)
let normalize_output s =
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
  if content = "" || content.[String.length content - 1] <> '\n'
  then content ^ "\n"
  else content
