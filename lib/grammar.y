class Riml::Parser

token IF THEN ELSE ELSIF END
token DEF
token INDENT DEDENT
token NEWLINE
token NUMBER
token STRING
token TRUE FALSE NIL
token IDENTIFIER
token CONSTANT
token SCOPE_MODIFIER

prechigh
  right '!'
  left '*' '/'
  left '+' '-'
  left '>' '>=' '<' '<='
  left '&&'
  left '||'
  right '='
  left ','
preclow

# All rules
rule

  Root:
    /* nothing */                         { result = Nodes.new([]) }
  | Expressions                           { result = val[0] }
  ;

  # any list of expressions
  Expressions:
    Expression                            { result = Nodes.new([ val[0] ]) }
  | Expressions Terminator Expression     { result = val[0] << val[2] }
  | Expressions Terminator                { result = val[0] }
  | Terminator                            { result = Nodes.new([]) }
  ;

  # All types of expressions in Riml
  Expression:
    Literal
  | Call
  | Operator
  | Constant
  | Assign
  | Def
  | If
  | '(' Expression ')'                    { result = val[1] }
  ;

  Terminator:
    NEWLINE
  | ";"
  ;

  # All hard-coded values
  Literal:
    NUMBER                                { result = NumberNode.new(val[0]) }
  | STRING                                { result = StringNode.new(val[0]) }
  | TRUE                                  { result = TrueNode.new }
  | FALSE                                 { result = FalseNode.new }
  | NIL                                   { result = NilNode.new }
  ;

  # A method call
  Call:
    # method
    IDENTIFIER                            { result = CallNode.new(val[0], []) }
    # method(args)
  | IDENTIFIER "(" ArgList ")"            { result = CallNode.new(val[0], val[2]) }
  ;

  ArgList:
    /* nothing */                         { result = [] }
  | Expression                            { result = val }
  | ArgList "," Expression                { result = val[0] << val[2] }
  ;

  # Binary operators
  Operator:
    Expression '||' Expression            { result = CallNode.new(val[0], val[1], val[2]) }
  | Expression '&&' Expression            { result = CallNode.new(val[0], val[1], val[2]) }
  | Expression '==' Expression            { result = CallNode.new(val[0], val[1], val[2]) }
  | Expression '!=' Expression            { result = CallNode.new(val[0], val[1], val[2]) }
  | Expression '>' Expression             { result = CallNode.new(val[0], val[1], val[2]) }
  | Expression '>=' Expression            { result = CallNode.new(val[0], val[1], val[2]) }
  | Expression '<' Expression             { result = CallNode.new(val[0], val[1], val[2]) }
  | Expression '<=' Expression            { result = CallNode.new(val[0], val[1], val[2]) }
  | Expression '+' Expression             { result = CallNode.new(val[0], val[1], val[2]) }
  | Expression '-' Expression             { result = CallNode.new(val[0], val[1], val[2]) }
  | Expression '*' Expression             { result = CallNode.new(val[0], val[1], val[2]) }
  | Expression '/' Expression             { result = CallNode.new(val[0], val[1], val[2]) }
  ;

  Constant:
    CONSTANT                              { result = GetConstantNode.new(val[0]) }
  ;

  # Assignment to a variable
  Assign:
    IDENTIFIER '=' Expression                   { result = SetVariableNode.new(nil, val[0], val[2]) }
  | SCOPE_MODIFIER IDENTIFIER '=' Expression    { result = SetVariableNode.new(val[0], val[1], val[3]) }
  | CONSTANT '=' Expression                     { result = SetConstantNode.new(val[0], val[2]) }
  ;

  # Method definition
  # [scope_modifier, name, args, expressions, indent]
  Def:
    DEF IDENTIFIER Block End                                   { indent = val[2].pop; result = DefNode.new(nil,    val[1], [],     val[2], indent) }
  | DEF IDENTIFIER "(" ParamList ")" Block End                 { indent = val[5].pop; result = DefNode.new(nil,    val[1], val[3], val[5], indent) }
  | DEF SCOPE_MODIFIER IDENTIFIER Block End                    { indent = val[3].pop; result = DefNode.new(val[1], val[2], [],     val[3], indent) }
  | DEF SCOPE_MODIFIER IDENTIFIER "(" ParamList ")" Block End  { indent = val[6].pop; result = DefNode.new(val[1], val[2], val[4], val[6], indent) }
  ;

  End:
    END NEWLINE DEDENT
  | END
  ;

  ParamList:
    /* nothing */                         { result = [] }
  | IDENTIFIER                            { result = val }
  | ParamList ',' IDENTIFIER              { result = val[0] << val[2] }
  ;

  # [expression, expressions, indent]
  If:
    IF Expression Block End             { indent = val[2].pop; result = IfNode.new(val[1], val[2], indent) }
  | IF Expression THEN Expression END   { result = IfNode.new(val[1], val[3], nil)}
  ;

  # [expressions, indent]
  # expressions list could contain an ElseNode, which contains expressions
  Block:
    NEWLINE INDENT Expressions ELSE NEWLINE Expressions { result = val[2] << ElseNode.new(val[5]) << val[1] }
  | NEWLINE INDENT Expressions                          { result = val[2] << val[1] }
  ;
end

---- header
  require File.expand_path("../lexer", __FILE__)
  require File.expand_path("../nodes", __FILE__)
  require 'pp'

---- inner
  # This code will be put as-is in the parser class

  # parses tokens or code into output nodes
  def parse(object, show_tokens=false)
    @tokens = if tokens?(object)
      object
    elsif code?(object)
      Riml::Lexer.new.tokenize(object)
    end
    pp(@tokens) if show_tokens
    do_parse
  end

  def next_token
    @tokens.shift
  end

  private
  # is an array of arrays and first five inner arrays are all doubles
  def tokens?(object)
    Array === object and object[0..5].all? {|e| e.respond_to?(:size) and e.size == 2}
  end

  def code?(object)
    String === object
  end
