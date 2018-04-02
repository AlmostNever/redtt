type ('i, 'a) tube = 'i * 'i * 'a
type ('i, 'a) system = ('i, 'a) tube list

type atm = Thin.t0
type var = Thin.t0

type 'a vbnd = VB of 'a
type 'a abnd = AB of 'a

type chk = [`Chk]
type inf = [`Inf]

type info = Lexing.position * Lexing.position

type _ f =
  | Atom : atm -> inf f
  | Var : var -> inf f
  | Car : inf t -> inf f
  | Cdr : inf t -> inf f
  | App : inf t * chk t -> inf f
  | Down : {ty : chk t; tm : chk t} -> inf f
  | Coe : chk t * chk t * chk t abnd * chk t -> inf f
  | HCom : chk t * chk t * chk t * chk t * (chk t, chk t vbnd) system -> inf f

  | Up : inf t -> chk f

  | Univ : Lvl.t -> chk f
  | Pi : chk t * chk t vbnd -> chk f
  | Sg : chk t * chk t vbnd -> chk f
  | Ext : chk t * (chk t, chk t) system -> chk f
  | Interval : chk f

  | Lam : chk t vbnd -> chk f
  | Cons : chk t * chk t -> chk f
  | Dim0 : chk f
  | Dim1 : chk f

and thin = {vthin : Thin.t0; athin : inf t Thin.t}

and 'a node = {info : info option; con : 'a f; thin : thin}
and 'a t = 'a node

let into tf = {info = None; con = tf; thin = {vthin = Thin.id; athin = Thin.id}}
let into_info info tf = {info = Some info; con = tf; thin = {vthin = Thin.id; athin = Thin.id}}
let info node = node.info

let thin : type a. thin -> a t -> a t = 
  fun th {info; con; thin} ->
    {info; con; thin = {vthin = Thin.cmp thin.vthin th.vthin; athin = Thin.cmp thin.athin th.athin}}

let thin_abnd : type a. thin -> a t abnd -> a t abnd = 
  fun th _ ->
    failwith "todo: thin_abnd"

let thin_vbnd : type a. thin -> a t vbnd -> a t vbnd = 
  fun th _ ->
    failwith "todo: thin_vbnd"

let thin_bsys : type a. thin -> (a t, a t vbnd) system -> (a t, a t vbnd) system = 
  fun th _ ->
    failwith "todo: thin_bsys"

let thin_sys : type a. thin -> (a t, a t) system -> (a t, a t) system = 
  fun th _ ->
    failwith "todo: thin_sys"


let thin_f : type a. thin -> a f -> a f = 
  fun th tf ->
    match tf with 
    | Atom g ->
      failwith "hard case"

    | Var g ->
      let h = Thin.cmp g th.vthin in
      Var h

    | Car t ->
      Car (thin th t)

    | Cdr t -> 
      Cdr (thin th t)

    | App (t1, t2) ->
      App (thin th t1, thin th t2)

    | Down {ty; tm} ->
      Down {ty = thin th ty; tm = thin th tm}

    | Coe (td0, td1, bnd, tm) ->
      Coe (thin th td0, thin th td1, thin_abnd th bnd, thin th tm)

    | HCom (td0, td1, ty, tm, sys) -> 
      HCom (thin th td0, thin th td1, thin th ty, thin th tm, thin_bsys th sys)

    | Up t ->
      Up (thin th t)

    | Univ lvl ->
      tf

    | Pi (dom, cod) ->
      Pi (thin th dom, thin_vbnd th cod)

    | Sg (dom, cod) ->
      Sg (thin th dom, thin_vbnd th cod)

    | Ext (ty, sys) ->
      Ext (thin th ty, thin_sys th sys)

    | Interval ->
      tf

    | Lam bdy ->
      Lam (thin_vbnd th bdy)

    | Cons (t1, t2) ->
      Cons (thin th t1, thin th t2)

    | Dim0 ->
      tf

    | Dim1 ->
      tf


let out node = thin_f node.thin node.con

let thin_var f =
  thin {vthin = f; athin = Thin.id}

let thin_atom f =
  thin {athin = f; vthin = Thin.id}

let path (VB ty, tm0, tm1) =
  let tube0 = (into @@ Up (into @@ Var Thin.id), into Dim0, thin_var (Thin.skip Thin.id) tm0) in
  let tube1 = (into @@ Up (into @@ Var Thin.id), into Dim1, thin_var (Thin.skip Thin.id) tm1) in
  into @@ Pi (into Interval, VB (into @@ Ext (ty, [tube0; tube1])))

module Pretty =
struct
  module Env :
  sig
    type t
    val emp : t
    val var : int -> t -> string
    val bind : t -> string * t
  end =
  struct
    type t = int * string list

    let emp = 0, []
    let var i (_, xs) = List.nth xs i
    let bind (i, xs) =
      let x = "x" ^ string_of_int i in
      x, (i + 1, x :: xs)
  end

  let pp : type a. Env.t -> Format.formatter -> a t -> unit = 
    fun _ _ -> failwith "pp"
end