(************************************************************************)
(* Rocq project file discovery and expansion for rocqformat. *)

let project_file_names = ["_CoqProject"; "RocqProject"]

let discover_project_file files =
  let search_from dir =
    let rec find = function
      | [] -> None
      | name :: rest ->
        match CoqProject_file.find_project_file ~from:dir ~projfile_name:name with
        | Some _ as found -> found
        | None -> find rest
    in
    find project_file_names
  in
  match files with
  | [] -> search_from (Sys.getcwd ())
  | file :: _ ->
    let file =
      if Filename.is_relative file then Filename.concat (Sys.getcwd ()) file
      else file
    in
    search_from (Filename.dirname file)

let project_root project_file = Filename.dirname project_file

let scan_project_v_files dir =
  let rec walk acc dir =
    if not (Sys.file_exists dir) then acc
    else
      Array.fold_left
        (fun acc name ->
           if name = "." || name = ".." then acc
           else
             let path = Filename.concat dir name in
             if Sys.is_directory path then walk acc path
             else if Filename.check_suffix name ".v" then path :: acc
             else acc)
        acc (Sys.readdir dir)
  in
  walk [] dir |> List.sort compare

let list_project_v_files project_file =
  let warning_fn msg = Printf.eprintf "Warning: %s\n%!" msg in
  let project = CoqProject_file.read_project_file ~warning_fn project_file in
  let root = project_root project_file in
  let listed =
    project
    |> CoqProject_file.all_files
    |> fun files -> CoqProject_file.files_by_suffix files [".v"]
    |> List.map (fun f ->
        let path = CoqProject_file.forget_source f in
        if Filename.is_relative path then Filename.concat root path else path)
  in
  if listed <> [] then listed else scan_project_v_files root

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

let apply_project_opts opts project_file =
  let args = expand_project_args [] project_file in
  fst (Coqargs.parse_args ~init:opts args)
