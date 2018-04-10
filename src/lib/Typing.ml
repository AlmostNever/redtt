module Ctx : 
sig
  type t
  val emp : t
  val ext : t -> Val.can Val.t -> t
  val lookup : Thin.t -> t -> Val.can Val.t
  val len : t -> int

  val env : t -> Val.env
  val qctx : t -> Quote.ctx
end = 
struct
  type t = 
    {tys : Val.can Val.t list;
     env : Val.env;
     qctx : Quote.ctx;
     len : int}

  let emp = 
    {tys = []; 
     env = []; 
     qctx = Quote.Ctx.emp;
     len = 0}

  let ext cx v =
    {tys = v :: cx.tys; 
     env = Val.generic v cx.len :: cx.env;
     qctx = Quote.Ctx.ext cx.qctx v;
     len = cx.len + 1}

  let lookup th cx =
    Thin.proj th cx.tys

  let len cx =
    cx.len

  let env cx =
    cx.env

  let qctx cx = 
    cx.qctx

end

type ctx = Ctx.t

let rec check ~ctx ~ty ~tm =
  match Val.out ty, Tm.out tm with
  | Val.Univ lvl, Tm.Univ lvl' ->
    if Lvl.greater lvl lvl' then () else failwith "Universe level failure"

  | Val.Univ _, Tm.Pi (dom, Tm.B cod) ->
    let vdom = check_eval ~ctx ~ty ~tm:dom in
    let ctx' = Ctx.ext ctx vdom in
    check ~ctx:ctx' ~ty ~tm:cod

  | Val.Univ _, Tm.Sg (dom, Tm.B cod) ->
    let vdom = check_eval ~ctx ~ty ~tm:dom in
    let ctx' = Ctx.ext ctx vdom in
    check ~ctx:ctx' ~ty ~tm:cod

  | Val.Pi (dom, cod), Tm.Lam (Tm.B tm) ->
    let vdom = Val.eval_clo dom in
    let ctx' = Ctx.ext ctx vdom in
    let vgen = Val.generic vdom @@ Ctx.len ctx in
    let vcod = Val.inst_bclo cod vgen in
    check ~ctx:ctx' ~ty:vcod ~tm

  | Val.Sg (dom, cod), Tm.Cons (tm0, tm1) ->
    let vdom = Val.eval_clo dom in
    let vtm0 = check_eval ~ctx ~ty:vdom ~tm:tm0 in
    let vcod = Val.inst_bclo cod vtm0 in
    check ~ctx ~ty:vcod ~tm:tm1

  | _, Tm.Up tm ->
    let ty' = infer ~ctx ~tm in
    let univ = Val.into @@ Val.Univ Lvl.Omega in
    Quote.approx ~ctx:(Ctx.qctx ctx) ~ty:univ ~can0:ty' ~can1:ty


  | _ -> failwith ""

and check_eval ~ctx ~ty ~tm = 
  check ~ctx ~ty ~tm;
  Val.eval (Ctx.env ctx) tm


and infer ~ctx ~tm = failwith "TODO: infer"