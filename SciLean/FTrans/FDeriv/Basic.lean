
import Mathlib.Analysis.Calculus.FDeriv.Basic
import Mathlib.Analysis.Calculus.FDeriv.Comp
import Mathlib.Analysis.Calculus.FDeriv.Prod
import Mathlib.Analysis.Calculus.FDeriv.Linear
import Mathlib.Analysis.Calculus.FDeriv.Add
import Mathlib.Analysis.Calculus.FDeriv.Mul

import Mathlib.Analysis.Calculus.Deriv.Basic
import Mathlib.Analysis.Calculus.Deriv.Inv 


import SciLean.FunctionSpaces.ContinuousLinearMap.Notation
import SciLean.FunctionSpaces.Differentiable.Basic
import SciLean.Tactic.FTrans.Basic


namespace SciLean

set_option linter.unusedVariables false

variable 
  {K : Type _} [NontriviallyNormedField K]
  {X : Type _} [NormedAddCommGroup X] [NormedSpace K X]
  {Y : Type _} [NormedAddCommGroup Y] [NormedSpace K Y]
  {Z : Type _} [NormedAddCommGroup Z] [NormedSpace K Z]
  {ι : Type _} [Fintype ι]
  {E : ι → Type _} [∀ i, NormedAddCommGroup (E i)] [∀ i, NormedSpace K (E i)]


-- Basic lambda calculus rules -------------------------------------------------
--------------------------------------------------------------------------------

theorem fderiv.id_rule 
  : (fderiv K fun x : X => x) = fun _ => fun dx =>L[K] dx
  := by ext x dx; simp

theorem fderiv.const_rule (x : X)
  : (fderiv K fun _ : Y => x) = fun _ => fun dx =>L[K] 0
  := by ext x dx; simp

theorem fderiv.comp_rule_at
  (x : X)
  (g : X → Y) (hg : DifferentiableAt K g x)
  (f : Y → Z) (hf : DifferentiableAt K f (g x))
  : (fderiv K fun x : X => f (g x)) x
    =
    let y := g x
    fun dx =>L[K]
      let dy := fderiv K g x dx
      let dz := fderiv K f y dy
      dz :=
by 
  rw[show (fun x => f (g x)) = f ∘ g by rfl]
  rw[fderiv.comp x hf hg]
  ext dx; simp

theorem fderiv.comp_rule
  (g : X → Y) (hg : Differentiable K g)
  (f : Y → Z) (hf : Differentiable K f)
  : (fderiv K fun x : X => f (g x))
    =
    fun x => 
      let y := g x
      fun dx =>L[K]
        let dy := fderiv K g x dx
        let dz := fderiv K f y dy
        dz :=
by 
  funext x;
  rw[show (fun x => f (g x)) = f ∘ g by rfl]
  rw[fderiv.comp x (hf (g x)) (hg x)]
  ext dx; simp


theorem fderiv.let_rule_at
  (x : X)
  (g : X → Y) (hg : DifferentiableAt K g x)
  (f : X → Y → Z) (hf : DifferentiableAt K (fun xy : X×Y => f xy.1 xy.2) (x, g x))
  : (fderiv K
      fun x : X =>
        let y := g x
        f x y) x
    =
    let y  := g x
    fun dx =>L[K]
      let dy := fderiv K g x dx
      let dz := fderiv K (fun xy : X×Y => f xy.1 xy.2) (x,y) (dx, dy)
      dz :=
by
  have h : (fun x => f x (g x)) = (fun xy : X×Y => f xy.1 xy.2) ∘ (fun x => (x, g x)) := by rfl
  conv => 
    lhs
    rw[h]
    rw[fderiv.comp x hf (DifferentiableAt.prod (by simp) hg)]
    rw[DifferentiableAt.fderiv_prod (by simp) hg]
  ext dx; simp[ContinuousLinearMap.comp]
  rfl


theorem fderiv.let_rule
  (g : X → Y) (hg : Differentiable K g)
  (f : X → Y → Z) (hf : Differentiable K fun xy : X×Y => f xy.1 xy.2)
  : (fderiv K fun x : X =>
       let y := g x
       f x y)
    =
    fun x => 
      let y  := g x
      fun dx =>L[K]
        let dy := fderiv K g x dx
        let dz := fderiv K (fun xy : X×Y => f xy.1 xy.2) (x,y) (dx, dy)
        dz := 
by
  funext x
  apply fderiv.let_rule_at x _ (hg x) _ (hf (x,g x))


