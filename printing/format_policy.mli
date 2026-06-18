(************************************************************************)
(* Layout policy for source formatting (rocqformat and beautify). *)

type if_layout =
  | IfAuto
  | IfInline
  | IfMultiline

type header_style =
  | HeaderPreserve
  | HeaderCompact

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
  header_style : header_style;
  notation_style : notation_style;
  inductive_style : inductive_style;
  module_style : module_style;
  comment_style : comment_style;
}

val default : t

(** Active policy for the current formatting session. *)
val active : t ref

(** [indent_prefix n] returns a document prefix of [n] spaces. *)
val indent_prefix : int -> Pp.t

(** [indent_text n s] indents every line of [s] by [n] spaces. *)
val indent_text : int -> string -> string

(** [is_single_line s] is true when [s] has no internal line breaks. *)
val is_single_line : string -> bool
