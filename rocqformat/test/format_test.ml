(************************************************************************)
(* Integration tests: run the rocqformat executable on fixture files. *)

open OUnit2
open Unix

let exe_name = "main.exe"

let find_rocqformat () =
  let root = Sys.getenv "PWD" in
  let candidates =
    [ Filename.concat root ("_build/default/rocqformat/" ^ exe_name)
    ; Filename.concat root "_build/default/rocqformat/main.exe"
    ; Filename.concat root
        ("_build/install/default/libexec/rocqformat/" ^ exe_name)
    ]
  in
  let rec try_candidates = function
    | [] -> None
    | path :: rest ->
        if Sys.file_exists path then Some (Filename.quote path)
        else try_candidates rest
  in
  match try_candidates candidates with
  | Some path -> path
  | None -> (
      match Sys.getenv_opt "ROCQFORMAT" with
      | Some path when Sys.file_exists path -> Filename.quote path
      | _ -> failwith "rocqformat executable not found (set ROCQFORMAT or build first)")

let cases_root =
  Filename.concat (Sys.getenv "PWD")
    "test-suite/misc/rocqformat/cases"

let read_file path =
  let ic = open_in_bin path in
  let len = in_channel_length ic in
  let buf = Bytes.create len in
  really_input ic buf 0 len;
  close_in ic;
  Bytes.to_string buf

let run_rocqformat rocqformat extra_args input =
  let cmd =
    Printf.sprintf "%s -q -boot -noinit %s %s 2>/dev/null" rocqformat extra_args
      (Filename.quote input)
  in
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 1024 in
  (try
     while true do
       Buffer.add_char buf (input_char ic)
     done
   with End_of_file -> ());
  ignore (Unix.close_process_in ic);
  Buffer.contents buf

let list_case_dirs () =
  if not (Sys.file_exists cases_root) then []
  else
    Sys.readdir cases_root
    |> Array.to_list
    |> List.filter (fun name -> name <> "_cli")
    |> List.map (Filename.concat cases_root)
    |> List.filter Sys.is_directory
    |> List.sort compare

let case_name case_dir = Filename.basename case_dir

let extra_args case_dir =
  let args_file = Filename.concat case_dir "args" in
  if Sys.file_exists args_file then read_file args_file |> String.trim else ""

let test_case rocqformat case_dir =
  let name = case_name case_dir in
  name >:: fun _ ->
    let input = Filename.concat case_dir "input.v" in
    let expected = Filename.concat case_dir "expected.v" in
    if not (Sys.file_exists input && Sys.file_exists expected) then
      skip_if true (name ^ " missing input.v or expected.v")
    else
      let output = run_rocqformat rocqformat (extra_args case_dir) input in
      let golden = read_file expected in
      assert_equal ~printer:(fun s -> s) golden output;
      let again = run_rocqformat rocqformat (extra_args case_dir) expected in
      assert_equal ~printer:(fun s -> s) golden again

let suite =
  let rocqformat = find_rocqformat () in
  let cases = list_case_dirs () in
  if cases = [] then
    "rocqformat_integration" >:: fun _ ->
      skip_if true "no cases found (run from repository root)"
  else
    "rocqformat_integration" >:::
      List.map (test_case rocqformat) cases

let () = run_test_tt_main suite
