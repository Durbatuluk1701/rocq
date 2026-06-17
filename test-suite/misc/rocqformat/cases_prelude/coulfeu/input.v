Inductive coulfeu : Set :=
  | Vert : coulfeu
  | Orange : coulfeu
  | Rouge : coulfeu.
Definition coul_suiv : coulfeu -> coulfeu :=
  fun c => match c with
  | Vert => Orange | Orange => Rouge | Rouge => Vert end.
Theorem th_crou_gen : forall c : coulfeu, c = Rouge -> coul_suiv c = Vert.
Proof.
  intro c0.
  (** block comment before intro *)
  intro c0rou.
  rewrite c0rou. cbn [coul_suiv]. reflexivity.
Qed.
