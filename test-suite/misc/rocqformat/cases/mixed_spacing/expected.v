Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

Definition zero : nat := O.
Definition succ (n : nat) : nat := S n.
