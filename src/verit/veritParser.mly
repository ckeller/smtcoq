%{
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

  open VeritSyntax
  open VeritAst


  (*let symbol_to_id s = 
    (* f transforms string "tn" to int n *)
    let f = (fun s -> let l = (String.length s) - 1 in
                      int_of_string (String.sub s 1 l)) in
    (* Subproof steps have labels*)                  
    let syms = List.map f (String.split_on_char '.' s) in
    if (List.length syms == 1) then 
      List.hd syms
    else 
      raise InvalidProofStepNo

  (* transform string "@p_n" to int n *)
  let atsymbol_to_id s = 
    let l = (String.length s) - 3 in
    int_of_string (String.sub s 3 l)

  let parse_bv s =
    let l = ref [] in
    for i = 2 to String.length s - 1 do
      match s.[i] with
      | '0' -> l := false :: !l
      | '1' -> l := true :: !l
      | _ -> assert false
    done;
    !l*)

%}


/*
  définition des lexèmes
*/

%token <string> SYMBOL
%token <string> ATSYMBOL
%token <string> ISYMBOL
%token <string> SPECCONST
%token <string> KEYWORD
%token <string> STRING
%token <int> INT
%token <Big_int.big_int> BIGINT

%token LPAREN RPAREN EOF EOL COLON BANG COLEQ
%token COLRULE COLSTEP COLARGS COLPREMISES COLDISCHARGE
%token ASSUME STEP ANCHOR DEFINEFUN CL ASTOK CHOICE
%token LET FORALL EXISTS MATCH TINT TBOOL NAMED

%token TRUE FALSE NOT IMPLIES AND OR XOR DIST ITE
%token NOTNOT
%token THRESO RESO TAUT CONT
%token REFL TRANS CONG EQRE EQTR EQCO EQCP
%token NOTOR NOTAND XOR1 XOR2 NXOR1 NXOR2 IMP NIMP1 NIMP2
%token EQU1 EQU2 NEQU1 NEQU2 ANDP ANDN ORP ORN
%token XORP1 XORP2 XORN1 XORN2 IMPP IMPN1 IMPN2
%token EQUP1 EQUP2 EQUN1 EQUN2
%token ITE1 ITE2 ITEP1 ITEP2 ITEN1 ITEN2 NITE1 NITE2
%token CONNDEF ANDSIMP ORSIMP NOTSIMP IMPSIMP
%token EQSIMP BOOLSIMP ACSIMP ITESIMP EQUALSIMP DISTELIM
%token EQ LT LEQ GT GEQ PLUS MINUS MULT
%token LAGE LIAGE LATA LADE DIVSIMP PRODSIMP 
%token UMINUSSIMP MINUSSIMP SUMSIMP COMPSIMP LARWEQ
%token FINS BIND QCNF SUBPROOF
%token SYMM REORD ALLSIMP
(*%token BBVA BBCONST BBEQ BBDIS BBOP BBNOT BBNEG BBADD
%token BBMUL BBULT BBSLT BBCONC BBEXTR BBZEXT BBSEXT
%token BBSHL BBSHR BVAND BVOR BVXOR BVADD BVMUL BVULT 
%token BVSLT BVULE BVSLE BVCONC BVEXTR BVZEXT BVSEXT
%token BVNOT BVNEG BVSHL BVSHR
%token <string> BITV*)

%start proof
%type <VeritAst.certif> proof


%type <string> argument
%type <string list> arguments
%type <VeritAst.clause> clause
%type <string list> discharge
%type <VeritAst.term> ident
%type <VeritAst.step> line
%type <VeritAst.term list> list(term)
%type <string list> nonempty_list(SYMBOL)
%type <string list> nonempty_list(argument)
%type <VeritAst.step list> nonempty_list(line)
%type <(string * VeritAst.typ) list> nonempty_list(sorted_var)
%type <VeritAst.term list> nonempty_list(term)
%type <(string list) option> option(arguments)
%type <VeritAst.params option> option(premises)
%type <VeritAst.params> premises
%type <VeritAst.rule> rulename
%type <VeritAst.typ> sort
%type <string * VeritAst.typ> sorted_var
%type <VeritAst.step> subproof
%type <VeritAst.step list> subproofline
%type <VeritAst.term> term


