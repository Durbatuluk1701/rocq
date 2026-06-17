Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

Inductive list (A : Set) : Set :=
  | nil : list A
  | cons : forall (x : A) (xs : list A), list A.

Definition empty_list (A : Set) : list A := @nil A.
