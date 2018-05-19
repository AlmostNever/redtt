type atom = Symbol.t
type star = DimStar.t
type gen = DimGeneric.t
type rel = Restriction.t

type dim = Dim.t

type value
type clo

type ('x, 'a) face = ('x, 'a) Face.face

(* TODO: now it may be possible to semantic domain to use the fancy restriction data structure,
   instead of inventing a new dimension and doing a diagonal. Needs further investigation.

   It was already necessary to *evaluate* with respect to a restriction, based on the needs of the
   typechecker; but the further question is how things should work in the internal semantic operations. *)

type con =
  | Pi : {dom : value; cod : clo} -> con
  | Sg : {dom : value; cod : clo} -> con
  | Rst : {ty : value; sys : val_sys} -> con
  | Ext : ext_abs -> con

  | Coe : {dir : star; abs : abs; el : value} -> con
  | HCom : {dir : star; ty : value; cap : value; sys : comp_sys} -> con
  | FCom : {dir : star; cap : value; sys : comp_sys} -> con

  | Univ : {kind : Kind.t; lvl : Lvl.t} -> con
  | V : {x : gen; ty0 : value; ty1 : value; equiv : value} -> con
  | VIn : {x : gen; el0 : value; el1 : value} -> con

  | Lam : clo -> con
  | ExtLam : abs -> con
  | Cons : value * value -> con
  | Bool : con
  | Tt : con
  | Ff : con

  | Up : {ty : value; neu : neu} -> con

and neu =
  | Lvl : string option * int -> neu
  | FunApp : neu * nf -> neu
  | ExtApp : neu * val_sys * dim list -> neu
  | Car : neu -> neu
  | Cdr : neu -> neu
  | If : {mot : clo; neu : neu; tcase : value; fcase : value} -> neu

  (* Invariant: neu \in vty, vty is a V type
  *)
  | VProj : {x : gen; ty0 : value; ty1 : value; equiv : value; neu : neu} -> neu

and nf = {ty : value; el : value}

and abs = value Abstraction.abs

and rigid_abs_face = ([`Rigid], abs) face
and val_face = ([`Any], value) face
and rigid_val_face = ([`Rigid], value) face

and comp_sys = rigid_abs_face list
and val_sys = val_face list
and box_sys = rigid_val_face list
and cap_sys = rigid_abs_face list
and ext_abs = (value * val_sys) Abstraction.abs

and env_el = Val of value | Atom of atom
and env = env_el list


module type S =
sig
  val make : con -> value
  val unleash : value -> con

  val eval : rel -> env -> 'a Tm.t -> value
  val eval_dim : rel -> env -> 'a Tm.t -> Dim.repr
  val eval_tm_sys : rel -> env -> Tm.chk Tm.t Tm.system -> val_sys

  val apply : value -> value -> value
  val ext_apply : value -> dim list -> value
  val car : value -> value
  val cdr : value -> value

  val inst_clo : clo -> value -> value
  val const_clo : value -> clo

  val unleash_pi : value -> value * clo
  val unleash_sg : value -> value * clo
  val unleash_v : value -> gen * value * value * value
  val unleash_ext : value -> dim list -> value * val_sys


  val pp_value : Format.formatter -> value -> unit
  val pp_neu : Format.formatter -> neu -> unit


  module Val : Sort.S
    with type t = value
    with type 'a m = 'a


  module ExtAbs : Abstraction.S
    with type el = value * val_sys

  module Abs : Abstraction.S
    with type el = value

  module Macro : sig
    val equiv : value -> value -> value
  end
end

type sig_entry =
  | Opaque of {ty : Tm.chk Tm.t}
  | Transparent of {tm : Tm.chk Tm.t}

module type Sig =
sig
  val lookup : string -> sig_entry
end

module M (Sig : Sig) : S
