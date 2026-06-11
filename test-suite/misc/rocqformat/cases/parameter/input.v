Inductive nat : Set := | O : _ | S : forall n : nat, _.
Parameter (n : nat).
Definition use_n : nat := n.
