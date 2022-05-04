import SciLean.Core.Adjoint
import SciLean.Core.Diff

namespace SciLean

variable {α β γ : Type}
variable {X Y Z : Type} [SemiHilbert X] [SemiHilbert Y] [SemiHilbert Z]
variable {Y₁ Y₂ : Type} [SemiHilbert Y₁] [SemiHilbert Y₂]
variable {ι : Type} [Enumtype ι]


class HasAdjDiff (f : X → Y) : Prop where
  isSmooth : IsSmooth f
  hasAdjDiff : ∀ x, HasAdjoint $ δ f x

theorem infer_HasAdjDiff {f : X → Y} [IsSmooth f] : (∀ x, HasAdjoint $ δ f x) → HasAdjDiff f := sorry

----------------------------------------------------------------------

instance id.arg_x.hasAdjDiff (x : X)
  : HasAdjoint $ δ (λ x' => x') x := by simp infer_instance

instance id.arg_x.hasAdjDiff' 
  : HasAdjDiff (λ x : X => x) := by apply infer_HasAdjDiff; intro; simp; infer_instance

instance const.arg_x.hasAdjDiff (x : X)
  : HasAdjoint $ δ (λ (x' : X) (i : ι) => x') x := by simp infer_instance

instance const.arg_x.hasAdjDiff' 
  : HasAdjDiff (λ (x : X) (i : ι) => x) := by apply infer_HasAdjDiff; intro; simp; infer_instance

instance const.arg_y.hasAdjDiff (x : X) (y : Y)
  : HasAdjoint $ δ (λ (y' : Y) => x) y := by simp infer_instance

instance (priority := low) swap.arg_y.hasAdjDiff
  (f : ι → Y → Z) [∀ x, IsSmooth (f x)] [∀ x y, HasAdjoint $ δ (f x) y]
  (y : Y)
  : HasAdjoint $ δ (λ y' x => f x y') y := by simp infer_instance

instance comp.arg_x.hasAdjDiff
  (f : Y → Z) [IsSmooth f] [∀ y, HasAdjoint (δ f y)]
  (g : X → Y) [IsSmooth g] [∀ x, HasAdjoint (δ g x)]
  (x : X)
  : HasAdjoint (δ (λ x' => f (g x')) x) := by simp infer_instance

instance diag.arg_x.hasAdjDiff
  (f : Y₁ → Y₂ → Z) [IsSmooth f] [∀ y₁, IsSmooth (f y₁)] 
  [∀ y₁ y₂, HasAdjoint (λ dy₁ => δ f y₁ dy₁ y₂)]
  [∀ y₁ y₂, HasAdjoint (λ dy₂ => δ (f y₁) y₂ dy₂)]
  (g₁ : X → Y₁) [IsSmooth g₁] [∀ x, HasAdjoint (δ g₁ x)]
  (g₂ : X → Y₂) [IsSmooth g₂] [∀ x, HasAdjoint (δ g₂ x)]
  (x : X)
  : HasAdjoint $ δ (λ x' => f (g₁ x') (g₂ x')) x := 
  by 
    simp
    have inst : HasAdjoint (λ yy : Z × Z => yy.1 + yy.2) := sorry
    infer_instance

instance eval.arg_x.parm1.hasAdjDiff
  (f : X → ι → Z) [IsSmooth f] [∀ x, HasAdjoint $ δ f x] (i : ι) (x : X)
  : HasAdjoint $ δ (λ x => f x i) x := by simp infer_instance

----------------------------------------------------------------------

instance comp.arg_x.parm1.hasAdjDiff
  (a : α)
  (f : Y → α → Z) [IsSmooth f] [∀ y, HasAdjoint $ λ dy => δ f y dy a]
  (g : X → Y) [IsSmooth g] [∀ x, HasAdjoint (δ g x)]
  (x : X)
  : HasAdjoint $ λ dx => δ (λ x' => f (g x')) x dx a := by simp infer_instance


instance diag.arg_x.parm1.hasAdjDiff
  (a : α)
  (f : Y₁ → Y₂ → α → Z) [IsSmooth f] [∀ y₁, IsSmooth (f y₁)] 
  [∀ y₁ y₂, HasAdjoint (λ dy₁ => δ f y₁ dy₁ y₂ a)]
  [∀ y₁ y₂, HasAdjoint (λ dy₂ => δ (f y₁) y₂ dy₂ a)]
  (g₁ : X → Y₁) [IsSmooth g₁] [∀ x, HasAdjoint (δ g₁ x)]
  (g₂ : X → Y₂) [IsSmooth g₂] [∀ x, HasAdjoint (δ g₂ x)]
  (x : X)
  : HasAdjoint $ λ dx => δ (λ x' => f (g₁ x') (g₂ x')) x dx a := 
  by 
    simp
    have inst : HasAdjoint (λ yy : Z × Z => yy.1 + yy.2) := sorry
    infer_instance


