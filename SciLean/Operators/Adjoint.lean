import SciLean.Categories.Lin

import Init.Classical

namespace SciLean

variable {X Y Z : Type} [Hilbert X] [Hilbert Y] [Hilbert Z]

def adjoint_definition (f : X → Y) (h : IsLin f) (y : Y) 
    : ∃ (x' : X), ∀ x, ⟨x', x⟩ = ⟨y, (f x)⟩ := sorry

noncomputable
def adjoint (f : X → Y) (y : Y) : X :=
    match Classical.propDecidable (IsLin f) with
      | isTrue  h => Classical.choose (adjoint_definition f h y)
      | _ => (0 : X)

postfix:max "†" => adjoint

namespace Adjoint

  instance (f : X → Y) [IsLin f] : IsLin f† := sorry

  @[simp]
  def adjoint_of_adjoint (f : X → Y) [IsLin f] : f†† = f := sorry

  @[simp] 
  def adjoint_of_id 
      : (id : X → X)† = id := sorry

  @[simp]
  def adjoint_of_const {n}
      : (λ (x : X) (i : Fin n) => x)† = sum := sorry

  @[simp]
  def adjoint_of_sum {n}
      : (sum)† = (λ (x : X) (i : Fin n) => x) := sorry

  @[simp]
  def adjoint_of_swap {n m}
      : (λ (f : Fin n → Fin m → Y) => (λ j i => f i j))† = λ f i j => f j i := sorry

  @[simp] 
  def adjoint_of_composition (f : Y → Z) [IsLin f] (g : X → Y) [IsLin g] 
      : (f∘g)† = g† ∘ f† := sorry

  variable (f g : X → Y) 
  variable (r : ℝ)

  @[simp]
  def adjoint_of_add [IsLin f] [IsLin g] : (f + g)† = f† + g† := sorry

  @[simp]
  def adjoint_of_sub [IsLin f] [IsLin g] : (f - g)† = f† - g† := sorry

  @[simp]
  def adjoint_of_hmul [IsLin f] : (r*f)† = r*f† := sorry

  @[simp]
  def adjoint_of_neg [IsLin f] : (-f)† = -f† := sorry

end Adjoint