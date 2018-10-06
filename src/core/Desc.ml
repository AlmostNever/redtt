open RedBasis
open Tm

type rec_spec =
  | Self

type arg_spec =
  [ `Const of tm
  | `Rec of rec_spec
  | `Dim
  ]

type ('a, 'e) telescope =
  | TNil of 'e
  | TCons of 'a * ('a, 'e) telescope Tm.bnd


module Telescope (B : LocallyNameless.S) (E : LocallyNameless.S) :
sig
  include LocallyNameless.S with type t = (B.t, E.t) telescope
  val bind : Name.t -> t -> t bnd
  val unbind_with : Tm.tm Tm.cmd -> t bnd -> t
  val unbind_all : Tm.tm Tm.cmd list -> t -> E.t
end =
struct
  type t = (B.t, E.t) telescope

  let rec open_var i a =
    function
    | TNil e ->
      TNil (E.open_var i a e)
    | TCons (b, Tm.B (nm, tele)) ->
      let b = B.open_var i a b in
      let tele = open_var (i + 1) a tele in
      TCons (b, Tm.B (nm, tele))

  let rec close_var a i =
    function
    | TNil e ->
      TNil (E.close_var a i e)
    | TCons (b, Tm.B (nm, tele)) ->
      let b = B.close_var a i b in
      let tele = close_var a (i + 1) tele in
      TCons (b, Tm.B (nm, tele))

  let rec subst sub =
    function
    | TNil e ->
      TNil (E.subst sub e)
    | TCons (b, Tm.B (nm, tele)) ->
      let b = B.subst sub b in
      let tele = subst (Tm.lift sub) tele in
      TCons (b, Tm.B (nm, tele))

  let bind x tele =
    Tm.B (Name.name x, close_var x 0 tele)

  let unbind_with cmd (Tm.B (_, tele)) =
    subst (Tm.dot cmd (Tm.shift 0)) tele

  let rec unbind_all cmds tele =
    match cmds, tele with
    | [], TNil e -> e
    | cmd :: cmds, TCons (_, btele) ->
      let tele = unbind_with cmd btele in
      unbind_all cmds tele
    | _ ->
      failwith "Telescope.unbind_all: length mismatch"
end

type constr = (arg_spec, (tm, tm) system) telescope

module ArgSpec : LocallyNameless.S with type t = arg_spec =
struct
  type t = arg_spec

  let open_var i a =
    function
    | `Const tm -> `Const (Tm.open_var i a tm)
    | `Rec Self -> `Rec Self
    | `Dim -> `Dim

  let close_var a i =
    function
    | `Const tm -> `Const (Tm.close_var a i tm)
    | `Rec Self -> `Rec Self
    | `Dim -> `Dim

  let subst sub =
    function
    | `Const tm -> `Const (Tm.subst sub tm)
    | `Rec Self -> `Rec Self
    | `Dim -> `Dim
end

module Face : LocallyNameless.S with type t = (tm, tm) face =
struct
  type t = (tm, tm) face

  let open_var i a (t0, t1, ot) =
    Tm.open_var i a t0, Tm.open_var i a t1, Option.map (Tm.open_var i a) ot

  let close_var a i (t0, t1, ot) =
    Tm.close_var a i t0, Tm.close_var a i t1, Option.map (Tm.close_var a i) ot

  let subst sub (t0, t1, ot) =
    Tm.subst sub t0, Tm.subst sub t1, Option.map (Tm.subst sub) ot
end

module Boundary = LocallyNameless.List (Face)

module Constr =
struct
  module ConstrLN = Telescope (ArgSpec) (Boundary)
  include ConstrLN

  let rec specs =
    function
    | TNil _ -> []
    | TCons (spec, Tm.B (nm, constr)) ->
      (nm, spec) :: specs constr

  let rec boundary =
    function
    | TNil sys -> sys
    | TCons (_, Tm.B (_, constr)) ->
      boundary constr

  let pp_cell fmt =
    function
    | (Some lbl, `Const ty) ->
      Format.fprintf fmt "%s : %a" lbl Tm.pp0 ty
    | _ ->
      Format.fprintf fmt "<cell>"

  let pp fmt tele =
    Pp.pp_list pp_cell fmt @@ specs tele

end

type param = tm
type constrs = (string * constr) list
type body = (param, constrs) telescope

type desc =
  {kind : Kind.t;
   lvl : Lvl.t;
   body : (param, constrs) telescope;
   status : [`Complete | `Partial]}

module Param : LocallyNameless.S with type t = tm =
struct
  type t = tm
  let open_var i a = Tm.open_var i a
  let close_var i a = Tm.close_var i a
  let subst = Tm.subst
end

module LabeledConstr = LocallyNameless.Pair (LocallyNameless.Const (struct type t = string end)) (Constr)

module Body =
struct
  module M = Telescope (Param) (LocallyNameless.List (LabeledConstr))
  include M

  let rec instance tms tele =
    match tms, tele with
    | [], TNil e ->
      e

    | tm :: tms, TCons (ty, btele) ->
      let cmd = Tm.ann ~ty ~tm in
      let tele = unbind_with cmd btele in
      instance tms tele

    | _ ->
      failwith "Desc.Body.instance: length mismatch"
end


let constrs desc =
  let rec go =
    function
    | TNil cs -> cs
    | TCons (_, Tm.B (_, body)) ->
      go body
  in
  go desc.body

let add_constr desc constr =
  let rec go =
    function
    | TNil cs ->
      TNil (cs @ [constr])
    | TCons (prm, Tm.B (nm, desc')) ->
      TCons (prm, Tm.B (nm, go desc'))
  in
  {desc with body = go desc.body}

let flip f x y = f y x

let rec dim_specs constr =
  match constr with
  | TNil _ -> []
  | TCons (spec, Tm.B (nm, constr)) ->
    match spec with
    | `Dim -> nm :: dim_specs constr
    | _ -> dim_specs constr


exception ConstructorNotFound of string

let lookup_constr lbl constrs =
  try
    let _, constr = List.find (fun (lbl', _) -> lbl' = lbl) constrs in
    constr
  with
  | _ ->
    raise @@ ConstructorNotFound lbl

let is_strict_set desc =
  let constr_is_point constr =
    match dim_specs constr with
    | [] -> true
    | _ -> false
  in
  match desc.body with
  | TNil constrs ->
    List.fold_right (fun (_, constr) r -> constr_is_point constr && r) constrs true
  | _ ->
    false
