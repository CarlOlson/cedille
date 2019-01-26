module ctxt-types where

open import lib
open import cedille-types
open import general-util
open import syntax-util

location : Set
location = string × posinfo -- file path and starting position in the file

-- file path and starting / ending position in file
span-location = string × posinfo × posinfo

-- missing locations
missing-location : location
missing-location = ("missing" , "missing")

missing-span-location : span-location
missing-span-location = ("missing" , "missing" , "missing")

{- we will generally keep classifiers of variables in hnf in the ctxt, although
   we will not necessarily unfold recursive type definitions. -}

defScope : Set
defScope = 𝔹

localScope : defScope
localScope = tt

globalScope : defScope
globalScope = ff

defParams : Set
defParams = maybe params

data ctxt-info : Set where
  -- for defining a datatype
  datatype-def : params → kind → ctxt-info

  -- for defining a datatype constructor
  const-def : type → ctxt-info

  -- for declaring a variable to have a given type (with no definition)
  term-decl : type → ctxt-info

  -- for defining a variable to equal a term with a given type
  term-def : defParams → opacity → term → type → ctxt-info

  -- for untyped term definitions
  term-udef : defParams → opacity → term → ctxt-info

  -- for declaring a variable to have a given kind (with no definition)
  type-decl : kind → ctxt-info

  -- for defining a variable to equal a type with a given kind
  type-def : defParams → opacity → type → kind → ctxt-info

  -- for defining a variable to equal a kind
  kind-def : params → kind → ctxt-info

  -- to rename a variable at any level to another
  rename-def : var → ctxt-info

  -- representing a declaration of a variable with no other information about it
  var-decl : ctxt-info

sym-info : Set
sym-info = ctxt-info × location

-- module filename, name, parameters, and qualifying substitution
mod-info : Set
mod-info = string × string × params × qualif

-- datatypes info
datatype-info : Set
datatype-info = defDatatype

is-term-level : ctxt-info → 𝔹
is-term-level (term-decl _) = tt
is-term-level (term-def _ _ _ _) = tt
is-term-level (term-udef _ _ _) = tt
is-term-level (const-def _ ) = tt
is-term-level _ = ff

data ctxt : Set where
  mk-ctxt : (mod : mod-info) →                     -- current module
            (syms : trie (string × 𝕃 string) × trie string × trie params × trie ℕ × Σ ℕ (𝕍 string)) →    -- map each filename to its module name and the symbols declared in that file, map each module name to its filename and params, and file ID's for use in to-string.agda
            (i : trie sym-info) →                  -- map symbols (from Cedille files) to their ctxt-info and location
            (sym-occurrences : trie (𝕃 (var × posinfo × string))) →  -- map symbols to a list of definitions they occur in (and relevant file info)
            (datatypes-info : trie datatype-info) →
            ctxt


ctxt-binds-var : ctxt → var → 𝔹
ctxt-binds-var (mk-ctxt (_ , _ , _ , q) _ i _ _) x = trie-contains q x || trie-contains i x

ctxt-var-decl : var → ctxt → ctxt
ctxt-var-decl v (mk-ctxt (fn , mn , ps , q) syms i symb-occs d) =
  mk-ctxt (fn , mn , ps , (trie-insert q v (v , ArgsNil))) syms (trie-insert i v (var-decl , "missing" , "missing")) symb-occs d

ctxt-var-decl-loc : posinfo → var → ctxt → ctxt
ctxt-var-decl-loc pi v (mk-ctxt (fn , mn , ps , q) syms i symb-occs d) =
  mk-ctxt (fn , mn , ps , (trie-insert q v (v , ArgsNil))) syms (trie-insert i v (var-decl , fn , pi)) symb-occs d

qualif-var : ctxt → var → var
qualif-var (mk-ctxt (_ , _ , _ , q) _ _ _ _) v with trie-lookup q v
...| just (v' , _) = v'
...| nothing = v

start-modname : start → string
start-modname (File _ _ _ _ mn _ _ _) = mn

ctxt-get-current-filename : ctxt → string
ctxt-get-current-filename (mk-ctxt (fn , _) _ _ _ _) = fn

ctxt-get-current-mod : ctxt → mod-info
ctxt-get-current-mod (mk-ctxt m _ _ _ _) = m

ctxt-get-current-modname : ctxt → string
ctxt-get-current-modname (mk-ctxt (_ , mn , _ , _) _ _ _ _) = mn

ctxt-get-current-params : ctxt → params
ctxt-get-current-params (mk-ctxt (_ , _ , ps , _) _ _ _ _) = ps

ctxt-get-symbol-occurrences : ctxt → trie (𝕃 (var × posinfo × string))
ctxt-get-symbol-occurrences (mk-ctxt _ _ _ symb-occs _) = symb-occs

ctxt-set-symbol-occurrences : ctxt → trie (𝕃 (var × posinfo × string)) → ctxt
ctxt-set-symbol-occurrences (mk-ctxt fn syms i symb-occs d) new-symb-occs = mk-ctxt fn syms i new-symb-occs d
