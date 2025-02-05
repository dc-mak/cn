let rec group_toplevel_defs new_list = function
  | [] -> new_list
  | (loc, strs) :: xs ->
    let matching_elems =
      List.filter (fun (toplevel_loc, _) -> loc == toplevel_loc) new_list
    in
    if List.is_empty matching_elems then
      group_toplevel_defs ((loc, strs) :: new_list) xs
    else (
      (* Unsafe *)
      let _, toplevel_strs = List.nth matching_elems 0 in
      let non_matching_elems =
        List.filter (fun (toplevel_loc, _) -> loc != toplevel_loc) new_list
      in
      group_toplevel_defs ((loc, toplevel_strs @ strs) :: non_matching_elems) xs)


let rec open_auxilliary_files
  source_filename
  prefix
  included_filenames
  already_opened_list
  =
  match included_filenames with
  | [] -> []
  | fn :: fns ->
    (match fn with
     | Some fn' ->
       if
         String.equal fn' source_filename || List.mem String.equal fn' already_opened_list
       then
         []
       else (
         let fn_list = String.split_on_char '/' fn' in
         let output_fn = List.nth fn_list (List.length fn_list - 1) in
         let output_fn_with_prefix = Filename.concat prefix output_fn in
         if Sys.file_exists output_fn_with_prefix then (
           Printf.printf
             "Error in opening file %s as it already exists\n"
             output_fn_with_prefix;
           open_auxilliary_files source_filename prefix fns (fn' :: already_opened_list))
         else (
           let output_channel = Stdlib.open_out output_fn_with_prefix in
           (fn', output_channel)
           :: open_auxilliary_files source_filename prefix fns (fn' :: already_opened_list)))
     | None -> [])


let filter_injs_by_filename inj_pairs fn =
  List.filter
    (fun (loc, _) ->
      match Cerb_location.get_filename loc with
      | Some name -> String.equal name fn
      | None -> false)
    inj_pairs


let rec inject_injs_to_multiple_files ail_prog in_stmt_injs block_return_injs cn_header
  = function
  | [] -> ()
  | (fn', oc') :: xs ->
    Stdlib.output_string oc' (cn_header ^ "\n");
    let in_stmt_injs_for_fn' = filter_injs_by_filename in_stmt_injs fn' in
    let squashed_return_injs_for_fn' = filter_injs_by_filename block_return_injs fn' in
    let return_injs_for_fn' =
      List.map
        (fun (loc, (e_opt, strs)) -> (loc, e_opt, strs))
        squashed_return_injs_for_fn'
    in
    (* let injs_for_fn' = List.map (fun (loc, (_, strs)) -> (loc, strs)) injs_with_syms
       in *)
    (match
       Source_injection.(
         output_injections
           oc'
           { filename = fn';
             program = ail_prog;
             pre_post = [];
             in_stmt = in_stmt_injs_for_fn';
             returns = return_injs_for_fn';
             inject_in_preproc = false
           })
     with
     | Ok () -> ()
     | Error str ->
       (* TODO(Christopher/Rini): maybe lift this error to the exception monad? *)
       prerr_endline str);
    Stdlib.close_out oc';
    inject_injs_to_multiple_files ail_prog in_stmt_injs block_return_injs cn_header xs


let copy_source_dir_files_into_output_dir filename already_opened_fns_and_ocs prefix =
  let source_files_already_opened = filename :: List.map fst already_opened_fns_and_ocs in
  let split_str_list = String.split_on_char '/' filename in
  let rec remove_last_elem = function
    | [] -> []
    | [ _ ] -> []
    | x :: xs -> x :: remove_last_elem xs
  in
  let source_dir_path = String.concat "/" (remove_last_elem split_str_list) in
  let source_dir_all_files_without_path = Array.to_list (Sys.readdir source_dir_path) in
  let source_dir_all_files_with_path =
    List.map
      (fun fn -> String.concat "/" [ source_dir_path; fn ])
      source_dir_all_files_without_path
  in
  let remaining_source_dir_files =
    List.filter
      (fun fn -> not (List.mem String.equal fn source_files_already_opened))
      source_dir_all_files_with_path
  in
  let remaining_source_dir_files =
    List.filter
      (fun fn -> List.mem String.equal (Filename.extension fn) [ ".c"; ".h" ])
      remaining_source_dir_files
  in
  let remaining_source_dir_files_opt =
    List.map (fun str -> Some str) remaining_source_dir_files
  in
  let remaining_fns_and_ocs =
    open_auxilliary_files filename prefix remaining_source_dir_files_opt []
  in
  let read_file file = In_channel.with_open_bin file In_channel.input_all in
  let copy_file_contents_to_output_dir (input_fn, fn_oc) =
    let input_file_contents = read_file input_fn in
    Stdlib.output_string fn_oc input_file_contents;
    ()
  in
  let _ = List.map copy_file_contents_to_output_dir remaining_fns_and_ocs in
  ()


let memory_accesses_injections ail_prog =
  let open Cerb_frontend in
  let open Cerb_location in
  let loc_of_expr (AilSyntax.AnnotatedExpression (_, _, loc, _)) = loc in
  let pos_bbox loc =
    match bbox [ loc ] with `Other _ -> assert false | `Bbox (b, e) -> (b, e)
  in
  let acc = ref [] in
  let xs = Ail_analysis.collect_memory_accesses ail_prog in
  List.iter
    (fun access ->
      match access with
      | Ail_analysis.Load { loc; _ } ->
        let b, e = pos_bbox loc in
        acc := (point b, [ "CN_LOAD(" ]) :: (point e, [ ")" ]) :: !acc
      | Store { lvalue; expr; _ } ->
        (* NOTE: we are not using the location of the access (the AilEassign), because if
           in the source the assignment was surrounded by parens its location will contain
           the parens, which will break the CN_STORE macro call *)
        let b, pos1 = pos_bbox (loc_of_expr lvalue) in
        let pos2, e = pos_bbox (loc_of_expr expr) in
        acc
        := (point b, [ "CN_STORE(" ])
           :: (region (pos1, pos2) NoCursor, [ ", " ])
           :: (point e, [ ")" ])
           :: !acc
      | StoreOp { lvalue; aop; expr; _ } ->
        let b, pos1 = pos_bbox (loc_of_expr lvalue) in
        let pos2, e = pos_bbox (loc_of_expr expr) in
        let op_str =
          match aop with
          | Mul -> "*"
          | Div -> "/"
          | Mod -> "%"
          | Add -> "+"
          | Sub -> "-"
          | Shl -> "<<"
          | Shr -> ">>"
          | Band -> "&"
          | Bxor -> "^"
          | Bor -> "|"
        in
        acc
        := (point b, [ "CN_STORE_OP(" ])
           :: (region (pos1, pos2) NoCursor, [ "," ^ op_str ^ "," ])
           :: (point e, [ ")" ])
           :: !acc
      | Postfix { loc; op; lvalue } ->
        let op_str = match op with `Incr -> "++" | `Decr -> "--" in
        let b, e = pos_bbox loc in
        let pos1, pos2 = pos_bbox (loc_of_expr lvalue) in
        (* E++ *)
        acc
        := (region (b, pos1) NoCursor, [ "CN_POSTFIX(" ])
           :: (region (pos2, e) NoCursor, [ ", " ^ op_str ^ ")" ])
           :: !acc)
    xs;
  !acc


let output_to_oc oc str_list = List.iter (Stdlib.output_string oc) str_list

open Executable_spec_gen_injections

let main
  ?(without_ownership_checking = false)
  ?(without_loop_invariants = false)
  ?(with_loop_leak_checks = false)
  ?(with_test_gen = false)
  ?(copy_source_dir = false)
  filename
  ~use_preproc
  ((_, sigm) as ail_prog)
  output_decorated
  output_decorated_dir
  prog5
  =
  let output_filename =
    match output_decorated with
    | None -> Filename.(remove_extension (basename filename)) ^ "-exec.c"
    | Some output_filename' -> output_filename'
  in
  let prefix = match output_decorated_dir with Some dir_name -> dir_name | None -> "" in
  let oc = Stdlib.open_out (Filename.concat prefix output_filename) in
  let cn_oc = Stdlib.open_out (Filename.concat prefix "cn.c") in
  let cn_header_oc = Stdlib.open_out (Filename.concat prefix "cn.h") in
  let instrumentation, _ = Executable_spec_extract.collect_instrumentation prog5 in
  Executable_spec_records.populate_record_map instrumentation prog5;
  let executable_spec =
    generate_c_specs
      without_ownership_checking
      without_loop_invariants
      with_loop_leak_checks
      instrumentation
      sigm
      prog5
  in
  let c_datatype_defs, _c_datatype_decls, c_datatype_equality_fun_decls =
    generate_c_datatypes sigm
  in
  let c_function_defs, c_function_decls, locs_and_c_extern_function_decls, _c_records =
    generate_c_functions_internal sigm prog5.logical_predicates
  in
  let c_predicate_defs, locs_and_c_predicate_decls, _c_records' =
    generate_c_predicates_internal sigm prog5.resource_predicates
  in
  let conversion_function_defs, conversion_function_decls =
    generate_conversion_and_equality_functions sigm
  in
  let cn_header_pair = ("cn.h", false) in
  let cn_header = Executable_spec_utils.generate_include_header cn_header_pair in
  let cn_utils_header_pair = ("cn-executable/utils.h", true) in
  let cn_utils_header =
    Executable_spec_utils.generate_include_header cn_utils_header_pair
  in
  let ownership_function_defs, ownership_function_decls =
    generate_ownership_functions
      without_ownership_checking
      Cn_to_ail.ownership_ctypes
      sigm
  in
  let c_struct_defs = generate_c_struct_strs sigm.tag_definitions in
  let cn_converted_struct_defs = generate_cn_versions_of_structs sigm.tag_definitions in
  let record_fun_defs, record_fun_decls =
    Executable_spec_records.generate_c_record_funs sigm
  in
  let datatype_strs = String.concat "\n" (List.map snd c_datatype_defs) in
  let predicate_decls =
    String.concat "\n" (List.concat (List.map snd locs_and_c_predicate_decls))
  in
  let record_defs, _record_decls = Executable_spec_records.generate_all_record_strs () in
  let cn_header_decls_list =
    [ cn_utils_header;
      "\n";
      (if not (String.equal record_defs "") then "\n/* CN RECORDS */\n\n" else "");
      record_defs;
      c_struct_defs;
      cn_converted_struct_defs;
      (if not (String.equal datatype_strs "") then "\n/* CN DATATYPES */\n\n" else "");
      datatype_strs;
      "\n\n/* OWNERSHIP FUNCTIONS */\n\n";
      ownership_function_decls;
      conversion_function_decls;
      record_fun_decls;
      c_function_decls;
      "\n";
      predicate_decls
    ]
  in
  let cn_header_oc_str =
    Executable_spec_utils.ifndef_wrap
      "CN_HEADER"
      (String.concat "\n" cn_header_decls_list)
  in
  output_to_oc cn_header_oc [ cn_header_oc_str ];
  (* Genereate CN.c *)

  (* TODO: Topological sort *)
  let cn_defs_list =
    [ cn_header;
      record_fun_defs;
      conversion_function_defs;
      ownership_function_defs;
      c_function_defs;
      "\n";
      c_predicate_defs
    ]
  in
  output_to_oc cn_oc cn_defs_list;
  (* Generate myfile-exec.c *)
  let incls =
    [ ("assert.h", true); ("stdlib.h", true); ("stdbool.h", true); ("math.h", true) ]
  in
  let headers = List.map Executable_spec_utils.generate_include_header incls in
  let source_file_strs_list = [ cn_header; List.fold_left ( ^ ) "" headers; "\n" ] in
  output_to_oc oc source_file_strs_list;
  let c_datatypes_with_fn_prots =
    List.combine c_datatype_defs c_datatype_equality_fun_decls
  in
  let c_datatypes_locs_and_strs =
    List.map
      (fun ((loc, dt_str), eq_prot_str) ->
        (loc, [ String.concat "\n" [ dt_str; eq_prot_str ] ]))
      c_datatypes_with_fn_prots
  in
  let toplevel_locs_and_defs =
    group_toplevel_defs
      []
      (c_datatypes_locs_and_strs
       @ locs_and_c_extern_function_decls
       @ locs_and_c_predicate_decls)
  in
  let toplevel_locs_and_defs =
    List.map (fun (loc, _) -> (loc, [ "" ])) toplevel_locs_and_defs
  in
  let accesses_stmt_injs =
    if without_ownership_checking then [] else memory_accesses_injections ail_prog
  in
  let struct_injs_with_filenames =
    Executable_spec_gen_injections.generate_struct_injs sigm
  in
  let struct_injs_with_filenames =
    List.map (fun (loc, _) -> (loc, [ "" ])) struct_injs_with_filenames
  in
  let in_stmt_injs =
    executable_spec.in_stmt
    @ accesses_stmt_injs
    @ toplevel_locs_and_defs
    @ struct_injs_with_filenames
  in
  (* Treat source file separately from header files *)
  let source_file_in_stmt_injs = filter_injs_by_filename in_stmt_injs filename in
  (* Return injections *)
  let block_return_injs = executable_spec.returns in
  let squashed_block_return_injs =
    List.map (fun (l, e_opt, strs) -> (l, (e_opt, strs))) block_return_injs
  in
  let source_file_return_injs_squashed =
    filter_injs_by_filename squashed_block_return_injs filename
  in
  let source_file_return_injs =
    List.map (fun (l, (e_opt, strs)) -> (l, e_opt, strs)) source_file_return_injs_squashed
  in
  let included_filenames =
    List.map (fun (loc, _) -> Cerb_location.get_filename loc) in_stmt_injs
  in
  let included_filenames' =
    included_filenames
    @ List.map (fun (loc, _) -> Cerb_location.get_filename loc) squashed_block_return_injs
  in
  let remaining_fns_and_ocs =
    if use_preproc then
      []
    else
      open_auxilliary_files filename prefix included_filenames' []
  in
  let pre_post_pairs =
    if with_test_gen then
      if not (has_main sigm) then
        executable_spec.pre_post
      else
        failwith
          "Input file cannot have predefined main function when passing to CN test-gen \
           tooling"
    else if without_ownership_checking then
      executable_spec.pre_post
    else (
      (* Inject ownership init function calls and mapping and unmapping of globals into provided main function *)
      let global_ownership_init_pair = generate_ownership_global_assignments sigm prog5 in
      global_ownership_init_pair @ executable_spec.pre_post)
  in
  (match
     Source_injection.(
       output_injections
         oc
         { filename;
           program = ail_prog;
           pre_post = pre_post_pairs;
           in_stmt = source_file_in_stmt_injs;
           returns = source_file_return_injs;
           inject_in_preproc = use_preproc
         })
   with
   | Ok () -> ()
   | Error str ->
     (* TODO(Christopher/Rini): maybe lift this error to the exception monad? *)
     prerr_endline str);
  if copy_source_dir then
    copy_source_dir_files_into_output_dir filename remaining_fns_and_ocs prefix;
  inject_injs_to_multiple_files
    ail_prog
    in_stmt_injs
    squashed_block_return_injs
    cn_header
    remaining_fns_and_ocs;
  close_out oc;
  close_out cn_oc;
  close_out cn_header_oc
