module Riml
  RimlError = Class.new(StandardError) do
    attr_accessor :node
  end

  SyntaxError  = Class.new(RimlError)
  ParseError   = Class.new(RimlError)
  CompileError = Class.new(RimlError)

  FileNotFound = Class.new(RimlError)
  IncludeFileLoop = Class.new(RimlError)
  SourceFileLoop = Class.new(RimlError)
  IncludeNotTopLevel = Class.new(RimlError)
  # bad user arguments to Riml functions
  UserArgumentError = Class.new(RimlError)
  UserFunctionNotFoundError = Class.new(RimlError)

  ClassNotFound = Class.new(RimlError)
  ClassRedefinitionError = Class.new(RimlError)
end
