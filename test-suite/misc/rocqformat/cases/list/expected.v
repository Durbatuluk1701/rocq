Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

Inductive list (A : Set) : Set :=
  | nil : list A
  | cons : forall (x : A) (xs : list A), list A.

Fixpoint length (A : Set) (l : list A) : nat :=
  match l with
  | nil => O
  | cons _ xs => S (length A xs)
  end.
