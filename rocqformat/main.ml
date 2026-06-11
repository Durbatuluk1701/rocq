(************************************************************************)
(*         *      The Rocq Prover / The Rocq Development Team           *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

let () =
  let args = List.tl (Array.to_list Sys.argv) in
  if List.mem "--rocqformat-version" args then
    Printf.printf "rocqformat (Rocq %s)\n%!" Coq_config.version
  else
    Rocqformat_lib.run args