theorem fderiv.pi_rule_at
  (x : X)
  (f : (i : ι) → X → E i) (hf : ∀ i, DifferentiableAt K (f i) x)
  : (fderiv K fun (x : X) (i : ι) => f i x) x
    = 
    fun dx =>L[K] fun i =>
      fderiv K (f i) x dx
  := fderiv_pi hf


theorem fderiv.pi_rule
  (f : (i : ι) → X → E i) (hf : ∀ i, Differentiable K (f i))
  : (fderiv K fun (x : X) (i : ι) => f i x)
    = 
    fun x => fun dx =>L[K] fun i =>
      fderiv K (f i) x dx
  := by funext x; apply fderiv_pi (fun i => hf i x)



-- Register `fderiv` as function transformation --------------------------------
--------------------------------------------------------------------------------

open Lean Meta Qq

def fderiv.discharger (e : Expr) : SimpM (Option Expr) := do
  withTraceNode `fwdDeriv_discharger (fun _ => return s!"discharge {← ppExpr e}") do
  let cache := (← get).cache
  let config : FProp.Config := {}
  let state  : FProp.State := { cache := cache }
  let (proof?, state) ← FProp.fprop e |>.run config |>.run state
  modify (fun simpState => { simpState with cache := state.cache })
  if proof?.isSome then
    return proof?
  else
    -- if `fprop` fails try assumption
    let tac := FTrans.tacticToDischarge (Syntax.mkLit ``Lean.Parser.Tactic.assumption "assumption")
    let proof? ← tac e
    return proof?

open Lean Elab Term FTrans
def fderiv.ftransExt : FTransExt where
  ftransName := ``fderiv

  getFTransFun? e := 
    if e.isAppOf ``fderiv then

      if let .some f := e.getArg? 8 then
        some f
      else 
        none
    else
      none

  replaceFTransFun e f := 
    if e.isAppOf ``fderiv then
      e.modifyArg (fun _ => f) 8 
    else          
      e

  identityRule     := .some <| .thm ``fderiv.id_rule
  constantRule     := .some <| .thm ``fderiv.const_rule
  compRule         := .some <| .thm ``fderiv.comp_rule
  lambdaLetRule    := .some <| .thm ``fderiv.let_rule
  lambdaLambdaRule := .some <| .thm ``fderiv.pi_rule

  discharger := fderiv.discharger


-- register fderiv
#eval show Lean.CoreM Unit from do
  modifyEnv (λ env => FTrans.ftransExt.addEntry env (``fderiv, fderiv.ftransExt))


end SciLean

--------------------------------------------------------------------------------
-- Function Rules --------------------------------------------------------------
--------------------------------------------------------------------------------

variable 
  {K : Type _} [NontriviallyNormedField K]
  {X : Type _} [NormedAddCommGroup X] [NormedSpace K X]
  {Y : Type _} [NormedAddCommGroup Y] [NormedSpace K Y]
  {Z : Type _} [NormedAddCommGroup Z] [NormedSpace K Z]
  {ι : Type _} [Fintype ι]
  {E : ι → Type _} [∀ i, NormedAddCommGroup (E i)] [∀ i, NormedSpace K (E i)]



-- Prod.mk -----------------------------------v---------------------------------
--------------------------------------------------------------------------------

@[ftrans_rule]
theorem Prod.mk.arg_fstsnd.fderiv_at_comp
  (x : X)
  (g : X → Y) (hg : DifferentiableAt K g x)
  (f : X → Z) (hf : DifferentiableAt K f x)
  : fderiv K (fun x => (g x, f x)) x
    =
    fun dx =>L[K]
      (fderiv K g x dx, fderiv K f x dx) := 
by 
  apply DifferentiableAt.fderiv_prod hg hf


@[ftrans_rule]
theorem Prod.mk.arg_fstsnd.fderiv_comp
  (g : X → Y) (hg : Differentiable K g)
  (f : X → Z) (hf : Differentiable K f)
  : fderiv K (fun x => (g x, f x))
    =    
    fun x => fun dx =>L[K]
      (fderiv K g x dx, fderiv K f x dx) := 
by 
  funext x; apply DifferentiableAt.fderiv_prod (hg x) (hf x)

 

-- Prod.fst --------------------------------------------------------------------
--------------------------------------------------------------------------------

@[ftrans_rule]
theorem Prod.fst.arg_self.fderiv_at_comp
  (x : X)
  (f : X → Y×Z) (hf : DifferentiableAt K f x)
  : fderiv K (fun x => (f x).1) x
    =
    fun dx =>L[K] (fderiv K f x dx).1 := 
by
  apply fderiv.fst hf


@[ftrans_rule]
theorem Prod.fst.arg_self.fderiv_comp
  (f : X → Y×Z) (hf : Differentiable K f)
  : fderiv K (fun x => (f x).1)
    =
    fun x => fun dx =>L[K] (fderiv K f x dx).1 := 
by
  funext x; apply fderiv.fst (hf x)


@[ftrans_rule]
theorem Prod.fst.arg_self.fderiv
  : fderiv K (fun xy : X×Y => xy.1)
    =  
    fun _ => fun dxy =>L[K] dxy.1
:= by funext xy; apply fderiv_fst



-- Prod.fst --------------------------------------------------------------------
--------------------------------------------------------------------------------

@[ftrans_rule]
theorem Prod.snd.arg_self.fderiv_at_comp
  (x : X)
  (f : X → Y×Z) (hf : DifferentiableAt K f x)
  : fderiv K (fun x => (f x).2) x
    =
    fun dx =>L[K] (fderiv K f x dx).2 := 
by
  apply fderiv.snd hf



@[ftrans_rule]
theorem Prod.snd.arg_self.fderiv_comp
  (f : X → Y×Z) (hf : Differentiable K f)
  : fderiv K (fun x => (f x).2)
    =
    fun x => fun dx =>L[K] (fderiv K f x dx).2 :=
by
  funext x; apply fderiv.snd (hf x)


@[ftrans_rule]
theorem Prod.snd.arg_self.fderiv
  : fderiv K (fun xy : X×Y => xy.2)
    =  
    fun _ => fun dxy =>L[K] dxy.2
:= by funext xy; apply fderiv_snd



-- HAdd.hAdd -------------------------------------------------------------------
--------------------------------------------------------------------------------

@[ftrans_rule]
theorem HAdd.hAdd.arg_a4a5.fderiv_at_comp
  (x : X) (f g : X → Y) (hf : DifferentiableAt K f x) (hg : DifferentiableAt K g x)
  : (fderiv K fun x => f x + g x) x
    =
    fun dx =>L[K]
      fderiv K f x dx + fderiv K g x dx
  := fderiv_add hf hg


@[ftrans_rule]
theorem HAdd.hAdd.arg_a4a5.fderiv_comp
  (f g : X → Y) (hf : Differentiable K f) (hg : Differentiable K g)
  : (fderiv K fun x => f x + g x)
    =
    fun x => fun dx =>L[K]
      fderiv K f x dx + fderiv K g x dx
  := by funext x; apply fderiv_add (hf x) (hg x)



-- HSub.hSub -------------------------------------------------------------------
--------------------------------------------------------------------------------

@[ftrans_rule]
theorem HSub.hSub.arg_a4a5.fderiv_at_comp
  (x : X) (f g : X → Y) (hf : DifferentiableAt K f x) (hg : DifferentiableAt K g x)
  : (fderiv K fun x => f x - g x) x
    =
    fun dx =>L[K]
      fderiv K f x dx - fderiv K g x dx
  := fderiv_sub hf hg


@[ftrans_rule]
theorem HSub.hSub.arg_a4a5.fderiv_comp
  (f g : X → Y) (hf : Differentiable K f) (hg : Differentiable K g)
  : (fderiv K fun x => f x - g x)
    =
    fun x => fun dx =>L[K]
      fderiv K f x dx - fderiv K g x dx
  := by funext x; apply fderiv_sub (hf x) (hg x)



-- Neg.neg ---------------------------------------------------------------------
--------------------------------------------------------------------------------

@[ftrans_rule]
theorem Neg.neg.arg_a2.fderiv_at_comp
  (x : X) (f : X → Y)
  : (fderiv K fun x => - f x) x
    =
    fun dx =>L[K]
      - fderiv K f x dx
  := fderiv_neg


@[ftrans_rule]
theorem Neg.neg.arg_a2.fderiv_comp
  (f : X → Y)
  : (fderiv K fun x => - f x)
    =
    fun x => fun dx =>L[K]
      - fderiv K f x dx
  := by funext x; apply fderiv_neg


-- HMul.hmul -------------------------------------------------------------------
--------------------------------------------------------------------------------

@[ftrans_rule]
theorem HMul.hMul.arg_a4a5.fderiv_at_comp
  {Y : Type _} [NormedCommRing Y] [NormedAlgebra K Y] 
  (x : X) (f g : X → Y)
  (hf : DifferentiableAt K f x) (hg : DifferentiableAt K g x)
  : (fderiv K fun x => f x * g x) x
    =
    let fx := f x
    let gx := g x
    fun dx =>L[K]
      (fderiv K g x dx) * fx + (fderiv K f x dx) * gx := 
by
  ext dx
  simp[fderiv_mul hf hg, mul_comm]; rfl


@[ftrans_rule]
theorem HMul.hMul.arg_a4a5.fderiv_comp
  {Y : Type _} [NormedCommRing Y] [NormedAlgebra K Y] 
  (f g : X → Y)
  (hf : Differentiable K f) (hg : Differentiable K g)
  : (fderiv K fun x => f x * g x)
    =
    fun x => 
      let fx := f x
      let gx := g x
      fun dx =>L[K]
        (fderiv K g x dx) * fx + (fderiv K f x dx) * gx := 
by 
  funext x; ext dx;
  simp[fderiv_mul (hf x) (hg x), mul_comm]; rfl



-- SMul.smul -------------------------------------------------------------------
--------------------------------------------------------------------------------

@[ftrans_rule]
theorem SMul.smul.arg_a3a4.fderiv_at_comp
  (x : X) (f : X → K) (g : X → Y) 
  (hf : DifferentiableAt K f x) (hg : DifferentiableAt K g x)
  : (fderiv K fun x => f x • g x) x
    =
    let k := f x
    let y := g x
    fun dx =>L[K]
      k • (fderiv K g x dx) + (fderiv K f x dx) • y  
  := fderiv_smul hf hg


@[ftrans_rule]
theorem SMul.smul.arg_a3a4.fderiv_comp
  (f : X → K) (g : X → Y) 
  (hf : Differentiable K f) (hg : Differentiable K g)
  : (fderiv K fun x => f x • g x)
    =
    fun x => 
      let k := f x
      let y := g x
      fun dx =>L[K]
        k • (fderiv K g x dx) + (fderiv K f x dx) • y  
  := by funext x; apply fderiv_smul (hf x) (hg x)



-- HDiv.hDiv -------------------------------------------------------------------
--------------------------------------------------------------------------------

@[ftrans_rule]
theorem HDiv.hDiv.arg_a4a5.fderiv_at_comp
  {R : Type _} [NontriviallyNormedField R] [NormedAlgebra R K]
  (x : R) (f : R → K) (g : R → K) 
  (hf : DifferentiableAt R f x) (hg : DifferentiableAt R g x) (hx : g x ≠ 0)
  : (fderiv R fun x => f x / g x) x
    =
    let k := f x
    let k' := g x
    fun dx =>L[R]
      ((fderiv R f x dx) * k' - k * (fderiv R g x dx)) / k'^2 := 
by
  have h : ∀ (f : R → K) x, fderiv R f x 1 = deriv f x := by simp[deriv]
  ext; simp[h]; apply deriv_div hf hg hx


@[ftrans_rule]
theorem HDiv.hDiv.arg_a4a5.fderiv_comp
  {R : Type _} [NontriviallyNormedField R] [NormedAlgebra R K]
  (f : R → K) (g : R → K) 
  (hf : Differentiable R f) (hg : Differentiable R g) (hx : ∀ x, g x ≠ 0)
  : (fderiv R fun x => f x / g x)
    =
    fun x => 
      let k := f x
      let k' := g x
      fun dx =>L[R]
        ((fderiv R f x dx) * k' - k * (fderiv R g x dx)) / k'^2 := 
by
  have h : ∀ (f : R → K) x, fderiv R f x 1 = deriv f x := by simp[deriv]
  ext x; simp[h]; apply deriv_div (hf x) (hg x) (hx x)


-- HPow.hPow ---------------------------------------------------------------------
-------------------------------------------------------------------------------- 

@[ftrans_rule]
def HPow.hPow.arg_a4.fderiv_at_comp
  (n : Nat) (x : X) (f : X → K) (hf : DifferentiableAt K f x) 
  : fderiv K (fun x => f x ^ n) x
    =
    fun dx =>L[K] n * fderiv K f x dx * (f x ^ (n-1)) :=
by
  induction n
  case zero =>
    simp; rfl
  case succ n hn =>
    ext dx
    simp_rw[pow_succ]
    rw[HMul.hMul.arg_a4a5.fderiv_at_comp x f _ (by fprop) (by fprop)]
    rw[hn]
    induction n
    case zero => simp
    case succ => 
      rw[show ∀ (n : Nat), n.succ - 1 = n by simp]
      rw[pow_succ]
      simp; ring


@[ftrans_rule]
def HPow.hPow.arg_a4.fderiv_comp
  (n : Nat) (f : X → K) (hf : Differentiable K f) 
  : fderiv K (fun x => f x ^ n)
    =
    fun x => fun dx =>L[K] n * fderiv K f x dx * (f x ^ (n-1)) :=
by
  funext x; apply HPow.hPow.arg_a4.fderiv_at_comp n x f (hf x)