module subst where

open import lib

open import cedille-types
open import ctxt-types
open import is-free
open import rename
open import general-util
open import syntax-util

substh-ret-t : Set → Set
substh-ret-t T = ∀ {ed} → ctxt → renamectxt → trie ⟦ ed ⟧ → T → T

substh : ∀ {ed} → substh-ret-t ⟦ ed ⟧
substh-term : substh-ret-t term
substh-type : substh-ret-t type
substh-kind : substh-ret-t kind
substh-tk : substh-ret-t tk
substh-optClass : substh-ret-t optClass
substh-optGuide : substh-ret-t optGuide
substh-optTerm : substh-ret-t optTerm
substh-optType : substh-ret-t optType
substh-liftingType : substh-ret-t liftingType
substh-arg : substh-ret-t arg
substh-args : substh-ret-t args
substh-params : substh-ret-t params
substh-cases : substh-ret-t cases
substh-varargs : {ed : exprd} → ctxt → renamectxt → trie ⟦ ed ⟧ → varargs → varargs × renamectxt

substh{TERM} = substh-term
substh{TYPE} = substh-type
substh{KIND} = substh-kind
substh{LIFTINGTYPE} = substh-liftingType
substh{TK} = substh-tk
substh{ARG} = substh-arg
substh{QUALIF} = λ Γ ρ σ q → q

subst-rename-var-if : {ed : exprd} → ctxt → renamectxt → var → trie ⟦ ed ⟧ → var
subst-rename-var-if Γ ρ "_" σ = "_"
subst-rename-var-if Γ ρ x σ =
  {- rename bound variable x iff it is one of the vars being substituted for,
     or if x occurs free in one of the terms we are substituting for vars,
     or if it is the renamed version of any variable -}
  if trie-contains σ x || trie-any (is-free-in check-erased x) σ || renamectxt-in-range ρ x || ctxt-binds-var Γ x then
    rename-away-from x (λ s → ctxt-binds-var Γ s || trie-contains σ s) ρ
  else
    x

substh-term Γ ρ σ (App t m t') = App (substh-term Γ ρ σ t) m (substh-term Γ ρ σ t')
substh-term Γ ρ σ (AppTp t tp) = AppTp (substh-term Γ ρ σ t) (substh-type Γ ρ σ tp)
substh-term Γ ρ σ (Lam _ b _ x oc t) =
  let x' = subst-rename-var-if Γ ρ x σ in
    Lam posinfo-gen b posinfo-gen x' (substh-optClass Γ ρ σ oc)
      (substh-term (ctxt-var-decl x' Γ) (renamectxt-insert ρ x x') σ t)
