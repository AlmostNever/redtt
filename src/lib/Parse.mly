%{
  let make_node start stop con = 
    PTm.(Node {info = (start, stop); con = con})
%}

%token <int> NUMERAL
%token <string> ATOM
%token LEFT_SQUARE
%token RIGHT_SQUARE
%token LEFT_PAREN
%token RIGHT_PAREN
%token EOF

%start <PTm.t option> prog
%%
prog:
  | e = expr 
    { Some e }
  | EOF
    { None }
  ;

expr:
  | LEFT_PAREN; xs = list(expr); RIGHT_PAREN
    { make_node $startpos $endpos @@ PTm.List xs }
  | a = ATOM
    { make_node $startpos $endpos @@ PTm.Atom a }
  | n = NUMERAL
    { make_node $startpos $endpos @@ PTm.Numeral n }
  | LEFT_SQUARE; x = ATOM; RIGHT_SQUARE; e = expr
    { make_node $startpos $endpos @@ PTm.Bind (x, e) }
  ;