Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

Axiom (nat_h : nat).