substh-term Γ ρ σ (Let _ (DefTerm _ x m t) t') =
  let x' = subst-rename-var-if Γ ρ x σ in
     (Let posinfo-gen (DefTerm posinfo-gen x' (substh-optType Γ ρ σ m) (substh-term Γ ρ σ t))
      (substh-term (ctxt-var-decl x' Γ) (renamectxt-insert ρ x x') σ t'))
substh-term Γ ρ σ (Let _ (DefType _ x k t) t') =
  let x' = subst-rename-var-if Γ ρ x σ in
     (Let posinfo-gen (DefType posinfo-gen x' (substh-kind Γ ρ σ k) (substh-type Γ ρ σ t))
      (substh-term (ctxt-var-decl x' Γ) (renamectxt-insert ρ x x') σ t'))
substh-term Γ ρ σ (Open _ x t) = Open posinfo-gen x (substh-term Γ ρ σ t)
substh-term Γ ρ σ (Parens _ t _) = substh-term Γ ρ σ t
substh-term{TERM} Γ ρ σ (Var _ x) =
 let x' = renamectxt-rep ρ x in
   trie-lookup-else (Var posinfo-gen x') σ x'
substh-term{ARG} Γ ρ σ (Var _ x) =
 let x' = renamectxt-rep ρ x in
   inst-lookup-term σ x'
substh-term{QUALIF} Γ ρ σ (Var _ x) =
 let x' = renamectxt-rep ρ x in
   qualif-lookup-term σ x'
substh-term{QUALIF} Γ ρ σ (Hole pi) = Hole (ctxt-get-current-filename Γ # pi)
substh-term Γ ρ σ (Var _ x) = Var posinfo-gen (renamectxt-rep ρ x)
substh-term Γ ρ σ (Hole pi) = Hole pi -- Retain position, so jumping to hole works
substh-term Γ ρ σ (Beta _ ot ot') = Beta posinfo-gen (substh-optTerm Γ ρ σ ot) (substh-optTerm Γ ρ σ ot')
substh-term Γ ρ σ (IotaPair _ t1 t2 og pi') = IotaPair posinfo-gen (substh-term Γ ρ σ t1) (substh-term Γ ρ σ t2) (substh-optGuide Γ ρ σ og) pi'
substh-term Γ ρ σ (IotaProj t n _) = IotaProj (substh-term Γ ρ σ t) n posinfo-gen
substh-term Γ ρ σ (Epsilon _ lr m t) = Epsilon posinfo-gen lr m (substh-term Γ ρ σ t)
substh-term Γ ρ σ (Sigma _ t) = Sigma posinfo-gen (substh-term Γ ρ σ t)
substh-term Γ ρ σ (Phi _ t t₁ t₂ _) = Phi posinfo-gen (substh-term Γ ρ σ t) (substh-term Γ ρ σ t₁) (substh-term Γ ρ σ t₂) posinfo-gen
substh-term Γ ρ σ (Rho _ op on t og t') = Rho posinfo-gen op on (substh-term Γ ρ σ t) (substh-optGuide Γ ρ σ og) (substh-term Γ ρ σ t')
substh-term Γ ρ σ (Chi _ T t') = Chi posinfo-gen (substh-optType Γ ρ σ T) (substh-term Γ ρ σ t')
substh-term Γ ρ σ (Delta _ T t') = Delta posinfo-gen (substh-optType Γ ρ σ T) (substh-term Γ ρ σ t')
substh-term Γ ρ σ (Theta _ θ t ls) = Theta posinfo-gen (substh-theta θ) (substh-term Γ ρ σ t) (substh-lterms ls)
  where substh-lterms : lterms → lterms
        substh-lterms (LtermsNil pi) = LtermsNil pi
        substh-lterms (LtermsCons m t ls) = LtermsCons m (substh-term Γ ρ σ t) (substh-lterms ls)
        substh-vars : vars → vars
        substh-vars (VarsStart x) = VarsStart (renamectxt-rep ρ x)
        substh-vars (VarsNext x xs) = VarsNext (renamectxt-rep ρ x) (substh-vars xs)
        substh-theta : theta → theta
        substh-theta (AbstractVars xs) = AbstractVars (substh-vars xs)
        substh-theta θ = θ
substh-term Γ ρ σ (Mu _ x t ot _ cs _) =
  let x' = subst-rename-var-if Γ ρ x σ in
  let ρ' = renamectxt-insert ρ x x'    in
    Mu posinfo-gen x' (substh-term (ctxt-var-decl x' Γ) ρ' σ t) (substh-optType Γ ρ σ ot) posinfo-gen (substh-cases Γ ρ' σ cs) posinfo-gen
substh-term Γ ρ σ (Mu' _ t ot _ cs _) = Mu' posinfo-gen (substh-term Γ ρ σ t) (substh-optType Γ ρ σ ot) posinfo-gen (substh-cases Γ ρ σ cs) posinfo-gen

substh-cases Γ ρ σ NoCase = NoCase
substh-cases Γ ρ σ (SomeCase _ x varargs t cs) =
  let res = substh-varargs Γ ρ σ varargs in
  SomeCase posinfo-gen x (fst res) (substh-term Γ (snd res) σ t) (substh-cases Γ ρ σ cs)

substh-varargs Γ ρ σ NoVarargs                = NoVarargs , ρ
substh-varargs Γ ρ σ (NormalVararg x varargs) =
  let x' = subst-rename-var-if Γ ρ x σ in
  let ρ' = renamectxt-insert ρ x x'    in
  let res = substh-varargs Γ ρ' σ varargs in
  NormalVararg x' (fst res) , snd res
substh-varargs Γ ρ σ (ErasedVararg x varargs) =
  let x' = subst-rename-var-if Γ ρ x σ in
  let ρ' = renamectxt-insert ρ x x'    in
  let res = substh-varargs Γ ρ' σ varargs in
  ErasedVararg x' (fst res) , snd res
substh-varargs Γ ρ σ (TypeVararg   x varargs) =
  let x' = subst-rename-var-if Γ ρ x σ in
  let ρ' = renamectxt-insert ρ x x'    in
  let res = substh-varargs Γ ρ' σ varargs in
  TypeVararg x' (fst res) , snd res

substh-type Γ ρ σ (Abs _ b _ x atk t) =
  let x' = subst-rename-var-if Γ ρ x σ in
    Abs posinfo-gen b posinfo-gen x' (substh-tk Γ ρ σ atk)
      (substh-type (ctxt-var-decl x' Γ) (renamectxt-insert ρ x x') σ t)
substh-type Γ ρ σ (TpLambda _ _ x atk t) =
  let x' = subst-rename-var-if Γ ρ x σ in
    TpLambda posinfo-gen posinfo-gen x' (substh-tk Γ ρ σ atk)
      (substh-type (ctxt-var-decl x' Γ) (renamectxt-insert ρ x x') σ t)
substh-type Γ ρ σ (Iota _ _ x m t) =
  let x' = subst-rename-var-if Γ ρ x σ in
    Iota posinfo-gen posinfo-gen x' (substh-type Γ ρ σ m)
      (substh-type (ctxt-var-decl x' Γ) (renamectxt-insert ρ x x') σ t)
substh-type Γ ρ σ (Lft _ _ x t l) =
  let x' = subst-rename-var-if Γ ρ x σ in
    Lft posinfo-gen posinfo-gen x' (substh-term (ctxt-var-decl x' Γ) (renamectxt-insert ρ x x') σ t)
      (substh-liftingType Γ ρ σ l)
substh-type Γ ρ σ (TpApp tp tp₁) = TpApp (substh-type Γ ρ σ tp) (substh-type Γ ρ σ tp₁)
substh-type Γ ρ σ (TpAppt tp t) = TpAppt (substh-type Γ ρ σ tp) (substh-term Γ ρ σ t)
substh-type Γ ρ σ (TpArrow tp arrowtype tp₁) = TpArrow (substh-type Γ ρ σ tp) arrowtype (substh-type Γ ρ σ tp₁)
substh-type Γ ρ σ (TpEq _ x₁ x₂ _) = TpEq posinfo-gen (substh-term Γ ρ σ x₁) (substh-term Γ ρ σ x₂) posinfo-gen
substh-type Γ ρ σ (TpParens _ tp _) = substh-type Γ ρ σ tp
substh-type Γ ρ σ (NoSpans tp _) = substh-type Γ ρ σ tp
substh-type{TYPE} Γ ρ σ (TpVar _ x) =
 let x' = renamectxt-rep ρ x in
   trie-lookup-else (TpVar posinfo-gen x') σ x'
substh-type{ARG} Γ ρ σ (TpVar _ x) =
 let x' = renamectxt-rep ρ x in
   inst-lookup-type σ x'
substh-type{QUALIF} Γ ρ σ (TpVar _ x) =
 let x' = renamectxt-rep ρ x in
   qualif-lookup-type σ x'
substh-type Γ ρ σ (TpVar _ x) = TpVar posinfo-gen (renamectxt-rep ρ x)
substh-type{QUALIF} Γ ρ σ (TpHole pi) = TpHole (ctxt-get-current-filename Γ # pi)
substh-type Γ ρ σ (TpHole pi) = TpHole pi -- Retain position, so jumping to hole works
substh-type Γ ρ σ (TpLet _ (DefTerm _ x m t) t') =
  let x' = subst-rename-var-if Γ ρ x σ in
     (TpLet posinfo-gen (DefTerm posinfo-gen x' (substh-optType Γ ρ σ m) (substh-term Γ ρ σ t))
      (substh-type (ctxt-var-decl x' Γ) (renamectxt-insert ρ x x') σ t'))
substh-type Γ ρ σ (TpLet _ (DefType _ x k t) t') =
  let x' = subst-rename-var-if Γ ρ x σ in
     (TpLet posinfo-gen (DefType posinfo-gen x' (substh-kind Γ ρ σ k) (substh-type Γ ρ σ t))
      (substh-type (ctxt-var-decl x' Γ) (renamectxt-insert ρ x x') σ t'))
substh-kind Γ ρ σ (KndArrow k k₁) = KndArrow (substh-kind Γ ρ σ k) (substh-kind Γ ρ σ k₁)
substh-kind Γ ρ σ (KndParens x₁ k x₂) = substh-kind Γ ρ σ k
substh-kind Γ ρ σ (KndPi _ _ x atk k) =
  let x' = subst-rename-var-if Γ ρ x σ in
    KndPi posinfo-gen posinfo-gen x' (substh-tk Γ ρ σ atk)
      (substh-kind (ctxt-var-decl x' Γ) (renamectxt-insert ρ x x') σ k)
substh-kind Γ ρ σ (KndTpArrow t k) = KndTpArrow (substh-type Γ ρ σ t) (substh-kind Γ ρ σ k)
substh-kind{QUALIF} Γ ρ σ (KndVar _ x xs) =
   qualif-lookup-kind (substh-args Γ ρ σ xs) σ x
substh-kind Γ ρ σ (KndVar _ x xs) = KndVar posinfo-gen x (substh-args Γ ρ σ xs)
substh-kind Γ ρ σ (Star _) = Star posinfo-gen

substh-arg Γ ρ σ (TermArg me t) = TermArg me (substh-term Γ ρ σ t)
substh-arg Γ ρ σ (TypeArg T) = TypeArg (substh-type Γ ρ σ T)

substh-args Γ ρ σ (ArgsCons a as) = ArgsCons (substh-arg Γ ρ σ a) (substh-args Γ ρ σ as)
substh-args Γ ρ σ ArgsNil = ArgsNil

substh-params{QUALIF} Γ ρ σ (ParamsCons (Decl _ pi me x atk _) ps) =
  ParamsCons (Decl posinfo-gen posinfo-gen me (pi % x) (substh-tk Γ ρ σ atk) posinfo-gen)
    (substh-params Γ (renamectxt-insert ρ x (pi % x)) (trie-remove σ (pi % x)) ps)
substh-params Γ ρ σ (ParamsCons (Decl _ _ me x atk _) ps) =
  ParamsCons (Decl posinfo-gen posinfo-gen me x (substh-tk Γ ρ σ atk) posinfo-gen)
    (substh-params Γ (renamectxt-insert ρ x x) (trie-remove σ x) ps)
substh-params Γ ρ σ ParamsNil = ParamsNil

substh-tk Γ ρ σ (Tkk k) = Tkk (substh-kind Γ ρ σ k)
substh-tk Γ ρ σ (Tkt t) = Tkt (substh-type Γ ρ σ t)

substh-optClass Γ ρ σ NoClass = NoClass
substh-optClass Γ ρ σ (SomeClass atk) = SomeClass (substh-tk Γ ρ σ atk)
substh-liftingType Γ ρ σ (LiftArrow l l₁) = LiftArrow (substh-liftingType Γ ρ σ l) (substh-liftingType Γ ρ σ l₁)
substh-liftingType Γ ρ σ (LiftParens _ l _) = substh-liftingType Γ ρ σ l
substh-liftingType Γ ρ σ (LiftPi _ x tp l) =
  let x' = subst-rename-var-if Γ ρ x σ in
    LiftPi posinfo-gen x' (substh-type Γ ρ σ tp)
       (substh-liftingType (ctxt-var-decl x' Γ) (renamectxt-insert ρ x x') σ l)
substh-liftingType Γ ρ σ (LiftStar _) = LiftStar posinfo-gen
substh-liftingType Γ ρ σ (LiftTpArrow tp l) =
  LiftTpArrow (substh-type Γ ρ σ tp) (substh-liftingType Γ ρ σ l)

substh-optType Γ ρ σ NoType = NoType
substh-optType Γ ρ σ (SomeType T) = SomeType (substh-type Γ ρ σ T)

substh-optTerm Γ ρ σ NoTerm = NoTerm
substh-optTerm Γ ρ σ (SomeTerm t _) = (SomeTerm (substh-term Γ ρ σ t) posinfo-gen)

substh-optGuide Γ ρ σ NoGuide = NoGuide
substh-optGuide Γ ρ σ (Guide _ x T) =
  let x' = subst-rename-var-if Γ ρ x σ in
  Guide posinfo-gen x' (substh-type (ctxt-var-decl x' Γ) (renamectxt-insert ρ x x') σ T)


subst-ret-t : Set → Set
subst-ret-t T = {ed : exprd} → ctxt → ⟦ ed ⟧ → var → T → T

subst : ∀ {ed} → subst-ret-t ⟦ ed ⟧
subst Γ t x = substh Γ empty-renamectxt (trie-single x t)

subst-term = subst {TERM}
subst-type = subst {TYPE}
subst-kind = subst {KIND}
subst-liftingType = subst {LIFTINGTYPE}
subst-tk = subst {TK}


subst-renamectxt : ∀ {ed : exprd} → ctxt → renamectxt → ⟦ ed ⟧ → ⟦ ed ⟧
subst-renamectxt {ed} Γ ρ = substh {ed} {ed} Γ ρ empty-trie

rename-var : ∀ {ed} → ctxt → var → var → ⟦ ed ⟧ → ⟦ ed ⟧
rename-var Γ x x' = subst-renamectxt Γ (renamectxt-single x x')


substs-ret-t : Set → Set
substs-ret-t T = ∀ {ed} → ctxt → trie ⟦ ed ⟧ → T → T

substs : ∀ {ed} → substs-ret-t ⟦ ed ⟧
substs Γ = substh Γ empty-renamectxt

substs-term = substs {TERM}
substs-type = substs {TYPE}
substs-kind = substs {KIND}
substs-liftingType = substs {LIFTINGTYPE}
substs-tk = substs {TK}

substs-args : substs-ret-t args
substs-args Γ = substh-args Γ empty-renamectxt

substs-params : substs-ret-t params
substs-params Γ = substh-params Γ empty-renamectxt

subst-params-args : ∀ {ed} → ctxt → params → args → ⟦ ed ⟧ → ⟦ ed ⟧ × params × args
subst-params-args Γ (ParamsCons (Decl _ _ me x atk _) ps) (ArgsCons a as) t =
  subst-params-args Γ (substs-params Γ (trie-single x a) ps) as (subst Γ a x t)
subst-params-args Γ ps as t = t , ps , as
