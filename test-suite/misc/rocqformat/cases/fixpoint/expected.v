Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

Fixpoint plus (n m : nat) : nat :=
  match n with
  | O => m
  | S p => S (plus p m)
  end.
