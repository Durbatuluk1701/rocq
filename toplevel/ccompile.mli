(************************************************************************)
(*         *      The Rocq Prover / The Rocq Development Team           *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

(** [compile_file opts] compile file specified in [opts] *)
val compile_file : Coqargs.t -> Stm.AsyncOpts.stm_opt -> Coqcargs.t -> Coqargs.injection_command list -> unit

(** [format_file opts stm_options injections ~output ~f_in ~layout] parses and pretty-prints
    [f_in] to [output] using Rocq's vernacular printer, reusing the same
    document setup as compilation. Commands are fully interpreted and
    type-checked ([check:true]) so formatting fails on files that do not
    compile. Use [rocqformat --continue-on-error] to keep formatting past
    failing commands. *)
val format_file :
  Coqargs.t -> Stm.AsyncOpts.stm_opt -> Coqargs.injection_command list ->
  output:Format.formatter -> f_in:string ->
  layout:Vernac.format_layout ->
  unit
