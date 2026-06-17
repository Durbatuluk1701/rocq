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
\n  --continue-on-error     keep formatting after command interpretation errors\
\n  --block-indent=n      indent Section/Module bodies by n spaces (default 2)\
\n  --proof-indent=n      indent proof scripts by n spaces per level (default 2)\
\n  --proof-margin=n      wrap proof scripts at n columns (default: margin)\
\n  --no-compact          keep blank lines between one-line commands\
\n  --signature-break-indent=n  indent for wrapped type signatures (default 4)\
\n  --body-break-indent=n       indent for definition bodies (default 2)\
\n  --if-style=auto|inline|multiline  if/then/else layout (default auto)\
\n  --header-style=preserve|compact  blank lines after copyright blocks (default preserve)\
\n  --notation-style=inline|auto  Reserved/Notation modifier layout (default inline)\
\n  --inductive-style=auto|compact|verbose  inductive constructor layout (default auto)\
\n  --project=FILE            read -R/-Q paths from a RocqProject/_CoqProject file\
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

let parse_if_style = function
  | "auto" -> Rocqformat_layout.IfAuto
  | "inline" -> Rocqformat_layout.IfInline
  | "multiline" -> Rocqformat_layout.IfMultiline
  | s ->
    Printf.eprintf "Invalid --if-style: %s (expected auto, inline, or multiline)\n%!" s;
    exit 1

let parse_header_style = function
  | "preserve" -> Rocqformat_layout.HeaderPreserve
  | "compact" -> Rocqformat_layout.HeaderCompact
  | s ->
    Printf.eprintf "Invalid --header-style: %s (expected preserve or compact)\n%!" s;
    exit 1

let parse_notation_style = function
  | "auto" -> Rocqformat_layout.NotationAuto
  | "inline" -> Rocqformat_layout.NotationInline
  | s ->
    Printf.eprintf "Invalid --notation-style: %s (expected auto or inline)\n%!" s;
    exit 1

let parse_inductive_style = function
  | "auto" -> Rocqformat_layout.InductiveAuto
  | "compact" -> Rocqformat_layout.InductiveCompact
  | "verbose" -> Rocqformat_layout.InductiveVerbose
  | s ->
    Printf.eprintf "Invalid --inductive-style: %s (expected auto, compact, or verbose)\n%!" s;
    exit 1

let expand_project_args extras project_file =
  let warning_fn msg = Printf.eprintf "Warning: %s\n%!" msg in
  try
    let project = CoqProject_file.read_project_file ~warning_fn project_file in
    CoqProject_file.coqtop_args_from_project project @ extras
  with
  | CoqProject_file.Parsing_error msg ->
    Printf.eprintf "rocqformat: invalid project file %s: %s\n%!" project_file msg;
    exit 1
  | CoqProject_file.UnableToOpenProjectFile msg ->
    Printf.eprintf "rocqformat: cannot open project file %s: %s\n%!" project_file msg;
    exit 1

let finalize_parsing acc extras =
  let extras =
    match acc.layout.project_file with
    | None -> extras
    | Some file -> expand_project_args extras file
  in
  acc, extras

