From Stdlib Require Import Nat.
Theorem add_0_n : forall n, n + 0 = n.
Proof. intro n. rewrite Nat.add_0_r. reflexivity. Qed.
