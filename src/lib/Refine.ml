open Unify
open Contextual
open RedBasis

module Notation = Monad.Notation (Contextual)
open Notation

let rec pop_hole =
  popr >>= function
  | E (alpha, ty, Hole) ->
    ret (alpha, ty)
  | _ -> failwith "No hole"

let refine_pair =
  pop_hole >>= fun (alpha, ty) ->
  match Tm.unleash ty with
  | Tm.Sg (dom, Tm.B (_, cod)) ->
    hole Emp dom @@ fun proj0 ->
    let cod' = Tm.subst (Tm.Sub (Tm.Id, proj0)) cod in
    hole Emp cod' @@ fun proj1 ->
    define Emp alpha ~ty @@
    Tm.cons (Tm.up proj0) (Tm.up proj1)
  | _ ->
    failwith "refine_pair"

let refine_tt =
  pop_hole >>= fun (alpha, ty) ->
  match Tm.unleash ty with
  | Tm.Bool ->
    define Emp alpha ~ty @@
    Tm.make Tm.Tt
  | _ ->
    failwith "refine_tt"

let test_script : unit m =
  let alpha = Name.fresh () in
  let bool = Tm.make Tm.Bool in
  let goal_ty = Tm.sg None bool bool in
  pushr @@ E (alpha, goal_ty, Hole) >>
  begin
    (* This isn't quite right: I need to descend past the Defn notes that get unleashed *)
    refine_pair >>
    refine_tt >>
    refine_tt
  end >>
  failwith "what now? Lol"


