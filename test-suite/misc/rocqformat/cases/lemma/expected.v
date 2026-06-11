Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

Lemma zero_nat : nat.
