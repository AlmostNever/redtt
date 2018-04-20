(* sorts *)
type can
type neu

type tclo
type bclo
type sclo

module Tube :
sig
  type equ = DimVal.equ
  type 'a t = 
    | Indeterminate of equ * 'a
    | True of 'a
    | False of equ
    | Delete
end

type 'a tube = 'a Tube.t
type 'a system = 'a tube list

type 'a t

type _ f =
  | Lvl : int -> neu f

  | Up : can t * neu t -> can f

  | Pi : tclo * bclo -> can f
  | Sg : tclo * bclo -> can f
  | Ext : bclo * sclo -> can f

  | Univ : Lvl.t -> can f
  | Interval : can f

  | Dim0 : can f
  | Dim1 : can f
  | DimGen : can f

  | Bool : can f
  | Tt : can f
  | Ff : can f
  | If : {mot : bclo; scrut : neu t; tcase : tclo; fcase : tclo} -> neu f

  | Lam : bclo -> can f
  | Cons : tclo * tclo -> can f

  | Coe : {dim0 : DimVal.t; dim1 : DimVal.t; ty : bclo; tm : can t} -> can f
  | HCom : {dim0 : DimVal.t; dim1 : DimVal.t; ty : can t; cap : can t; sys : bclo system} -> can f

  | FunApp : neu t * can t -> neu f
  | ExtApp : neu t * DimVal.t -> neu f

  | Car : neu t -> neu f
  | Cdr : neu t -> neu f

val into : 'a f -> 'a t
val out : 'a t -> 'a f


module Env : 
sig
  type el = can t

  type t
  val emp : t
  val ext : t -> el -> t

  include DimRel.S with type t := t

  val set_rel : DimRel.t -> t -> t
end


type env = Env.t


val eval : env -> 'a Tm.t -> can t

val project_dimval : can t -> DimVal.t
val embed_dimval : DimVal.t -> can t

val eval_clo : tclo -> can t
val inst_bclo : bclo -> can t -> can t

val apply : can t -> can t -> can t
val car : can t -> can t
val cdr : can t -> can t

val out_pi : can t -> tclo * bclo
val out_sg : can t -> tclo * bclo
val out_ext : can t -> bclo * sclo

val generic : can t -> int -> can t
val reflect : can t -> neu t -> can t