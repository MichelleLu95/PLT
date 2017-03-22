%{
open Ast
%}

%token SEMI LPAREN RPAREN LBRACE RBRACE COMMA BAR COLON LSQBRACE RSQBRACE
%token PLUS MINUS TIMES DIVIDE ASSIGN NOT MMINUS MTIMES MDIVIDE PLUSEQ
%token EQ NEQ LT LEQ GT GEQ TRUE FALSE AND OR MEQ
%token RETURN IF ELSE FOR WHILE INT BOOL VOID MATRIX ROW FLOAT COLUMN FILE TUPLE

%token <int> INT_LIT
%token <string> ID
%token <string> STRING_LIT
%token <bool> BOOL_LIT
%token <float> FLOAT_LIT

%token EOF

%nonassoc NOELSE
%nonassoc ELSE
%right ASSIGN
%left OR
%left AND
%left EQ NEQ
%left LT GT LEQ GEQ MEQ
%left PLUS MINUS MPLUS MMINUS PLUSEQ
%left TIMES DIVIDE MTIMES MDIVIDE
%right NOT NEG

%start program
%type <Ast.program> program

%%

program:
  decls EOF { $1 }

decls:
   /* nothing */ { [], [] }
 | decls vdecl { ($2 :: fst $1), snd $1 }
 | decls fdecl { fst $1, ($2 :: snd $1) }

fdecl:
   DEF typ ID LPAREN formals_opt RPAREN LBRACE vdecl_list stmt_list RBRACE
     { { typ = $1;
	 fname = $2;
	 formals = $4;
	 locals = List.rev $7;
	 body = List.rev $8 } }

formals_opt:
    /* nothing */ { [] }
  | formal_list   { List.rev $1 }

formal_list:
    typ ID                   { [($1,$2)] }
  | formal_list COMMA typ ID { ($3,$4) :: $1 }

typ:
	primitive { typ($1) }
  | INT { Int }
  | BOOL { Bool }
  | VOID { Void }
  | MATRIX { Matrix }
  | ROW { Row }
  | FLOAT { Float }
  | COLUMN { Column }
  | FILE { File }
  | matrix_typ { $1 }
  | row_typ { $1 }
  | column_typ { $1 }
  | tuple_typ { $1 }

matrix_typ:
  primitive ID LSQBRACE INT_LITERAL RSQBRACE LSQBRACE INT_LITERAL RSQBRACE SEMI { MatrixTyp($2, $4, $7) }

row_typ:
  primitive ID LSQBRACE INT_LITERAL RSQBRACE SEMI { RowTyp($2, $4) }

column_typ:
  primitive ID LSQBRACE INT_LITERAL RSQBRACE SEMI { ColumnTyp($2, $4) }

tuple_typ:
  INT ID LPAREN INT_LITERAL RPAREN SEMI { TupleTyp($2, $4) }

primitive:
  	INT { Int }
  | BOOL { Bool }
  | VOID { Void }
  | FLOAT { Float }
  | TUPLE { Tuple }

vdecl_list:
    /* nothing */    { [] }
  | vdecl_list vdecl { $2 :: $1 }

vdecl:
   typ ID SEMI { ($1, $2) }

stmt_list:
    /* nothing */  { [] }
  | stmt_list stmt { $2 :: $1 }

stmt:
    expr SEMI { Expr $1 }
  | RETURN SEMI { Return Noexpr }
  | RETURN expr SEMI { Return $2 }
  | LBRACE stmt_list RBRACE { Block(List.rev $2) }
  | IF LPAREN expr RPAREN stmt %prec NOELSE { If($3, $5, Block([])) }
  | IF LPAREN expr RPAREN stmt ELSE stmt    { If($3, $5, $7) }
  | IF LPAREN expr RPAREN stmt ELIF stmt %prec NOELSE { If($3, $5, $7, Block([])) }
  | IF LPAREN expr RPAREN stmt ELIF stmt ELSE stmt { If($3, $5, $7, $9) }
  | FOR LPAREN expr_opt SEMI expr SEMI expr_opt RPAREN stmt
     { For($3, $5, $7, $9) }
  | FOR LPAREN expr IN expr RPAREN stmt { For($3, $5, $7) }
  | WHILE LPAREN expr RPAREN stmt { While($3, $5) }

