open Cerb_frontend

val ownership_ctypes : Ctype.ctype list ref

val get_records : unit -> ((Id.t * BaseTypes.t) list * Sym.t) list

val augment_record_map : ?cn_sym:Sym.t -> BaseTypes.t -> unit

val lookup_records_map_opt : BaseTypes.t -> Sym.t option

val bt_to_ail_ctype : ?pred_sym:Sym.t option -> BaseTypes.t -> Ctype.ctype

val wrap_with_convert_from
  :  ?sct:Sctypes.t ->
  GenTypes.genTypeCategory AilSyntax.expression_ ->
  BaseTypes.t ->
  GenTypes.genTypeCategory AilSyntax.expression_

val wrap_with_convert_to
  :  ?sct:Sctypes.t ->
  GenTypes.genTypeCategory AilSyntax.expression_ ->
  BaseTypes.t ->
  GenTypes.genTypeCategory AilSyntax.expression_

val wrap_with_convert_from_cn_bool
  :  GenTypes.genTypeCategory AilSyntax.expression ->
  GenTypes.genTypeCategory AilSyntax.expression

type ail_bindings_and_statements =
  AilSyntax.bindings * GenTypes.genTypeCategory AilSyntax.statement_ list

type ail_executable_spec =
  { pre : ail_bindings_and_statements;
    post : ail_bindings_and_statements;
    in_stmt : (Locations.t * ail_bindings_and_statements) list;
    loops :
      ((Locations.t * ail_bindings_and_statements)
      * (Locations.t * ail_bindings_and_statements))
        list
  }

val get_or_put_ownership_function
  :  without_ownership_checking:bool ->
  Ctype.ctype ->
  AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition

val assume_ownership_function
  :  without_ownership_checking:bool ->
  Ctype.ctype ->
  AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition

val datatype_equality_function
  :  AilSyntax.sigma_cn_datatype ->
  (AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list

val datatype_map_get
  :  Cerb_frontend.Symbol.sym Cerb_frontend.Cn.cn_datatype ->
  (AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list

val datatype_default_function
  :  Cerb_frontend.Symbol.sym Cerb_frontend.Cn.cn_datatype ->
  (AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list

val struct_conversion_to_function
  :  AilSyntax.sigma_tag_definition ->
  (AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list

val struct_conversion_from_function
  :  AilSyntax.sigma_tag_definition ->
  (AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list

val struct_equality_function
  :  ?is_record:bool ->
  AilSyntax.sigma_tag_definition ->
  (AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list

val struct_map_get
  :  AilSyntax.sigma_tag_definition ->
  (AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list

val struct_default_function
  :  ?is_record:bool ->
  AilSyntax.sigma_tag_definition ->
  (AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list

val record_tag : Sym.t -> BaseTypes.t -> Sym.t option

val record_opt : Sym.t -> BaseTypes.t -> AilSyntax.sigma_tag_definition option

val record_equality_function
  :  Sym.t * BaseTypes.member_types ->
  (AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list

val record_default_function
  :  'a ->
  Sym.t * BaseTypes.member_types ->
  (AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list

val record_map_get
  :  Sym.t * 'a ->
  (AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list

val expr_toplevel
  :  AilSyntax.sigma_cn_datatype list ->
  (Ctype.union_tag * Ctype.ctype) list ->
  Sym.t option ->
  IndexTerms.t ->
  AilSyntax.bindings
  * GenTypes.genTypeCategory AilSyntax.statement_ list
  * GenTypes.genTypeCategory AilSyntax.expression

val logical_constraint
  :  AilSyntax.sigma_cn_datatype list ->
  (Ctype.union_tag * Ctype.ctype) list ->
  LogicalConstraints.t ->
  AilSyntax.bindings
  * GenTypes.genTypeCategory AilSyntax.statement_ list
  * GenTypes.genTypeCategory AilSyntax.expression

val struct_ : AilSyntax.sigma_tag_definition -> AilSyntax.sigma_tag_definition list

val datatype
  :  ?first:bool ->
  AilSyntax.sigma_cn_datatype ->
  Locations.t * AilSyntax.sigma_tag_definition list

val records
  :  ((Id.t * BaseTypes.t) list * AilSyntax.ail_identifier) list ->
  AilSyntax.sigma_tag_definition list

val function_
  :  Sym.t * Definition.Function.t ->
  AilSyntax.sigma_cn_datatype list ->
  AilSyntax.sigma_cn_function list ->
  ((Locations.t * AilSyntax.sigma_declaration)
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition option)
  * AilSyntax.sigma_tag_definition option

val predicates
  :  (Sym.t * Definition.Predicate.t) list ->
  AilSyntax.sigma_cn_datatype list ->
  (Sym.t * Ctype.ctype) list ->
  AilSyntax.sigma_cn_predicate list ->
  ((Locations.t * AilSyntax.sigma_declaration)
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list
  * AilSyntax.sigma_tag_definition option list

val pre_post
  :  without_ownership_checking:bool ->
  with_loop_leak_checks:bool ->
  AilSyntax.sigma_cn_datatype list ->
  (Sym.t * Definition.Predicate.t) list ->
  (Sym.t * Ctype.ctype) list ->
  Ctype.ctype ->
  Extract.fn_args_and_body option ->
  ail_executable_spec

val assume_predicates
  :  (Sym.t * Definition.Predicate.t) list ->
  AilSyntax.sigma_cn_datatype list ->
  (Sym.t * Ctype.ctype) list ->
  (Sym.t * Definition.Predicate.t) list ->
  (AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition)
    list

val assume_pre
  :  AilSyntax.sigma_cn_datatype list ->
  Ctype.union_tag ->
  (Ctype.union_tag * (BaseTypes.t * Ctype.ctype)) list ->
  (Ctype.union_tag * Ctype.ctype) list ->
  (Ctype.union_tag * Definition.Predicate.t) list ->
  'a LogicalArgumentTypes.t ->
  AilSyntax.sigma_declaration
  * GenTypes.genTypeCategory AilSyntax.sigma_function_definition
