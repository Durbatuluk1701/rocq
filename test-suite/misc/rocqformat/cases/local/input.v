Inductive nat : Set := | O : _ | S : forall n : nat, _.
Local Definition hidden : nat := O.
Definition visible : nat := hidden.
