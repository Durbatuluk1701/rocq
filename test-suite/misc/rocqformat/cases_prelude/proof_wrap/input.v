From Stdlib Require Import Nat.
Lemma long_line : forall n m p q r : nat, n + m + p + q + r = r + q + p + m + n.
Proof.
  intros n m p q r. repeat rewrite Nat.add_assoc. reflexivity.
Qed.
