module Riml
  class ClassNotFound < NameError; end

  # Map of {"ClassName" => ClassDefinitionNode}
  # Can also query object for superclass of a named class, etc...
  #
  # Ex : classes["SomeClass"].superclass_name => "SomeClassBase"
  class ClassMap
    def initialize
      @map = {}
    end

    def [](key)
      ensure_key_is_string!(key)
      @map[key]
    end

    def []=(key, val)
      ensure_key_is_string!(key)
      @map[key] = val
    end

    def superclass(key)
      ensure_key_is_string!(key)
      super_key = @map[key].superclass_name
      raise ClassNotFound.new(super_key) unless @map[super_key]
      @map[super_key]
    end

    def classes
      @map.values
    end

    def class_names
      @map.keys
    end

    protected
    def ensure_key_is_string!(key)
      unless key.is_a?(String)
        raise ArgumentError, "key must be name of class (String)"
      end
    end

  end
end
