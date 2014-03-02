require File.expand_path('../constants', __FILE__)

module Riml
  class RimlError < StandardError
    attr_accessor :node
    def initialize(msg = nil, node = nil)
      super(msg)
      @node = node
    end

    def verbose_message
      "#{self.class}\n" <<
      "location: #{location_info}\n" <<
      "message: #{message.to_s.sub(/\A\n/, '')}"
    end

    def location_info
      if @node
        @node.location_info
      else
        Constants::UNKNOWN_LOCATION_INFO
      end
    end
  end

  module ErrorWithoutNodeAvailable
    attr_accessor :filename, :lineno
    def initialize(msg = nil, filename = nil, lineno = nil)
      super(msg, nil)
      @filename = filename
      @lineno = lineno
    end

    def location_info
      if @filename || @lineno
        "#{@filename}:#{@lineno}"
      else
        Constants::UNKNOWN_LOCATION_INFO
      end
    end
  end

  class SyntaxError < RimlError
    include ErrorWithoutNodeAvailable
  end
  class ParseError < RimlError
    include ErrorWithoutNodeAvailable
  end

  CompileError = Class.new(RimlError)
  InvalidMethodDefinition = Class.new(RimlError)

  FileNotFound = Class.new(RimlError)
  IncludeFileLoop = Class.new(RimlError)
  SourceFileLoop = Class.new(RimlError)
  IncludeNotTopLevel = Class.new(RimlError)

  # bad user arguments to Riml functions
  UserArgumentError = Class.new(RimlError)

  # super is called in invalid context
  InvalidSuper = Class.new(RimlError)

  ClassNotFound = Class.new(RimlError)
  ClassRedefinitionError = Class.new(RimlError)
end
