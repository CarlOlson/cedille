module constants where

open import lib

cedille-extension : string
cedille-extension = "ced"

self-name : string
self-name = "self"


pattern ignored-var = "_"

pattern meta-var-pfx = '?'
pattern qual-local-chr = '@'
pattern qual-global-chr = '.'

meta-var-pfx-str = 𝕃char-to-string [ meta-var-pfx ]
qual-local-str = 𝕃char-to-string [ qual-local-chr ]
qual-global-str = 𝕃char-to-string [ qual-global-chr ]

options-file-name : string
options-file-name = "options"

global-error-string : string → string
global-error-string msg = "{\"error\":\"" ^ msg ^ "\"" ^ "}"

dot-cedille-directory : string → string
dot-cedille-directory dir = combineFileNames dir ".cedille"
