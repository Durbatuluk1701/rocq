(************************************************************************)
(*         *      The Rocq Prover / The Rocq Development Team           *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

(** Library API for formatting Rocq source files.

    Call {!init} once per process (or rely on {!format_file} which initializes
    lazily), then use {!format_file} / {!check_file} for editor or LSP
    integrations. The {!run} entry point is the CLI driver. *)

module Layout = Rocqformat_layout

val default_layout : Layout.t

(** Initialize Rocq's runtime for formatting. Idempotent. *)
val init : unit -> unit

(** [format_file ?layout file] reads [file], formats it with Rocq's parser and
    vernacular printer, and returns the formatted contents. *)
val format_file :
  ?layout:Layout.t -> ?continue_on_error:bool -> string -> string

(** [check_file ?layout file] is [true] when [file] is already formatted. *)
val check_file :
  ?layout:Layout.t -> ?continue_on_error:bool -> string -> bool

(** [run args] parses [args], initializes Rocq like [rocq compile], and formats
    the given [.v] files using Rocq's parser and vernacular printer. *)
val run : string list -> unit
