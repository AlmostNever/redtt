type t =
  | Define of {name : string; info : Tm.info; args : TmUtil.tele; body : Tm.chk Tm.t }

type document = t list

let rec tele_to_multibind tele bdy = 
  match tele with
  | TmUtil.TEnd _ -> TmUtil.MBEnd bdy
  | TmUtil.TCons (_, tele) -> TmUtil.MBCons (tele_to_multibind tele bdy)

let to_inf decl = 
  match decl with
  | Define {info; args; body; _} ->
    let ty = TmUtil.pi_from_tele (Some info) args in
    let tm = TmUtil.lam_from_multibind (Some info) @@ tele_to_multibind args body in
    Tm.into @@ Tm.Down {ty; tm}


let rec check_document ctx decls = 
  match decls with
  | [] ->
    ()

  | decl :: decls ->
    let ctx' = check_decl ctx decl in
    check_document ctx' decls

and check_decl ctx decl = 
  let tm = to_inf decl in
  let ty = Typing.infer ~ctx ~tm in
  let el = Val.eval (Typing.Ctx.env ctx) tm in
  Typing.Ctx.def ctx ~ty ~tm:el