module Riml
  class RewrittenASTCache
    def initialize
      @cache = {}
      @ast_classes_registered_cache = {}
    end

    def [](filename)
      @cache[filename]
    end

    def fetch(filename)
      ast = @cache[filename]
      return ast if ast
      @cache[filename] = yield
    end

    def clear
      @cache.clear
      @ast_classes_registered_cache.clear
    end

    def save_classes_registered(ast, class_diff)
      @ast_classes_registered_cache[ast] = class_diff
    end

    def fetch_classes_registered(ast)
      @ast_classes_registered_cache[ast] || {}
    end
  end
end
