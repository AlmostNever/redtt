open RedBasis.Bwd
include module type of TmData


type tm

type ('a, 'k) telescope =
  | TNil of 'k
  | TCons of 'a * ('a, 'k) telescope bnd

module NewDesc :
sig
  type bface = tm * tm * tm
  type bsys = bface list

  type const_spec = [`Const of tm]
  type rec_spec = [`Rec]
  type dim_spec = [`I]

  type boundary_spec = bsys
  type param_spec = [`Param of tm]

  type dim_specs = (dim_spec, boundary_spec) telescope
  type rec_specs = (rec_spec, dim_specs) telescope
  type constr = (const_spec, rec_specs) telescope

  type desc = Desc of {kind : Kind.t; lvl : Lvl.t; constrs : (string * constr) list}
  type pdesc = (param_spec, desc) telescope

  val bind_pdesc : Name.t -> pdesc -> pdesc bnd
  val bind_constr : Name.t -> constr -> constr bnd
  val bind_rec_specs : Name.t -> rec_specs -> rec_specs bnd
  val bind_dim_specs : Name.t -> dim_specs -> dim_specs bnd


  val inst_pdesc : pdesc -> tm list -> desc
end




module Error :
sig
  type t
  val pp : t Pp.t0
  exception E of t
end

val map_head : (tm -> tm) -> tm head -> tm head
val map_frame : (tm -> tm) -> tm frame -> tm frame
val map_spine : (tm -> tm) -> tm spine -> tm spine
val map_tmf : (tm -> tm) -> tm tmf -> tm tmf
val map_tm_sys : (tm -> tm) -> (tm, tm) system -> (tm, tm) system


type 'a subst

val shift : int -> 'a subst
val dot : 'a -> 'a subst -> 'a subst




val make : tm tmf -> tm
val unleash : tm -> tm tmf

val close_var : Name.t -> ?twin:(twin -> twin) -> int -> tm -> tm
val open_var : int -> (twin -> tm cmd) -> tm -> tm

val bind : Name.t -> tm -> tm bnd
val bindn : Name.t bwd -> tm -> tm nbnd
val unbind : tm bnd -> Name.t * tm
val unbindn : tm nbnd -> Name.t bwd * tm
val unbind_ext : (tm * (tm, tm) system) nbnd -> Name.t bwd * tm * (tm, tm) system
val unbind_ext_with : tm cmd list -> (tm * (tm, tm) system) nbnd -> tm * (tm, tm) system
val bind_ext : Name.t bwd -> tm -> (tm, tm) system -> (tm * (tm, tm) system) nbnd

val unbind_with : tm cmd -> tm bnd -> tm

val subst : tm cmd subst -> tm -> tm
val subst_cmd : tm cmd subst -> tm cmd -> tm cmd

val shift_univ : int -> tm -> tm

(* make sure you know what you are doing, LOL *)
val eta_contract : tm -> tm


val up : tm cmd -> tm
val ann : ty:tm -> tm:tm -> tm cmd

val ix : ?twin:twin -> int -> tm cmd
val var : ?twin:twin -> Name.t -> tm cmd
val car : tm cmd -> tm cmd
val cdr : tm cmd -> tm cmd
val let_ : string option -> tm cmd -> tm -> tm

val lam : string option -> tm -> tm
val ext_lam : string option bwd -> tm -> tm
val pi : string option -> tm -> tm -> tm
val sg : string option -> tm -> tm -> tm
val cons : tm -> tm -> tm
val univ : kind:Kind.t -> lvl:Lvl.t -> tm


val arr : tm -> tm -> tm
val times : tm -> tm -> tm

(* non-dependent path *)
val path : tm -> tm -> tm -> tm
val is_contr : tm -> tm
val fiber : ty0:tm -> ty1:tm -> f:tm -> x:tm -> tm
val equiv : tm -> tm -> tm

(** boundary refinement *)
val refine_ty : tm -> (tm, tm) system -> tm
val refine_thunk : tm -> tm
val refine_force : 'a cmd -> 'a cmd


val pp : tm Pp.t
val pp0 : tm Pp.t0
val pp_cmd : tm cmd Pp.t
val pp_head : tm head Pp.t
val pp_frame : tm frame Pp.t
val pp_spine : tm spine Pp.t
val pp_sys : (tm, tm) system Pp.t
val pp_bnd : tm bnd Pp.t
val pp_nbnd : tm nbnd Pp.t

(* val pp_bterm : btm Pp.t0 *)

include Occurs.S with type t := tm

module Sp :
sig
  include Occurs.S with type t = tm spine
end


module Notation :
sig
  val (@<) : 'a cmd -> 'a frame -> 'a cmd
end