expr_opt:
    /* nothing */ { Noexpr }
  | expr          { $1 }

expr:
    literals          { $1 }
  | TRUE             { BoolLit(true) }
  | FALSE            { BoolLit(false) }
  | ID               { Id($1) }
  | expr PLUS   expr { Binop($1, Add,   $3) }
  | expr MINUS  expr { Binop($1, Sub,   $3) }
  | expr TIMES  expr { Binop($1, Mult,  $3) }
  | expr DIVIDE expr { Binop($1, Div,   $3) }
  | expr EQ     expr { Binop($1, Equal, $3) }
  | expr NEQ    expr { Binop($1, Neq,   $3) }
  | expr LT     expr { Binop($1, Less,  $3) }
  | expr LEQ    expr { Binop($1, Leq,   $3) }
  | expr GT     expr { Binop($1, Greater, $3) }
  | expr GEQ    expr { Binop($1, Geq,   $3) }
  | expr AND    expr { Binop($1, And,   $3) }
  | expr OR     expr { Binop($1, Or,    $3) }
  | expr MPLUS  expr { Binop($1, Madd,  $3) }
  | expr MMINUS expr { Binop($1, Msub,  $3) }
  | expr MTIMES expr { Binop($1, Mmult, $3) }
  | expr MDIVIDE expr{ Binop($1, Mdiv,  $3) }
  | expr MEQ    expr { Binop($1, Meq,   $3) }
  | expr PLUSEQ expr { Binop($1, PlusEq,$3) }
  | MINUS expr %prec NEG { Unop(Neg, $2) }
  | NOT expr         { Unop(Not, $2) }
  | ID ASSIGN expr   { Assign($1, $3) }
  | ID LPAREN actuals_opt RPAREN { Call($1, $3) }
  | LPAREN expr RPAREN { $2 }


primitives:
	INT_LIT { IntLit($1) }
  | FLOAT_LIT { FloatLit($1) }

literals:
	primitives { $1 }
  |	tuple_literal	{ $1 }
  |	LSQBRACE primitive_rowlit RSQBRACE { RowLit(List.Rev $2) }
  | LSQBRACE tuple_rowlit RSQBRACE { RowLit(List.Rev $2) }
  | LSQBRACE primitive_columnlit RSQBRACE { ColumnLit(List.Rev $2) }
  | LSQBRACE tuple_columnlit RSQBRACE { ColumnLit(List.Rev $2) }
  | LBRACE primitive_matrixlit RBRACE { MatrixLit(List.Rev $2) }
  | LBRACE tuple_matrixlit RBRACE { MatrixLit(List.Rev $2) }


tuple_literal:
	LPAREN INT COMMA INT COMMA INT RPAREN { TupleLit($1, $3, $5) }

primitive_rowlit:
	primitives { $1 }
  | primitive_rowlit COMMA primitives { $3 :: $1 }

primitive_columnlit:
	primitives { $1 }
  | primitive_columnlit BAR primitives { $3 :: $1 }	

tuple_rowlit:
	tuple_literal { $1 } 
  | tuple_rowlit COMMA tuple_literal { $3 :: $1 }

tuple_columnlit:
	tuple_literal { $1 }
  | tuple_columnlit BAR primitives { $3 :: $1 }

tuple_matrixlit:
	LSQBRACE tuple_rowlit RSQBRACE { $2 }
  | tuple_matrixlit COMMA LSQBRACE tuple_rowlit RSQBRACE { $4 :: $1 }
	
primitive_matrixlit:
	LSQBRACE primitive_rowlit RSQBRACE { $2 }
  | primitive_matrixlit COMMA LSQBRACE primitive_rowlit RSQBRACE { $4 ::$1 }
	

actuals_opt:
    /* nothing */ { [] }
  | actuals_list  { List.rev $1 }

actuals_list:
    expr                    { [$1] }
  | actuals_list COMMA expr { $3 :: $1 }