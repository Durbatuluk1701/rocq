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
  format_project : bool;
}

let default = {
  in_place = false;
  check_only = false;
  output = None;
  layout = Rocqformat_layout.default;
  files = [];
  format_project = false;
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
\n  --module-style=auto|compact|spaced  module/functor binder layout (default auto)\
\n  --comment-style=auto|preserve  multiline doc comment layout (default preserve)\
\n  --project=FILE            read -R/-Q paths from a RocqProject/_CoqProject file\
\n  --project-auto            search for _CoqProject near input files\
\n  --format-project          format all .v files listed in the project file\
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

let parse_enum ~flag values s =
  try List.assoc s values
  with Not_found ->
    let expected = String.concat ", " (List.map fst values) in
    Printf.eprintf "Invalid %s: %s (expected %s)\n%!" flag s expected;
    exit 1

let update_layout acc f = { acc with layout = f acc.layout }

let update_policy acc f =
  update_layout acc (fun layout -> Rocqformat_layout.update_policy layout f)

let arg_value prefix arg =
  let prefix_len = String.length prefix in
  if String.length arg > prefix_len && String.sub arg 0 prefix_len = prefix then
    Some (String.sub arg prefix_len (String.length arg - prefix_len))
  else None

let parse_prefixed_int ~opt prefix arg =
  match arg_value prefix arg with
  | None -> None
  | Some value -> Some (parse_int ~opt value)

type int_option = {
  prefix : string;
  opt : string;
  update : Rocqformat_layout.t -> int -> Rocqformat_layout.t;
}

let int_options = [
  { prefix = "--margin="; opt = "margin";
    update = (fun layout margin ->
        { layout with margin; max_indent = Rocqformat_layout.max_indent_of_margin margin });
  };
  { prefix = "--indent="; opt = "indent";
    update = (fun layout max_indent -> { layout with max_indent });
  };
  { prefix = "--depth="; opt = "depth";
    update = (fun layout max_boxes -> { layout with max_boxes });
  };
  { prefix = "--box-level="; opt = "box-level";
    update = (fun layout box_level -> { layout with box_level });
  };
  { prefix = "--block-indent="; opt = "block-indent";
    update = (fun layout block_indent ->
        Rocqformat_layout.update_policy layout (fun policy ->
            { policy with block_indent }));
  };
  { prefix = "--proof-indent="; opt = "proof-indent";
    update = (fun layout proof_indent ->
        Rocqformat_layout.update_policy layout (fun policy ->
            { policy with proof_indent }));
  };
  { prefix = "--proof-margin="; opt = "proof-margin";
    update = (fun layout proof_margin ->
        { layout with proof_margin = Some proof_margin });
  };
  { prefix = "--signature-break-indent="; opt = "signature-break-indent";
    update = (fun layout n ->
        Rocqformat_layout.update_policy layout (fun policy ->
            { policy with signature_break_indent = n }));
  };
  { prefix = "--body-break-indent="; opt = "body-break-indent";
    update = (fun layout n ->
        Rocqformat_layout.update_policy layout (fun policy ->
            { policy with body_break_indent = n }));
  };
]

let parse_if_style s =
  parse_enum ~flag:"--if-style" [
    "auto", Format_policy.IfAuto;
    "inline", Format_policy.IfInline;
    "multiline", Format_policy.IfMultiline;
  ] s

let parse_header_style s =
  parse_enum ~flag:"--header-style" [
    "preserve", Rocqformat_layout.HeaderPreserve;
    "compact", Rocqformat_layout.HeaderCompact;
  ] s

let parse_notation_style s =
  parse_enum ~flag:"--notation-style" [
    "auto", Format_policy.NotationAuto;
    "inline", Format_policy.NotationInline;
  ] s

let parse_inductive_style s =
  parse_enum ~flag:"--inductive-style" [
    "auto", Format_policy.InductiveAuto;
    "compact", Format_policy.InductiveCompact;
    "verbose", Format_policy.InductiveVerbose;
  ] s

let parse_module_style s =
  parse_enum ~flag:"--module-style" [
    "auto", Format_policy.ModuleAuto;
    "compact", Format_policy.ModuleCompact;
    "spaced", Format_policy.ModuleSpaced;
  ] s

let parse_comment_style s =
  parse_enum ~flag:"--comment-style" [
    "auto", Format_policy.CommentAuto;
    "preserve", Format_policy.CommentPreserve;
  ] s

let expand_project_files acc =
  if not acc.format_project then acc
  else
    match acc.layout.project_file with
    | None ->
      Printf.eprintf
        "rocqformat: --format-project requires --project=FILE or --project-auto\n%!";
      exit 1
    | Some project_file ->
      let project_files = Rocqformat_project.list_project_v_files project_file in
      { acc with files = Rocqformat_util.dedup_paths (acc.files @ project_files) }

let finalize_parsing acc extras =
  let acc =
    match acc.layout.project_file with
    | Some _ -> acc
    | None when acc.layout.project_auto || acc.format_project ->
      (match Rocqformat_project.discover_project_file acc.files with
       | None -> acc
       | Some file ->
         update_layout acc (fun layout -> { layout with project_file = Some file }))
    | None -> acc
  in
  let acc = expand_project_files acc in
  let acc =
    if acc.format_project && not acc.layout.continue_on_error then
      update_layout acc (fun layout -> { layout with continue_on_error = true })
    else acc
  in
  acc, extras

let parse_int_option acc arg =
  List.find_map
    (fun spec ->
       match parse_prefixed_int ~opt:spec.opt spec.prefix arg with
       | None -> None
       | Some value -> Some (spec.update acc value))
    int_options

let try_parse_if_style arg acc =
  match arg_value "--if-style=" arg with
  | None -> None
  | Some value ->
    let if_layout = parse_if_style value in
    Some (update_policy acc (fun policy -> { policy with if_layout }))

let try_parse_header_style arg acc =
  match arg_value "--header-style=" arg with
  | None -> None
  | Some value ->
    let header_style = parse_header_style value in
    Some (update_layout acc (fun layout -> { layout with header_style }))

let try_parse_notation_style arg acc =
  match arg_value "--notation-style=" arg with
  | None -> None
  | Some value ->
    let notation_style = parse_notation_style value in
    Some (update_policy acc (fun policy -> { policy with notation_style }))

let try_parse_inductive_style arg acc =
  match arg_value "--inductive-style=" arg with
  | None -> None
  | Some value ->
    let inductive_style = parse_inductive_style value in
    Some (update_policy acc (fun policy -> { policy with inductive_style }))

let try_parse_module_style arg acc =
  match arg_value "--module-style=" arg with
  | None -> None
  | Some value ->
    let module_style = parse_module_style value in
    Some (update_policy acc (fun policy -> { policy with module_style }))

let try_parse_comment_style arg acc =
  match arg_value "--comment-style=" arg with
  | None -> None
  | Some value ->
    let comment_style = parse_comment_style value in
    Some (update_policy acc (fun policy -> { policy with comment_style }))

let style_parsers = [
  try_parse_if_style;
  try_parse_header_style;
  try_parse_notation_style;
  try_parse_inductive_style;
  try_parse_module_style;
  try_parse_comment_style;
]

let parse_style_arg acc arg =
  List.find_map (fun parse -> parse arg acc) style_parsers

let parse_project_or_file acc arg =
  match arg_value "--project=" arg with
  | Some file ->
    update_layout acc (fun layout -> { layout with project_file = Some file })
  | None ->
    if String.length arg > 0 && arg.[0] = '-' then (
      Printf.eprintf "Unknown option: %s\n%!" arg;
      exit 1)
    else { acc with files = acc.files @ [arg] }

let rec parse acc = function
  | "-help" :: _ | "--help" :: _ ->
      Boot.Usage.print_usage stderr usage;
      exit 0
  | "-i" :: rest | "--in-place" :: rest -> parse { acc with in_place = true } rest
  | "--check" :: rest -> parse { acc with check_only = true } rest
  | "--continue-on-error" :: rest ->
      parse (update_layout acc (fun layout -> { layout with continue_on_error = true })) rest
  | "-o" :: file :: rest -> parse { acc with output = Some file } rest
  | "--output" :: file :: rest | "-output" :: file :: rest ->
      parse { acc with output = Some file } rest
  | "--no-extra-blank-lines" :: rest ->
      parse (update_layout acc (fun layout -> { layout with extra_blank_line = false })) rest
  | "--no-compact" :: rest ->
      parse (update_policy acc (fun policy -> { policy with compact = false })) rest
  | "--project-auto" :: rest ->
      parse (update_layout acc (fun layout -> { layout with project_auto = true })) rest
  | "--format-project" :: rest ->
      parse { acc with format_project = true } rest
  | arg :: rest -> (
    match parse_int_option acc.layout arg with
    | Some layout -> parse { acc with layout } rest
    | None -> (
      match parse_style_arg acc arg with
      | Some acc -> parse acc rest
      | None -> parse (parse_project_or_file acc arg) rest))
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

let apply_project_opts = Rocqformat_project.apply_project_opts
