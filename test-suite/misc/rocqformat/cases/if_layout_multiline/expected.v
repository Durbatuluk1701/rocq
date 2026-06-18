Inductive bool : Set :=
  | true | false.

Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

Definition pick (b : bool) : nat :=
  
  if b
  then O
  else S O.
