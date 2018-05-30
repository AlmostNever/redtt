include module type of Grammar

module I = Grammar.MenhirInterpreter

val loop : Lexing.lexbuf -> I.token Lwt_stream.t -> Refine.esig I.checkpoint -> unit -> unit Lwt.t
