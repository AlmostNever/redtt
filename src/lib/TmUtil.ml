let make_node start stop con =
  Tm.into_info (Some (start, stop)) con

type tele =
  | TCons of string option * Tm.chk Tm.t * tele
  | TEnd of Tm.chk Tm.t

type 'a multibind =
  | MBConsVar of string option * 'a multibind
  | MBConsDim of string option * 'a multibind
  | MBEnd of 'a

let rec pi_from_tele info tele =
  match tele with
  | TEnd ty -> ty
  | TCons (nm, ty, tele) ->
    Tm.into_info info @@
    Tm.Pi (ty, Tm.B (nm, pi_from_tele info tele))

let rec sg_from_tele info tele =
  match tele with
  | TEnd ty -> ty
  | TCons (nm, ty, tele) ->
    Tm.into_info info @@
    Tm.Pi (ty, Tm.B (nm, sg_from_tele info tele))

let rec lam_from_multibind info mb =
  match mb with
  | MBEnd bdy -> bdy
  | MBConsVar (nm, mb) ->
    Tm.into_info info @@
    Tm.Lam (Tm.B (nm, lam_from_multibind info mb))
  | MBConsDim (nm, mb) ->
    Tm.into_info info @@
    Tm.ExtLam (Tm.NB ([nm], lam_from_multibind info mb))

let rec ext_from_multibind start stop mb =
  (* match mb with
     | MBConsDim (nm, MBEnd (ty, sys)) ->
     Tm.into_info (Some (start, stop)) @@
     Tm.Ext (Tm.NB (nm, (ty, sys)))

     | MBConsDim (nm, mb) ->
     Tm.into_info (Some (start, stop)) @@
     Tm.Ext (Tm.B (nm, (ext_from_multibind start stop mb, [])))

     | _ -> *)
  failwith "ext_from_multibind"


let rec make_multi_funapp start stop fn rest =
  match rest with
  | [] ->
    fn
  | arg :: rest ->
    let fn' = make_multi_funapp start stop fn rest in
    make_node start stop @@ Tm.FunApp (fn', arg)

let make_dim_const start stop i =
  match i with
  | 0 -> make_node start stop Tm.Dim0
  | 1 -> make_node start stop Tm.Dim1
  | _ -> failwith "make_dim_const"
