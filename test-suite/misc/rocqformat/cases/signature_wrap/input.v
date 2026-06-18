Inductive nat : Set := | O : _ | S : forall n : nat, _.
Definition very_long_identifier_for_wrapping : forall (n m k : nat), nat := fun n m k => n.
