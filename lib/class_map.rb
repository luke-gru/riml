require File.expand_path("../errors", __FILE__)
require File.expand_path("../imported_class", __FILE__)

module Riml
  # Map of {"ClassName" => ClassDefinitionNode}
  # Can also query object for superclass of a named class, etc...
  #
  # Ex : class_map.superclass("g:SomeClass") => "g:SomeClassBase"
  class ClassMap
    attr_reader :globbed_imports

    def initialize
      @map = {}
      # list of ImportedClass objects that are #globbed?
      @globbed_imports = []
    end

    def [](key)
      ensure_key_is_string!(key)
      klass = @map[key]
      return klass if klass
      if key[0..1] == 'g:'
        globbed_imports.each do |imported_class|
          if imported_class.match?(key)
            return @map[key] = ImportedClass.new(key)
          end
        end
      end
      raise ClassNotFound, "class #{key.inspect} not found."
    end

    def []=(key, val)
      ensure_key_is_string!(key)
      if class_node = @map[key]
        if !class_node.instance_variable_get("@registered_state") &&
           !val.instance_variable_get("@registered_state")
          raise ClassRedefinitionError, "can't redefine class #{key.inspect}."
        end
      end
      @map[key] = val
    end

    def superclass(key)
      super_key = self[key].superclass_name
      self[super_key]
    end

    def classes
      @map.values
    end

    def class_names
      @map.keys
    end

    def has_global_import?
      @globbed_imports.any? { |import| import.global_import? }
    end

    protected

    def ensure_key_is_string!(key)
      unless key.is_a?(String)
        raise ArgumentError, "key must be name of class (String)"
      end
    end

  end
end
