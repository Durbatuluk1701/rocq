(************************************************************************)
(*         *      The Rocq Prover / The Rocq Development Team           *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

type time_output

val make_time_output : Coqargs.time_config -> time_output

(** Parsing of vernacular. *)
module State : sig

  type t = {
    doc : Stm.doc;
    sid : Stateid.t;
    proof : Proof.t option;
    time : time_output option;
  }

end

(** [process_expr sid cmd] Executes vernac command [cmd]. Callers are
    expected to handle and print errors in form of exceptions, however
    care is taken so the state machine is left in a consistent
    state. *)
val process_expr : state:State.t -> Vernacexpr.vernac_control -> State.t

(** Layout parameters for source formatting. *)
type format_layout = {
  box_level : int;
  extra_blank_line : bool;
  (** When [true], interpretation errors on a command do not abort formatting
      of subsequent commands. Already pretty-printed commands are preserved. *)
  continue_on_error : bool;
  block_indent : int;
  proof_indent : int;
  proof_margin : int;
  compact : bool;
}

val default_format_layout : format_layout

(** [format_ast ?layout ?indent ?trailing_newlines fmt ast comments] Pretty-prints
    a parsed vernacular command to [fmt], preserving comments from the parser. *)
val format_ast :
  ?layout:format_layout -> ?indent:int -> ?trailing_newlines:int ->
  Format.formatter -> Vernacexpr.vernac_control ->
  ((int * int) * string) list -> unit

(** [format_file ?layout ~output ~check ~state file] Parses [file] using Rocq's
    parser, optionally interprets commands to keep grammar state in sync,
    and pretty-prints each command to [output]. When [check] is [false],
    type-checking is skipped (as with [rocq compile -vos]). *)
val format_file :
  ?layout:format_layout ->
  output:Format.formatter -> check:bool -> state:State.t ->
  ?source:Loc.source -> string -> State.t

(** [load_vernac sid file] Loads [file] on top of [sid].
    Callers are expected to handle and print errors in form of exceptions. *)
val load_vernac : ?beautify:bool -> check:bool ->
  state:State.t -> ?source:Loc.source -> string -> State.t
