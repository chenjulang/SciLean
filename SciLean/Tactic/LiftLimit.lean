import Lean
import Lean.Meta.Basic
import Lean.Elab.Tactic.Basic

open Lean 
open Lean.Meta
open Lean.Elab.Tactic

partial def replaceSubExpression (e : Expr) (test : Expr → Bool) (replace : Expr → MetaM Expr) : MetaM Expr := do
if (test e) then
  (replace e)
else
match e with
  | Expr.app f x d => do (mkApp (← (replaceSubExpression f test replace)) (← (replaceSubExpression x test replace)))
  | Expr.lam n x b _ => mkLambda n e.binderInfo x (← replaceSubExpression b test replace)

-- do lambdaTelescope e fun xs b => do
--             mkLambdaFVars xs (← replaceSubExpression b test replace)
  -- 
  -- this is incomplete and should use lambda telescope
  | _ => e


-- use 
def getlimit (e : Expr) (N : Expr) : MetaM Expr := do
  -- let lim_spec : IO.Ref Expr ← IO.mkRef arbitrary
  let test := (λ e : Expr => 
                   match e.getAppFn.constName? with
                     | some name => name == `limit
                     | none => false)
  let replace := (λ e : Expr => 
                    do
                      -- lim_spec.modify (λ _ => lim)
                      let lim := e.getAppArgs[2]
                      let mut args := #[N]
                      if e.getAppNumArgs > 3 then 
                        args := args.append e.getAppArgs[3:]
                      mkAppM' lim args)
  mkLambdaFVars #[N] (← replaceSubExpression e test replace)
  
def liftLimitCore (mvarId : MVarId) (N msg : Expr) : MetaM (List MVarId) :=
  withMVarContext mvarId do
    let tag      ← getMVarTag mvarId
    let target   ← getMVarType mvarId

    -- Check if target is actually `Impl`
    let spec := target.getAppArgs[1]
    let lim_spec ← getlimit spec N
    let new_spec ← (mkApp lim_spec N)
    let new_target ← mkAppM `Impl #[new_spec]
    let new_mvar  ← mkFreshExprSyntheticOpaqueMVar new_target tag
    let eq       ← mkEq spec (← mkAppM `limit #[lim_spec])
    let eq_mvar  ← mkFreshExprSyntheticOpaqueMVar eq

    assignExprMVar mvarId (← mkAppM `Impl.limit #[lim_spec, N, new_mvar, eq_mvar, msg])

    return [eq_mvar.mvarId!, new_mvar.mvarId!, mvarId]  

syntax (name := lift_limit) "lift_limit" (colGt term:max)* : tactic

@[tactic lift_limit] def tacticLiftLimit : Tactic
| `(tactic| lift_limit $N:term $msg:term) => do 
          let N ← elabTerm N none true
          let msg ← elabTerm msg none true
          let mainGoal ← getMainGoal
          let todos ← liftLimitCore mainGoal N msg
          setGoals todos
          pure ()
| _ => Lean.Elab.throwUnsupportedSyntax