Inductive nat : Set := | O : _ | S : forall n : nat, _.
Section S.
Variable (n : nat).
Definition twice : nat := n.
End S.
