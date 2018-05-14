type meta = Symbol.t
type term = Tm.chk Tm.t

type dev =
  | Lam of {nm : string option; bdy : meta}
  | Hole
  | Guess of {guess : meta; bdy: meta}
  | Let of {soln : Tm.inf Tm.t; bdy : meta}
  | Ret of term

module Cx = Typing.Cx

module MCx = Map.Make (Symbol)

type boundary = Tm.chk Tm.t Tm.system
type cell = {ty : Tm.chk Tm.t; sys : boundary; hole : dev}

type mcx = cell MCx.t

let map_boundary f sys =
  List.map (fun (r, r', otm) -> f r, f r', Option.map f otm) sys


let rec check mcx cx ty (sys : boundary) dev =
  match Tm.unleash ty, dev with
  | Tm.Pi (dom, Tm.B (_, cod)), Lam {nm; bdy} ->
    let vdom = Cx.eval cx dom in
    let cxx, _ = Cx.ext_ty cx ~nm vdom in
    let sys' =
      List.map
        (fun (r0, r1, otm) ->
           Tm.subst Tm.Proj r0, Tm.subst Tm.Proj r1,
           let go tm =
             let func = Tm.make @@ Tm.Down {ty = Tm.subst Tm.Proj ty; tm = Tm.subst Tm.Proj tm} in
             let arg = Tm.up @@ Tm.var 0 in
             let app = Tm.make @@ Tm.FunApp (func, arg) in
             Tm.up app
           in
           Option.map go otm)
        sys
    in
    check_meta mcx cxx cod sys' bdy

  | Tm.Ext (Tm.B (_, (cod, sys'))), Lam {nm; bdy} ->
    let cxx, _ = Cx.ext_dim cx ~nm in
    let sys'' = map_boundary (Tm.subst Tm.Proj) sys @ sys' in
    check_meta mcx cxx cod sys'' bdy

  | _, Guess {guess; bdy} ->
    let cell = MCx.find guess mcx in
    let cxx, _ = Cx.ext_ty cx ~nm:None @@ Cx.eval cx cell.ty in
    let ty = Tm.subst Tm.Proj ty in
    let sys = map_boundary (Tm.subst Tm.Proj) sys in
    check_meta mcx cxx ty sys bdy

  | _, Let {soln; bdy} ->
    let ty' = Typing.infer cx soln in
    let el = Cx.eval cx soln in
    let cxx = Cx.ext_el cx ~nm:None ~ty:ty' ~el in
    check_meta mcx cxx ty (failwith "") bdy

  | _, Hole ->
    ()

  | _, Ret t ->
    let vty = Cx.eval cx ty in
    Typing.check cx vty t
  (* TODO: check boundary *)

  | _ -> failwith ""

and check_meta mcx cx ty sys alpha =
  let cell = MCx.find alpha mcx in
  let vty = Cx.eval cx ty in
  let vty' = Cx.eval cx cell.ty in
  Cx.check_subtype cx vty' vty;
  check mcx cx ty sys cell.hole

