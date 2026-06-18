From Stdlib Require Import Nat.
Lemma add_succ_r : forall n m : nat, S (n + m) = n + S m.
Proof.
  intros n m. induction n as [| n IHn].
  - reflexivity.
  - simpl. rewrite IHn. reflexivity.
Qed.
