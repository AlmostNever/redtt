open RedBasis.Bwd

type tm = Tm.tm
type ty = Tm.tm

type 'a decl =
  | Hole
  | Defn of 'a

type status =
  | Blocked
  | Active

type ('a, 'b) equation =
  {ty0 : ty;
   tm0 : 'a;
   ty1 : ty;
   tm1 : 'b}

type param =
  | P of ty
  | Tw of ty * ty

type params = (Name.t * param) bwd

type 'a bind

type problem =
  | Unify of (tm, tm) equation
  | All of param * problem bind

type entry =
  | E of Name.t * ty * tm decl
  | Q of status * problem

val bind : Name.t -> problem -> problem bind
val unbind : problem bind -> Name.t * problem


type twin = Tm.twin


module Problem :
sig
  include Occurs.S with type t = problem
  val eqn : ty0:ty -> tm0:tm -> ty1:ty -> tm1:tm -> problem
  val all : Name.t -> ty -> problem -> problem
  val all_twins : Name.t -> ty -> ty -> problem -> problem
end

module Param : Occurs.S with type t = param
module Params : Occurs.S with type t = param bwd
module Equation :
sig
  include Occurs.S with type t = (tm, tm) equation
  val sym : ('a, 'b) equation -> ('b, 'a) equation
end

module Decl : Occurs.S with type t = tm decl
module Entry : Occurs.S with type t = entry
module Entries : Occurs.S with type t = entry list
