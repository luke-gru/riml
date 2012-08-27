class Riml::Parser

token IF ELSE ELSEIF THEN UNLESS END
token WHILE UNTIL
token FOR IN
token DEF SPLAT CALL BUILTIN_COMMAND # such as echo "hi"
token COMMAND NARGS
token NEWLINE
token NUMBER
token STRING_D STRING_S # single- and double-quoted
token TRUE FALSE NIL
token LET IDENTIFIER DICT_VAL_REF
token SCOPE_MODIFIER SPECIAL_VAR_PREFIX
token FINISH

prechigh
  right '!'
  left '*' '/' '%'
  left '+' '+=' '-' '-='
  left '.'
  left '>' '>=' '<' '<='
  left '=='
  left '&&'
  left '||'
  right '?'
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
  | DictGet                               { result = val[0] }
  | ListOrDictGet                         { result = val[0] }
  | DictSet                               { result = val[0] }
  | Def                                   { result = val[0] }
  | Command                               { result = val[0] }
  | VariableRetrieval                     { result = val[0] }
  | Literal                               { result = val[0] }
  | If                                    { result = val[0] }
  | Unless                                { result = val[0] }
  | Ternary                               { result = val[0] }
  | While                                 { result = val[0] }
  | Until                                 { result = val[0] }
  | For                                   { result = val[0] }
  | '(' Expression ')'                    { result = val[1] }
  | EndScript                             { result = val[0] }
  ;

  Terminator:
    NEWLINE
  | ";"
  ;

  # All hard-coded values
  Literal:
    Number                                { result = val[0] }
  | String                                { result = val[0] }
  | List                                  { result = val[0] }
  | Dictionary                            { result = val[0] }
  | TRUE                                  { result = TrueNode.new }
  | FALSE                                 { result = FalseNode.new }
  | NIL                                   { result = NilNode.new }
  ;

  Number:
    NUMBER                                { result = NumberNode.new(val[0]) }
  ;


  String:
    STRING_S                              { result = StringNode.new(val[0], :s) }
  | STRING_D                              { result = StringNode.new(val[0], :d) }
  ;

  List:
    ListLiteral                           { result = ListNode.new(val[0]) }
  ;

  ListLiteral:
    '[' ListItems ']'                     { result = val[1] }
  ;

  ListItems:
    /* nothing */                         { result = [] }
  | Literal                               { result = val }
  | VariableRetrieval                     { result = val }
  | ListItems "," Literal                 { result = val[0] << val[2] }
  | ListItems "," VariableRetrieval       { result = val[0] << val[2] }
  ;

  Dictionary
    DictionaryLiteral                     { result = DictionaryNode.new(val[0]) }
  ;

  # {'key' => 'value', 'key' => 'value'}
  DictionaryLiteral:
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

  DictGet:
    Dictionary DictGetWithBrackets               { result = DictGetBracketNode.new(val[0], val[1]) }
  | Dictionary LiteralDictGetWithDot             { result = DictGetDotNode.new(val[0], val[1]) }
  | VariableRetrieval VariableDictGetWithDot     { result = DictGetDotNode.new(val[0], val[1]) }
  | VariableRetrieval DictGetWithBracketsString  { result = DictGetBracketNode.new(val[0], val[1]) }
  | DictGet DictGetWithBracketsString            { result = DictGetBracketNode.new(val[0], val[1]) }
  | Call DictGetWithBracketsString               { result = DictGetBracketNode.new(val[0], val[1]) }
  ;

  DictGetWithBrackets:
   '['  Literal ']'                              { result = [val[1]] }
  | DictGetWithBrackets '[' Literal ']'          { result = val[0] << val[2] }
  ;

  DictGetWithBracketsString:
   '[' String ']'                              { result = [val[1]] }
  | DictGetWithBracketsString '[' String ']'   { result = val[0] << val[2] }
  ;

  VariableDictGetWithDot:
    DICT_VAL_REF                                 { result = [val[0]] }
  | VariableDictGetWithDot DICT_VAL_REF          { result = val[0] << val[1] }
  ;

  LiteralDictGetWithDot:
    '.' IDENTIFIER                               { result = [val[1]]}
  | LiteralDictGetWithDot DICT_VAL_REF           { result = val[0] << val[1] }
  ;

  DictSet:
    VariableRetrieval VariableDictGetWithDot '=' Literal     { result = DictSetNode.new(val[0], val[1], val[3]) }
  | LET VariableRetrieval VariableDictGetWithDot '=' Literal { result = DictSetNode.new(val[1], val[2], val[4]) }
  ;

  # can only tell if the identifier is a list or dict at compile time
  ListOrDictGet:
    VariableRetrieval ListOrDictGetWithKey    { result = ListOrDictGetNode.new(val[0], val[1]) }
  | DictGet ListOrDictGetWithKey              { result = ListOrDictGetNode.new(val[0], val[1]) }
  | Call ListOrDictGetWithKey                 { result = ListOrDictGetNode.new(val[0], val[1]) }
  ;

  ListOrDictGetWithKey:
    '[' ListOrDictKey ']'                      { result = [val[1]] }
  | ListOrDictGetWithKey '[' ListOrDictKey ']' { result = val[0] << val[2] }
  | ListOrDictGetWithKey '[' String ']'        { result = val[0] << val[2] }
  ;

  ListOrDictKey:
    VariableRetrieval { result = val[0] }
  | DictGet           { result = val[0] }
  | Number            { result = val[0] }
  | Call              { result = val[0] }
  ;

  Call:
    Scope IDENTIFIER         "(" ArgList ")"  { result = CallNode.new(val[0], val[1], val[3]) }
  | CALL Scope IDENTIFIER    "(" ArgList ")"  { result = ExplicitCallNode.new(val[1], val[2], val[4]) }
  | BUILTIN_COMMAND          "(" ArgList ")"  { result = CallNode.new(nil, val[0], val[2]) }
  | BUILTIN_COMMAND              ArgList      { result = CallNode.new(nil, val[0], val[1]) }
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
  | Expression '==#' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '==?' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '!=' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '!=#' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '!=?' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
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

  # Assignment to a variable
  Assign:
    LET Scope IDENTIFIER '=' Expression                   { result = SetVariableNode.new(val[1], val[2], val[4]) }
  | Scope IDENTIFIER '=' Expression                       { result = SetVariableNode.new(val[0], val[1], val[3]) }
  | LET ListLiteral '=' Expression                        { result = SetVariableNodeList.new(ListNode.new(val[1]), val[3]) }
  | ListLiteral '=' Expression                            { result = SetVariableNodeList.new(ListNode.new(val[0]), val[2]) }
  | LET SPECIAL_VAR_PREFIX IDENTIFIER '=' Expression      { result = SetSpecialVariableNode.new(val[1], val[2], val[4]) }
  | SPECIAL_VAR_PREFIX IDENTIFIER '=' Expression          { result = SetSpecialVariableNode.new(val[0], val[1], val[3]) }
  ;

  # retrieving the value of a variable
  VariableRetrieval:
    Scope IDENTIFIER                            { result = GetVariableNode.new(val[0], val[1]) }
  | SPECIAL_VAR_PREFIX IDENTIFIER               { result = GetSpecialVariableNode.new(val[0], val[1]) }
  ;

  # Method definition
  # [scope_modifier, name, args, keyword, expressions]
  Def:
    DEF Scope IDENTIFIER Keyword Block END                                { result = DefNode.new(val[1], val[2], [],     val[3], val[4]) }
  | DEF Scope IDENTIFIER "(" ParamList ")" Keyword Block END              { result = DefNode.new(val[1], val[2], val[4], val[6], val[7]) }
  | DEF Scope IDENTIFIER "(" ParamList ',' SPLAT ")" Keyword Block END    { result = DefNode.new(val[1], val[2], val[4] << val[6], val[8], val[9]) }
  ;

  # Example: 'range' after function definition
  Keyword:
    IDENTIFIER            { result = val[0] }
  | /* nothing */         { result = nil }
  ;

  Command:
    COMMAND NARGS IDENTIFIER {}
  ;

  EndScript:
    FINISH                                { result = FinishNode.new }
  ;

  ParamList:
    /* nothing */                         { result = [] }
  | IDENTIFIER                            { result = val }
  | ParamList ',' IDENTIFIER              { result = val[0] << val[2] }
  ;

  # [expression, expressions]
  If:
    IF Expression Block END                 { result = IfNode.new(val[1], val[2]) }
  | IF Expression THEN Expression END       { result = IfNode.new( val[1], Nodes.new([val[3]]) ) }
  ;

  Unless:
    UNLESS Expression Block END             { result = UnlessNode.new(val[1], val[2]) }
  | UNLESS Expression THEN Expression END   { result = UnlessNode.new( val[1], Nodes.new([val[3]]) ) }
  ;

  Ternary:
    Expression '?' Expression ':' Expression   { result = TernaryOperatorNode.new([val[0], val[2], val[4]]) }
  ;

  While:
    WHILE Expression Block END                 { result = WhileNode.new(val[1], val[2]) }
  ;

  Until:
    UNTIL Expression Block END                 { result = UntilNode.new(val[1], val[2]) }
  ;

  For:
    FOR IDENTIFIER IN Call Block END           { result = ForNodeCall.new(val[1], val[3], val[4]) }
  | FOR IDENTIFIER IN List Block END           { result = ForNodeList.new(val[1], val[3], val[4]) }
  ;

  # [expressions]
  # expressions list could contain an ElseNode, which contains expressions
  # itself
  Block:
    NEWLINE Expressions ELSE NEWLINE Expressions { result = val[1] << ElseNode.new(val[4]) }
  | NEWLINE Expressions                          { result = val[1] }
  | NEWLINE                                      { result = Nodes.new([]) }
  ;
end

---- header
  require File.expand_path("../lexer", __FILE__)
  require File.expand_path("../nodes", __FILE__)
  require 'pp'

---- inner
  # This code will be put as-is in the parser class

  # parses tokens or code into output nodes
  def parse(object)
    @tokens = if tokens?(object)
      object
    elsif code?(object)
      Riml::Lexer.new.tokenize(object)
    end
    pp(@tokens) unless ENV["RIML_DEBUG"].nil?
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
