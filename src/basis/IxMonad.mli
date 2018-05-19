module type S =
sig
  type ('i, 'o, 'a) m
  val ret : 'a -> ('i, 'i, 'a) m
  val bind : ('i, 'j, 'a) m -> ('a -> ('j, 'k, 'b) m) -> ('i, 'k, 'b) m
end

module type Notation =
sig
  type ('i, 'o, 'a) m

  val (>>=) : ('i, 'j, 'a) m -> ('a -> ('j, 'k, 'b) m) -> ('i, 'k, 'b) m
  val (>>) : ('i, 'j, 'a) m -> ('j, 'k, 'b) m -> ('i, 'k, 'b) m
  val (<$>) : ('a -> 'b) -> ('i, 'o, 'a) m -> ('i, 'o, 'b) m
end

module Notation (M : S) : Notation
  with type ('i, 'o, 'a) m := ('i, 'o, 'a) M.m

