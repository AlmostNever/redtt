module D = Dim
module Star = DimStar
module Gen = DimGeneric

type atom = Symbol.t
type dim = D.t
type star = Star.t
type gen = Gen.t

module R = Restriction
type rel = R.t

(* Notes: I have defined the semantic domain and evaluator in a fairly naive way, in order to avoid
   some confusing questions. It may not be that efficient! But it should be easier at this point to
   transform it make something efficient, since the code is currently simple-minded enough to
   think about. *)

type con =
  | Pi : {dom : value; cod : clo} -> con
  | Sg : {dom : value; cod : clo} -> con
  | Ext : ext_abs -> con

  | Coe : {dir : star; abs : abs; el : value} -> con
  | HCom : {dir : star; ty : value; cap : value; sys : comp_sys} -> con
  | FCom : {dir : star; cap : value; sys : comp_sys} -> con

  | Univ : Lvl.t -> con
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
  | ExtApp : neu * ext_sys * D.t -> neu
  | Car : neu -> neu
  | Cdr : neu -> neu

  | If : {mot : clo; neu : neu; tcase : value; fcase : value} -> neu

  (* Invariant: neu \in vty, vty is a V type *)
  | VProj : {x : gen; ty0 : value; ty1 : value; equiv : value; neu : neu} -> neu

and nf = {ty : value; el : value}

and ('x, 'a) face = ('x, 'a) Face.face

and clo =
  | Clo of {bnd : Tm.chk Tm.t Tm.bnd; rho : env; rel : rel; action : D.action}
  | Const of value

and env_el = Val of value | Atom of atom
and env = env_el list

