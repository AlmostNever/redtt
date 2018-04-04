type can = [`Can]
type neu = [`Neu]

type 'a bnd = B of 'a

type ('i, 'a) tube = 'i * 'i * 'a option
type ('i, 'a) system = ('i, 'a) tube list

module DimVal = 
struct
  type t = 
    | Dim0
    | Dim1
    | Lvl of int
    | Atom of string
end

module DimBind :
sig
  type 'a t
  val inst : 'a t -> DimVal.t -> 'a
  val make : (DimVal.t -> 'a) -> 'a t
  val map : ('a -> 'b) -> 'a t -> 'b t
end = 
struct
  type 'a t = DimVal.t -> 'a
  let inst f a = f a
  let make f = f
  let map f g x = f (g x)
end

module StringMap = Map.Make (String)

type 'a dimbind = 'a DimBind.t

type _ f = 
  | Atom : string -> can f
  | Lvl : int -> neu f

  | Up : can t * neu t -> can f

  | Pi : clo * bclo -> can f
  | Sg : clo * bclo -> can f
  | Ext : clo * (can t, clo) system -> can f
  | Univ : Lvl.t -> can f
  | Interval : can f

  | Dim0 : can f
  | Dim1 : can f

  | Lam : bclo -> can f
  | Cons : clo * clo -> can f

  | Coe : can t * can t * can t dimbind * can t -> can f

  | HCom : can t * can t * can t * can t * (can t, can t dimbind) system -> can f

  | App : neu t * can t -> neu f
  | Car : neu t -> neu f
  | Cdr : neu t -> neu f

and 'a t = { con : 'a f; atom_env : atom_env list }

and atom_env = can t StringMap.t
and env = can t list
and clo = Clo of Tm.chk Tm.t * env * atom_env list
and bclo = BClo of Tm.chk Tm.t Tm.bnd * env * atom_env list

let into vf = 
  {con = vf; atom_env = []}

let merge_atom_envs arho0 arho1 =
  StringMap.merge (fun _ x _ -> x) arho0 arho1

let subst_atoms arho v =
  {con = v.con; atom_env = arho @ v.atom_env}

