type (_, 'a) face =
  | False : DimStar.t -> ('x, 'a) face
  | True : Dim.t * Dim.t * 'a -> ([`Any], 'a) face
  | Indet : DimStar.t * 'a -> ('x, 'a) face

module M (X : Sort.S with type 'a m = 'a) :
sig
  type 'x t = ('x, X.t) face
  val act : Dim.action -> ('x, X.t) face -> [`Any] t
end
