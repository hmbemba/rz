import rz/core         ; export core
import rz/macros       ; export macros
import rz/combinators  ; export combinators
import rz/parsers      ; export parsers
import rz/collections  ; export collections
import rz/json         ; export json

when not defined(js):
    import rz/io ; export io

when defined(js):
    import rz/js/[fetch, parsers, helpers]
    export fetch, parsers, helpers
