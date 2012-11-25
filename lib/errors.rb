module Riml
  RimlError = Class.new(StandardError)

  SyntaxError  = Class.new(RimlError)
  ParseError   = Class.new(RimlError)
  CompileError = Class.new(RimlError)

  FileNotFound = Class.new(RimlError)
end
