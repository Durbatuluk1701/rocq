(************************************************************************)
(* Layout policy for source formatting (rocqformat and beautify). *)

open Pp

type if_layout =
  | IfAuto
  | IfInline
  | IfMultiline

type notation_style =
  | NotationAuto
  | NotationInline

type inductive_style =
  | InductiveAuto
  | InductiveCompact
  | InductiveVerbose

type module_style =
  | ModuleAuto
  | ModuleCompact
  | ModuleSpaced

type comment_style =
  | CommentAuto
  | CommentPreserve

type t = {
  block_indent : int;
  proof_indent : int;
  proof_margin : int;
  compact : bool;
  signature_break_indent : int;
  body_break_indent : int;
  if_layout : if_layout;
  notation_style : notation_style;
  inductive_style : inductive_style;
  module_style : module_style;
  comment_style : comment_style;
}

let default = {
  block_indent = 2;
  proof_indent = 2;
  proof_margin = 80;
  compact = true;
  signature_break_indent = 4;
  body_break_indent = 2;
  if_layout = IfAuto;
  notation_style = NotationAuto;
  inductive_style = InductiveAuto;
  module_style = ModuleAuto;
  comment_style = CommentAuto;
}

let active = ref default

let preserve_comments () =
  match !active.comment_style with
  | CommentPreserve -> true
  | CommentAuto -> false

let notation_inline () =
  match !active.notation_style with
  | NotationInline -> true
  | NotationAuto -> false

let module_style () = !active.module_style

let inductive_style () = !active.inductive_style

let indent_prefix n =
  if n <= 0 then mt () else str (String.make n ' ')

let indent_text n s =
  if n <= 0 then s
  else
    let pad = String.make n ' ' in
    let len = String.length s in
    let buf = Buffer.create (len + n * 10) in
    let rec loop i at_line_start =
      if i >= len then Buffer.contents buf
      else
        let c = s.[i] in
        if at_line_start then Buffer.add_string buf pad;
        Buffer.add_char buf c;
        loop (i + 1) (c = '\n')
    in
    loop 0 true

let is_single_line s =
  let len = String.length s in
  let rec end_without_trailing i =
    if i <= 0 then 0
    else match s.[i - 1] with
    | '\n' | '\r' -> end_without_trailing (i - 1)
    | _ -> i
  in
  let end_pos = end_without_trailing len in
  let rec loop i =
    if i >= end_pos then true
    else if s.[i] = '\n' || s.[i] = '\r' then false
    else loop (i + 1)
  in
  loop 0
