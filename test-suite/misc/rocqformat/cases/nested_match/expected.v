Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

Fixpoint fib (n : nat) : nat :=
  match n with
  | O => O
  | S O => S O
  | S (S p) => S (fib p)
  end.