let clo_subst_atoms arho clo = 
  let Clo (t, vrho, arho') = clo in
  Clo (t, vrho, arho @ arho')

let bclo_subst_atoms arho clo = 
  let BClo (t, vrho, arho') = clo in
  BClo (t, vrho, arho @ arho')


let embed_dimval dv = 
  match dv with 
  | DimVal.Dim0 -> into Dim0
  | DimVal.Dim1 -> into Dim1
  | DimVal.Atom a -> into @@ Atom a
  | DimVal.Lvl i -> into @@ Up (into Interval, into @@ Lvl i)


let rec subst_atoms_f : type a. atom_env list -> a f -> a f =
  fun arhos vf ->
    match vf with
    | Atom x ->
      proj_atom (List.rev arhos) x

    | Up (vty, vneu) ->
      Up (subst_atoms arhos vty, subst_atoms arhos vneu)

    | Pi (clo, bclo) ->
      Pi (clo_subst_atoms arhos clo, bclo_subst_atoms arhos bclo)

    | Sg (clo, bclo) ->
      Sg (clo_subst_atoms arhos clo, bclo_subst_atoms arhos bclo)

    | Ext (vty, vsys) ->
      failwith ""

    | Lam bclo ->
      Lam (bclo_subst_atoms arhos bclo)

    | Cons (clo0, clo1) ->
      Cons (clo_subst_atoms arhos clo0, clo_subst_atoms arhos clo1)

    | Coe (vd0, vd1, vbnd, v) ->
      let vd0' = subst_atoms arhos vd0 in
      let vd1' = subst_atoms arhos vd1 in
      let vbnd' = dimbind_subst_atoms arhos vbnd in
      let v' = subst_atoms arhos v in
      Coe (vd0', vd1', vbnd', v')

    | HCom (vd0, vd1, vty, vcap, vsys) ->
      let vd0' = subst_atoms arhos vd0 in
      let vd1' = subst_atoms arhos vd1 in
      let vty' = subst_atoms arhos vty in
      let vcap' = subst_atoms arhos vcap in
      let vsys' = List.map (btube_subst_atoms arhos) vsys in
      HCom (vd0', vd1', vty', vcap', vsys')

    | App (vneu, varg) ->
      App (subst_atoms arhos vneu, subst_atoms arhos varg)

    | Car vneu ->
      Car (subst_atoms arhos vneu)

    | Cdr vneu ->
      Cdr (subst_atoms arhos vneu)

    | Univ _ -> vf
    | Interval -> vf
    | Dim0 -> vf
    | Dim1 -> vf
    | Lvl _ -> vf


(* TODO: optimize *)
and proj_atom (arhos : atom_env list) (x : string) : can f = 
  match arhos with 
  | [] -> Atom x
  | arho :: arhos ->
    match StringMap.find_opt x arho with 
    | None -> proj_atom arhos x
    | Some v -> subst_atoms_f (List.rev_append arhos v.atom_env) v.con


and btube_subst_atoms arhos (vd0, vd1, obnd) =
  let vd0' = subst_atoms arhos vd0 in
  let vd1' = subst_atoms arhos vd1 in
  let obnd' =
    match project_dimval vd0', project_dimval vd1', obnd with
    | DimVal.Dim0, DimVal.Dim1, _ -> None
    | DimVal.Dim1, DimVal.Dim0, _ -> None
    | _, _, Some bnd ->
      Some (dimbind_subst_atoms arhos bnd)
    | _ -> failwith "btube_subst_atoms: expected Some"
  in
  (vd0', vd1', obnd')

and dimbind_subst_atoms arhos bnd = 
  DimBind.make @@ fun x ->
  let arhos' =
    match x with 
    | DimVal.Atom x -> List.map (StringMap.remove x) arhos
    | _ -> arhos
  in
  subst_atoms arhos' @@ DimBind.inst bnd x

and project_dimval (type a) (v : a t) = 
  match out v with
  | Dim0 -> DimVal.Dim0
  | Dim1 -> DimVal.Dim1
  | Atom a -> DimVal.Atom a
  | Up (_, vneu) ->
    begin
      match out vneu with
      | Lvl i -> DimVal.Lvl i
      | _ -> failwith "project_dimval/Up"
    end
  | _ -> failwith "project_dimval"

and out : type a. a t -> a f = fun node ->
  subst_atoms_f node.atom_env node.con

let clo tm rho = 
  Clo (tm, rho, [])

let bclo bnd rho =
  BClo (bnd, rho, [])


let map_btubes f vsys = 
  List.map (fun (vd0, vd1, vbnd) -> (vd0, vd1, Option.map (DimBind.map f) vbnd)) vsys


let out_pi v = 
  match out v with 
  | Pi (dom, cod) -> dom, cod
  | _ -> failwith "out_pi"

let out_sg v = 
  match out v with 
  | Sg (dom, cod) -> dom, cod
  | _ -> failwith "out_sg"


let rec eval : type a. env -> a Tm.t -> can t =
  fun rho tm ->
    match Tm.out tm with 
    | Tm.Var i ->
      let v = Thin.proj i rho in
      v

    | Tm.Pi (dom, cod) ->
      into @@ Pi (clo dom rho, bclo cod rho)

    | Tm.Sg (dom, cod) ->
      into @@ Sg (clo dom rho, bclo cod rho)

    | Tm.Ext (ty, sys) ->
      into @@ Ext (clo ty rho, eval_sys rho sys)

    | Tm.Lam bdy ->
      into @@ Lam (bclo bdy rho)

    | Tm.Cons (t0, t1) ->
      into @@ Cons (clo t0 rho, clo t1 rho)

    | Tm.Coe (d0, d1, Tm.B ty, tm) ->
      let vd0 = eval rho d0 in
      let vd1 = eval rho d1 in
      let vty = DimBind.make (fun x -> eval (embed_dimval x :: rho) ty) in
      let vtm = eval rho tm in
      into @@ Coe (vd0, vd1, vty, vtm)

    | Tm.HCom (d0, d1, ty, cap, sys) ->
      let vd0 = eval rho d0 in
      let vd1 = eval rho d1 in
      let vty = eval rho ty in 
      let vcap = eval rho cap in
      let vsys = eval_bsys rho sys in
      into @@ HCom (vd0, vd1, vty, vcap, vsys)

    | Tm.Univ lvl ->
      into @@ Univ lvl

    | Tm.Interval -> 
      into Interval

    | Tm.Dim0 ->
      into Dim0

    | Tm.Dim1 ->
      into Dim1

    | Tm.Car t ->
      car @@ eval rho t

    | Tm.Cdr t ->
      cdr @@ eval rho t

    | Tm.App (t1, t2) ->
      apply (eval rho t1) (eval rho t2)

    | Tm.Down t ->
      eval rho t.tm

    | Tm.Up t ->
      eval rho t


and eval_sys rho sys =
  List.map (eval_tube rho) sys

and eval_bsys rho bsys =
  List.map (eval_btube rho) bsys

and eval_tube rho (t0, t1, otm) =
  let vd0 = eval rho t0 in
  let vd1 = eval rho t1 in
  let ov =
    match project_dimval vd0, project_dimval vd1, otm with
    | DimVal.Dim0, DimVal.Dim1, _ -> None
    | DimVal.Dim1, DimVal.Dim0, _ -> None
    | _, _, Some tm -> Some (clo tm rho)
    | _ -> failwith "eval_tube: expected Some"
  in
  (vd0, vd1, ov)

and eval_btube rho (t0, t1, obnd) =
  let vd0 = eval rho t0 in
  let vd1 = eval rho t1 in
  let ovbnd =
    match project_dimval vd0, project_dimval vd1, obnd with
    | DimVal.Dim0, DimVal.Dim1, _ -> None
    | DimVal.Dim1, DimVal.Dim0, _ -> None
    | _, _, Some (Tm.B tm) ->
      let vbnd = 
        DimBind.make @@ fun x ->
        eval (embed_dimval x :: rho) tm
      in
      Some vbnd
    | _ -> failwith "eval_tube: expected Some"
  in
  (vd0, vd1, ovbnd)



and com (vd0, vd1, vbnd, vcap, vsys) =
  let vcap' = into @@ Coe (vd0, vd1, vbnd, vcap) in
  let vty' = DimBind.inst vbnd @@ project_dimval vd1 in
  let vsys' = List.map (fun (vd0', vd1', ovbnd) -> (vd0', vd1', Option.map (fun vbnd -> DimBind.make (fun x -> into @@ Coe (embed_dimval x, vd1, vbnd, DimBind.inst vbnd x))) ovbnd)) vsys in
  into @@ HCom (vd0, vd1, vty', vcap', vsys')

and out_bind_pi vbnd = 
  let a = "fresh" in
  match out @@ DimBind.inst vbnd @@ DimVal.Atom a with
  | Pi (dom, cod) ->
    DimBind.make (fun x -> clo_subst_atoms [StringMap.singleton a (embed_dimval x)] dom),
    DimBind.make (fun x -> bclo_subst_atoms [StringMap.singleton a (embed_dimval x)] cod)
  | _ -> failwith "out_bind_pi"

and out_bind_sg vbnd = 
  let a = "fresh" in
  match out @@ DimBind.inst vbnd @@ DimVal.Atom a with
  | Sg (dom, cod) ->
    DimBind.make (fun x -> clo_subst_atoms [StringMap.singleton a (embed_dimval x)] dom),
    DimBind.make (fun x -> bclo_subst_atoms [StringMap.singleton a (embed_dimval x)] cod)
  | _ -> failwith "out_bind_sg"

and apply vfun varg = 
  match out vfun with 
  | Lam bclo ->
    inst_bclo bclo varg

  | Up (vty, vneu) ->
    let dom, cod = out_pi vty in
    let vcod = inst_bclo cod varg in
    reflect vcod @@ into @@ App (vneu, varg)

  | Coe (vd0, vd1, vbnd, vfun) ->
    let dom, cod = out_bind_pi vbnd in
    let vdom = DimBind.map eval_clo dom in
    let vcod =
      DimBind.make @@ fun x -> 
      let coe = into @@ Coe (vd1, embed_dimval x, vdom, varg) in
      inst_bclo (DimBind.inst cod x) coe
    in
    let coe = into @@ Coe (vd1, vd0, vdom, varg) in
    into @@ Coe (vd0, vd1, vcod, apply vfun coe)

  | _ -> failwith "apply"

and car v = 
  match out v with 
  | Cons (clo, _) ->
    eval_clo clo

  | Up (vty, vneu) -> 
    let dom, cod = out_sg vty in
    let vdom = eval_clo dom in
    reflect vdom @@ into @@ Car vneu

  | Coe (vd0, vd1, vbnd, v) ->
    let dom, cod = out_bind_sg vbnd in
    let vdom = DimBind.map eval_clo dom in
    let vcar = car v in
    into @@ Coe (vd0, vd1, vdom, vcar)


(*

  | HCom (vd0, vd1, vty, vcap, vsys) ->
    let dom, cod = out_sg vty in
    let vdom = eval_clo dom in
    let vcap' = car vcap in
    let vsys' = map_btubes car vsys in
    into @@ HCom (vd0, vd1, vdom, vcap', vsys')

*)
  | _ -> failwith "car"

(* TODO: hcom *)
and cdr v = 
  match out v with 
  | Cons (_, clo) ->
    eval_clo clo

  | Up (vty, vneu) ->
    let dom, cod = out_sg vty in
    let vcar = car v in
    let vcod = inst_bclo cod vcar in
    reflect vcod @@ into @@ Cdr vneu

  | Coe (vd0, vd1, vbnd, v) -> 
    let dom, cod = out_bind_pi vbnd in
    let vdom = DimBind.map eval_clo dom in
    let vcar = car v in
    let vcod =
      DimBind.make @@ fun x -> 
      let coe = into @@ Coe (vd0, embed_dimval x, vdom, vcar) in
      inst_bclo (DimBind.inst cod x) coe
    in
    into @@ Coe (vd0, vd1, vcod, cdr v)

  | _ -> failwith "cdr"

and reflect vty vneu =
  match out vty with
  | Ext (dom, sys) ->
    reflect_ext dom sys vneu
  | _ -> into @@ Up (vty, vneu)

and reflect_ext dom sys vneu = 
  match sys with 
  | [] -> reflect (eval_clo dom) vneu
  | (vd0, vd1, clo) :: sys ->
    if dim_eq vd0 vd1 then 
      match clo with 
      | Some clo -> eval_clo clo
      | None -> failwith "reflect_ext: did not expect None in tube"
    else
      reflect_ext dom sys vneu

and dim_eq vd0 vd1 =
  match out vd0, out vd1 with
  | Dim0, Dim0 -> true
  | Dim1, Dim1 -> true
  | Atom x, Atom y -> x = y
  | Up (_, vnd0), Up (_, vnd1) ->
    dim_eq_neu vnd0 vnd1
  | _ -> false

(* The only reason this makes sense is that the neutral form of dimensions
   can only be variables or atoms. This does *not* work if we allow dimensions
   to appear in sigma types, or on the rhs of pi types, etc. *)
and dim_eq_neu vnd0 vnd1 = 
  match out vnd0, out vnd1 with 
  | Lvl i, Lvl j -> i = j
  | _ -> false

and inst_bclo : bclo -> can t -> can t =
  fun (BClo (Tm.B tm, vrho, arho)) v ->
    subst_atoms arho @@ eval (v :: vrho) tm

and eval_clo : clo -> can t = 
  fun (Clo (tm, vrho, arho)) -> 
    subst_atoms arho @@ eval vrho tm
