require File.expand_path('../nodes', __FILE__)

module Riml
  class ImportedClass

    ANCHOR_BEGIN = '\A'
    ANCHOR_END = '\Z'

    attr_reader :name
    def initialize(name)
      @name = rm_modifier(name)
    end

    def imported?
      true
    end

    # an ImportedClass is #globbed? if its name contains 1 or more '*'
    # characters.
    def globbed?
      not @name.index('*').nil?
    end

    # returns MatchData or `nil`
    def match?(class_name)
      match_regexp.match(rm_modifier(class_name))
    end

    # returns Regexp
    def match_regexp
      @match_regexp ||= begin
        normalized_glob = @name.gsub(/\*/, '.*?')
        Regexp.new(ANCHOR_BEGIN + normalized_glob + ANCHOR_END)
      end
    end

    def global_import?
      @name == '*'
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
      "#{@name}Constructor"
    end

    def constructor_obj_name
      @name[0..0].downcase + @name[1..-1] + "Obj"
    end

    private

    def rm_modifier(class_name)
      class_name.sub(/g:/, '')
    end

  end
end
