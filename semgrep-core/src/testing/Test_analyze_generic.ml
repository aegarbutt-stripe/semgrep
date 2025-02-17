open Common
open AST_generic
module H = AST_generic_helpers
module V = Visitor_AST

let test_typing_generic file =
  let ast = Parse_target.parse_program file in
  let lang = List.hd (Lang.langs_of_filename file) in
  Naming_AST.resolve lang ast;

  let v =
    V.mk_visitor
      {
        V.default_visitor with
        V.kfunction_definition =
          (fun (_k, _) def ->
            let body = H.funcbody_to_stmt def.fbody in
            let s = AST_generic.show_any (S body) in
            pr2 s;
            pr2 "==>";

            let xs = AST_to_IL.stmt lang body in
            let s = IL.show_any (IL.Ss xs) in
            pr2 s);
      }
  in
  v (Pr ast)

let test_cfg_generic file =
  let ast = Parse_target.parse_program file in
  ast
  |> List.iter (fun item ->
         match item.s with
         | DefStmt (_ent, FuncDef def) -> (
             try
               let flow = Controlflow_build.cfg_of_func def in
               Controlflow.display_flow flow
             with Controlflow_build.Error err ->
               Controlflow_build.report_error err)
         | _ -> ())

module F = Controlflow

module DataflowX = Dataflow_core.Make (struct
  type node = F.node

  type edge = F.edge

  type flow = (node, edge) CFG.t

  let short_string_of_node = F.short_string_of_node
end)

let test_dfg_generic file =
  let ast = Parse_target.parse_program file in
  ast
  |> List.iter (fun item ->
         match item.s with
         | DefStmt (_ent, FuncDef def) ->
             let flow = Controlflow_build.cfg_of_func def in
             pr2 "Reaching definitions";
             let mapping = Dataflow_reaching.fixpoint flow in
             DataflowX.display_mapping flow mapping Dataflow_core.ns_to_str;
             pr2 "Liveness";
             let mapping = Dataflow_liveness.fixpoint flow in
             DataflowX.display_mapping flow mapping (fun () -> "()")
         | _ -> ())

let test_naming_generic file =
  let ast = Parse_target.parse_program file in
  let lang = List.hd (Lang.langs_of_filename file) in
  Naming_AST.resolve lang ast;
  let s = AST_generic.show_any (AST_generic.Pr ast) in
  pr2 s

let test_constant_propagation file =
  let ast = Parse_target.parse_program file in
  let lang = List.hd (Lang.langs_of_filename file) in
  Naming_AST.resolve lang ast;
  Constant_propagation.propagate_basic lang ast;
  let s = AST_generic.show_any (AST_generic.Pr ast) in
  pr2 s

let test_il_generic file =
  let ast = Parse_target.parse_program file in
  let lang = List.hd (Lang.langs_of_filename file) in
  Naming_AST.resolve lang ast;

  let v =
    V.mk_visitor
      {
        V.default_visitor with
        V.kfunction_definition =
          (fun (_k, _) def ->
            let body = H.funcbody_to_stmt def.fbody in
            let s = AST_generic.show_any (S body) in
            pr2 s;
            pr2 "==>";

            let xs = AST_to_IL.stmt lang body in
            let s = IL.show_any (IL.Ss xs) in
            pr2 s);
      }
  in
  v (Pr ast)

let test_cfg_il file =
  let ast = Parse_target.parse_program file in
  let lang = List.hd (Lang.langs_of_filename file) in
  Naming_AST.resolve lang ast;

  let v =
    V.mk_visitor
      {
        V.default_visitor with
        V.kfunction_definition =
          (fun (_k, _) def ->
            let body = H.funcbody_to_stmt def.fbody in
            let xs = AST_to_IL.stmt lang body in
            let cfg = CFG_build.cfg_of_stmts xs in
            Display_IL.display_cfg cfg);
      }
  in
  v (Pr ast)

module F2 = IL

module DataflowY = Dataflow_core.Make (struct
  type node = F2.node

  type edge = F2.edge

  type flow = (node, edge) CFG.t

  let short_string_of_node n = Display_IL.short_string_of_node_kind n.F2.n
end)

let test_dfg_constness file =
  let ast = Parse_target.parse_program file in
  let lang = List.hd (Lang.langs_of_filename file) in
  Naming_AST.resolve lang ast;
  let v =
    V.mk_visitor
      {
        V.default_visitor with
        V.kfunction_definition =
          (fun (_k, _) def ->
            let inputs, xs = AST_to_IL.function_definition lang def in
            let flow = CFG_build.cfg_of_stmts xs in
            pr2 "Constness";
            let mapping = Dataflow_constness.fixpoint inputs flow in
            Dataflow_constness.update_constness flow mapping;
            DataflowY.display_mapping flow mapping
              Dataflow_constness.string_of_constness;
            let s = AST_generic.show_any (S (H.funcbody_to_stmt def.fbody)) in
            pr2 s);
      }
  in
  v (Pr ast)

let actions () =
  [
    ("-typing_generic", " <file>", Common.mk_action_1_arg test_typing_generic);
    ("-cfg_generic", " <file>", Common.mk_action_1_arg test_cfg_generic);
    ("-dfg_generic", " <file>", Common.mk_action_1_arg test_dfg_generic);
    ("-naming_generic", " <file>", Common.mk_action_1_arg test_naming_generic);
    ( "-constant_propagation",
      " <file>",
      Common.mk_action_1_arg test_constant_propagation );
    ("-il_generic", " <file>", Common.mk_action_1_arg test_il_generic);
    ("-cfg_il", " <file>", Common.mk_action_1_arg test_cfg_il);
    ("-dfg_constness", " <file>", Common.mk_action_1_arg test_dfg_constness);
  ]
