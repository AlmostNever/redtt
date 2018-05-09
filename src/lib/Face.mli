type (_, 'a) face =
  | False : DimStar.t -> ('x, 'a) face
  | True : Dim.t * Dim.t * 'a -> ([`Any], 'a) face
  | Indet : DimStar.t * 'a -> ('x, 'a) face

val map : (Dim.t -> Dim.t -> 'a -> 'b) -> ('x, 'a) face -> ('x, 'b) face

val forall : Dim.atom -> ('x, 'a) face -> [`Delete | `Keep]

module M (X : Sort.S with type 'a m = 'a) :
sig
  type 'x t = ('x, X.t) face
  val act : Dim.action -> ('x, X.t) face -> [`Any] t
end
