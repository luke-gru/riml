module Riml
  module Constants
    RIML_KEYWORDS = %w(def function function! end if then else elseif unless while
                       for in true false nil command command? return finish break
                       continue call let)
    VIML_END_KEYWORDS = %w(endif endfunction endwhile endfor)
    KEYWORDS = RIML_KEYWORDS + VIML_END_KEYWORDS

    VIML_SPECIAL_VARIABLE_PREFIXES = %w(& @ $)

    VIML_FUNC_NO_PARENS_NECESSARY = %W(echo echon echohl execute sleep)
  end
end