//%type <VeritAst.step> line
%%




proof:
  | l=line+ EOF { l }
;

line:
  | LPAREN ASSUME s=SYMBOL t=term RPAREN EOL
    { mk_step (s, AssumeAST, mk_cl [t], [], []) }
  | LPAREN STEP s=SYMBOL c=clause COLRULE r=rulename p=premises? a=arguments? RPAREN EOL
    { match p, a with
      | None, None -> mk_step (s, r, c, [], [])
      | Some prems, None -> mk_step (s, r, c, prems, []) 
      | None, Some args -> mk_step (s, r, c, [], args) 
      | Some prems, Some args -> mk_step (s, r, c, prems, args) }
  | LPAREN ANCHOR COLSTEP s=SYMBOL arguments RPAREN EOL
    { mk_step ((generate_id ()), AnchorAST, [], [s], []) }
  | s=subproof { s }
;

subproofline:
  | LPAREN ASSUME s=SYMBOL t=term RPAREN EOL
    sl=subproofline
    { mk_step (s, AssumeAST, mk_cl [t], [], []) :: sl }
  | LPAREN STEP s=SYMBOL c=clause COLRULE r=rulename p=premises? a=arguments? RPAREN EOL
    sl=subproofline
    { let st = (match p, a with
        | None, None -> mk_step (s, r, c, [], [])
        | Some prems, None -> mk_step (s, r, c, prems, []) 
        | None, Some args -> mk_step (s, r, c, [], args) 
        | Some prems, Some args -> mk_step (s, r, c, prems, args)) in
      st :: sl }
  | LPAREN ANCHOR COLSTEP s=SYMBOL arguments RPAREN EOL
    sl=subproofline
    { mk_step ((generate_id ()), AnchorAST, [], [s], []) :: sl }
  | LPAREN STEP s=SYMBOL c=clause COLRULE SUBPROOF discharge RPAREN EOL
    { mk_step(s, DischargeAST, c, [], []) :: [] }
  | sp=subproof
    sl=subproofline { sp :: sl }
;

subproof:
  | LPAREN ANCHOR COLSTEP s=SYMBOL RPAREN EOL 
    l=subproofline
    { mk_step (s, SubproofAST l, [], [], []) }
;

premises:
  | COLPREMISES LPAREN prems=SYMBOL+ RPAREN { prems }
;

arguments:
  | COLARGS LPAREN args=argument+ RPAREN { args }
;

discharge:
  | COLDISCHARGE LPAREN hyps=SYMBOL+ RPAREN { hyps }
;

(* TODO: Rules with args need to be parsed properly *)
argument:
  | s=SYMBOL                                { s }
  | LPAREN s=SYMBOL RPAREN                  { s } (* Negative ints are parameterized *)
  | LPAREN MINUS i=INT RPAREN               { string_of_int (-i) }
  | i=INT                                   { string_of_int i }
  | LPAREN COLEQ sv=sorted_var s=SYMBOL RPAREN 
    { s } (* Need to process these properly *)
  | LPAREN COLEQ s1=SYMBOL s2=SYMBOL RPAREN { s1 }
;
  
ident:
  | s=SYMBOL                                { Var s }
  | i=ISYMBOL                               { Var i }
;

clause:
  | LPAREN CL ts=term* RPAREN               { mk_cl ts }
;

