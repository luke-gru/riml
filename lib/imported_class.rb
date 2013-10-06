require File.expand_path('../nodes', __FILE__)

module Riml
  class ImportedClass

    attr_reader :name
    def initialize(name)
      @name = name
    end

    def imported?
      true
    end

    def scope_modifier
      'g:'
    end

    # stubbed out constructor function
    def constructor
      @contructor ||= begin
        DefNode.new('!', nil, scope_modifier, constructor_name, ['...'], [], Nodes.new([]))
      end
    end

    def constructor_name
      "#{name}Constructor"
    end

    def constructor_obj_name
      name[0].downcase + name[1..-1] + "Obj"
    end

  end
end
