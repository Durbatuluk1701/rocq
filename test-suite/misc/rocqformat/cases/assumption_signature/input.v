Inductive nat : Set :=
  | O : _
  | S : forall n : nat, _.

Example ex_nat : nat := O.

Theorem th_nat (n : nat) : nat.
Admitted.

Axiom (ax_h : nat).
Parameter (par_n : nat).
