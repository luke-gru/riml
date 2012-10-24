class Riml::Parser

token IF ELSE THEN UNLESS END # TODO: add elseif
token WHILE UNTIL BREAK CONTINUE
token TRY CATCH ENSURE
token FOR IN
token DEF SPLAT CALL BUILTIN_COMMAND # such as echo "hi"
token CLASS NEW DEFM SUPER
token RETURN
token NEWLINE
token NUMBER
token STRING_D STRING_S # single- and double-quoted
token HEREDOC EX_LITERAL
token REGEXP
token TRUE FALSE NIL
token LET UNLET IDENTIFIER
token DICT_VAL # like dict.key, 'key' is a DICT_VAL
token SCOPE_MODIFIER SCOPE_MODIFIER_LITERAL SPECIAL_VAR_PREFIX
token FINISH

prechigh
  right '!'
  left '*' '/' '%'
  left '+' '+=' '-' '-=' '.'
  left '>' '>#' '>?' '<' '<#' '<?' '>=' '>=#' '>=?'  '<=' '<=#' '<=?'
  left '==' '==?' '==#' '=~' '=~?' '=~#' '!~' '!~?' '!~#' '!=' '!=?' '!=#'
  left 'is' 'isnot'
  left '&&'
  left '||'
  right '?'
  right '='
  left ','
  left IF UNLESS
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
  | Return                                { result = val[0] }
  | VariableRetrieval                     { result = val[0] }
  | UnletVariable                         { result = val[0] }
  | Literal                               { result = val[0] }
  | ExLiteral                             { result = val[0] }
  | Heredoc                               { result = val[0] }
  | If                                    { result = val[0] }
  | Unless                                { result = val[0] }
  | Ternary                               { result = val[0] }
  | While                                 { result = val[0] }
  | Until                                 { result = val[0] }
  | For                                   { result = val[0] }
  | Try                                   { result = val[0] }
  | ClassDefinition                       { result = val[0] }
  | ObjectInstantiation                   { result = val[0] }
  | Super                                 { result = val[0] }
  | '(' Expression ')'                    { result = val[1] }
  | EndScript                             { result = val[0] }
  | LoopConstruct                         { result = val[0] }
  ;

  Terminator:
    NEWLINE                               { result = NewlineNode.new }
  | ';'                                   { result = nil }
  | '|'                                   { result = nil }
  ;

  # All hard-coded values
  Literal:
    Number                                { result = val[0] }
  | String                                { result = val[0] }
  | Regexp                                { result = val[0] }
  | List                                  { result = val[0] }
  | Dictionary                            { result = val[0] }
  | ScopeModifierLiteral                  { result = val[0] }
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

  Heredoc:
    HEREDOC String                        { result = HeredocNode.new(val[0], val[1]) }
  ;

  Regexp:
    REGEXP                                { result = RegexpNode.new(val[0]) }
  ;

  ScopeModifierLiteral:
    SCOPE_MODIFIER_LITERAL                { result = ScopeModifierLiteralNode.new(val[0]) }
  ;

  List:
    ListLiteral                           { result = ListNode.new(val[0]) }
  ;

  ListLiteral:
    '[' ListItems ']'                     { result = val[1] }
  | '[' ListItems ',' ']'                 { result = val[1] }
  ;

  ListItems:
    /* nothing */                         { result = [] }
  | Literal                               { result = val }
  | VariableRetrieval                     { result = val }
  | ListItems ',' Literal                 { result = val[0] << val[2] }
  | ListItems ',' VariableRetrieval       { result = val[0] << val[2] }
  ;

  Dictionary
    DictionaryLiteral                     { result = DictionaryNode.new(val[0]) }
  ;

  # {'key': 'value', 'key': 'value'}
  DictionaryLiteral:
    '{' DictItems '}'                     { result = Hash[val[1]] }
  | '{' DictItems ',' '}'                 { result = Hash[val[1]] }
  ;

  # [[key, value], [key, value]]
  DictItems:
    /* nothing */                         { result = [] }
  | DictItem                              { result = val }
  | DictItems ',' DictItem                { result = val[0] << val[2] }
  ;

  # [key, value]
  DictItem:
    Literal ':' Literal                   { result = [val[0], val[2]] }
  ;

  DictGet:
    Dictionary DictGetWithBrackets               { result = DictGetBracketNode.new(val[0], val[1]) }
  | Dictionary DictGetWithDotLiteral             { result = DictGetDotNode.new(val[0], val[1]) }
  | VariableRetrieval DictGetWithDot             { result = DictGetDotNode.new(val[0], val[1]) }
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

  DictGetWithDot:
    DICT_VAL                        { result = [val[0]]}
  | DictGetWithDot DICT_VAL         { result = val[0] << val[1] }
  ;

  DictGetWithDotLiteral:
    '.' IDENTIFIER                  { result = [val[1]] }
  | DictGetWithDotLiteral DICT_VAL  { result = val[0] << val[1] }
  ;

  DictSet:
    VariableRetrieval DictGetWithDot '=' Expression     { result = DictSetNode.new(val[0], val[1], val[3]) }
  | LET VariableRetrieval DictGetWithDot '=' Expression { result = DictSetNode.new(val[1], val[2], val[4]) }
  ;

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
    Scope DefCallIdentifier '(' ArgList ')'       { result = CallNode.new(val[0], val[1], val[3]) }
  | DictGet '(' ArgList ')'                       { result = CallNode.new(nil, val[0], val[2]) }
  | CALL Scope DefCallIdentifier '(' ArgList ')'  { result = ExplicitCallNode.new(val[1], val[2], val[4]) }
  | CALL DictGet '(' ArgList ')'                  { result = ExplicitCallNode.new(nil, val[1], val[3]) }
  | BUILTIN_COMMAND '(' ArgList ')'               { result = CallNode.new(nil, val[0], val[2]) }
  | BUILTIN_COMMAND ArgList                       { result = CallNode.new(nil, val[0], val[1]) }
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

  # added by riml
  | Expression '===' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }

  | Expression '!=' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '!=#' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '!=?' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }

  | Expression '=~' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '=~#' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '=~?' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }

  | Expression '!~' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '!~#' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '!~?' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }

  | Expression '>' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '>#' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '>?' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }

  | Expression '>=' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '>=#' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '>=?' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }

  | Expression '<' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '<#' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '<?' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }

  | Expression '<=' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '<=#' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '<=?' Expression           { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }

  | Expression '+' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '+=' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '-' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '-=' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '*' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '/' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '.' Expression             { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | Expression '.=' Expression            { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }

  | List 'is'    List                     { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
  | List 'isnot' List                     { result = BinaryOperatorNode.new(val[1], [val[0]] << val[2]) }
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
  | Scope CurlyBraceName                        { result = GetCurlyBraceNameNode.new(val[0], val[1])}
  ;

  UnletVariable:
    UNLET VariableRetrieval                               { result = UnletVariableNode.new([ val[1] ]) }
  | UnletVariable VariableRetrieval                       { result = val[0] << val[1] }
  ;

  CurlyBraceName:
    IDENTIFIER '{' VariableRetrieval '}'               { result = CurlyBraceVariable.new([ CurlyBracePart.new(val[0]), CurlyBracePart.new(val[2]) ]) }
  | '{' VariableRetrieval '}' IDENTIFIER               { result = CurlyBraceVariable.new([ CurlyBracePart.new(val[1]), CurlyBracePart.new(val[3]) ]) }
  | CurlyBraceName IDENTIFIER                          { result = val[0] << CurlyBracePart.new(val[1]) }
  ;

  # Method definition
  # [scope_modifier, name, parameters, keyword, expressions]
  Def:
    FunctionType Scope DefCallIdentifier Keyword Block END                               { result = Object.const_get(val[0]).new(val[1], val[2], [], val[3], val[4]) }
  | FunctionType Scope DefCallIdentifier '(' ParamList ')' Keyword Block END             { result = Object.const_get(val[0]).new(val[1], val[2], val[4], val[6], val[7]) }
  | FunctionType Scope DefCallIdentifier '(' ParamList ',' SPLAT ')' Keyword Block END   { result = Object.const_get(val[0]).new(val[1], val[2], val[4] << val[6], val[8], val[9]) }
  ;

  FunctionType:
    DEF  { result = "DefNode" }
  | DEFM { result = "DefMethodNode" }

  DefCallIdentifier:
    # use '' for first argument instead of nil in order to avoid a double scope-modifier
    CurlyBraceName          { result = GetCurlyBraceNameNode.new('', val[0])}
  | IDENTIFIER              { result = val[0] }
  ;

  # Example: 'range' or 'dict' after function definition
  Keyword:
    IDENTIFIER            { result = val[0] }
  | /* nothing */         { result = nil }
  ;

  ParamList:
    /* nothing */                         { result = [] }
  | IDENTIFIER                            { result = val }
  | ParamList ',' IDENTIFIER              { result = val[0] << val[2] }
  ;

  Return:
    RETURN Expression       { result = ReturnNode.new(val[1]) }
  ;

  EndScript:
    FINISH                                { result = FinishNode.new }
  ;

  # [expression, expressions]
  If:
    IF Expression IfBlock END               { result = IfNode.new(val[1], val[2]) }
  | IF Expression THEN Expression END       { result = IfNode.new(val[1], Nodes.new([val[3]])) }
  | Expression IF Expression                { result = IfNode.new(val[2], Nodes.new([val[0]])) }
  ;

  Unless:
    UNLESS Expression IfBlock END           { result = UnlessNode.new(val[1], val[2]) }
  | UNLESS Expression THEN Expression END   { result = UnlessNode.new(val[1], Nodes.new([val[3]])) }
  | Expression UNLESS Expression            { result = UnlessNode.new(val[2], Nodes.new([val[0]])) }
  ;

  Ternary:
    Expression '?' Expression ':' Expression   { result = TernaryOperatorNode.new([val[0], val[2], val[4]]) }
  ;

  While:
    WHILE Expression Block END                 { result = WhileNode.new(val[1], val[2]) }
  ;

  LoopConstruct:
    BREAK                                      { result = BreakNode.new }
  | CONTINUE                                   { result = ContinueNode.new }
  ;

  Until:
    UNTIL Expression Block END                 { result = UntilNode.new(val[1], val[2]) }
  ;

  For:
    FOR IDENTIFIER IN Call Block END           { result = ForNodeCall.new(val[1], val[3], val[4]) }
  | FOR IDENTIFIER IN List Block END           { result = ForNodeList.new(val[1], val[3], val[4]) }
  ;

  Try:
    TRY Block END                              { result = TryNode.new(val[1], nil, nil) }
  | TRY Block Catch END                        { result = TryNode.new(val[1], val[2], nil) }
  | TRY Block Catch ENSURE Block END           { result = TryNode.new(val[1], val[2], val[4]) }
  ;

  Catch:
    /* nothing */                              { result = nil }
  | CATCH Block                                { result = [ CatchNode.new(nil, val[1]) ] }
  | CATCH Regexp Block                         { result = [ CatchNode.new(val[1], val[2]) ] }
  | Catch CATCH Block                          { result = val[0] << CatchNode.new(nil, val[2]) }
  | Catch CATCH Regexp Block                   { result = val[0] << CatchNode.new(val[2], val[3]) }
  ;

  # [expressions]
  # expressions list could contain an ElseNode, which contains expressions
  # itself
  Block:
    NEWLINE Expressions                          { result = val[1] }
  | NEWLINE                                      { result = Nodes.new([]) }
  ;

  IfBlock:
    Block                                        { result = val[0] }
  | NEWLINE Expressions ELSE NEWLINE Expressions { result = val[1] << ElseNode.new(val[4]) }
  ;

  ClassDefinition:
    CLASS IDENTIFIER Block END                   { result = ClassDefinitionNode.new(val[1], nil, val[2]) }
  | CLASS IDENTIFIER '<' IDENTIFIER Block END    { result = ClassDefinitionNode.new(val[1], val[3], val[4]) }
  ;

  ObjectInstantiation:
    NEW Call                  { result = ObjectInstantiationNode.new(val[1]) }
  ;

  Super:
    SUPER '(' ArgList ')'     { result = SuperNode.new(val[2], true) }
  | SUPER                     { result = SuperNode.new([], false) }
  ;

  ExLiteral:
    EX_LITERAL                { result = ExLiteralNode.new(val[0])}
  ;
end

---- header
  require File.expand_path("../lexer", __FILE__)
  require File.expand_path("../nodes", __FILE__)
  require File.expand_path("../ast_rewriter", __FILE__)
---- inner
  # This code will be put as-is in the parser class

  # parses tokens or code into output nodes
  def parse(object, rewrite_ast = true)
    @tokens = if tokens?(object)
      object
    elsif code?(object)
      Riml::Lexer.new.tokenize(object)
    end
    ast = do_parse
    return ast if rewrite_ast == false
    AST_Rewriter.new(ast).rewrite
  end

  def next_token
    @tokens.shift
  end

  private
  def tokens?(object)
    Array === object
  end

  def code?(object)
    String === object
  end
