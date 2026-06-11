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

let read_file path =
  let ic = open_in_bin path in
  let len = in_channel_length ic in
  let buf = Bytes.create len in
  really_input ic buf 0 len;
  close_in ic;
  Bytes.to_string buf

let make_formatter ?(margin=80) chan =
  let out s b e = output_substring chan s b e in
  let fmt = Format.make_formatter out (fun () -> flush chan) in
  Format.pp_set_margin fmt margin;
  Format.pp_set_max_boxes fmt max_int;
  fmt

let formatter_to_string ?(margin=80) f =
  let buf = Buffer.create 1024 in
  let out s b e = Buffer.add_substring buf s b e in
  let fmt = Format.make_formatter out (fun () -> ()) in
  Format.pp_set_margin fmt margin;
  Format.pp_set_max_boxes fmt max_int;
  f fmt;
  Format.pp_print_flush fmt ();
  Buffer.contents buf

let format_to_string ~margin opts stm_opts injections file =
  formatter_to_string ~margin (fun fmt ->
      Ccompile.format_file opts stm_opts injections ~output:fmt ~f_in:file)

let format_to_channel ~margin opts stm_opts injections file ch =
  let fmt = make_formatter ~margin ch in
  Ccompile.format_file opts stm_opts injections ~output:fmt ~f_in:file;
  Format.pp_print_flush fmt ()

let format_to_file ~margin opts stm_opts injections file output =
  let oc = open_out_bin output in
  Util.try_finally (fun () ->
      format_to_channel ~margin opts stm_opts injections file oc)
    () (fun () -> close_out oc) ()

let process_file (fmt : Rocqformat_args.t) opts stm_opts injections file =
  if fmt.check_only then begin
    let original = read_file file in
    let formatted = format_to_string ~margin:fmt.margin opts stm_opts injections file in
    if not (String.equal original formatted) then (
      Printf.eprintf "rocqformat: %s needs formatting\n%!" file;
      exit 1)
  end else if fmt.in_place then begin
    let tmp = Filename.temp_file (Filename.basename file) ".rocqformat" in
    format_to_file ~margin:fmt.margin opts stm_opts injections file tmp;
    Sys.rename tmp file
  end else
    match fmt.output with
    | Some out -> format_to_file ~margin:fmt.margin opts stm_opts injections file out
    | None -> format_to_channel ~margin:fmt.margin opts stm_opts injections file stdout

let rocqformat_init (fmt, _stm_opts) _injections ~opts =
  Flags.quiet := true;
  System.trust_file_cache := true;
  Colors.init_color `ON;
  ignore (fmt, opts);
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

let run args = Coqtop.start_coq custom_rocqformat args
