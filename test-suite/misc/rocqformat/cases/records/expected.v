Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

Record point : Set :={ x  : nat; y  : nat }.
Definition origin : point := {| x := O; y := O |}.
