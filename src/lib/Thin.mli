type ('x, 'a) f = 
  | Id
  | Keep of 'a
  | Skip of 'a
  | Sub of 'a * 'x

type 'x t
type t0 = Void.t t

val id : 'x t
val keep : 'x t -> 'x t
val skip : 'x t -> 'x t
val sub : 'x t -> 'x -> 'x t

val out : 'x t -> ('x, 'x t) f
