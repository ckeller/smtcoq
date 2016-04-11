(**************************************************************************)
(*                                                                        *)
(*                            LFSCtoSmtCoq                                *)
(*                                                                        *)
(*                         Copyright (C) 2016                             *)
(*          by the Board of Trustees of the University of Iowa            *)
(*                                                                        *)
(*                    Alain Mebsout and Burak Ekici                       *)
(*                       The University of Iowa                           *)
(*                                                                        *)
(*                                                                        *)
(*  This file is distributed under the terms of the Apache Software       *)
(*  License version 2.0                                                   *)
(*                                                                        *)
(**************************************************************************)

open Ast
open Builtin
open Format
open Translator_sig


module Make (T : Translator_sig.S) = struct

  open T

  module MTerm = Map.Make (Term)


  type env = {
    clauses : int list;
    ax : bool;
    mpred : bool MTerm.t;
    assum : string list;
  }


  let empty = {
    clauses = [];
    ax = false;
    mpred = MTerm.empty;
    assum = [];
  }


  let th_res p = match app_name (deref p).ttype with
    | Some ("th_holds", [r]) -> r
    | _ -> assert false

  

  let rec ignore_all_decls p = match value p with
    | Lambda (s, p) -> ignore_all_decls p
    | _ -> p


  let rec ignore_decls p = match value p with
    | Lambda (s, p) ->
      (match s.sname with
       | Name n when n.[0] = 'A' -> p
       | _ -> ignore_decls p
      )
    | _ -> p


  let rec ignore_preproc p = match app_name p with
    | Some ("th_let_pf", [_; _; p]) ->
      begin match value p with
        | Lambda (_, p) -> ignore_preproc p
        | _ -> assert false
      end
    | _ -> p


  let rec produce_inputs_preproc p = match app_name p with
    | Some ("th_let_pf", [_; _; p]) ->
      begin match value p with
        | Lambda ({sname = Name h; stype}, p) ->
          begin match app_name stype with
            | Some ("th_holds", [formula]) ->
              mk_input h formula;
              produce_inputs_preproc p
            | _ -> assert false
          end
        | _ -> assert false
      end
    | _ -> p


  let rec produce_inputs p = match value p with
    | Lambda ({sname = Name h; stype}, p) ->
      begin match app_name stype with
        | Some ("th_holds", [formula])
          when (match name formula with Some "true" -> false | _ -> true)
          ->
          mk_input h formula;
          produce_inputs p
        | _ -> produce_inputs p
      end
    | _ -> p



  let rec register_prop_vars p = match app_name p with
    | Some ("decl_atom", [formula; p]) ->
      begin match value p with
        | Lambda (v, p) ->
          let vt = (symbol_to_const v) in
          (* eprintf "register prop var: %a@." print_term_type vt; *)
          register_prop_abstr vt formula;
          begin match value p with
            | Lambda (_, p) -> register_prop_vars p
            | _ -> assert false
          end
        | _ -> assert false
      end
    | _ -> p




  let rec get_assumptions acc p = match app_name p with
    | Some (("asf"|"ast"), [_; _; _; _; p]) ->
      begin match value p with
        | Lambda ({sname = Name n}, p) -> get_assumptions (n :: acc) p
        | _ -> assert false
      end
    | _ -> acc, p



  let rec rm_used' assumptions t = match name t with
    | Some x -> List.filter (fun y -> y <> x) assumptions
    | None -> (* match app_name t with *)
      (* | Some (_, l) -> List.fold_left rm_used' assumptions l *)
      (* | None -> *) assumptions

  let rm_used env t = { env with assum = rm_used' env.assum t }


  let rec trim_junk_satlem p = match app_name p with
    | Some ("clausify_false", [p]) -> trim_junk_satlem p
    | Some ("contra", [_; p1; p2]) ->
      trim_junk_satlem p1 @ trim_junk_satlem p2
    | _ -> [p]



  let mk_inter_resolution clauses = match clauses with
    | [id] -> id
    | _ -> mk_clause ~reuse:false Reso [] clauses



  let is_ty_Bool ty = match name ty with
    | Some "Bool" -> true
    | _ -> false



  let rec cong neqs env p = match app_name p with
    | Some ("cong", [ty; rty; f; f'; x; y; p_f_eq_f'; r]) ->

      let neqs = not_ (eq ty x y) :: neqs in
      let env = lem env r in

      begin match name f, name f' with
        | Some n, Some n' when n = n' -> neqs, env
        | None, None -> cong neqs env p_f_eq_f'
        | _ -> assert false
      end

    | Some (("symm"|"negsymm"), [_; _; _; r])
    | Some ("trans", [_; _; _; _; r; _])
    | Some ("refl", [_; r]) -> cong neqs (rm_used env r) r

    | _ ->
      eprintf "something went wrong in congruence@.";
      neqs, env

  and trans neqs env p = match app_name p with
    | Some ("trans", [ty; x; y; z; p1; p2]) ->

      (* let clauses = lem mpred assum (lem mpred assum clauses p1) p2 in *)

      let neqs1, env = trans neqs env p1 in
      let neqs2, env = trans neqs env p2 in

      let x_y = th_res p1 in
      let y_z = th_res p2 in

      let neqs = match neqs1, neqs2 with
        | [], [] -> [not_ x_y; not_ y_z]
        | [], _ -> not_ x_y :: neqs2
        | _, [] -> neqs1 @ [not_ y_z]
        | _, _ -> neqs1 @ neqs2
      in

      neqs, env

    | Some (("symm"|"negsymm"), [_; _; _; r]) -> trans neqs (rm_used env r) r

    | _ -> neqs, lem env p




  and lem env p = match app_name p with
    | Some (("or_elim_1"|"or_elim_2"), [_; _; x; r])
      when (match app_name r with
            Some (("impl_elim"|"not_and_elim"), _) -> true | _ -> false)
      ->
      let env = rm_used env x in
      let env = lem env r in
      { env with ax = true }

    | Some (("or_elim_1"|"or_elim_2"), [a; b; x; r]) ->
      let env = rm_used env x in
      let env = lem env r in
      let clauses = match env.clauses with
        | [_] when not env.ax -> mk_clause_cl Or [a; b] env.clauses :: []
        | _ ->
          let a_or_b = th_res r in
          mk_clause_cl Orp [not_ a_or_b; a; b] [] :: env.clauses
      in
      { env with clauses; ax = true }

    | Some ("impl_elim", [a; b; r]) ->
      let env = lem env r in
      let clauses = match env.clauses with
        | [_] when not env.ax -> mk_clause_cl Imp [not_ a; b] env.clauses :: []
        | _ ->
          let a_impl_b = th_res r in
          mk_clause_cl Impp [not_ a_impl_b; not_ a; b] [] :: env.clauses
      in
      { env with clauses }

    | Some ("not_and_elim", [a; b; r]) ->
      let env = lem env r in
      let clauses = match env.clauses with
        | [_] when not env.ax ->
          mk_clause_cl Nand [not_ a; not_ b] env.clauses :: []
        | _ ->
          let a_and_b = and_ a b in
          mk_clause_cl Andn [a_and_b; not_ a; not_ b] [] :: env.clauses
      in
      { env with clauses }

    | Some ("and_elim_1", [a; _; r]) ->
      begin match app_name r with
        | Some ("not_impl_elim", [a; b; r]) ->
          let env = lem env r in
          let clauses = match env.clauses with
            | [_] when not env.ax -> mk_clause_cl Nimp1 [a] env.clauses :: []
            | _ ->
              let a_impl_b = impl_ a b in
              mk_clause_cl Impn1 [a_impl_b; a] [] :: env.clauses
          in
          { env with clauses }

        | Some ("not_or_elim", [a; b; r]) ->
          let env = lem env r in
          let clauses = match env.clauses with
            | [id] when not env.ax -> mk_clause_cl Nor [not_ a] [id; 0] :: []
            | _ ->
              let a_or_b = or_ a b in
              mk_clause_cl Orn [a_or_b; not_ a] [0] :: env.clauses
          in
          { env with clauses }

        | _ ->
          let env = lem env r in
          let clauses = match env.clauses with
            | [id] when not env.ax -> mk_clause_cl And [a] [id; 0] :: []
            | _ ->
              let a_and_b = th_res r in
              mk_clause_cl Andp [not_ a_and_b; a] [0] :: env.clauses
          in
          { env with clauses }
      end

    | Some ("and_elim_2", [a; b; r]) ->
      begin match app_name r with
        | Some ("not_impl_elim", [a; b; r]) ->
          let env = lem env r in
          let clauses = match env.clauses with
            | [_] when not env.ax ->
              mk_clause_cl Nimp2 [not_ b] env.clauses :: []
            | _ ->
              let a_impl_b = impl_ a b in
              mk_clause_cl Impn2 [a_impl_b; not_ b] [] :: env.clauses
          in
          { env with clauses }

        | Some ("not_or_elim", [a; b; r]) ->
          let env = lem env r in
          let clauses = match env.clauses with
            | [id] when not env.ax -> mk_clause_cl Nor [not_ b] [id; 1] :: []
            | _ ->
              let a_or_b = or_ a b in
              mk_clause_cl Orn [a_or_b; not_ b] [1] :: env.clauses
          in
          { env with clauses }

        | _ ->
          let env = lem env r in
          let clauses = match env.clauses with
            | [id] when not env.ax -> mk_clause_cl And [b] [id; 1] :: []
            | _ ->
              let a_and_b = th_res r in
              mk_clause_cl Andp [not_ a_and_b; b] [1] :: env.clauses
          in
          { env with clauses }
      end

    (* Ignore symmetry of equlity rules *)
    | Some (("symm"|"negsymm"), [_; _; _; r]) -> lem (rm_used env r) r

    (* Should not be traversed anyway *)
    | Some (("pred_eq_t"|"pred_eq_f"), [_; r]) -> lem env r


    | Some ("trans", [_; _; _; _; r; w])
      when (match app_name w with
            Some (("pred_eq_t"|"pred_eq_f"), _) -> true | _ -> false)
      ->
      (* Remember which direction of the implication we want for congruence over
         predicates *)
      let env = match app_name w with
        | Some ("pred_eq_t", [pt; x]) ->
          let env = rm_used env x in
          { env with mpred = MTerm.add pt false env.mpred }
        | Some ("pred_eq_f", [pt; x]) ->
          let env = rm_used env x in
          { env with mpred = MTerm.add pt true env.mpred }
        | _ -> assert false
      in

      lem env r

    | Some ("trans", [ty; x; y; z; p1; p2]) ->

      let neqs, env = trans [] env p in
      let x_z = eq ty x z in
      { env with
        clauses = mk_clause_cl Eqtr (neqs @ [x_z]) [] :: env.clauses;
        ax = true }

    (* | Some ("trans", [ty; x; y; z; p1; p2]) ->

       (* let clauses1 = lem mpred assum clauses p1 in *)
       (* let clauses2 = lem mpred assum clauses p2 in *)

       (* TODO: intermediate resolution step *)
       let clauses = lem mpred assum (lem mpred assum clauses p1) p2 in

       let x_y = th_res p1 in
       let y_z = th_res p2 in
       let x_z = eq ty x z in
       let clauses = mk_clause_cl "eq_transitive" [not_ x_y; not_ y_z; x_z] [] :: clauses in

       (* let cl1 = [th_res p1] in *)
       (* let cl2 = [th_res p2] in *)
       (* let clauses = [ *)
       (*   mk_inter_resolution cl1 clauses1; *)
       (*   mk_inter_resolution cl2 clauses2] *)
       (* in *)
       clauses
    *)

    (* Congruence with predicates *)
    | Some ("cong", [_; rty; pp; _; x; y; _; _]) when is_ty_Bool rty ->
      let neqs, env = cong [] env p in
      let cptr, cpfa = match app_name (th_res p) with
        | Some ("=", [_; apx; apy]) ->
          (match MTerm.find apx env.mpred, MTerm.find apy env.mpred with
           | true, false -> p_app apx, not_ (p_app apy)
           | false, true -> p_app apy, not_ (p_app apx)
           | true, true -> p_app apx, p_app apy
           | false, false -> not_ (p_app apx), not_ (p_app apy)
          )
        | _ -> assert false
      in
      let cl = neqs @ [cpfa; cptr] in
      { env with
        clauses = mk_clause_cl Eqcp cl [] :: env.clauses;
        ax = true }

    (* Congruence *)
    | Some ("cong", [_; _; _; _; _; _; _; _]) ->
      let neqs, env = cong [] env p in
      let fx_fy = th_res p in
      let cl = neqs @ [fx_fy] in
      { env with
        clauses = mk_clause_cl Eqco cl [] :: env.clauses;
        ax = true }

    | Some ("refl", [_; _]) ->
      let x_x = th_res p in
      { env with clauses = mk_clause_cl Eqre [x_x] [] :: env.clauses }


    | Some (rule, _) ->
      (* TODO *)
      failwith (sprintf "Rule %s not implemented" rule)

    | None ->

      match name p with
      | Some h ->
        (* should be an input clause *)
        (try { env with clauses = get_input_id h :: env.clauses }
         with Not_found ->
           { env with
             ax = true;
             assum = List.filter (fun a -> a <> h) env.assum }
        )

      | None -> { env with ax = true }

  

  let result_satlem p = match value p with
    | Lambda ({sname=Name n} as s, r) ->

      begin match app_name s.stype with
        | Some ("holds", [cl]) -> n, cl, r
        | _ -> assert false
      end

    | _ -> assert false

  let continuation_satlem p = match value p with
    | Lambda (_, r) -> r
    | _ -> assert false


  let rec satlem p = match app_name p with

    | Some ("satlem", [c; _; l; p]) ->
      (* eprintf "SATLEM ---@."; *)
      let assumptions, l = get_assumptions [] l in
      let l = trim_junk_satlem l in
      let env = { empty with assum = assumptions } in
      let env =
        List.fold_left (fun env p ->
            let local_env =
              { env with
                clauses = [];
                ax = false;
                mpred = MTerm.empty;
              } in
            let local_env = lem local_env p in
            { env with
              clauses = List.rev_append local_env.clauses env.clauses;
              assum = local_env.assum
            }
          ) env l
      in
      let clauses = (* List.rev *) env.clauses in
      let id = mk_inter_resolution clauses in
      (* eprintf "remaining assumptions:"; *)
      (* List.iter (eprintf "%s, ") env.assu; *)
      (* eprintf "@."; *)
      let cl = to_clause c in
      let satlem_id =
        if env.assum = [] then id else mk_clause Weak cl [id]
      in
      register_clause_id cl satlem_id;
      (* eprintf "--- SATLEM@."; *)
      satlem (continuation_satlem p)

    | _ -> p



  let clause_qr p = match app_name (deref p).ttype with
    | Some ("holds", [cl]) -> get_clause_id (to_clause cl)
    | _ -> raise Not_found


  let rec reso_of_QR acc qr = match app_name qr with
    | Some (("Q"|"R"), [_; _; u1; u2; _]) -> reso_of_QR (reso_of_QR acc u1) u2
    | _ -> clause_qr qr :: acc

  let reso_of_QR qr = reso_of_QR [] qr |> List.rev


  let rec reso_of_satlem_simplify pid p = match app_name p with

    | Some ("satlem_simplify", [_; _; _; qr; p]) ->

      let clauses = reso_of_QR qr in
      let _, res, p = result_satlem p in
      let cl_res = to_clause res in
      let id = mk_clause ~reuse:false Reso cl_res clauses in
      register_clause_id cl_res id; 

      reso_of_satlem_simplify id p

    | None when name p <> None -> pid

    | _ -> assert false


  let convert p =
    p
    |> ignore_all_decls
    |> produce_inputs_preproc
    (* |> ignore_decls *)
    (* |> produce_inputs *)
    (* |> ignore_preproc *)
    |> register_prop_vars
    |> satlem
    |> reso_of_satlem_simplify 0


  let clear () = T.clear ()


end
