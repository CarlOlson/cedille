module subst where

open import lib

open import cedille-types
open import ctxt-types
open import is-free
open import rename
open import general-util
open import syntax-util

substh-ret-t : Set → Set
substh-ret-t T = {ed : exprd} → ctxt → renamectxt → trie ⟦ ed ⟧ → T → T

substh-term : substh-ret-t term
substh-type : substh-ret-t type
substh-kind : substh-ret-t kind
substh-tk : substh-ret-t tk
substh-optClass : substh-ret-t optClass
substh-optType : substh-ret-t optType
substh-optTerm : substh-ret-t optTerm
substh-liftingType : substh-ret-t liftingType
substh-maybeAtype : substh-ret-t maybeAtype
substh-maybeCheckType : substh-ret-t maybeCheckType
substh-args : substh-ret-t args

subst-rename-var-if : {ed : exprd} → ctxt → renamectxt → var → trie ⟦ ed ⟧ → var
subst-rename-var-if Γ ρ x σ =
  {- rename bound variable x iff it is one of the vars being substituted for, 
     or if x occurs free in one of the terms we are substituting for vars, 
     or if it is the renamed version of any variable -}
  if trie-contains σ x || trie-any (is-free-in check-erased x) σ || renamectxt-in-range ρ x then 
    rename-away-from x (λ s → ctxt-binds-var Γ s || trie-contains σ s) ρ
  else
    x

