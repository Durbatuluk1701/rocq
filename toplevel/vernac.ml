(************************************************************************)
(*         *      The Rocq Prover / The Rocq Development Team           *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

(* Parsing of vernacular. *)

open Pp
open CErrors
open Util
open Vernacexpr
open Vernacprop

(* The functions in this module may raise (unexplainable!) exceptions.
   Use the module Coqtoplevel, which catches these exceptions
   (the exceptions are explained only at the toplevel). *)

let checknav { CAst.loc; v = { expr } }  =
  if is_navigation_vernac expr && not (is_reset expr) then
    CErrors.user_err ?loc (str "Navigation commands forbidden in files.")

type format_layout = {
  box_level : int;
  extra_blank_line : bool;
  continue_on_error : bool;
  block_indent : int;
  proof_indent : int;
  proof_margin : int;
  compact : bool;
}

let default_format_layout = {
  box_level = 0;
  extra_blank_line = true;
  continue_on_error = false;
  block_indent = 2;
  proof_indent = 2;
  proof_margin = 80;
  compact = true;
}

let active_format_layout = ref default_format_layout

type format_context = {
  block_depth : int;
  proof_depth : int;
  prev_single_line : bool;
}

let default_format_context = {
  block_depth = 0;
  proof_depth = 0;
  prev_single_line = false;
}

let active_format_context = ref default_format_context

let is_block_open = function
  | VernacSynterp (VernacBeginSection _) -> true
  | VernacSynterp (VernacDefineModule (_, _, _, _, bd)) -> CList.is_empty bd
  | VernacSynterp (VernacDeclareModule _) -> true
  | _ -> false

let is_block_close = function
  | VernacSynterp (VernacEndSegment _) -> true
  | _ -> false

let is_proof_command = function
  | VernacSynPure e -> (
    match e with
    | VernacBullet _ | VernacSubproof _ | VernacEndSubproof
    | VernacProof _ | VernacEndProof _ | VernacExactProof _ -> true
    | _ -> false)
  | VernacSynterp (VernacExtend (s, _)) ->
    String.equal s.ext_entry "VernacSolve"
    || String.equal s.ext_entry "VernacSolveParallel"
  | _ -> false

let update_format_context ctx expr =
  match expr with
  | VernacSynPure e -> (
    match e with
    | VernacProof _ ->
      { ctx with proof_depth = max ctx.proof_depth 1 }
    | VernacEndProof _ ->
      { ctx with proof_depth = 0 }
    | VernacSubproof _ ->
      { ctx with proof_depth = ctx.proof_depth + 1 }
    | VernacEndSubproof ->
      { ctx with proof_depth = max 0 (ctx.proof_depth - 1) }
    | _ -> ctx)
  | _ -> ctx

let adjust_block_depth ctx expr =
  let ctx = if is_block_close expr then
    { ctx with block_depth = max 0 (ctx.block_depth - 1) }
  else ctx in
  if is_block_open expr then
    { ctx with block_depth = ctx.block_depth + 1 }
  else ctx

let command_indent layout ctx expr =
  let ctx =
    if is_block_close expr then
      { ctx with block_depth = max 0 (ctx.block_depth - 1) }
    else ctx
  in
  let block = ctx.block_depth * layout.block_indent in
  let proof =
    if is_proof_command expr || ctx.proof_depth > 0 then
      ctx.proof_depth * layout.proof_indent
    else 0
  in
  block + proof

let leading_blank_line layout ctx single_line =
  layout.extra_blank_line
  && layout.compact
  && ctx.prev_single_line
  && not single_line

let trailing_newlines layout single_line =
  if not layout.extra_blank_line then 1
  else if layout.compact && single_line then 1
  else 2

let run_with_proof_margin layout f =
  let old = Topfmt.get_margin () in
  Topfmt.set_margin (Some layout.proof_margin);
  Fun.protect ~finally:(fun () -> Topfmt.set_margin old) f

let pr_trailing_comments ~cmd_end trailing =
  let rec aux first = function
    | [] -> mt()
    | ((b,_), text) :: rest ->
      let prefix =
        if first && b <= cmd_end + 40 then str " "
        else if first then mt()
        else fnl()
      in
      prefix ++ comment [text] ++ aux false rest
  in
  aux true trailing

let format_box level doc =
  if level <= 0 then hov 0 doc else hv level doc

let format_ast ?(layout=default_format_layout) ?(indent=0) ?(trailing_newlines=1) fmt ast comments =
  let layout = layout in
  try
  Pputils.beautify_comments := comments;
  let loc = Option.cata Loc.unloc (0,0) ast.CAst.loc in
  let before = Pputils.extract_comments (fst loc) in
  let before =
    if CList.is_empty before then mt()
    else comment before ++ (if layout.extra_blank_line then fnl() else mt())
  in
  let print_com () =
    (if is_proof_command ast.v.expr then
       run_with_proof_margin layout (fun () -> Ppvernac.pr_vernac ast)
     else
       Ppvernac.pr_vernac ast)
  in
  let com = print_com () in
  let trailing_comments = Pputils.extract_trailing_comments (snd loc) in
  let after = pr_trailing_comments ~cmd_end:(snd loc) trailing_comments in
  let trailing = if trailing_newlines <= 1 then fnl ()
    else if Pp.ismt after then fnl () ++ fnl () else fnl () in
  let doc =
    Format_policy.indent_prefix indent
    ++ format_box layout.box_level (before ++ com ++ after)
    ++ trailing
  in
  Pp.pp_with fmt doc
  with e ->
    let e, info = Exninfo.capture e in
    let info = match ast.loc with None -> info | Some loc -> Loc.add_loc info loc  in
    Exninfo.iraise (e,info)

let format_to_buffer layout ast comments =
  let buf = Buffer.create 512 in
  let out s b e = Buffer.add_substring buf s b e in
  let buf_fmt = Format.make_formatter out (fun () -> ()) in
  Format.pp_set_max_boxes buf_fmt max_int;
  let margin =
    match Topfmt.get_margin () with Some m -> m | None -> 80
  in
  Format.pp_set_margin buf_fmt margin;
  format_ast ~layout ~indent:0 ~trailing_newlines:1 buf_fmt ast comments;
  Format.pp_print_flush buf_fmt ();
  Buffer.contents buf

type time_output =
  | ToFeedback
  | ToChannel of Format.formatter

let make_time_output = function
  | Coqargs.ToFeedback -> ToFeedback
  | ToFile f ->
    let ch = open_out f in
    let fch = Format.formatter_of_out_channel ch in
    let close () =
      Format.pp_print_flush fch ();
      close_out ch
    in
    at_exit close;
    ToChannel fch

module State = struct

  type t = {
    doc : Stm.doc;
    sid : Stateid.t;
    proof : Proof.t option;
    time : time_output option;
  }

end

let emit_time state com tstart tend =
  match state.State.time with
  | None -> ()
  | Some time ->
    let pp = Topfmt.pr_cmd_header com ++ System.fmt_time_difference tstart tend in
    match time with
    | ToFeedback -> Feedback.msg_notice pp
    | ToChannel ch -> Pp.pp_with ch (pp ++ fnl())

let interp_vernac ~check ~state ({CAst.loc;_} as com) =
  let open State in
    try
      let doc, nsid, ntip = Stm.add ~doc:state.doc ~ontop:state.sid (not !Flags.quiet) com in

      (* Main STM interaction *)
      if ntip <> Stm.NewAddTip then
        anomaly (str "vernac.ml: We got an unfocus operation on the toplevel!");

      (* Force the command  *)
      let () = if check then Stm.observe ~doc nsid in
      let new_proof = Vernacstate.Declare.give_me_the_proof_opt () [@ocaml.warning "-3"] in
      { state with doc; sid = nsid; proof = new_proof; }
    with reraise ->
      let (reraise, info) = Exninfo.capture reraise in
      let info =
        (* Set the loc to the whole command if no loc *)
        match Loc.get_loc info, loc with
        | None, Some loc -> Loc.add_loc info loc
        | Some _, _ | _, None  -> info
      in
      Exninfo.iraise (reraise, info)

(* Load a vernac file. CErrors are annotated with file and location *)
let load_vernac_core ~beautify ~check ~state ?source file =
  (* Keep in sync *)
  let in_chan = open_utf8_file_in file in
  let input_cleanup () = close_in in_chan in

  let source = Option.default (Loc.InFile {dirpath=None; file}) source in
  let in_pa = Procq.Parsable.make ~loc:Loc.(initial source)
      (Gramlib.Stream.of_channel in_chan) in
  let open State in

  let rec loop state =
    let tstart = System.get_time () in
    match
      NewProfile.profile "parse_command" (fun () ->
          Stm.parse_sentence
            ~doc:state.doc ~entry:Pvernac.main_entry state.sid in_pa)
        ()
    with
    | None ->
      let () = beautify |> Option.iter @@ fun beautify ->
        (* print end of file comments if any *)
        let comments =
          List.sort (fun ((b1,_),_) ((b2,_),_) -> Int.compare b1 b2)
            (Procq.Parsable.comments in_pa)
        in
        Pp.pp_with beautify (comment (List.map snd comments))
      in
      input_cleanup ();
      state
    | Some ast ->
      let () = beautify |> Option.iter @@ fun _ ->
        Procq.Parsable.lex_trailing_on_current_line in_pa
      in
      let format_ctx_update = ref None in
      let () = beautify |> Option.iter @@ fun beautify ->
        let layout = !active_format_layout in
        let ctx = !active_format_context in
        let indent = command_indent layout ctx ast.v.expr in
        let content = format_to_buffer layout ast
          (Procq.Parsable.comments in_pa) in
        let single = Format_policy.is_single_line content in
        format_ctx_update := Some (ctx, single, ast.v.expr);
        let trailing = trailing_newlines layout single in
        let indented = Format_policy.indent_text indent content in
        let doc =
          (if leading_blank_line layout ctx single then fnl () else mt ())
          ++ str indented
          ++ (if trailing > 1 && not (String.equal indented "") then fnl ()
              else mt ())
        in
        Pp.pp_with beautify doc;
        Format.pp_print_flush beautify ();
        Procq.Parsable.drop_comments in_pa
      in

      checknav ast;

      let prev_state = state in
      let state =
        try_finally
          (fun () ->
             NewProfile.profile "command"
               ~args:(fun () ->
                   let lnum = match ast.loc with
                     | None -> "unknown"
                     | Some loc -> string_of_int loc.line_nb
                   in
                   [("cmd", `String (Pp.string_of_ppcmds (Topfmt.pr_cmd_header ast)));
                    ("line", `String lnum)])
               (fun () ->
                  if !active_format_layout.continue_on_error then
                    (try Flags.silently (interp_vernac ~check ~state:prev_state) ast
                     with reraise ->
                       let reraise, info = Exninfo.capture reraise in
                       Feedback.msg_warning (CErrors.iprint (reraise, info));
                       prev_state)
                  else
                    Flags.silently (interp_vernac ~check ~state:prev_state) ast)
               ())
          ()
          (fun () ->
             let tend = System.get_time () in
             emit_time prev_state ast tstart tend)
          ()
      in

      let () =
        if state != prev_state then
          Option.iter (fun (ctx, single, expr) ->
              let next_ctx =
                adjust_block_depth (update_format_context ctx expr) expr
              in
              active_format_context := { next_ctx with prev_single_line = single })
            !format_ctx_update
      in

      (loop [@ocaml.tailcall]) state
  in
  try loop state
  with any ->   (* whatever the exception *)
    let (e, info) = Exninfo.capture any in
    input_cleanup ();
    Exninfo.iraise (e, info)

let process_expr ~state loc_ast =
  try interp_vernac ~check:true ~state loc_ast
  with reraise ->
    let reraise, info = Exninfo.capture reraise in

    (* Exceptions don't carry enough state to print themselves (typically missing the nametab)
       so we need to print before resetting to an older state. See eg #16745 *)
    let reraise = UserError (CErrors.iprint (reraise, info)) in
    (* Keep just the loc in the info as it's printed separately *)
    let info = Option.cata (Loc.add_loc Exninfo.null) Exninfo.null (Loc.get_loc info) in

    ignore(Stm.edit_at ~doc:state.doc state.sid);
    Exninfo.iraise (reraise, info)

let process_expr ~state loc_ast =
  let tstart = System.get_time () in
  try_finally (fun () -> process_expr ~state loc_ast)
    ()
    (fun () ->
       let tend = System.get_time () in
       emit_time state loc_ast tstart tend)
    ()

(******************************************************************************)
(* Beautify-specific code                                                     *)
(******************************************************************************)

(* vernac parses the given stream, executes interpfun on the syntax tree it
 * parses, and is verbose on "primitives" commands if verbosely is true *)
let beautify_suffix = ".beautified"

let set_formatter_translator ch =
  let out s b e = output_substring ch s b e in
  let ft = Format.make_formatter out (fun () -> flush ch) in
  Format.pp_set_max_boxes ft max_int;
  ft

let open_beautify filename =
  let chan_beautify = open_out (filename^beautify_suffix) in
  let fmt = set_formatter_translator chan_beautify in
  fmt, fun () -> Format.pp_print_flush fmt(); close_out chan_beautify

let format_file ?(layout=default_format_layout) ~output ~check ~state ?source filename =
  let old_layout = !active_format_layout in
  let old_ctx = !active_format_context in
  Util.try_finally
    (fun () ->
       active_format_layout := layout;
       active_format_context := default_format_context;
       load_vernac_core ~beautify:(Some output) ~check ~state ?source filename)
    ()
    (fun () ->
       active_format_layout := old_layout;
       active_format_context := old_ctx)
    ()

(* Main driver for file loading. For now, we only do one beautify
   pass. *)
let load_vernac ?(beautify=false) ~check ~state ?source filename =
  let beautify, close_beautify = if not beautify then None, Fun.id
    else let fmt, close = open_beautify filename in Some fmt, close
  in
  let ostate =
    Util.try_finally (fun () ->
        load_vernac_core ~beautify ~check ~state ?source filename)
      ()
      close_beautify
      ()
  in
  ostate