term:
  (* Shared terms *)
  | LPAREN BANG t=term NAMED a=ATSYMBOL RPAREN
    { NTerm (a, t) }
  | a=ATSYMBOL                              { STerm a }

  (* Formulas *)
  | TRUE                                    { True }
  | FALSE                                   { False }
  | LPAREN NOT t=term RPAREN                { Not t }  
  | LPAREN AND ts=term* RPAREN              { And ts }
  | LPAREN OR ts=term* RPAREN               { Or ts }
  | LPAREN IMPLIES ts=term* RPAREN          { Imp ts }
  | LPAREN XOR ts=term* RPAREN              { Xor ts }
  | LPAREN ITE ts=term* RPAREN
    { Ite ts }
  | LPAREN FORALL LPAREN vs=sorted_var+ RPAREN t=term RPAREN
    { Forall (vs, t) }
  (*| LPAREN LET LPAREN vs=var_binding+ RPAREN term RPAREN
    { Exists (vs, t) }*)

  (* Atoms *)
  | i=INT                                   { Int i }
  (*| b=BIGINT                              {}
  | b=BITV                                  {}*)
  | LPAREN LT x=term y=term RPAREN          { Lt (x, y) }
  | LPAREN LEQ x=term y=term RPAREN         { Leq  (x, y) }
  | LPAREN GT x=term y=term RPAREN          { Gt (x, y) }
  | LPAREN GEQ x=term y=term RPAREN         { Geq (x, y) }
  | LPAREN MINUS x=term RPAREN              { UMinus x }
  | LPAREN PLUS x=term y=term RPAREN        { Plus (x, y) }
  | LPAREN MINUS x=term y=term RPAREN       { Minus (x, y) }
  | LPAREN MULT x=term y=term RPAREN        { Mult (x, y) }
  (*| LPAREN DIST terms=term* RPAREN        {}
  | LPAREN BVNOT t=term RPAREN              {}
  | LPAREN BVAND t1=term t2=term RPAREN     {}
  | LPAREN BVOR t1=term t2=term RPAREN      {}
  | LPAREN BVXOR t1=term t2=term RPAREN     {}
  | LPAREN BVNEG t=term RPAREN              {}
  | LPAREN BVADD t1=term t2=term RPAREN     {}
  | LPAREN BVMUL t1=term t2=term RPAREN     {}
  | LPAREN BVULT t1=term t2=term RPAREN     {}
  | LPAREN BVSLT t1=term t2=term RPAREN     {}
  | LPAREN BVULE t1=term t2=term RPAREN     {}
  | LPAREN BVSLE t1=term t2=term RPAREN     {}
  | LPAREN BVSHL t1=term t2=term RPAREN     {}
  | LPAREN BVSHR t1=term t2=term RPAREN     {}
  | LPAREN BVCONC t1=term t2=term RPAREN    {}
  | LPAREN BVEXTR j=INT i=INT t=term RPAREN {}
  | LPAREN BVZEXT n=INT t=term RPAREN       {}
  | LPAREN BVSEXT n=INT t=term RPAREN       {}*)
  | i=ident                                 { i }
  | LPAREN f=SYMBOL l=term+ RPAREN          { App (f,l) }
  | LPAREN EQ t1=term t2=term RPAREN        { Eq (t1, t2) }
  (*| LPAREN EXISTS LPAREN sorted_var+ RPAREN term RPAREN { "" }
  | LPAREN MATCH term LPAREN match_case+ RPAREN RPAREN { "" }
  | LPAREN BANG term attr+ RPAREN { "" }*)
;

sort:
  | TINT                                    { Int }
  | TBOOL                                   { Bool }
;

sorted_var:
  | LPAREN s=SYMBOL t=sort RPAREN           { (s,t) }
;