substh-term Γ ρ σ (App t m t') = App (substh-term Γ ρ σ t) m (substh-term Γ ρ σ t')
substh-term Γ ρ σ (AppTp t tp) = AppTp (substh-term Γ ρ σ t) (substh-type Γ ρ σ tp)
substh-term Γ ρ σ (Hole x₁) = Hole x₁
substh-term Γ ρ σ (Lam pi b pi' x oc t) =
  let x' = subst-rename-var-if Γ ρ x σ in
    Lam pi b pi' x' (substh-optClass Γ ρ σ oc) 
      (substh-term (ctxt-var-decl posinfo-gen x' Γ) (renamectxt-insert ρ x x') σ t)
substh-term Γ ρ σ (Let pi (DefTerm pi'' x m t) t') =
  let x' = subst-rename-var-if Γ ρ x σ in
     (Let pi (DefTerm pi'' x' (substh-maybeCheckType Γ ρ σ m) (substh-term Γ ρ σ t))
      (substh-term (ctxt-var-decl posinfo-gen x' Γ) (renamectxt-insert ρ x x') σ t'))
substh-term Γ ρ σ (Let pi (DefType pi'' x k t) t') =
  let x' = subst-rename-var-if Γ ρ x σ in
     (Let pi (DefType pi'' x' (substh-kind Γ ρ σ k) (substh-type Γ ρ σ t))
      (substh-term (ctxt-var-decl posinfo-gen x' Γ) (renamectxt-insert ρ x x') σ t'))
substh-term Γ ρ σ (Parens x₁ t x₂) = substh-term Γ ρ σ t
substh-term{TERM} Γ ρ σ (Var pi x) =
 let x' = renamectxt-rep ρ x in
   trie-lookup-else (Var pi x') σ x'
substh-term{ARG} Γ ρ σ (Var pi x) =
 let x' = renamectxt-rep ρ x in
   inst-lookup-term pi σ x'
substh-term{QUALIF} Γ ρ σ (Var pi x) =
 let x' = renamectxt-rep ρ x in
   qualif-lookup-term pi σ x'
substh-term Γ ρ σ (Var pi x) = Var pi (renamectxt-rep ρ x)
substh-term Γ ρ σ (Unfold pi t) = Unfold pi (substh-term Γ ρ σ t)
substh-term Γ ρ σ (Beta pi ot) = Beta pi (substh-optTerm Γ ρ σ ot)
substh-term Γ ρ σ (Delta pi t) = Delta pi (substh-term Γ ρ σ t)
substh-term Γ ρ σ (Omega pi t) = Omega pi (substh-term Γ ρ σ t)
substh-term Γ ρ σ (IotaPair pi t1 t2 ot pi') = IotaPair pi (substh-term Γ ρ σ t1) (substh-term Γ ρ σ t2) (substh-optTerm Γ ρ σ ot) pi'
substh-term Γ ρ σ (IotaProj t n pi) = IotaProj (substh-term Γ ρ σ t) n pi
substh-term Γ ρ σ (PiInj pi n t) = PiInj pi n (substh-term Γ ρ σ t)
substh-term Γ ρ σ (Epsilon pi lr m t) = Epsilon pi lr m (substh-term Γ ρ σ t)
substh-term Γ ρ σ (Sigma pi t) = Sigma pi (substh-term Γ ρ σ t)
substh-term Γ ρ σ (Rho pi r t t') = Rho pi r (substh-term Γ ρ σ t) (substh-term Γ ρ σ t')
substh-term Γ ρ σ (Chi pi T t') = Chi pi (substh-maybeAtype Γ ρ σ T) (substh-term Γ ρ σ t')
substh-term Γ ρ σ (Theta pi u t ls) = Theta pi u (substh-term Γ ρ σ t) (substh-lterms Γ ρ σ ls) 
  where substh-lterms : substh-ret-t lterms
        substh-lterms Γ ρ σ (LtermsNil pi) = LtermsNil pi
        substh-lterms Γ ρ σ (LtermsCons m t ls) = LtermsCons m (substh-term Γ ρ σ t) (substh-lterms Γ ρ σ ls)

substh-type Γ ρ σ (Abs pi b pi' x atk t) =
  let x' = subst-rename-var-if Γ ρ x σ in
    Abs pi b pi' x' (substh-tk Γ ρ σ atk)
      (substh-type (ctxt-var-decl posinfo-gen x' Γ) (renamectxt-insert ρ x x') σ t)
substh-type Γ ρ σ (TpLambda pi pi' x atk t) =
  let x' = subst-rename-var-if Γ ρ x σ in
    TpLambda pi pi' x' (substh-tk Γ ρ σ atk) 
      (substh-type (ctxt-var-decl posinfo-gen x' Γ) (renamectxt-insert ρ x x') σ t)
substh-type Γ ρ σ (IotaEx pi ie pi' x m t) =
  let x' = subst-rename-var-if Γ ρ x σ in
    IotaEx pi ie pi' x' (substh-optType Γ ρ σ m)
      (substh-type (ctxt-var-decl posinfo-gen x' Γ) (renamectxt-insert ρ x x') σ t)
substh-type Γ ρ σ (Lft pi pi' x t l) =
  let x' = subst-rename-var-if Γ ρ x σ in
    Lft pi pi' x' (substh-term (ctxt-var-decl posinfo-gen x' Γ) (renamectxt-insert ρ x x') σ t) 
      (substh-liftingType Γ ρ σ l)
substh-type Γ ρ σ (TpApp tp tp₁) = TpApp (substh-type Γ ρ σ tp) (substh-type Γ ρ σ tp₁)
substh-type Γ ρ σ (TpAppt tp t) = TpAppt (substh-type Γ ρ σ tp) (substh-term Γ ρ σ t)
substh-type Γ ρ σ (TpArrow tp arrowtype tp₁) = TpArrow (substh-type Γ ρ σ tp) arrowtype (substh-type Γ ρ σ tp₁)
substh-type Γ ρ σ (TpEq x₁ x₂) = TpEq (substh-term Γ ρ σ x₁) (substh-term Γ ρ σ x₂)
substh-type Γ ρ σ (TpParens x₁ tp x₂) = substh-type Γ ρ σ tp
substh-type Γ ρ σ (NoSpans tp _) = substh-type Γ ρ σ tp
substh-type{TYPE} Γ ρ σ (TpVar pi x) =
 let x' = renamectxt-rep ρ x in
   trie-lookup-else (TpVar pi x') σ x'
substh-type{ARG} Γ ρ σ (TpVar pi x) =
 let x' = renamectxt-rep ρ x in
   inst-lookup-type pi σ x'
substh-type{QUALIF} (mk-ctxt _ _ i _) ρ σ (TpVar pi x) =
 let x' = renamectxt-rep ρ x in
   if trie-contains i x'
    then (TpVar pi x')
    else qualif-lookup-type pi σ x'
substh-type Γ ρ σ (TpVar pi x) = TpVar pi (renamectxt-rep ρ x)
substh-type Γ ρ σ (TpHole pi) = TpHole pi --ACG
substh-kind Γ ρ σ (KndArrow k k₁) = KndArrow (substh-kind Γ ρ σ k) (substh-kind Γ ρ σ k₁)
substh-kind Γ ρ σ (KndParens x₁ k x₂) = substh-kind Γ ρ σ k
substh-kind Γ ρ σ (KndPi pi pi' x atk k) =
  let x' = subst-rename-var-if Γ ρ x σ in
    KndPi pi pi' x' (substh-tk Γ ρ σ atk)
      (substh-kind (ctxt-var-decl posinfo-gen x' Γ) (renamectxt-insert ρ x x') σ k)
substh-kind Γ ρ σ (KndTpArrow t k) = KndTpArrow (substh-type Γ ρ σ t) (substh-kind Γ ρ σ k)
substh-kind{QUALIF} Γ ρ σ (KndVar pi x xs) =
   qualif-lookup-kind pi (substh-args Γ ρ σ xs) σ x
substh-kind Γ ρ σ (KndVar pi x xs) = KndVar pi x (substh-args Γ ρ σ xs)
substh-kind Γ ρ σ (Star pi) = Star pi

substh-args Γ ρ σ (ArgsCons (TermArg x₁) xs) = ArgsCons (TermArg (substh-term Γ ρ σ x₁)) (substh-args Γ ρ σ xs)
substh-args Γ ρ σ (ArgsCons (TypeArg x₁) xs) = ArgsCons (TypeArg (substh-type Γ ρ σ x₁)) (substh-args Γ ρ σ xs)
substh-args Γ ρ σ (ArgsNil x₁) = ArgsNil x₁

substh-tk Γ ρ σ (Tkk k) = Tkk (substh-kind Γ ρ σ k)
substh-tk Γ ρ σ (Tkt t) = Tkt (substh-type Γ ρ σ t)

substh-optClass Γ ρ σ NoClass = NoClass
substh-optClass Γ ρ σ (SomeClass atk) = SomeClass (substh-tk Γ ρ σ atk)
substh-optType Γ ρ σ NoType = NoType
substh-optType Γ ρ σ (SomeType t1) = SomeType (substh-type Γ ρ σ t1)
substh-liftingType Γ ρ σ (LiftArrow l l₁) = LiftArrow (substh-liftingType Γ ρ σ l) (substh-liftingType Γ ρ σ l₁)
substh-liftingType Γ ρ σ (LiftParens x₁ l x₂) = substh-liftingType Γ ρ σ l
substh-liftingType Γ ρ σ (LiftPi pi x tp l) =
  let x' = subst-rename-var-if Γ ρ x σ in 
    LiftPi pi x' (substh-type Γ ρ σ tp) 
       (substh-liftingType (ctxt-var-decl posinfo-gen x' Γ) (renamectxt-insert ρ x x') σ l)
substh-liftingType Γ ρ σ (LiftStar pi) = LiftStar pi
substh-liftingType Γ ρ σ (LiftTpArrow tp l) = 
  LiftTpArrow (substh-type Γ ρ σ tp) (substh-liftingType Γ ρ σ l)

substh-maybeAtype Γ ρ σ NoAtype = NoAtype
substh-maybeAtype Γ ρ σ (Atype T) = Atype (substh-type Γ ρ σ T)

substh-maybeCheckType Γ ρ σ NoCheckType = NoCheckType
substh-maybeCheckType Γ ρ σ (Type T) = Type (substh-type Γ ρ σ T)

substh-optTerm Γ ρ σ NoTerm = NoTerm
substh-optTerm Γ ρ σ (SomeTerm t pi') = (SomeTerm (substh-term Γ ρ σ t) pi')

subst-ret-t : Set → Set
subst-ret-t T = {ed : exprd} → ctxt → ⟦ ed ⟧ → var → T → T

subst-term : subst-ret-t term
subst-term Γ t x a = substh-term Γ empty-renamectxt (trie-single x t) a

subst-type : subst-ret-t type
subst-type Γ t x a = substh-type Γ empty-renamectxt (trie-single x t) a

subst-kind : subst-ret-t kind
subst-kind Γ t x a = substh-kind Γ empty-renamectxt (trie-single x t) a

subst-liftingType : subst-ret-t liftingType
subst-liftingType Γ t x a = substh-liftingType Γ empty-renamectxt (trie-single x t) a

rename-type : ctxt → var → var → (is-term-var : 𝔹) → type → type
rename-type Γ x y tt tp = subst-type Γ (Var posinfo-gen y) x tp
rename-type Γ x y ff tp = subst-type Γ (TpVar posinfo-gen y) x tp

rename-kind : ctxt → var → var → (is-term-var : 𝔹) → kind → kind
rename-kind Γ x y tt k = subst-kind Γ (Var posinfo-gen y) x k
rename-kind Γ x y ff k = subst-kind Γ (TpVar posinfo-gen y) x k

substs-ret-t : Set → Set
substs-ret-t T = {ed : exprd} → ctxt → trie ⟦ ed ⟧ → T → T

substs-term : substs-ret-t term
substs-term Γ = substh-term Γ empty-renamectxt

substs-type : substs-ret-t type
substs-type Γ = substh-type Γ empty-renamectxt

substs-kind : substs-ret-t kind
substs-kind Γ = substh-kind Γ empty-renamectxt
