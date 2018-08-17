import path
import void
import unit
import nat
import equivalence
import isotoequiv

data int where
| pos [n : nat]
| negsuc [n : nat]

let pred (x : int) : int =
  elim x [
  | pos n ⇒
    elim n [
    | zero ⇒ negsuc zero
    | suc n ⇒ pos n
    ]
  | negsuc n ⇒ negsuc (suc n)
  ]

let isuc (x : int) : int =
  elim x [
  | pos n ⇒ pos (suc n)
  | negsuc n ⇒
    elim n [
    | zero ⇒ pos zero
    | suc n ⇒ negsuc n
    ]
  ]


let pred-isuc (n : int) : Path int (pred (isuc n)) n =
  elim n [
  | pos n ⇒ auto
  | negsuc n ⇒
    elim n [
    | zero ⇒ auto
    | suc n ⇒ auto
    ]
  ]

let isuc-pred (n : int) : Path int (isuc (pred n)) n =
  elim n [
  | pos n ⇒
    elim n [
    | zero ⇒ auto
    | suc n' ⇒ auto
    ]
  | negsuc n ⇒ auto
  ]

let isuc-equiv : Equiv int int =
  Iso/Equiv _ _ <isuc, <pred, <isuc-pred, pred-isuc>>>

let IntPathCode (x : int) : int → type =
  elim x [
  | pos m ⇒ λ y →
    elim y [
    | pos n ⇒ NatPathCode m n
    | negsuc _ ⇒ void
    ]
  | negsuc m ⇒ λ y →
    elim y [
    | pos _ ⇒ void
    | negsuc n ⇒ NatPathCode m n
    ]
  ]

let int-refl (x : int) : IntPathCode x x =
  elim x [
  | pos m ⇒ nat-refl m
  | negsuc m ⇒ nat-refl m
  ]

let int-path/encode (x,y : int) (p : Path int x y)
  : IntPathCode x y
  =
  coe 0 1 (int-refl x) in λ i → IntPathCode x (p i)

let int-repr (x : int) : nat =
  elim x [ pos m ⇒ m | negsuc m ⇒ m ]

let int/discrete : discrete int =
  λ x →
  elim x [
  | pos m ⇒ λ y →
    elim y [
    | pos n ⇒
      elim (nat/discrete m n) [
      | inl l ⇒ inl (λ i → pos (l i))
      | inr r ⇒ inr (λ p → r (λ i → int-repr (p i)))
      ]
    | negsuc n ⇒ inr (int-path/encode _ _)
    ]
  | negsuc m ⇒ λ y →
    elim y [
    | pos n ⇒ inr (int-path/encode _ _)
    | negsuc n ⇒
      elim (nat/discrete m n) [
      | inl l ⇒ inl (λ i → negsuc (l i))
      | inr r ⇒ inr (λ p → r (λ i → int-repr (p i)))
      ]
    ]
  ]

let int/set : IsSet int =
  discrete/to/set int int/discrete