and abs = value Abstraction.abs
and ext_abs = (value * ext_sys) Abstraction.abs
and rigid_abs_face = ([`Rigid], abs) face
and val_face = ([`Any], value) face
and rigid_val_face = ([`Rigid], value) face

and comp_sys = rigid_abs_face list
and ext_sys = val_face list
and box_sys = rigid_val_face list
and cap_sys = rigid_abs_face list

and node = Node of {con : con; action : D.action}
and value = node ref



type step =
  | Ret : neu -> step
  | Step : value -> step

let ret v = Ret v
let step v = Step v

module type Sort = Sort.S

module Val : Sort with type t = value with type 'a m = 'a =
struct
  type 'a m = 'a
  type t = value

  let act : D.action -> value -> value =
    fun phi thunk ->
      let Node node = !thunk in
      ref @@ Node {node with action = D.cmp phi node.action}
end

let make : con -> value =
  fun con ->
    ref @@ Node {con; action = D.idn}


module Abs = Abstraction.M (Val)

module ValFace = Face.M (Val)
module AbsFace = Face.M (Abs)

module Clo : Sort with type t = clo with type 'a m = 'a =
struct
  type t = clo
  type 'a m = 'a

  let act phi clo =
    match clo with
    | Clo info ->
      Clo {info with action = D.cmp phi info.action}
    | Const v ->
      Const (Val.act phi v)
end

module CompSys :
sig
  include Sort
    with type t = comp_sys
    with type 'a m = [`Ok of comp_sys | `Proj of abs]
end =
struct
  type t = comp_sys
  type 'a m = [`Ok of comp_sys | `Proj of abs]

  exception Proj of abs

  let rec act_aux phi (sys : t) =
    match sys with
    | [] -> []
    | face :: sys ->
      match AbsFace.act phi face with
      | Face.True (_, _, abs) ->
        raise @@ Proj abs
      | Face.False p ->
        Face.False p :: act_aux phi sys
      | Face.Indet (p, t) ->
        Face.Indet (p, t) :: act_aux phi sys

  let act phi sys =
    try `Ok (act_aux phi sys)
    with
    | Proj abs ->
      `Proj abs
end

module ExtSys :
sig
  include Sort
    with type t = ext_sys
    with type 'a m = 'a
end =
struct
  type t = ext_sys
  type 'a m = 'a

  let act phi =
    List.map (ValFace.act phi)
end

module ExtAbs : Abstraction.S with type el = value * ext_sys =
  Abstraction.M (Sort.Prod (Val) (ExtSys))

exception ProjAbs of abs
exception ProjVal of value


let rec eval_dim : type x. rel -> env -> x Tm.t -> D.repr =
  fun rel rho tm ->
    match Tm.unleash tm with
    | Tm.Dim0 ->
      D.Dim0
    | Tm.Dim1 ->
      D.Dim1
    | Tm.Up tm ->
      eval_dim rel rho tm
    | Tm.Down {tm; _} ->
      eval_dim rel rho tm
    | Tm.Var i ->
      begin
        match List.nth rho i with
        | Atom x ->
          R.canonize (D.Atom x) rel
        | _ ->
          failwith "eval_dim: expected atom in environment"
      end
    | _ ->
      failwith "eval_dim"

let eval_dim_class : type x. rel -> env -> x Tm.t -> D.t =
  fun rel rho tm ->
    R.unleash (eval_dim rel rho tm) rel

let rec act_can phi con =
  match con with
  | Pi info ->
    let dom = Val.act phi info.dom in
    let cod = Clo.act phi info.cod in
    make @@ Pi {dom; cod}

  | Sg info ->
    let dom = Val.act phi info.dom in
    let cod = Clo.act phi info.cod in
    make @@ Sg {dom; cod}

  | Ext abs ->
    let abs' = ExtAbs.act phi abs in
    make @@ Ext abs'

  | Coe info ->
    make_coe
      (Star.act phi info.dir)
      (Abs.act phi info.abs)
      (Val.act phi info.el)

  | HCom info ->
    make_hcom
      (Star.act phi info.dir)
      (Val.act phi info.ty)
      (Val.act phi info.cap)
      (CompSys.act phi info.sys)

  | FCom info ->
    make_fcom
      (Star.act phi info.dir)
      (Val.act phi info.cap)
      (CompSys.act phi info.sys)

  | V info ->
    make_v
      (Gen.act phi info.x)
      (Val.act phi info.ty0)
      (Val.act phi info.ty1)
      (Val.act phi info.equiv)

  | VIn info ->
    make_vin
      (Gen.act phi info.x)
      (Val.act phi info.el0)
      (Val.act phi info.el1)

  | Univ _ ->
    make con

  | Bool ->
    make con

  | Tt ->
    make con

  | Ff ->
    make con

  | Lam clo ->
    make @@ Lam (Clo.act phi clo)

  | ExtLam abs ->
    make @@ ExtLam (Abs.act phi abs)

  | Cons (v0, v1) ->
    make @@ Cons (Val.act phi v0, Val.act phi v1)

  | Up info ->
    let ty = Val.act phi info.ty in
    begin
      match act_neu phi info.neu with
      | Ret neu ->
        make @@ Up {ty; neu}
      | Step v ->
        v
    end

and act_neu phi con =
  match con with
  | VProj info ->
    let mx = Gen.act phi info.x in
    let ty0 = Val.act phi info.ty0 in
    let ty1 = Val.act phi info.ty1 in
    let equiv = Val.act phi info.equiv in
    begin
      match act_neu phi info.neu with
      | Ret neu ->
        let vty = make_v mx ty0 ty1 equiv in
        let el = make @@ Up {ty = vty; neu = neu} in
        step @@ vproj mx ~ty0 ~ty1 ~equiv ~el
      | Step el ->
        step @@ vproj mx ~ty0 ~ty1 ~equiv ~el
    end

  | FunApp (neu, arg) ->
    let varg = act_nf phi arg in
    begin
      match act_neu phi neu with
      | Ret neu ->
        ret @@ FunApp (neu, varg)
      | Step v ->
        let {el; _} = varg in
        step @@ apply v el
    end

  | ExtApp (neu, sys, r) ->
    let sys = ExtSys.act phi sys in
    let r = Dim.act phi r in
    begin
      match act_neu phi neu with
      | Ret neu ->
        begin
          match force_ext_sys sys with
          | `Rigid _ ->
            ret @@ ExtApp (neu, sys, r)
          | `Proj v ->
            step v
        end
      | Step v ->
        step @@ ext_apply v r
    end

  | Car neu ->
    begin
      match act_neu phi neu with
      | Ret neu ->
        ret @@ Car neu
      | Step v ->
        step @@ car v
    end

  | Cdr neu ->
    begin
      match act_neu phi neu with
      | Ret neu ->
        ret @@ Cdr neu
      | Step v ->
        step @@ cdr v
    end

  | If info ->
    let mot = Clo.act phi info.mot in
    let tcase = Val.act phi info.tcase in
    let fcase = Val.act phi info.fcase in
    begin
      match act_neu phi info.neu with
      | Ret neu ->
        ret @@ If {mot; neu; tcase; fcase}
      | Step v ->
        step @@ if_ mot v tcase fcase
    end

  | Lvl _ ->
    ret con

and act_nf phi (nf : nf) =
  match nf with
  | info ->
    let ty = Val.act phi info.ty in
    let el = Val.act phi info.el in
    {ty; el}

and force_abs_face face =
  match face with
  | Face.True (_, _, abs) ->
    raise @@ ProjAbs abs
  | Face.False xi ->
    Face.False xi
  | Face.Indet (xi, abs) ->
    Face.Indet (xi, abs)

and force_ext_face (face : val_face) =
  match face with
  | Face.True (_, _, v) ->
    raise @@ ProjVal v
  | Face.False xi ->
    Face.False xi
  | Face.Indet (xi, v) ->
    Face.Indet (xi, v)

and force_ext_sys sys =
  try
    `Rigid (List.map force_ext_face sys)
  with
  | ProjVal v ->
    `Proj v

and force_abs_sys sys =
  try
    `Ok (List.map force_abs_face sys)
  with
  | ProjAbs abs ->
    `Proj abs

and unleash : value -> con =
  fun node ->
    let Node info = !node in
    match Dim.action_is_id info.action with
    | true ->
      info.con
    | false ->
      let node' = act_can info.action info.con in
      let con = unleash node' in
      node := Node {con = con; action = D.idn};
      con

and make_v mgen ty0 ty1 equiv : value =
  match mgen with
  | `Ok x ->
    make @@ V {x; ty0; ty1; equiv}
  | `Const `Dim0 ->
    ty0
  | `Const `Dim1 ->
    ty1

and make_vin mgen el0 el1 : value =
  match mgen with
  | `Ok x ->
    make @@ VIn {x; el0; el1}
  | `Const `Dim0 ->
    el0
  | `Const `Dim1 ->
    el0

and make_coe mdir abs el : value =
  match mdir with
  | `Ok dir ->
    rigid_coe dir abs el
  | `Same _ ->
    el

and make_hcom mdir ty cap msys : value =
  match mdir with
  | `Ok dir ->
    begin
      match msys with
      | `Ok sys ->
        rigid_hcom dir ty cap sys
      | `Proj abs ->
        let _, r' = Star.unleash dir in
        let x, el = Abs.unleash1 abs in
        Val.act (D.subst r' x) el
    end
  | `Same _ ->
    cap

and make_com mdir abs cap msys : value =
  match mdir with
  | `Ok dir ->
    let _, r' = Star.unleash dir in
    begin
      match msys with
      | `Ok sys ->
        rigid_com dir abs cap sys
      | `Proj abs ->
        Abs.inst1 abs r'
    end
  | `Same _ ->
    cap

and make_fcom mdir cap msys : value =
  match mdir with
  | `Ok dir ->
    begin
      match msys with
      | `Ok sys ->
        make @@ FCom {dir; cap; sys}
      | `Proj abs ->
        let _, r' = Star.unleash dir in
        let x, el = Abs.unleash1 abs in
        Val.act (D.subst r' x) el
    end
  | `Same _ ->
    cap

and rigid_coe dir abs el =
  let x, tyx = Abs.unleash1 abs in
  match unleash tyx with
  | (Pi _ | Sg _ ) ->
    make @@ Coe {dir; abs; el}

  | (Bool | Univ _) ->
    el

  | FCom _info ->
    failwith "Coe in fcom, taste it!!"

  | V info ->
    begin
      let r, r' = Star.unleash dir in
      let xty1 = Abs.bind1 x info.ty1 in

      match Gen.make r with
      | `Const `Dim0 ->
        let el1 =
          rigid_coe dir xty1 @@
          apply (car @@ Val.act (D.subst D.dim0 x) info.equiv) el
        in
        make_vin (Gen.make r') el el1

      | `Const `Dim1 ->
        let coe1r'el = rigid_coe dir xty1 el in
        let el0 = car @@ apply (cdr @@ Val.act (D.subst r' x) info.equiv) coe1r'el in
        let el1 =
          let ty1r' = Val.act (D.subst r' x) info.ty1 in
          let cap = coe1r'el in
          let sys =
            force_abs_sys @@
            let face0 =
              AbsFace.make r' D.dim0 @@
              let y = Symbol.fresh () in
              Abs.bind1 y @@ ext_apply (cdr el0) @@ D.named y
            in
            let face1 = AbsFace.make r' D.dim1 @@ Abs.bind [Symbol.fresh ()] coe1r'el in
            [face0; face1]
          in
          make_hcom (Star.make D.dim1 D.dim0) ty1r' cap sys
        in
        make_vin (Gen.make r') (car el0) el1

      | `Ok _ ->
        begin
          match D.compare (Gen.unleash info.x) (D.named x) with
          | D.Same ->
            failwith "This is the hard one"

          | _ ->
            let xty0 = Abs.bind1 x info.ty0 in
            let el0 = rigid_coe dir xty0 el in
            let el1 =
              let cap =
                let phi = Dim.subst r x in
                let ty0r = Val.act phi info.ty0 in
                let ty1r = Val.act phi info.ty1 in
                let equivr = Val.act phi info.equiv in
                rigid_vproj info.x ~el ~ty0:ty0r ~ty1:ty1r ~equiv:equivr
              in
              let r2x = Star.make r (D.named x) in
              let sys =
                let face0 =
                  AbsFace.gen_const info.x `Dim0 @@
                  Abs.bind1 x @@ apply (car info.equiv) @@
                  make_coe r2x xty0 el
                in
                let face1 =
                  AbsFace.gen_const info.x `Dim1 @@
                  Abs.bind1 x @@
                  make_coe r2x xty1 el
                in
                [face0; face1]
              in
              rigid_com dir xty1 cap sys
            in
            make @@ VIn {x = info.x; el0; el1}
        end
    end

  | _ ->
    failwith "TODO: rigid_coe"

and rigid_hcom dir ty cap sys : value =
  match unleash ty with
  | Pi _ ->
    make @@ HCom {dir; ty; cap; sys}

  | Bool ->
    cap

  | Univ _ ->
    make @@ FCom {dir; cap; sys}

  | FCom _info ->
    failwith "hcom in fcom, taste it!!"

  | V _info ->
    failwith "hcom in V, taste it!!!"

  | _ ->
    failwith "TODO"

and rigid_com dir abs cap (sys : comp_sys) : value =
  let _, r' = Star.unleash dir in
  let ty = Abs.inst1 abs r' in
  let capcoe = rigid_coe dir abs cap in
  let syscoe : comp_sys =
    let face =
      Face.map @@ fun ri r'i absi ->
      let phi = D.equate ri r'i in
      let yi, vi = Abs.unleash1 absi in
      let y2r' = Star.make (D.named yi) (D.act phi r') in
      Abs.bind1 yi @@ make_coe y2r' (Abs.act phi abs) @@ Val.act phi vi
    in
    List.map face sys
  in
  rigid_hcom dir ty capcoe syscoe


and clo bnd rel rho =
  Clo {bnd; rho; rel; action = D.idn}

and eval : type x. rel -> env -> x Tm.t -> value =
  fun rel rho tm ->
    match Tm.unleash tm with
    | Tm.Var i ->
      begin
        match List.nth rho i with
        | Val v -> v
        | _ -> failwith "Expected value in environment"
      end

    | Tm.Pi (dom, cod) ->
      let dom = eval rel rho dom in
      let cod = clo cod rel rho in
      make @@ Pi {dom; cod}

    | Tm.Sg (dom, cod) ->
      let dom = eval rel rho dom in
      let cod = clo cod rel rho in
      make @@ Sg {dom; cod}

    | Tm.Ext bnd ->
      let abs = eval_ext_abs rel rho bnd in
      make @@ Ext abs

    | Tm.V info ->
      let r = eval_dim_class rel rho info.r in
      let ty0 = eval rel rho info.ty0 in
      let ty1 = eval rel rho info.ty1 in
      let equiv = eval rel rho info.equiv in
      make_v (Gen.make r) ty0 ty1 equiv

    | Tm.Lam bnd ->
      make @@ Lam (clo bnd rel rho)

    | Tm.ExtLam bnd ->
      let abs = eval_abs rel rho bnd in
      make @@ ExtLam abs

    | Tm.Cons (t0, t1) ->
      let v0 = eval rel rho t0 in
      let v1 = eval rel rho t1 in
      make @@ Cons (v0, v1)

    | Tm.Coe info ->
      let r = eval_dim_class rel rho info.r in
      let r' = eval_dim_class rel rho info.r' in
      let dir = Star.make r r' in
      let abs = eval_abs rel rho info.ty  in
      let el = eval rel rho info.tm in
      make_coe dir abs el

    | Tm.HCom info ->
      let r = eval_dim_class rel rho info.r in
      let r' = eval_dim_class rel rho info.r' in
      let dir = Star.make r r' in
      let ty = eval rel rho info.ty in
      let cap = eval rel rho info.cap in
      let sys = eval_abs_sys rel rho info.sys in
      make_hcom dir ty cap sys

    | Tm.Com info ->
      let r = eval_dim_class rel rho info.r in
      let r' = eval_dim_class rel rho info.r' in
      let dir = Star.make r r' in
      let abs = eval_abs rel rho info.ty in
      let cap = eval rel rho info.cap in
      let sys = eval_abs_sys rel rho info.sys in
      make_com dir abs cap sys

    | Tm.FCom info ->
      let r = eval_dim_class rel rho info.r  in
      let r' = eval_dim_class rel rho info.r' in
      let dir = Star.make r r' in
      let cap = eval rel rho info.cap in
      let sys = eval_abs_sys rel rho info.sys in
      make_fcom dir cap sys

    | Tm.FunApp (t0, t1) ->
      let v0 = eval rel rho t0 in
      let v1 = eval rel rho t1 in
      apply v0 v1

    | Tm.ExtApp (t, tr) ->
      let v = eval rel rho t in
      let r = eval_dim_class rel rho tr in
      ext_apply v r

    | Tm.Car t ->
      car @@ eval rel rho t

    | Tm.Cdr t ->
      cdr @@ eval rel rho t

    | Tm.VProj info ->
      let r = eval_dim_class rel rho info.r in
      let ty0 = eval rel rho info.ty0 in
      let ty1 = eval rel rho info.ty1 in
      let el = eval rel rho info.tm in
      let equiv = eval rel rho info.equiv in
      vproj (Gen.make r) ~ty0 ~ty1 ~equiv ~el

    | Tm.Univ lvl ->
      make @@ Univ lvl

    | Tm.Bool ->
      make Bool

    | Tm.Tt ->
      make Tt

    | Tm.Ff ->
      make Ff

    | Tm.Dim0 ->
      failwith "0 is a dimension"

    | Tm.Dim1 ->
      failwith "1 is a dimension"

    | Tm.Down info ->
      eval rel rho info.tm

    | Tm.Up t ->
      eval rel rho t

    | Tm.If info ->
      let mot = clo info.mot rel rho in
      let scrut = eval rel rho info.scrut in
      let tcase = eval rel rho info.tcase in
      let fcase = eval rel rho info.fcase in
      if_ mot scrut tcase fcase

    | Tm.Let (t0, Tm.B (_, t1)) ->
      let v0 = eval rel rho t0 in
      eval rel (Val v0 :: rho) t1


and eval_abs_face rel rho (tr, tr', obnd) =
  let r = eval_dim rel rho tr in
  let r' = eval_dim rel rho tr' in
  let sr = R.unleash r rel in
  let sr' = R.unleash r' rel in
  match Star.make sr sr' with
  | `Ok xi ->
    begin
      match D.compare sr sr' with
      | D.Apart ->
        Face.False xi
      | _ ->
        let bnd = Option.get_exn obnd in
        let rel' = R.equate r r' rel in
        let abs = eval_abs rel' rho bnd in
        Face.Indet (xi, abs)
    end
  | `Same _ ->
    let bnd = Option.get_exn obnd in
    let abs = eval_abs rel rho bnd in
    Face.True (sr, sr', abs)

and eval_abs_sys rel rho sys  =
  try
    let sys =
      List.map
        (fun x -> force_abs_face @@ eval_abs_face rel rho x)
        sys
    in `Ok sys
  with
  | ProjAbs abs ->
    `Proj abs

and eval_ext_face rel rho (tr, tr', otm) : val_face =
  let r = eval_dim rel rho tr in
  let r' = eval_dim rel rho tr' in
  let sr = R.unleash r rel in
  let sr' = R.unleash r' rel in
  match Star.make sr sr' with
  | `Ok xi ->
    begin
      match D.compare sr sr' with
      | D.Apart ->
        Face.False xi
      | _ ->
        let tm = Option.get_exn otm in
        let rel' = R.equate r r' rel in
        let el = eval rel' rho tm in
        Face.Indet (xi, el)
    end
  | `Same _ ->
    let tm = Option.get_exn otm in
    let el = eval rel rho tm in
    Face.True (sr, sr', el)

and eval_ext_sys rel rho sys : ext_sys =
  List.map (eval_ext_face rel rho) sys

and eval_abs rel rho bnd =
  let Tm.B (_, tm) = bnd in
  let x = Symbol.fresh () in
  let rho = Atom x :: rho in
  Abs.bind1 x @@ eval rel rho tm

and eval_ext_abs rel rho bnd =
  let Tm.B (_, (tm, sys)) = bnd in
  let x = Symbol.fresh () in
  let rho = Atom x :: rho in
  ExtAbs.bind1 x (eval rel rho tm, eval_ext_sys rel rho sys)

and unleash_pi v =
  match unleash v with
  | Pi {dom; cod} -> dom, cod
  | _ -> failwith "unleash_pi"

and unleash_sg v =
  match unleash v with
  | Sg {dom; cod} -> dom, cod
  | _ -> failwith "unleash_sg"

and unleash_ext v r =
  match unleash v with
  | Ext abs ->
    ExtAbs.inst1 abs r
  | _ ->
    failwith "unleash_ext"

and unleash_v v =
  match unleash v with
  | V {x; ty0; ty1; equiv} ->
    x, ty0, ty1, equiv
  | _ ->
    failwith "unleash_v"

and apply vfun varg =
  match unleash vfun with
  | Lam clo ->
    inst_clo clo varg

  | Up info ->
    let dom, cod = unleash_pi info.ty in
    let cod' = inst_clo cod varg in
    let app = FunApp (info.neu, {ty = dom; el = varg}) in
    make @@ Up {ty = cod'; neu = app}

  | Coe info ->
    let r, r' = Star.unleash info.dir in
    let x, tyx = Abs.unleash1 info.abs in
    let domx, codx = unleash_pi tyx in
    let abs =
      Abs.bind1 x @@
      inst_clo codx @@
      make_coe
        (Star.make r' (D.named x))
        (Abs.bind1 x domx)
        varg
    in
    let el =
      apply info.el @@
      make_coe
        (Star.make r' r)
        (Abs.bind1 x domx)
        varg
    in
    rigid_coe info.dir abs el

  | HCom info ->
    let _, cod = unleash_pi info.ty in
    let ty = inst_clo cod varg in
    let cap = apply info.cap varg in
    let app_face =
      Face.map @@ fun r r' abs ->
      let x, v = Abs.unleash1 abs in
      Abs.bind1 x @@ apply v (Val.act (D.equate r r') v)
    in
    let sys = List.map app_face info.sys in
    rigid_hcom info.dir ty cap sys

  | _ ->
    failwith "apply"

and ext_apply vext s =
  match unleash vext with
  | ExtLam abs ->
    Abs.inst1 abs s

  | Up info ->
    let tyr, sysr = unleash_ext info.ty s in
    begin
      match force_ext_sys sysr with
      | `Rigid _ ->
        let app = ExtApp (info.neu, sysr, s) in
        make @@ Up {ty = tyr; neu = app}
      | `Proj v ->
        v
    end

  | Coe info ->
    let y, ext_y = Abs.unleash1 info.abs in
    let ty_s, sys_s = unleash_ext ext_y s in
    let forall_y_sys_s =
      let filter_face face =
        match Face.forall y face with
        | `Keep -> true
        | `Delete -> false
      in
      List.filter filter_face sys_s
    in
    begin
      match force_ext_sys forall_y_sys_s with
      | `Proj v ->
        v

      | `Rigid rsys ->
        let correction =
          let face = Face.map @@ fun _ _ v -> Abs.bind1 y v in
          List.map face rsys
        in
        let abs = Abs.bind1 y ty_s in
        let cap = ext_apply info.el s in
        rigid_com info.dir abs cap correction
    end

  | HCom info ->
    let ty_s, sys_s = unleash_ext info.ty s in
    begin
      match force_ext_sys sys_s with
      | `Proj v ->
        v
      | `Rigid boundary_sys ->
        let cap = ext_apply info.cap s in
        let correction_sys =
          let face = Face.map @@ fun _ _ v -> Abs.bind [Symbol.fresh ()] v in
          List.map face boundary_sys
        in
        rigid_hcom info.dir ty_s cap @@ correction_sys @ info.sys
    end

  | _ ->
    failwith "ext_apply"


and vproj mgen ~ty0 ~ty1 ~equiv ~el : value =
  match mgen with
  | `Ok x ->
    rigid_vproj x ~ty0 ~ty1 ~equiv ~el
  | `Const `Dim0 ->
    let func = car equiv in
    apply func el
  | `Const `Dim1 ->
    el

and rigid_vproj x ~ty0 ~ty1 ~equiv ~el : value =
  match unleash el with
  | VIn info ->
    info.el1
  | Up up ->
    let neu = VProj {x; ty0; ty1; equiv; neu = up.neu} in
    make @@ Up {ty = ty1; neu}
  | _ ->
    failwith "rigid_vproj"

and if_ mot scrut tcase fcase =
  match unleash scrut with
  | Tt ->
    tcase
  | Ff ->
    fcase
  | Up up ->
    let neu = If {mot; neu = up.neu; tcase; fcase} in
    let mot' = inst_clo mot scrut in
    make @@ Up {ty = mot'; neu}
  | _ ->
    failwith "if_"

and car v =
  match unleash v with
  | Cons (v0, _) ->
    v0

  | Up info ->
    let dom, _ = unleash_sg info.ty in
    make @@ Up {ty = dom; neu = Car info.neu}

  | Coe info ->
    let x, tyx = Abs.unleash1 info.abs in
    let domx, _ = unleash_sg tyx in
    let abs = Abs.bind1 x domx in
    let el = car info.el in
    rigid_coe info.dir abs el

  | HCom info ->
    let dom, _ = unleash_sg info.ty in
    let cap = car info.cap in
    let face =
      Face.map @@ fun _ _ abs ->
      let y, v = Abs.unleash1 abs in
      Abs.bind1 y @@ car v
    in
    let sys = List.map face info.sys in
    rigid_hcom info.dir dom cap sys

  | _ ->
    failwith "car"

and cdr v =
  match unleash v with
  | Cons (_, v1) ->
    v1

  | Coe info ->
    let abs =
      let x, tyx = Abs.unleash1 info.abs in
      let domx, codx = unleash_sg tyx in
      let r, _ = Star.unleash info.dir in
      let coerx =
        make_coe
          (Star.make r (D.named x))
          (Abs.bind1 x domx)
          (car info.el)
      in
      Abs.bind1 x @@ inst_clo codx coerx
    in
    let el = cdr info.el in
    rigid_coe info.dir abs el

  | HCom info ->
    let abs =
      let r, _ = Star.unleash info.dir in
      let dom, cod = unleash_sg info.ty in
      let z = Symbol.fresh () in
      let sys =
        let face =
          Face.map @@ fun _ _ absi ->
          let yi, vi = Abs.unleash absi in
          Abs.bind yi @@ car vi
        in
        `Ok (List.map face info.sys)
      in
      let hcom =
        make_hcom
          (Star.make r (D.named z))
          dom
          (car info.cap)
          sys
      in
      Abs.bind1 z @@ inst_clo cod hcom
    in
    let cap = cdr info.cap in
    let sys =
      let face =
        Face.map @@ fun _ _ absi ->
        let yi, vi = Abs.unleash absi in
        Abs.bind yi @@ cdr vi
      in
      List.map face info.sys
    in
    rigid_com info.dir abs cap sys

  | _ -> failwith "TODO: cdr"

and inst_clo clo varg =
  match clo with
  | Clo info ->
    let Tm.B (_, tm) = info.bnd in
    Val.act info.action @@
    eval info.rel (Val varg :: info.rho) tm
  | Const v ->
    v

let const_clo v =
  Const v



module Macro =
struct
  let equiv ty0 ty1 : value =
    let rho = [Val ty0; Val ty1] in
    eval R.emp rho @@
    Tm.Macro.equiv
      (Tm.up @@ Tm.var 0)
      (Tm.up @@ Tm.var 1)

end

let rec pp_value fmt value =
  match unleash value with
  | Up up ->
    Format.fprintf fmt "%a" pp_neu up.neu
  | Lam clo ->
    Format.fprintf fmt "@[<1>(λ@ %a)@]" pp_clo clo
  | ExtLam abs ->
    Format.fprintf fmt "@[<1>(λ@ %a)@]" pp_abs abs
  | Tt ->
    Format.fprintf fmt "tt"
  | Ff ->
    Format.fprintf fmt "ff"
  | Bool ->
    Format.fprintf fmt "bool"
  | Pi {dom; cod} ->
    Format.fprintf fmt "@[<1>(Π@ %a@ %a)@]" pp_value dom pp_clo cod
  | Sg {dom; cod} ->
    Format.fprintf fmt "@[<1>(Σ@ %a@ %a)@]" pp_value dom pp_clo cod
  | Ext abs ->
    Format.fprintf fmt "@[<1>(#@ %a)@]" pp_ext_abs abs
  | Univ lvl ->
    Format.fprintf fmt "@[<1>(U@ %a)@]" Lvl.pp lvl
  | Cons (v0, v1) ->
    Format.fprintf fmt "@[<1>(cons@ %a %a)@]" pp_value v0 pp_value v1
  | V _ ->
    Format.fprintf fmt "<v-type>"
  | VIn _ ->
    Format.fprintf fmt "<vin>"
  | Coe _ ->
    Format.fprintf fmt "<coe>"
  | HCom _ ->
    Format.fprintf fmt "<hcom>"
  | FCom _ ->
    Format.fprintf fmt "<fcom>"

and pp_abs fmt abs =
  let x, v = Abs.unleash1 abs in
  Format.fprintf fmt "@[<1><%s>@ %a@]" (Symbol.to_string x) pp_value v

and pp_ext_abs fmt abs =
  let x, (tyx, sysx) = ExtAbs.unleash1 abs in
  Format.fprintf fmt "@[<1><%s>@ %a@ %a@]" (Symbol.to_string x) pp_value tyx pp_val_sys sysx

and pp_val_sys fmt sys =
  let pp_sep fmt () = Format.fprintf fmt " " in
  Format.pp_print_list ~pp_sep pp_val_face fmt sys

and pp_val_face fmt face =
  match face with
  | Face.True (r0, r1, v) ->
    Format.fprintf fmt "@[<1>[!%a=%a@ %a]@]" Dim.pp r0 Dim.pp r1 pp_value v
  | Face.False p ->
    let r0, r1 = Star.unleash p in
    Format.fprintf fmt "@[<1>[%a/=%a]@]" Dim.pp r0 Dim.pp r1
  | Face.Indet (p, v) ->
    let r0, r1 = Star.unleash p in
    Format.fprintf fmt "@[<1>[?%a=%a %a]@]" Dim.pp r0 Dim.pp r1 pp_value v

and pp_clo fmt _ =
  Format.fprintf fmt "<clo>"

and pp_neu fmt neu =
  match neu with
  | Lvl (None, i) ->
    Format.fprintf fmt "#%i" i

  | Lvl (Some x, _) ->
    Format.fprintf fmt "%s" x

  | FunApp (neu, arg) ->
    Format.fprintf fmt "@[<1>(%a@ %a)@]" pp_neu neu pp_value arg.el

  | ExtApp (neu, _, arg) ->
    Format.fprintf fmt "@[<1>(%s@ %a@ %a)@]" "@" pp_neu neu Dim.pp arg

  | Car neu ->
    Format.fprintf fmt "@[<1>(car %a)@]" pp_neu neu

  | Cdr neu ->
    Format.fprintf fmt "@[<1>(cdr %a)@]" pp_neu neu

  | _ ->
    Format.fprintf fmt "<neu>"
