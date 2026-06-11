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
  layout : Rocqformat_layout.t;
  files : string list;
}

let default = {
  in_place = false;
  check_only = false;
  output = None;
  layout = Rocqformat_layout.default;
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
\n  --indent=cols         set maximum indentation (default: derived from margin)\
\n  --depth=boxes         set maximum box depth for pretty-printing (default 10000)\
\n  --box-level=n         set box level for top-level commands (default 0)\
\n  --no-extra-blank-lines  do not insert an extra blank line between commands\
\n\
\nrocqformat uses Rocq's parser and pretty-printer. Pass standard Rocq\
\noptions (-R, -Q, -boot, -noinit, ...) before the file names.\
\n"
}

let parse_int ~opt s =
  try int_of_string s
  with Failure _ ->
    Printf.eprintf "Invalid %s: %s\n%!" opt s;
    exit 1

let parse_prefixed_int ~opt arg prefix =
  if String.length arg > String.length prefix
     && String.sub arg 0 (String.length prefix) = prefix
  then Some (parse_int ~opt (String.sub arg (String.length prefix)
                                (String.length arg - String.length prefix)))
  else None

let update_layout acc f = { acc with layout = f acc.layout }

let rec parse acc = function
  | "-help" :: _ | "--help" :: _ ->
      Boot.Usage.print_usage stderr usage;
      exit 0
  | "-i" :: rest | "--in-place" :: rest -> parse { acc with in_place = true } rest
  | "--check" :: rest -> parse { acc with check_only = true } rest
  | "-o" :: file :: rest -> parse { acc with output = Some file } rest
  | "--output" :: file :: rest | "-output" :: file :: rest ->
      parse { acc with output = Some file } rest
  | "--no-extra-blank-lines" :: rest ->
      parse (update_layout acc (fun l -> { l with extra_blank_line = false })) rest
  | arg :: rest ->
      begin match
        parse_prefixed_int ~opt:"margin" arg "--margin=",
        parse_prefixed_int ~opt:"indent" arg "--indent=",
        parse_prefixed_int ~opt:"depth" arg "--depth=",
        parse_prefixed_int ~opt:"box-level" arg "--box-level="
      with
      | Some margin, _, _, _ ->
          parse (update_layout acc (fun l ->
              { l with margin; max_indent = Rocqformat_layout.max_indent_of_margin margin }))
            rest
      | _, Some max_indent, _, _ ->
          parse (update_layout acc (fun l -> { l with max_indent })) rest
      | _, _, Some max_boxes, _ ->
          parse (update_layout acc (fun l -> { l with max_boxes })) rest
      | _, _, _, Some box_level ->
          parse (update_layout acc (fun l -> { l with box_level })) rest
      | _ ->
          if String.length arg > 0 && arg.[0] = '-' then (
            Printf.eprintf "Unknown option: %s\n%!" arg;
            exit 1)
          else parse { acc with files = acc.files @ [arg] } rest
      end
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
