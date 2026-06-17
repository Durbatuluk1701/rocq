(************************************************************************)
(*         *      The Rocq Prover / The Rocq Development Team           *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

type format_config = Rocqformat_args.t

module Layout = Rocqformat_layout

let default_layout = Layout.default

let boot_coqargs =
  { Coqargs.default with
    pre = { Coqargs.default.pre with boot = true; load_init = false } }

let read_file path =
  let ic = open_in_bin path in
  let len = in_channel_length ic in
  let buf = Bytes.create len in
  really_input ic buf 0 len;
  close_in ic;
  Bytes.to_string buf

let formatter_to_string layout f =
  let buf = Buffer.create 1024 in
  let out s b e = Buffer.add_substring buf s b e in
  let fmt = Format.make_formatter out (fun () -> ()) in
  Rocqformat_layout.configure_formatter layout fmt;
  f fmt;
  Format.pp_print_flush fmt ();
  Rocqformat_layout.normalize_output (Buffer.contents buf)

let format_to_string layout opts stm_opts injections file =
  let vernac_layout = Rocqformat_layout.to_vernac_layout layout in
  formatter_to_string layout (fun fmt ->
      Ccompile.format_file opts stm_opts injections ~layout:vernac_layout
        ~output:fmt ~f_in:file)

let format_to_file layout opts stm_opts injections file output =
  let content = format_to_string layout opts stm_opts injections file in
  let oc = open_out_bin output in
  output_string oc content;
  close_out oc

let process_file (fmt : Rocqformat_args.t) opts stm_opts injections file =
  let layout = fmt.layout in
  if fmt.check_only then begin
    let original = read_file file in
    let formatted = format_to_string layout opts stm_opts injections file in
    if not (String.equal original formatted) then (
      Printf.eprintf "rocqformat: %s needs formatting\n%!" file;
      exit 1)
  end else if fmt.in_place then begin
    format_to_file layout opts stm_opts injections file file
  end else
    match fmt.output with
    | Some out -> format_to_file layout opts stm_opts injections file out
    | None ->
        let content = format_to_string layout opts stm_opts injections file in
        output_string stdout content;
        flush stdout

let rocqformat_init ((fmt_args : format_config), _stm_opts) _injections ~opts =
  Flags.quiet := true;
  System.trust_file_cache := true;
  Colors.init_color `ON;
  Rocqformat_layout.apply_globals fmt_args.layout;
  ignore opts;
  _injections

let rocqformat_run ((fmt : format_config), stm_opts) ~opts injections =
  ignore (CoqworkmgrApi.get 1);
  Topfmt.(in_phase ~phase:CompilationPhase) (fun () ->
      List.iter (process_file fmt opts stm_opts injections) fmt.files)
    ();
  CoqworkmgrApi.giveback 1

let custom_rocqformat :
  ((format_config * Stm.AsyncOpts.stm_opt), Coqargs.injection_command list) Coqtop.custom_toplevel
  =
  Coqtop.{
    parse_extra = (fun opts extras ->
        let fmt_args, extras = Rocqformat_args.parse extras in
        Rocqformat_args.validate fmt_args;
        let stm_opts, extras = Stmargs.parse_args opts extras in
        (fmt_args, stm_opts), extras);
    usage = Rocqformat_args.usage;
    init_extra = rocqformat_init;
    run = rocqformat_run;
    initial_args = Coqargs.default;
  }

let initialized = ref false

let stm_opts = Stm.AsyncOpts.default_opts ~spawn_args:[]

let init () =
  if not !initialized then begin
    Coqinit.init_ocaml ();
    Stm.init_process stm_opts;
    Coqinit.init_runtime ~usage:Rocqformat_args.usage boot_coqargs;
    Coqinit.init_document boot_coqargs;
    Stm.init_core ();
    Flags.quiet := true;
    System.trust_file_cache := true;
    Colors.init_color `ON;
    initialized := true
  end

let format_file ?(layout=Rocqformat_layout.default) ?(continue_on_error=false) file =
  let layout = { layout with continue_on_error } in
  init ();
  Rocqformat_layout.apply_globals layout;
  format_to_string layout boot_coqargs stm_opts [] file

let check_file ?(layout=Rocqformat_layout.default) ?(continue_on_error=false) file =
  let layout = { layout with continue_on_error } in
  init ();
  Rocqformat_layout.apply_globals layout;
  let original = read_file file in
  let formatted = format_file ~layout ~continue_on_error file in
  String.equal original formatted

let run args = Coqtop.start_coq custom_rocqformat args
