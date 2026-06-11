(************************************************************************)
(*         *      The Rocq Prover / The Rocq Development Team           *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

type t = {
  in_place : bool;
  check_only : bool;
  output : string option;
  margin : int;
  files : string list;
}

let default = {
  in_place = false;
  check_only = false;
  output = None;
  margin = 80;
  files = [];
}

let usage = Boot.Usage.{
  executable_name = "rocqformat";
  extra_args = "file...";
  extra_options = "\n\
rocqformat specific options:\
\n  -i, --in-place        format files in place\
\n  --check               check that files are already formatted\
\n  -o f, --output=f      write output to file f (single input only)\
\n  --margin=cols         set pretty-printing margin (default 80)\
\n\
\nrocqformat uses Rocq's parser and pretty-printer. Pass standard Rocq\
\noptions (-R, -Q, -boot, -noinit, ...) before the file names.\
\n"
}

let parse_margin s =
  try int_of_string s
  with Failure _ ->
    Printf.eprintf "Invalid margin: %s\n%!" s;
    exit 1

let rec parse acc = function
  | "-i" :: rest | "--in-place" :: rest -> parse { acc with in_place = true } rest
  | "--check" :: rest -> parse { acc with check_only = true } rest
  | "-o" :: file :: rest -> parse { acc with output = Some file } rest
  | "--output" :: file :: rest | "-output" :: file :: rest ->
      parse { acc with output = Some file } rest
  | arg :: rest when String.length arg > 9 && String.sub arg 0 9 = "--margin=" ->
      parse { acc with margin = parse_margin (String.sub arg 9 (String.length arg - 9)) } rest
  | "-help" :: _ | "--help" :: _ ->
      Boot.Usage.print_usage stderr usage;
      exit 0
  | file :: rest when not (String.length file > 0 && file.[0] = '-') ->
      parse { acc with files = acc.files @ [file] } rest
  | rest -> acc, rest

let parse extras = parse default extras

let validate t =
  if t.files = [] then (
    Boot.Usage.print_usage stderr usage;
    exit 1);
  if t.check_only && (t.in_place || t.output <> None) then (
    Printf.eprintf "rocqformat: --check cannot be used with -i or -o\n%!";
    exit 1);
  if t.output <> None && List.length t.files <> 1 then (
    Printf.eprintf "rocqformat: -o requires exactly one input file\n%!";
    exit 1);
  if t.in_place && t.output <> None then (
    Printf.eprintf "rocqformat: -i and -o are incompatible\n%!";
    exit 1)
