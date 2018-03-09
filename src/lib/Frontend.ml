open Lexing

let print_position outx lexbuf =
  let pos = lexbuf.lex_curr_p in
  Format.fprintf outx "%s:%d:%d" pos.pos_fname
    pos.pos_lnum (pos.pos_cnum - pos.pos_bol + 1)

let parse_with_error lexbuf =
  try Parse.prog Lex.read lexbuf with
  | Lex.SyntaxError msg ->
    Format.fprintf Format.err_formatter "%a: %s\n" print_position lexbuf msg;
    None
  | Parse.Error ->
    Format.fprintf Format.err_formatter "%a: syntax error\n" print_position lexbuf;
    exit (-1)

module Resolver = PTm.Resolver (PTm.ResEnv)

let rec parse_and_print lexbuf =
  match parse_with_error lexbuf with
  | Some ptree ->
    Format.printf "foo\n";
    let tm = Resolver.inf PTm.ResEnv.init ptree in
    Format.printf "%a\n" (Tm.Pretty.pp_inf Tm.Pretty.Env.emp) tm;
    (* Format.printf "%a\n" Json.output_value value; *)
    parse_and_print lexbuf
  | None -> ()


let load_file filename =
  let ch = open_in filename in
  let lexbuf = Lexing.from_channel ch in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
  parse_and_print lexbuf;
  close_in ch
