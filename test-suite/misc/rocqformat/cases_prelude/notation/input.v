From Stdlib Require Import Nat.
Notation "'double' x" := (x + x) (at level 10).
Definition four : nat := double 2.