let rec parse acc = function
  | "-help" :: _ | "--help" :: _ ->
      Boot.Usage.print_usage stderr usage;
      exit 0
  | "-i" :: rest | "--in-place" :: rest -> parse { acc with in_place = true } rest
  | "--check" :: rest -> parse { acc with check_only = true } rest
  | "--continue-on-error" :: rest ->
      parse (update_layout acc (fun l -> { l with continue_on_error = true })) rest
  | "-o" :: file :: rest -> parse { acc with output = Some file } rest
  | "--output" :: file :: rest | "-output" :: file :: rest ->
      parse { acc with output = Some file } rest
  | "--no-extra-blank-lines" :: rest ->
      parse (update_layout acc (fun l -> { l with extra_blank_line = false })) rest
  | "--no-compact" :: rest ->
      parse (update_layout acc (fun l -> { l with compact = false })) rest
  | arg :: rest when String.length arg > 11 && String.sub arg 0 11 = "--if-style=" ->
      let style = parse_if_style (String.sub arg 11 (String.length arg - 11)) in
      parse (update_layout acc (fun l -> { l with if_layout = style })) rest
  | arg :: rest when String.length arg > 15 && String.sub arg 0 15 = "--header-style=" ->
      let style = parse_header_style (String.sub arg 15 (String.length arg - 15)) in
      parse (update_layout acc (fun l -> { l with header_style = style })) rest
  | arg :: rest when String.length arg > 17 && String.sub arg 0 17 = "--notation-style=" ->
      let style = parse_notation_style (String.sub arg 17 (String.length arg - 17)) in
      parse (update_layout acc (fun l -> { l with notation_style = style })) rest
  | arg :: rest when String.length arg > 18 && String.sub arg 0 18 = "--inductive-style=" ->
      let style = parse_inductive_style (String.sub arg 18 (String.length arg - 18)) in
      parse (update_layout acc (fun l -> { l with inductive_style = style })) rest
  | arg :: rest when String.length arg > 10 && String.sub arg 0 10 = "--project=" ->
      let file = String.sub arg 10 (String.length arg - 10) in
      parse (update_layout acc (fun l -> { l with project_file = Some file })) rest
  | arg :: rest ->
      begin match
        parse_prefixed_int ~opt:"margin" arg "--margin=",
        parse_prefixed_int ~opt:"indent" arg "--indent=",
        parse_prefixed_int ~opt:"depth" arg "--depth=",
        parse_prefixed_int ~opt:"box-level" arg "--box-level=",
        parse_prefixed_int ~opt:"block-indent" arg "--block-indent=",
        parse_prefixed_int ~opt:"proof-indent" arg "--proof-indent=",
        parse_prefixed_int ~opt:"proof-margin" arg "--proof-margin=",
        parse_prefixed_int ~opt:"signature-break-indent" arg "--signature-break-indent=",
        parse_prefixed_int ~opt:"body-break-indent" arg "--body-break-indent="
      with
      | Some margin, _, _, _, _, _, _, _, _ ->
          parse (update_layout acc (fun l ->
              { l with margin; max_indent = Rocqformat_layout.max_indent_of_margin margin }))
            rest
      | _, Some max_indent, _, _, _, _, _, _, _ ->
          parse (update_layout acc (fun l -> { l with max_indent })) rest
      | _, _, Some max_boxes, _, _, _, _, _, _ ->
          parse (update_layout acc (fun l -> { l with max_boxes })) rest
      | _, _, _, Some box_level, _, _, _, _, _ ->
          parse (update_layout acc (fun l -> { l with box_level })) rest
      | _, _, _, _, Some block_indent, _, _, _, _ ->
          parse (update_layout acc (fun l -> { l with block_indent })) rest
      | _, _, _, _, _, Some proof_indent, _, _, _ ->
          parse (update_layout acc (fun l -> { l with proof_indent })) rest
      | _, _, _, _, _, _, Some proof_margin, _, _ ->
          parse (update_layout acc (fun l -> { l with proof_margin = Some proof_margin })) rest
      | _, _, _, _, _, _, _, Some signature_break_indent, _ ->
          parse (update_layout acc (fun l -> { l with signature_break_indent })) rest
      | _, _, _, _, _, _, _, _, Some body_break_indent ->
          parse (update_layout acc (fun l -> { l with body_break_indent })) rest
      | _ ->
          if String.length arg > 0 && arg.[0] = '-' then (
            Printf.eprintf "Unknown option: %s\n%!" arg;
            exit 1)
          else parse { acc with files = acc.files @ [arg] } rest
      end
  | rest -> finalize_parsing acc rest

let parse extras =
  let acc, rest = parse default extras in
  acc, rest

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
