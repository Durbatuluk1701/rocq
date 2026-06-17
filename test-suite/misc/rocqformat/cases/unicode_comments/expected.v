(* Pour démontrer [c0 = Rouge], on suppose une hypothèse. *)

Inductive color : Set :=
  | Red : color
  | Green : color.

Definition next (c : color) : color :=
    match c with
    | Red => Green
    | Green => Red
    end.
