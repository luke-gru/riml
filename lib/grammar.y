class Riml::Parser

token IF ELSE ELSIF THEN UNLESS END
token WHILE UNTIL
token DEF
token COMMAND NARGS
token INDENT DEDENT
token NEWLINE
token NUMBER STRING_D STRING_S # single- and double-quoted
token TRUE FALSE NIL
token IDENTIFIER
token CONSTANT
token SCOPE_MODIFIER
token FINISH

prechigh
  right '!'
  left '*' '/'
  left '+' '+=' '-' '-='
  left '.'
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
    Operator                              { result = val[0] }
  | Call                                  { result = val[0] }
  | Assign                                { result = val[0] }
  | Def                                   { result = val[0] }
  | Command                               { result = val[0] }
  | VariableRetrieval                     { result = val[0] }
  | Literal                               { result = val[0] }
  | Constant                              { result = val[0] }
  | If                                    { result = val[0] }
  | Unless                                { result = val[0] }
  | Ternary                               { result = val[0] }
  | While                                 { result = val[0] }
  | '(' Expression ')'                    { result = val[1] }
  | EndScript                             { result = val[0] }
  ;

  Terminator:
    NEWLINE
  | ";"
  ;

  # All hard-coded values
  Literal:
    NUMBER                                { result = NumberNode.new(val[0]) }
  | String                                { result = val[0] }
  | List                                  { result = ListNode.new(val[0]) }
  | Dictionary                            { result = DictionaryNode.new(val[0]) }
  | TRUE                                  { result = TrueNode.new }
  | FALSE                                 { result = FalseNode.new }
  | NIL                                   { result = NilNode.new }
  ;

  String:
    STRING_S                              { result = StringNode.new(val[0], :s) }
  | STRING_D                              { result = StringNode.new(val[0], :d) }
  ;

  List:
    '[' ListItems ']'                     { result = val[1] }
  ;

  ListItems:
    /* nothing */                         { result = [] }
  | Literal                               { result = val }
  | ListItems "," Literal                 { result = val[0] << val[2] }
  ;

  Dictionary:
    '{' DictItems '}'                     { result = Hash[val[1]] }
  ;

  # [[key, value], [key, value]]
  DictItems:
    /* nothing */                         { result = [] }
  | DictItem                              { result = val }
  | DictItems "," DictItem                { result = val[0] << val[2] }
  ;

  # [key, value]
  DictItem:
    Literal ':' Literal                   { result = [val[0], val[2]] }
  ;

  # A function call
  # some_function()
  # some_function(a, b)
  Call:
    Scope IDENTIFIER "(" ArgList ")"        { result = CallNode.new(val[0], val[1], val[3]) }
  ;


  Scope:
    SCOPE_MODIFIER         { result = val[0] }
  | /* nothing */          { result = nil }
  ;

  ArgList:
    /* nothing */                         { result = [] }
  | Expression                            { result = val }
  | ArgList "," Expression                { result = val[0] << val[2] }
  ;

  # Binary operators
  Operator:
    Expression '||' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '&&' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '==' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '!=' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '=~' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '!~' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '>' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '>=' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '<' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '<=' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '+' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '+=' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '-' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '-=' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '*' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '/' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '.' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  ;

  Constant:
    CONSTANT                              { result = GetConstantNode.new(val[0]) }
  ;

  # Assignment to a variable
  Assign:
    Scope IDENTIFIER '=' Expression             { result = SetVariableNode.new(val[0], val[1], val[3]) }
  | CONSTANT '=' Expression                     { result = SetConstantNode.new(val[0], val[2]) }
  ;

  # retrieving the value of a variable
  VariableRetrieval:
    Scope IDENTIFIER                            { result = GetVariableNode.new(val[0], val[1])}
  ;

  # Method definition
  # [scope_modifier, name, args, expressions, indent]
  Def:
    DEF Scope IDENTIFIER Keyword Block End                             { indent = val[4].pop; result = DefNode.new(val[1], val[2], [],     val[3], val[4], indent) }
  | DEF Scope IDENTIFIER "(" ParamList ")" Keyword Block End           { indent = val[7].pop; result = DefNode.new(val[1], val[2], val[4], val[6], val[7], indent) }
  ;

  # like 'range' after function definition
  Keyword:
    IDENTIFIER            { result = val[0] }
  | /* nothing */         { result = nil }
  ;

  Command:
    COMMAND NARGS IDENTIFIER {}
  ;

  End:
    END NEWLINE DEDENT
  | END
  ;

  EndScript:
    FINISH                                      { result = FinishNode.new }
  ;

  ParamList:
    /* nothing */                         { result = [] }
  | IDENTIFIER                            { result = val }
  | ParamList ',' IDENTIFIER              { result = val[0] << val[2] }
  ;

  # [expression, expressions]
  If:
    IF Expression Block End                 { indent = val[2].pop; result = IfNode.new(val[1], val[2]) }
  | IF Expression THEN Expression End       { result = IfNode.new( val[1], Nodes.new([val[3]]) ) }
  ;

  Unless:
    UNLESS Expression Block End             { indent = val[2].pop; result = UnlessNode.new(val[1], val[2]) }
  | UNLESS Expression THEN Expression End   { result = UnlessNode.new( val[1], Nodes.new([val[3]]) ) }
  ;

  Ternary:
    Expression '?' Expression ':' Expression    { result = TernaryOperatorNode.new([val[0], val[2], val[4]]) }
  ;

  While:
    WHILE Expression Block End              { indent = val[2].pop; result = WhileNode.new(val[1], val[2]) }
  ;

  # [expressions, indent]
  # expressions list could contain an ElseNode, which contains expressions
  Block:
    NEWLINE INDENT Expressions ELSE NEWLINE Expressions { result = val[2] << ElseNode.new(val[5]) << val[1] }
  | NEWLINE INDENT Expressions                          { result = val[2] << val[1] }
  | NEWLINE INDENT                                      { result = Nodes.new([]) << val[1] }
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
    Array === object and object[0..4].all? {|e| e.respond_to?(:size) and e.size == 2}
  end

  def code?(object)
    String === object
  end
