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
end

module Constr =
struct
  type t = constr

  let rec open_var i a =
    function
    | TNil sys ->
      let sys = Tm.map_tm_sys (Tm.open_var i a) sys in
      TNil sys
    | TCons (spec, Tm.B (nm, constr)) ->
      let spec = ArgSpec.open_var i a spec in
      let constr = open_var (i + 1) a constr in
      TCons (spec, Tm.B (nm, constr))

  let rec close_var a i =
    function
    | TNil sys ->
      let sys = Tm.map_tm_sys (Tm.close_var a i) sys in
      TNil sys
    | TCons (spec, Tm.B (nm, constr)) ->
      let spec = ArgSpec.close_var a i spec in
      let constr = close_var a (i + 1) constr in
      TCons (spec, Tm.B (nm, constr))

  let bind x constr =
    Tm.B (Name.name x, close_var x 0 constr)

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

end

type desc_body = (string * constr) list

type desc =
  {kind : Kind.t;
   lvl : Lvl.t;
   constrs : desc_body; (* TODO: wrap in telescope ! *)
   status : [`Complete | `Partial]}



let flip f x y = f y x

let rec dim_specs constr =
  match constr with
  | TNil _ -> []
  | TCons (spec, Tm.B (nm, constr)) ->
    match spec with
    | `Dim -> nm :: dim_specs constr
    | _ -> dim_specs constr


exception ConstructorNotFound of string

let lookup_constr lbl desc =
  try
    let _, constr = List.find (fun (lbl', _) -> lbl' = lbl) desc.constrs in
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
  List.fold_right (fun (_, constr) r -> constr_is_point constr && r) desc.constrs true

let pp_string = Uuseg_string.pp_utf_8
let pp_string = Uuseg_string.pp_utf_8
