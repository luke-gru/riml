module Riml
  class PathCache
    def initialize
      @cache = {}
    end

    def []=(path, val)
      path = normalize_path(path)
      @cache[path] = val
    end

    def [](path)
      path = normalize_path(path)
      @cache[path]
    end

    def cache(path)
      path = normalize_path(path)
      @cache[path] = {}
      path.each do |dir|
        files = Dir.glob(File.join(dir, '*')).to_a.select { |file| File.file?(file) }
        files.each do |full_path|
          basename = File.basename(full_path)
          # first file wins in PATH
          unless @cache[path][basename]
            @cache[path][basename] = full_path
          end
        end
      end
    end

    def file(path, basename)
      return nil unless @cache[path]
      @cache[path][basename]
    end

    def clear
      @cache.clear
    end

    private

    # returns array of strings (directory names in path)
    def normalize_path(path)
      if path.is_a?(String)
        path.split(':')
      elsif path.respond_to?(:each)
        path
      else
        [path]
      end
    end
  end
end
