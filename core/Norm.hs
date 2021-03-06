module Norm where
import Types
import Ctxt

--eraseTerm :: Term -> PureTerm
eraseTerm (TmVar v) = PureVar v
eraseTerm (TmLambda v tp tm) = PureLambda v (eraseTerm tm)
eraseTerm (TmAppTm tm tm') = PureApp (eraseTerm tm) (eraseTerm tm')
eraseTerm (TmLambdaE v c tm) = eraseTerm tm
eraseTerm (TmAppTmE tm tm') = eraseTerm tm
eraseTerm (TmAppTp tm tp) = eraseTerm tm
eraseTerm (TmIota tm1 tm2 v tp) = eraseTerm tm1
eraseTerm (TmLetTm v tm tm') = PureApp (PureLambda v (eraseTerm tm')) (eraseTerm tm)
eraseTerm (TmLetTmE v tm tm') = eraseTerm tm'
eraseTerm (TmLetTp v kd tp tm) = eraseTerm tm
eraseTerm (IotaProj1 tm) = eraseTerm tm
eraseTerm (IotaProj2 tm) = eraseTerm tm
eraseTerm (Beta pt pt') = pt'
eraseTerm (Sigma tm) = eraseTerm tm
eraseTerm (Delta tp tm) = PureLambda "x" (PureVar "x")
eraseTerm (Rho tm v tp tm') = eraseTerm tm'
eraseTerm (Phi tm tm' pt) = pt

--eraseType :: Type -> PureType
eraseType (TpVar v) = TpVar v
eraseType (TpLambda v tk tp) = TpLambda v (eraseTpKd tk) (eraseType tp)
eraseType (TpAll v tk tp) = TpAll v (eraseTpKd tk) (eraseType tp)
eraseType (TpPi v tp tp') = TpPi v (eraseType tp) (eraseType tp')
eraseType (TpEq ptm ptm') = TpEq ptm ptm'
eraseType (TpAppTp tp tp') = TpAppTp (eraseType tp) (eraseType tp')
eraseType (TpAppTm tp tm) = TpAppTm (eraseType tp) (eraseTerm tm)
eraseType (TpIota v tp tp') = TpIota v (eraseType tp) (eraseType tp')

--eraseKind :: Kind -> PureKind
eraseKind Star = Star
eraseKind (KdPi v tk kd) = KdPi v (eraseTpKd tk) (eraseKind kd)

--eraseTpKd :: TpKd -> PureTpKd
eraseTpKd (TpKdTp tp) = TpKdTp (eraseType tp)
eraseTpKd (TpKdKd kd) = TpKdKd (eraseKind kd)

tpKdIsType (TpKdTp _) = True
tpKdIsType (TpKdKd _) = False

--substTerm :: Ctxt -> PureTerm -> PureTerm
substTerm c (PureVar v) = maybe (PureVar (ctxtRep c v)) (substTerm (ctxtOnlySubst c)) (ctxtLookupInternalTerm c v)
substTerm c (PureApp tm tm') = PureApp (substTerm c tm) (substTerm c tm')
substTerm c (PureLambda v tm) = freshVar c v $ \ v' ->
  PureLambda v' (substTerm (ctxtRename c v v') tm)

substType = hnfType . ctxtClearExternals
substKind = hnfKind . ctxtClearExternals
substTpKd = hnfTpKd . ctxtClearExternals

--hnfTerm :: Ctxt -> PureTerm -> PureTerm
hnfTerm c (PureVar v) = maybe (PureVar (ctxtRep c v)) (substTerm (ctxtOnlySubst c)) (ctxtLookupTermVar c v)
hnfTerm c (PureApp tm tm') = case hnfTerm c tm of
  PureLambda v tm'' -> hnfTerm (ctxtInternalDef c v (Left (hnfTerm c tm'))) tm''
  tm'' -> PureApp tm'' (substTerm c tm')
hnfTerm c (PureLambda v tm) = freshVar c v $ \ v' ->
  let c' = ctxtRename c v v'
      tm' = hnfTerm c' tm
      etm = PureLambda v' tm' in
  case tm' of
    (PureApp htm (PureVar v'')) ->
      if v' == v'' && not (freeInTerm v' htm) then htm else etm
    _ -> etm
  
--hnfType :: Ctxt -> PureType -> PureType
hnfType c (TpVar v) = maybe (TpVar (ctxtRep c v)) (substType (ctxtOnlySubst c)) (ctxtLookupTypeVar c v)
hnfType c (TpLambda v tk tp) = freshVar c v $ \ v' ->
  let c' = ctxtRename c v v'
      tp' = hnfType c' tp
      tk' = substTpKd c tk
      etp = TpLambda v' tk' tp' in
  case tp' of
    (TpAppTp htp (TpVar v'')) ->
      if not (tpKdIsType tk) && v' == v'' && not (freeInType v' htp) then htp else etp
    (TpAppTm htp (PureVar v'')) ->
      if tpKdIsType tk && v' == v'' && not (freeInType v' htp) then htp else etp
    _ -> etp
hnfType c (TpAll v tk tp) =
  freshVar c v $ \ v' -> TpAll v' (substTpKd c tk) (hnfType (ctxtRename c v v') tp)
hnfType c (TpPi v tp tp') =
  freshVar c v $ \ v' -> TpPi v' (substType c tp) (hnfType (ctxtRename c v v') tp')
hnfType c (TpIota v tp tp') =
  freshVar c v $ \ v' -> TpIota v' (substType c tp) (substType (ctxtRename c v v') tp')
hnfType c (TpAppTp tp tp') = case hnfType c tp of
  TpLambda v (TpKdKd _) tp'' -> substType (ctxtInternalDef c v (Right (hnfType (ctxtRename c v v) tp'))) tp''
  tp'' -> TpAppTp tp'' (substType c tp')
hnfType c (TpAppTm tp tm) = case hnfType c tp of
  TpLambda v (TpKdTp _) tp' -> substType (ctxtInternalDef c v (Left (hnfTerm (ctxtRename c v v) tm))) tp'
  tp' -> TpAppTm tp' (substTerm c tm)
hnfType c (TpEq tm tm') = TpEq (substTerm c tm) (substTerm c tm')

--hnfKind :: Ctxt -> PureKind -> PureKind
hnfKind c Star = Star
hnfKind c (KdPi v tk kd) =
  freshVar c v $ \ v' -> KdPi v' (substTpKd c tk) (hnfKind (ctxtRename c v v') kd)

--hnfTpKd :: Ctxt -> PureTpKd -> PureTpKd
hnfTpKd c (TpKdTp tp) = TpKdTp (hnfType c tp)
hnfTpKd c (TpKdKd kd) = TpKdKd (hnfKind c kd)

hnfeTerm c = hnfTerm c . eraseTerm
hnfeType c = hnfType c . eraseType
hnfeKind c = hnfKind c . eraseKind
hnfeTpKd c = hnfTpKd c . eraseTpKd

convTerm c tm tm' = convTerm' c tm tm' || convTerm' c (hnfTerm c tm) (hnfTerm c tm')
convType c tp tp' = convType' c tp tp' || convType' c (hnfType c tp) (hnfType c tp')

--convTerm' :: Ctxt -> PureTerm -> PureTerm -> Bool
convTerm' c (PureVar v) (PureVar v') = ctxtRep c v == ctxtRep c v'
convTerm' c (PureLambda v tm) (PureLambda v' tm') = convTerm' (ctxtRename c v v') tm tm'
convTerm' c (PureApp tm tm') (PureApp tm'' tm''') = convTerm' c tm tm'' && convTerm c tm' tm'''
-- For a case like \ x. \ y. x (cast y) == \ x. x, where the head is a
-- locally-bound variable, leading to the argument not being normalized
-- and hence not eta-contracted.
convTerm' c (PureLambda v tm) tm' = freshVar c v $ \ v' ->
  convTerm (ctxtRename c v v') tm (PureApp tm' (PureVar v'))
convTerm' c tm (PureLambda v tm') = freshVar c v $ \ v' ->
  convTerm (ctxtRename c v v') tm' (PureApp tm (PureVar v'))
convTerm' c tm tm' = False

--convType' :: Ctxt -> PureType -> PureType -> Bool
convType' c (TpVar v) (TpVar v') = ctxtRep c v == ctxtRep c v'
convType' c (TpLambda v tk tp) (TpLambda v' tk' tp') = convTpKd c tk tk' && convType' (ctxtRename c v v') tp tp'
convType' c (TpAll v tk tp) (TpAll v' tk' tp') = convTpKd c tk tk' && convType' (ctxtRename c v v') tp tp'
convType' c (TpPi v tp tp') (TpPi v' tp'' tp''') = convType c tp tp'' && convType' (ctxtRename c v v') tp' tp'''
convType' c (TpIota v tp tp') (TpIota v' tp'' tp''') = convType c tp tp'' && convType (ctxtRename c v v') tp' tp'''
convType' c (TpEq tm tm') (TpEq tm'' tm''') = convTerm c tm tm'' && convTerm c tm' tm'''
convType' c (TpAppTp tp tp') (TpAppTp tp'' tp''') = convType' c tp tp'' && convType c tp' tp'''
convType' c (TpAppTm tp tm) (TpAppTm tp' tm') = convType' c tp tp' && convTerm c tm tm'
convType' c (TpLambda v tk tp) tp' = freshVar c v $ \ v' ->
  convType (ctxtRename c v v') tp (if tpKdIsType tk then TpAppTm tp' (PureVar v') else TpAppTp tp' (TpVar v'))
convType' c tp (TpLambda v tk tp') = freshVar c v $ \ v' ->
  convType (ctxtRename c v v') tp' (if tpKdIsType tk then TpAppTm tp (PureVar v') else TpAppTp tp (TpVar v'))
convType' c tp tp' = False

--convKind' :: Ctxt -> PureKind -> PureKind -> Bool
convKind c Star Star = True
convKind c (KdPi v tk kd) (KdPi v' tk' kd') = convTpKd c tk tk' && convKind (ctxtRename c v v') kd kd'
convKind _ _ _ = False

convTpKd c (TpKdTp tp) (TpKdTp tp') = convType c tp tp'
convTpKd c (TpKdKd kd) (TpKdKd kd') = convKind c kd kd'
convTpKd _ _ _ = False

--freeInTerm :: Var -> PureTerm -> Bool
freeInTerm v (PureVar v') = v == v'
freeInTerm v (PureApp tm tm') = freeInTerm v tm || freeInTerm v tm'
freeInTerm v (PureLambda v' tm) = not (v == v') && freeInTerm v tm

--freeInType :: Var -> PureType -> Bool
freeInType v (TpVar v') = v == v'
freeInType v (TpLambda v' tk tp) = not (v == v') && (freeInTpKd v tk || freeInType v tp)
freeInType v (TpAll v' tk tp) = not (v == v') && (freeInTpKd v tk || freeInType v tp)
freeInType v (TpPi v' tp tp') = not (v == v') && (freeInType v tp || freeInType v tp')
freeInType v (TpIota v' tp tp') = not (v == v') && (freeInType v tp || freeInType v tp')
freeInType v (TpEq tm tm') = freeInTerm v tm || freeInTerm v tm'
freeInType v (TpAppTp tp tp') = freeInType v tp || freeInType v tp'
freeInType v (TpAppTm tp tm) = freeInType v tp || freeInTerm v tm

--freeInKind :: Var -> PureKind -> Bool
freeInKind v Star = False
freeInKind v (KdPi v' tk kd) = not (v == v') && (freeInTpKd v tk || freeInKind v kd)

--freeInTpKd :: Var -> PureTpKd -> Bool
freeInTpKd v (TpKdTp tp) = freeInType v tp
freeInTpKd v (TpKdKd kd) = freeInKind v kd