rulename:
  | ASSUME                                  { AssumeAST }
  | TRUE                                    { TrueAST }
  | FALSE                                   { FalsAST }
  | NOTNOT                                  { NotnotAST }
  | THRESO                                  { ThresoAST }
  | RESO                                    { ResoAST }
  | TAUT                                    { TautAST }
  | CONT                                    { ContAST }
  | REFL                                    { ReflAST }
  | TRANS                                   { TransAST }
  | CONG                                    { CongAST }
  | EQRE                                    { EqreAST }
  | EQTR                                    { EqtrAST }
  | EQCO                                    { EqcoAST }
  | EQCP                                    { EqcpAST }
  | AND                                     { AndAST }
  | NOTOR                                   { NorAST }
  | OR                                      { OrAST }
  | NOTAND                                  { NandAST }
  | XOR1                                    { Xor1AST }
  | XOR2                                    { Xor2AST }
  | NXOR1                                   { Nxor1AST }
  | NXOR2                                   { Nxor2AST }
  | IMP                                     { ImpAST }
  | NIMP1                                   { Nimp1AST }
  | NIMP2                                   { Nimp2AST }
  | EQU1                                    { Equ1AST }
  | EQU2                                    { Equ2AST }
  | NEQU1                                   { Nequ1AST }
  | NEQU2                                   { Nequ2AST }
  | ANDP                                    { AndpAST }
  | ANDN                                    { AndnAST }
  | ORP                                     { OrpAST }
  | ORN                                     { OrnAST }
  | XORP1                                   { Xorp1AST }
  | XORP2                                   { Xorp2AST }
  | XORN1                                   { Xorn1AST }
  | XORN2                                   { Xorn2AST }
  | IMPP                                    { ImppAST }
  | IMPN1                                   { Impn1AST }
  | IMPN2                                   { Impn2AST }
  | EQUP1                                   { Equp1AST }
  | EQUP2                                   { Equp2AST }
  | EQUN1                                   { Equn1AST }
  | EQUN2                                   { Equn2AST }
  | ITE1                                    { Ite1AST }
  | ITE2                                    { Ite2AST }
  | ITEP1                                   { Itep1AST }
  | ITEP2                                   { Itep2AST }
  | ITEN1                                   { Iten1AST }
  | ITEN2                                   { Iten2AST }
  | NITE1                                   { Nite1AST }
  | NITE2                                   { Nite2AST }
  | CONNDEF                                 { ConndefAST }
  | ANDSIMP                                 { AndsimpAST }
  | ORSIMP                                  { OrsimpAST }
  | NOTSIMP                                 { NotsimpAST }
  | IMPSIMP                                 { ImpsimpAST }
  | EQSIMP                                  { EqsimpAST }
  | BOOLSIMP                                { BoolsimpAST }
  (*| ACSIMP                                  { HoleAST }*)
  | ITESIMP                                 { ItesimpAST }
  | EQUALSIMP                               { EqualsimpAST }
  | DISTELIM                                { DistelimAST }
  | LAGE                                    { LageAST }
  | LIAGE                                   { LiageAST }
  | LATA                                    { LataAST} 
  | LADE                                    { LadeAST }
  | DIVSIMP                                 { DivsimpAST} 
  | PRODSIMP                                { ProdsimpAST }
  | UMINUSSIMP                              { UminussimpAST }
  | MINUSSIMP                               { MinussimpAST }
  | SUMSIMP                                 { SumsimpAST }
  | COMPSIMP                                { CompsimpAST }
  | LARWEQ                                  { LarweqAST}
  | BIND                                    { BindAST }
  | FINS                                    { FinsAST }
  | QCNF                                    { QcnfAST }
  | SYMM                                    { SameAST }
  | REORD                                   { SameAST }
  | ALLSIMP                                 { AllsimpAST }
(*function_def:
  | SYMBOL LPAREN sorted_var* RPAREN sort term { "" }
;

var_binding:
  | LPAREN SYMBOL term RPAREN { "" }
;
pattern:
  | SYMBOL { "" }
  | LPAREN SYMBOL SYMBOL+ RPAREN { "" }
;

match_case:
  | LPAREN pattern term RPAREN { "" }
;*)
