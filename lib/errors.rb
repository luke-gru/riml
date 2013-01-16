module Riml
  RimlError = Class.new(StandardError)

  SyntaxError  = Class.new(RimlError)
  ParseError   = Class.new(RimlError)
  CompileError = Class.new(RimlError)

  FileNotFound = Class.new(RimlError)

  ClassNotFound = Class.new(RimlError)
  ClassRedefinitionError = Class.new(RimlError)
end
