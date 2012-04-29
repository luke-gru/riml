module Riml
  module Constants
    RIML_KEYWORDS = %w(def function function! end if then else elsif unless while
                       for in true false nil command command? return finish break
                       continue call let)
    VIML_END_KEYWORDS = %w(endif endfunction endwhile endfor)
    KEYWORDS = RIML_KEYWORDS + VIML_END_KEYWORDS

    VIML_FUNC_NO_PARENS_NECESSARY = %W(echo echohl execute)
  end
end
