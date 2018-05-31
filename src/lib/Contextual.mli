open RedBasis
open Dev

include Monad.S

val ask : params m
val local : (params -> params) -> 'a m -> 'a m

val popl : entry m
val popr : entry m
val popr_opt : entry option m

val optional : 'a m -> 'a option m

val pushl : entry -> unit m
val pushr : entry -> unit m
val pushls : entry list -> unit m

val go_to_top : unit m
val go_to_bottom : unit m
val go_left : unit m
val go_right : unit m

val in_scope : Name.t -> param -> 'a m -> 'a m
val lookup_var : Name.t -> twin -> ty m
val lookup_meta : Name.t -> ty m

val postpone : status -> problem -> unit m
val active : problem -> unit m
val block : problem -> unit m


val check : ty:ty -> tm -> bool m
val check_eq : ty:ty -> tm -> tm -> bool m


val get_global_cx : Subst.t m
val typechecker : (module Typing.S) m

val dump_state : Format.formatter -> string -> unit m

val run : 'a m -> 'a
