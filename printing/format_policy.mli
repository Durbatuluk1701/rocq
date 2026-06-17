(************************************************************************)
(* Layout policy for source formatting (rocqformat and beautify). *)

type if_layout =
  | IfAuto
  | IfInline
  | IfMultiline

type t = {
  block_indent : int;
  proof_indent : int;
  proof_margin : int;
  compact : bool;
  signature_break_indent : int;
  body_break_indent : int;
  if_layout : if_layout;
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
