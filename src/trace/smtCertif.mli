(**************************************************************************)
(*                                                                        *)
(*     SMTCoq                                                             *)
(*     Copyright (C) 2011 - 2022                                          *)
(*                                                                        *)
(*     See file "AUTHORS" for the list of authors                         *)
(*                                                                        *)
(*   This file is distributed under the terms of the CeCILL-C licence     *)
(*                                                                        *)
(**************************************************************************)


type used = int
type clause_id = int
type 'hform rule =
  (* Weakening *)
  | Weaken of 'hform clause * 'hform list
     (*  * weaken          : {a_1 ... a_n} --> {a_1 ... a_n b_1 ... b_m} *)

  (* Simplification *)
  | ImmFlatten of 'hform clause * 'hform

  (* CNF Transformations *)
  | True
     (*  * true             : {true}
     *)
  | False
     (* * false             : {(not false)}
     *)
  | BuildDef of 'hform (* the first literal of the clause *)
     (*  * and_neg          : {(and a_1 ... a_n) (not a_1) ... (not a_n)}
         * or_pos           : {(not (or a_1 ... a_n)) a_1 ... a_n}
         * implies_pos      : {(not (implies a b)) (not a) b}
         * xor_pos1         : {(not (xor a b)) a b}
         * xor_neg1         : {(xor a b) a (not b)}
         * equiv_pos1       : {(not (iff a b)) a (not b)}
         * equiv_neg1       : {(iff a b) (not a) (not b)}
         * ite_pos1         : {(not (if_then_else a b c)) a c}
         * ite_neg1         : {(if_then_else a b c) a (not c)}
     *)
  | BuildDef2 of 'hform (* the first literal of the clause *)
     (* * xor_pos2          : {(not (xor a b)) (not a) (not b)}
        * xor_neg2          : {(xor a b) (not a) b}
        * equiv_pos2        : {(not (iff a b)) (not a) b}
        * equiv_neg2        : {(iff a b) a b}
        * ite_pos2          : {(not (if_then_else a b c)) (not a) b}
        * ite_neg2          : {(if_then_else a b c) (not a) (not b)}

     *)
  | BuildProj of 'hform * int
     (*  * or_neg           : {(or a_1 ... a_n) (not a_i)}
         * and_pos          : {(not (and a_1 ... a_n)) a_i}
         * implies_neg1     : {(implies a b) a}
         * implies_neg2     : {(implies a b) (not b)}
     *)

  (* Immediate CNF transformation : CNF transformation + Reso *)
  | ImmBuildDef of 'hform clause
     (* * not_and           : {(not (and a_1 ... a_n))} --> {(not a_1) ... (not a_n)}
        * or                : {(or a_1 ... a_n)} --> {a_1 ... a_n}
        * implies           : {(implies a b)} --> {(not a) b}
        * xor1              : {(xor a b)} --> {a b}
        * not_xor1          : {(not (xor a b))} --> {a (not b)}
        * equiv2            : {(iff a b)} --> {a (not b)}
        * not_equiv2        : {(not (iff a b))} --> {(not a) (not b)}
        * ite1              : {(if_then_else a b c)} --> {a c}
        * not_ite1          : {(not (if_then_else a b c))} --> {a (not c)}
     *)
  | ImmBuildDef2 of 'hform clause
     (* * xor2              : {(xor a b)} --> {(not a) (not b)}
        * not_xor2          : {(not (xor a b))} --> {(not a) b}
        * equiv1            : {(iff a b)} --> {(not a) b}
        * not_equiv1        : {(not (iff a b))} --> {a b}
        * ite2              : {(if_then_else a b c)} --> {(not a) b}
        * not_ite2          : {(not (if_then_else a b c))} --> {(not a) (not b)}
     *)
  | ImmBuildProj of 'hform clause * int
     (*  * and               : {(and a_1 ... a_n)} --> {a_i}
         * not_or            : {(not (or a_1 ... a_n))} --> {(not a_i)}
         * not_implies1      : {(not (implies a b))} --> {a}
         * not_implies2      : {(not (implies a b))} --> {(not b)}
     *)

  (* Equality *)
  | EqTr of 'hform * 'hform list
    (*  * eq_reflexive     : {(= x x)}
        * eq_transitive    : {(not (= x_1 x_2)) ... (not (= x_{n-1} x_n)) (= x_1 x_n)}
    *)
  | EqCgr of 'hform * ('hform option) list
    (*  * eq_congruent     : {(not (= x_1 y_1)) ... (not (= x_n y_n))
                                   (= (f x_1 ... x_n) (f y_1 ... y_n))}
    *)
  | EqCgrP of 'hform * 'hform * ('hform option) list
    (*  * eq_congruent_pred : {(not (= x_1 y_1)) ... (not (= x_n y_n))
                                   (not (p x_1 ... x_n)) (p y_1 ... y_n)}
    *)

  (* Linear arithmetic *)
  | LiaMicromega of 'hform list * CoqInterface.Micromega_plugin_Certificate.Mc.zArithProof list
  | LiaDiseq of 'hform

  (* Arithmetic simplifications *)
  | SplArith of 'hform clause * 'hform * CoqInterface.Micromega_plugin_Certificate.Mc.zArithProof list

  (* Elimination of operators *)
  | SplDistinctElim of 'hform clause * 'hform

  (* Bit-blasting *)
  | BBVar of 'hform
  (* Bit-blasting a variable:

       ----------------------- bbVar
        bbT(x, [x0; ...; xn])
   *)
  | BBConst of 'hform
  (* Bit-blasting a constant:

       ----------------------- bbConst
        bbT(#0100, [0; 0; 1; 0])
   *)
  | BBOp of 'hform clause * 'hform clause * 'hform
  (* Bit-blasting bitwise operations: bbAnd, bbOr, ...
        bbT(a, [a0; ...; an])      bbT(b, [b0; ...; bn])
       -------------------------------------------------- bbAnd
             bbT(a&b, [a0 /\ b0; ...; an /\ bn])
   *)
  | BBNot of 'hform clause * 'hform
  (* Bit-blasting bitvector not
           bbT(a, [a0; ...; an])
       ------------------------------ bbNot
        bbT(not a, [~a0 ; ...; ~an])
   *)
  | BBNeg of 'hform clause * 'hform
  (* Bit-blasting bitvector negation
           bbT(a, [a0; ...; an])
       ------------------------------ bbNot
        bbT(-a, [...])
   *)
  | BBAdd of 'hform clause * 'hform clause * 'hform
  (* Bit-blasting bitvector addition
        bbT(a, [a0; ...; an])      bbT(b, [b0; ...; bn])
       -------------------------------------------------- bbAnd
             bbT(a+b, [...])
   *)
  | BBMul of 'hform clause * 'hform clause * 'hform
  (* Bit-blasting bitvector multiplication
        bbT(a, [a0; ...; an])      bbT(b, [b0; ...; bn])
       -------------------------------------------------- bbAnd
             bbT(a*b, [...])
   *)
  | BBUlt of 'hform clause * 'hform clause * 'hform
  (* Bit-blasting bitvector unsigned comparison
        bbT(a, [a0; ...; an])      bbT(b, [b0; ...; bn])
       -------------------------------------------------- bbAnd
             bvult a b <-> ...
   *)
  | BBSlt of 'hform clause * 'hform clause * 'hform
  (* Bit-blasting bitvector signed comparison
        bbT(a, [a0; ...; an])      bbT(b, [b0; ...; bn])
       -------------------------------------------------- bbAnd
             bvslt a b <-> ...
   *)
  | BBConc of 'hform clause * 'hform clause * 'hform
  (* Bit-blasting bitvector concatenation
        bbT(a, [a0; ...; an])      bbT(b, [b0; ...; bn])
       -------------------------------------------------- bbConc
             bbT(concat a b, [a0; ...; an; b0; ...; bn])
   *)
  | BBExtr of 'hform clause * 'hform
  (* Bit-blasting bitvector extraction
             bbT(a, [a0; ...; an])
       ----------------------------------- bbExtr
        bbT(extract i j a, [ai; ...; aj])
   *)
  | BBZextn of 'hform clause * 'hform
  | BBSextn of 'hform clause * 'hform
  (* Bit-blasting bitvector extensions

  *)
  | BBShl of 'hform clause * 'hform clause * 'hform
  (* Bit-blasting bitvector shift left *)
  | BBShr of 'hform clause * 'hform clause * 'hform
  (* Bit-blasting bitvector shift right *)
  | BBEq of 'hform clause * 'hform clause * 'hform
  (* Bit-blasting equality
        bbT(a, [a0; ...; an])      bbT(b, [b0; ...; bn])
       -------------------------------------------------- bbEq
         (a = b) <-> [(a0 <-> b0) /\ ... /\ (an <-> bn)]
   *)

  | BBDiseq of 'hform
  (* disequality over constant bitvectors

       ----------------------------- bbDiseq
         #b000010101 <> #b00000000
   *)

  | RowEq of 'hform
  (* Read over write same index
       ------------------------------- roweq
         select (store a i v) i = v
   *)

  | RowNeq of 'hform list
  (* Read over write other index
       ------------------------------------------------- rowneq
         i <> j -> select (store a i v) j = select a j
   *)

  | Ext of 'hform
  (* Extensionality over arrays
       ------------------------------------------------------- ext
         a = b \/ select a (diff a b) <> select b (diff a b)
   *)

  (* Possibility to introduce "holes" in proofs (that should be filled in Coq) *)
  | Hole of ('hform clause) list * 'hform list
  | Forall_inst of 'hform clause * 'hform
  | Qf_lemma of 'hform clause * 'hform

and 'hform clause = {
    mutable id    : clause_id;
    mutable kind  : 'hform clause_kind;
    mutable pos   : int option;
    mutable used  : used;
    mutable prev  : 'hform clause option;
    mutable next  : 'hform clause option;
    mutable value : 'hform list option;
}
and 'hform clause_kind =
    Root
  | Same of 'hform clause
  | Res of 'hform resolution
  | Other of 'hform rule
and 'hform resolution = {
  mutable rc1 : 'hform clause;
  mutable rc2 : 'hform clause;
  mutable rtail : 'hform clause list;
}
val used_clauses : 'a rule -> 'a clause list
val to_string : 'a clause_kind -> string
val print_certif : ('a -> Format.formatter -> 'b -> unit) -> 'a -> 'b clause -> string -> unit
