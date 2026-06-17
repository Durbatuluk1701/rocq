Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.
Definition foo : nat := O.
