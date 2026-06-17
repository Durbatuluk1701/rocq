Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

#[local] Definition hidden : nat := O.
Definition visible : nat := hidden.
