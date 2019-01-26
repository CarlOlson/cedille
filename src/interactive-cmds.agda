import cedille-options

module interactive-cmds (options : cedille-options.options) where

open import lib
open import functions
open import cedille-types
open import conversion
open import ctxt
open import general-util
open import monad-instances
open import spans options {id}
open import subst
open import syntax-util
open import to-string options
open import toplevel-state options {IO}
open import untyped-spans options {IO}
open import parser
open import rewriting
open import rename
open import classify options {id}
import spans options {IO} as io-spans
open import elaboration (record options {during-elaboration = ff})
open import elaboration-helpers (record options {during-elaboration = ff})
open import templates

private

  {- Parsing -}

  ll-ind : ∀ {X : language-level → Set} → X ll-term → X ll-type → X ll-kind →
             (ll : language-level) → X ll
  ll-ind t T k ll-term = t
  ll-ind t T k ll-type = T
  ll-ind t T k ll-kind = k

  ll-lift : language-level → Set
  ll-lift = ⟦_⟧ ∘ ll-ind TERM TYPE KIND

  ll-ind' : ∀ {X : Σ language-level ll-lift → Set} → (s : Σ language-level ll-lift) → ((t : term) → X (ll-term , t)) → ((T : type) → X (ll-type , T)) → ((k : kind) → X (ll-kind , k)) → X s
  ll-ind' (ll-term , t) tf Tf kf = tf t
  ll-ind' (ll-type , T) tf Tf kf = Tf T
  ll-ind' (ll-kind , k) tf Tf kf = kf k

  ll-disambiguate : ctxt → term → maybe type
  ll-disambiguate Γ (Var pi x) = ctxt-lookup-type-var Γ x ≫=maybe λ _ → just (TpVar pi x)
  ll-disambiguate Γ (App t NotErased t') = ll-disambiguate Γ t ≫=maybe λ T →
    just (TpAppt T t')
  ll-disambiguate Γ (AppTp t T') = ll-disambiguate Γ t ≫=maybe λ T → just (TpApp T T')
  ll-disambiguate Γ (Lam pi KeptLambda pi' x (SomeClass atk) t) =
    ll-disambiguate (ctxt-tk-decl pi' x atk Γ) t ≫=maybe λ T →
    just (TpLambda pi pi' x atk T)
  ll-disambiguate Γ (Parens pi t pi') = ll-disambiguate Γ t
  ll-disambiguate Γ (Let pi d t) =
    ll-disambiguate (Γ' d) t ≫=maybe λ T → just (TpLet pi d T)
    where
    Γ' : defTermOrType → ctxt
    Γ' (DefTerm pi' x (SomeType T) t) = ctxt-term-def pi' localScope OpacTrans x t T Γ
    Γ' (DefTerm pi' x NoType t) = ctxt-term-udef pi' localScope OpacTrans x t Γ
    Γ' (DefType pi' x k T) = ctxt-type-def pi' localScope OpacTrans x T k Γ
  ll-disambiguate Γ t = nothing

  parse-string : (ll : language-level) → string → maybe (ll-lift ll)
  parse-string ll s = case ll-ind {λ ll → string → Either string (ll-lift ll)}
    parseTerm parseType parseKind ll s of λ {(Left e) → nothing; (Right e) → just e}

  ttk = "term, type, or kind"

  parse-err-msg : (failed-to-parse : string) → (as-a : string) → string
  parse-err-msg failed-to-parse "" =
    "Failed to parse \\\\\"" ^ failed-to-parse ^ "\\\\\""
  parse-err-msg failed-to-parse as-a =
    "Failed to parse \\\\\"" ^ failed-to-parse ^ "\\\\\" as a " ^ as-a

  infixr 7 _≫nothing_ _-_!_≫parse_ _!_≫error_
  _≫nothing_ : ∀{ℓ}{A : Set ℓ} → maybe A → maybe A → maybe A
  (nothing ≫nothing m₂) = m₂
  (m₁ ≫nothing m₂) = m₁

  _-_!_≫parse_ : ∀{A B : Set} → (string → maybe A) → string →
                  (error-msg : string) → (A → string ⊎ B) → string ⊎ B
  (f - s ! e ≫parse f') = maybe-else (inj₁ (parse-err-msg s e)) f' (f s)

  _!_≫error_ : ∀{E A B : Set} → maybe A → E → (A → E ⊎ B) → E ⊎ B
  (just a ! e ≫error f) = f a
  (nothing ! e ≫error f) = inj₁ e

  parse-try : ∀ {X : Set} → ctxt → string → maybe
                (((ll : language-level) → ll-lift ll → X) → X)
  parse-try Γ s =
    maybe-map (λ t f → maybe-else (f ll-term t) (f ll-type) (ll-disambiguate Γ t))
      (parse-string ll-term s) ≫nothing
    maybe-map (λ T f → f ll-type T) (parse-string ll-type s) ≫nothing
    maybe-map (λ k f → f ll-kind k) (parse-string ll-kind s)

  string-to-𝔹 : string → maybe 𝔹
  string-to-𝔹 "tt" = just tt
  string-to-𝔹 "ff" = just ff
  string-to-𝔹 _ = nothing

  parse-ll : string → maybe language-level
  parse-ll "term" = just ll-term
  parse-ll "type" = just ll-type
  parse-ll "kind" = just ll-kind
  parse-ll _ = nothing


  {- Local Context -}

  record lci : Set where
    constructor mk-lci
    field ll : string; x : var; t : string; T : string; fn : string; pi : posinfo

  merge-lcis-ctxt : ctxt → 𝕃 string → ctxt
  merge-lcis-ctxt c = foldr merge-lci-ctxt c ∘ (sort-lcis ∘ strings-to-lcis) where
    strings-to-lcis : 𝕃 string → 𝕃 lci
    strings-to-lcis ss = strings-to-lcis-h ss [] where
      strings-to-lcis-h : 𝕃 string → 𝕃 lci → 𝕃 lci
      strings-to-lcis-h (ll :: x :: t :: T :: fn :: pi :: tl) items =
        strings-to-lcis-h tl (mk-lci ll x t T fn pi :: items)
      strings-to-lcis-h _ items = items

    language-level-type-of : language-level → language-level
    language-level-type-of ll-term = ll-type
    language-level-type-of _ = ll-kind

    merge-lci-ctxt : lci → ctxt → ctxt
    merge-lci-ctxt (mk-lci ll v t T fn pi) Γ =
      maybe-else Γ (λ Γ → Γ) (parse-ll ll ≫=maybe λ ll →
        parse-string (language-level-type-of ll) T ≫=maybe h ll (parse-string ll t)) where
      h : (ll : language-level) → maybe (ll-lift ll) →
          ll-lift (language-level-type-of ll) → maybe ctxt
      h ll-term (just t) T =
        just (ctxt-term-def pi localScope OpacTrans v t (qualif-type Γ T) Γ)
      h ll-type (just T) k =
        just (ctxt-type-def pi localScope OpacTrans v T (qualif-kind Γ k) Γ)
      h ll-term nothing T = just (ctxt-term-decl pi v T Γ)
      h ll-type nothing k = just (ctxt-type-decl pi v k Γ)
      h _ _ _ = nothing

    sort-lcis : 𝕃 lci → 𝕃 lci
    sort-lcis = list-merge-sort.merge-sort lci λ l l' →
                posinfo-to-ℕ (lci.pi l) > posinfo-to-ℕ (lci.pi l')
      where import list-merge-sort

  get-local-ctxt : ctxt → (pos : ℕ) → (local-ctxt : 𝕃 string) → ctxt
  get-local-ctxt Γ @ (mk-ctxt (fn , mn , _) _ is _ _) pi =
    merge-lcis-ctxt (foldr (flip ctxt-clear-symbol ∘ fst) Γ
      (flip filter (trie-mappings is) λ {(x , ci , fn' , pi') →
        fn =string fn' && posinfo-to-ℕ pi' > pi}))


  {- Helpers -}

  qualif-ed : ∀ {ed : exprd} → ctxt → ⟦ ed ⟧ → ⟦ ed ⟧
  qualif-ed{TERM} = qualif-term
  qualif-ed{TYPE} = qualif-type
  qualif-ed{KIND} = qualif-kind
  qualif-ed Γ e = e

  step-reduce : ∀ {ed : exprd} → ctxt → ⟦ ed ⟧ → ⟦ ed ⟧
  step-reduce Γ t = let t' = erase t in maybe-else t' id (step-reduceh Γ t') where
    step-reduceh : ∀ {ed : exprd} → ctxt → ⟦ ed ⟧ → maybe ⟦ ed ⟧
    step-reduceh{TERM} Γ (Var pi x) = ctxt-lookup-term-var-def Γ (qualif-var Γ x)
    step-reduceh{TYPE} Γ (TpVar pi x) = ctxt-lookup-type-var-def Γ (qualif-var Γ x)
    step-reduceh{TERM} Γ (App (Lam pi b pi' x oc t) me t') = just (subst Γ t' x t)
    step-reduceh{TYPE} Γ (TpApp (TpLambda pi pi' x (Tkk _) T) T') = just (subst Γ T' x T)
    step-reduceh{TYPE} Γ (TpAppt (TpLambda pi pi' x (Tkt _) T) t) = just (subst Γ t x T)
    step-reduceh{TERM} Γ (App t me t') = step-reduceh Γ t ≫=maybe λ t → just (App t me t')
    step-reduceh{TYPE} Γ (TpApp T T') = step-reduceh Γ T ≫=maybe λ T → just (TpApp T T')
    step-reduceh{TYPE} Γ (TpAppt T t) = step-reduceh Γ T ≫=maybe λ T → just (TpAppt T t)
    step-reduceh{TERM} Γ (Lam pi b pi' x oc t) = step-reduceh (ctxt-var-decl x Γ) t ≫=maybe λ t → just (Lam pi b pi' x oc t)
    step-reduceh{TYPE} Γ (TpLambda pi pi' x atk T) = step-reduceh (ctxt-var-decl x Γ) T ≫=maybe λ T → just (TpLambda pi pi' x atk T)
    step-reduceh{TERM} Γ (Let pi (DefTerm pi' x ot t') t) = just (subst Γ t' x t)
    step-reduceh{TYPE} Γ (TpLet pi (DefTerm pi' x ot t) T) = just (subst Γ t x T)
    step-reduceh{TYPE} Γ (TpLet pi (DefType pi' x k T') T) = just (subst Γ T' x T)
    step-reduceh Γ t = nothing

  parse-norm : string → maybe (∀ {ed : exprd} → ctxt → ⟦ ed ⟧ → ⟦ ed ⟧)
  parse-norm "all" = just λ Γ t → hnf Γ unfold-all t tt
  parse-norm "head" = just λ Γ t → hnf Γ unfold-head t tt
  parse-norm "once" = just λ Γ → step-reduce Γ ∘ erase
  parse-norm _ = nothing


  {- Command Executors -}

  normalize-cmd : ctxt → (str ll pi norm : string) → 𝕃 string → string ⊎ tagged-val
  normalize-cmd Γ str ll pi norm ls =
    parse-ll - ll ! "language-level" ≫parse λ ll' →
    string-to-ℕ - pi ! "natural number" ≫parse λ sp →
    parse-norm - norm ! "normalization method (all, head, once)" ≫parse λ norm →
    parse-string ll' - str ! ll ≫parse λ t →
      let Γ' = get-local-ctxt Γ sp ls in
    inj₂ (to-string-tag "" Γ' (norm Γ' (qualif-ed Γ' t)))

  normalize-prompt : ctxt → (str norm : string) → 𝕃 string → string ⊎ tagged-val
  normalize-prompt Γ str norm ls =
    parse-norm - norm ! "normalization method (all, head, once)" ≫parse λ norm →
    let Γ' = merge-lcis-ctxt Γ ls in
    parse-try Γ' - str ! ttk ≫parse λ f → f λ ll t →
    inj₂ (to-string-tag "" Γ' (norm Γ' (qualif-ed Γ' t)))

  erase-cmd : ctxt → (str ll pi : string) → 𝕃 string → string ⊎ tagged-val
  erase-cmd Γ str ll pi ls =
    parse-ll - ll ! "language-level" ≫parse λ ll' →
    string-to-ℕ - pi ! "natural number" ≫parse λ sp →
    parse-string ll' - str ! ll ≫parse λ t →
    let Γ' = get-local-ctxt Γ sp ls in
    inj₂ (to-string-tag "" Γ' (erase (qualif-ed Γ' t)))

  erase-prompt : ctxt → (str : string) → 𝕃 string → string ⊎ tagged-val
  erase-prompt Γ str ls =
    let Γ' = merge-lcis-ctxt Γ ls in
    parse-try Γ' - str ! ttk ≫parse λ f → f λ ll t →
    inj₂ (to-string-tag "" Γ' (erase (qualif-ed Γ' t)))

  private
    cmds-to-escaped-string : cmds → strM
    cmds-to-escaped-string (CmdsNext c cs) = cmd-to-string c $ strAdd "\\n\\n" ≫str cmds-to-escaped-string cs
    cmds-to-escaped-string CmdsStart = strEmpty

  data-cmd : ctxt → (encoding name ps is cs : string) → string ⊎ tagged-val
  data-cmd Γ encodingₛ x psₛ isₛ csₛ =
    string-to-𝔹 - encodingₛ ! "boolean" ≫parse λ encoding →
    parse-string ll-kind - psₛ ! "kind" ≫parse λ psₖ →
    parse-string ll-kind - isₛ ! "kind" ≫parse λ isₖ →
    parse-string ll-kind - csₛ ! "kind" ≫parse λ csₖ →
    let ps = map (λ {(Index x atk) → Decl posinfo-gen posinfo-gen Erased x atk posinfo-gen}) $ kind-to-indices Γ psₖ
        cs = map (λ {(Index x (Tkt T)) → Ctr x T; (Index x (Tkk k)) → Ctr x $ mtpvar "ErrorExpectedTypeNotKind"}) $ kind-to-indices empty-ctxt csₖ
        is = kind-to-indices (add-constructors-to-ctxt cs $ add-parameters-to-ctxt ps $ Γ) isₖ
        picked-encoding = if encoding then mendler-encoding else mendler-simple-encoding
        defs = datatype-encoding.mk-defs picked-encoding Γ $ Data x ps is cs in
    inj₂ $ strRunTag "" Γ $ cmds-to-escaped-string $ fst defs

  br-cmd : ctxt → (str qed : string) → 𝕃 string → IO ⊤
  br-cmd Γ str qed ls =
    let Γ' = merge-lcis-ctxt Γ ls in
    maybe-else
      (return (io-spans.spans-to-rope (io-spans.global-error "Parse error" nothing)))
      (λ s → s >>= return ∘ io-spans.spans-to-rope)
      (parse-try {maybe (IO io-spans.spans)} Γ' str ≫=maybe λ f → f λ where
         ll-term t → just (untyped-term-spans t Γ' io-spans.empty-spans >>= return ∘ (snd ∘ snd))
         ll-type T →
           parse-string ll-term qed ≫=maybe λ q →
           case check-term q (just $ qualif-type Γ' T) Γ' empty-spans of λ where
             (triv , _ , ss @ (regular-spans nothing _)) →
               just (putStrLn "inhabited: Type inhabited" >> untyped-type-spans T Γ' io-spans.empty-spans >>= return ∘ (snd ∘ snd))
             (triv , _ , _) →
               just (untyped-type-spans T Γ' io-spans.empty-spans >>= return ∘ (snd ∘ snd))
         ll-kind k →
           just (untyped-kind-spans k Γ' io-spans.empty-spans >>= return ∘ (snd ∘ snd)))
      >>= putRopeLn

  conv-cmd : ctxt → (ll str1 str2 : string) → 𝕃 string → string ⊎ tagged-val
  conv-cmd Γ ll s1 s2 ls =
    parse-ll - ll ! "language-level" ≫parse λ ll' →
    parse-string ll' - s1 ! ll ≫parse λ t1 →
    parse-string ll' - s2 ! ll ≫parse λ t2 →
    let Γ' = merge-lcis-ctxt Γ ls; t2 = erase (qualif-ed Γ' t2) in
    if ll-ind {λ ll → ctxt → ll-lift ll → ll-lift ll → 𝔹}
         conv-term conv-type conv-kind ll' Γ' (qualif-ed Γ' t1) t2
      then inj₂ (to-string-tag "" Γ' t2)
      else inj₁ "Inconvertible"

  rewrite-cmd : ctxt → (span-str : string) → (input-str : string) →
                (use-hnf : string) → (local-ctxt : 𝕃 string) → string ⊎ tagged-val
  rewrite-cmd Γ ss is hd ls =
    string-to-𝔹 - hd ! "boolean" ≫parse λ use-hnf →
    let Γ = merge-lcis-ctxt Γ ls in
    parse-try Γ - ss ! ttk ≫parse λ f → f λ ll ss →
    parse-try Γ - is ! ttk ≫parse λ f → (f λ where
      ll-term t → (case check-term t nothing Γ empty-spans of λ
          {(just T , _ , regular-spans nothing _) → just T; _ → nothing})
        ! "Error when synthesizing a type for the input term" ≫error λ where
          (TpEq _ t₁ t₂ _) → inj₂ (t₁ , t₂)
          _ → inj₁ "Synthesized a non-equational type from the input term"
      ll-type (TpEq _ t₁ t₂ _) → inj₂ (t₁ , t₂)
      ll-type _ → inj₁ "Expected the input expression to be a term, but got a type"
      ll-kind _ → inj₁ "Expected the input expression to be a term, but got a kind")
    ≫=⊎ uncurry λ t₁ t₂ →
    let x = fresh-var "x" (ctxt-binds-var Γ) empty-renamectxt
        f = ll-ind {λ ll → ctxt → term → var → ll-lift ll → ll-lift ll}
              subst subst subst ll Γ t₂ x in
    case (ll-ind {λ ll → ll-lift ll → ctxt → 𝔹 → maybe stringset →
                         term → term → var → ℕ → ll-lift ll × ℕ × ℕ}
      rewrite-term rewrite-type rewrite-kind ll (qualif-ed Γ ss) Γ
      use-hnf nothing (Beta posinfo-gen NoTerm NoTerm) t₁ x 0) of λ where
        (e , 0 , _) → inj₁ "No rewrites could be performed"
        (e , _ , _) → inj₂ (strRunTag "" Γ
          (to-stringh (erase (f e)) ≫str strAdd "§" ≫str strAdd x ≫str strAdd "§" ≫str to-stringh (erase e)))


  {- Commands -}

  tv-to-rope : string ⊎ tagged-val → rope
  tv-to-rope (inj₁ s) = [[ "{\"error\":\"" ]] ⊹⊹ [[ s ]] ⊹⊹ [[ "\"}" ]]
  tv-to-rope (inj₂ (_ , v , ts)) =
    [[ "{" ]] ⊹⊹ tagged-val-to-rope 0 ("value" , v , ts) ⊹⊹ [[ "}" ]]

  interactive-cmd-h : ctxt → 𝕃 string → string ⊎ tagged-val
  interactive-cmd-h Γ ("normalize" :: input :: ll :: sp :: norm :: lc) =
    normalize-cmd Γ input ll sp norm lc
  interactive-cmd-h Γ ("erase" :: input :: ll :: sp :: lc) =
    erase-cmd Γ input ll sp lc
  interactive-cmd-h Γ ("normalizePrompt" :: input :: norm :: lc) =
    normalize-prompt Γ input norm lc
  interactive-cmd-h Γ ("erasePrompt" :: input :: lc) =
    erase-prompt Γ input lc
  interactive-cmd-h Γ ("conv" :: ll :: ss :: is :: lc) =
    conv-cmd Γ ll ss is lc
  interactive-cmd-h Γ ("rewrite" :: ss :: is :: head :: lc) =
    rewrite-cmd Γ ss is head lc
  interactive-cmd-h Γ ("data" :: encoding :: x :: ps :: is :: cs :: []) =
    data-cmd Γ encoding x ps is cs
  interactive-cmd-h Γ cs =
    inj₁ ("Unknown interactive cmd: " ^ 𝕃-to-string (λ s → s) ", " cs)


interactive-cmd : 𝕃 string → toplevel-state → IO ⊤
interactive-cmd ("br" :: input :: qed :: lc) ts = br-cmd (toplevel-state.Γ ts) input qed lc
interactive-cmd ls ts = putRopeLn (tv-to-rope (interactive-cmd-h (toplevel-state.Γ ts) ls))
