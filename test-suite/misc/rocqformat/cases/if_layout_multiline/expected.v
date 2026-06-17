Inductive bool : Set :=
  | true : _
  | false : _.

Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

Definition pick (b : bool) : nat :=
  
  if b
  then O
  else S O.
