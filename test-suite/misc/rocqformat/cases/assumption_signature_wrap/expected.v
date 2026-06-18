Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

Definition very_long_identifier_for_wrapping :
  forall n m k : nat, nat := fun n m k => n.

Theorem very_long_theorem_name_for_wrapping
  (n m k : nat) : nat.

Admitted.

Axiom
  (very_long_axiom_name_for_wrapping :
     forall n m k : nat, nat).

Parameter
  (very_long_parameter_name_for_wrapping :
     forall n m k : nat, nat).
