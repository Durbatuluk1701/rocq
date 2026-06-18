Module Type S.
  Parameter t : Type.
End S.

Module F (X : S).
  Definition ty := X.t.
End F.
