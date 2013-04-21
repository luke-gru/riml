class Riml::Parser

token IF ELSE ELSEIF THEN UNLESS END
token WHILE UNTIL BREAK CONTINUE
token TRY CATCH FINALLY
token FOR IN
token DEF DEF_BANG SPLAT CALL BUILTIN_COMMAND # such as echo "hi"
token CLASS NEW DEFM DEFM_BANG SUPER RIML_COMMAND
token RETURN
token NEWLINE
token NUMBER
token STRING_D STRING_S # single- and double-quoted
token EX_LITERAL
token REGEXP
token TRUE FALSE NIL
token LET UNLET UNLET_BANG IDENTIFIER
token DICT_VAL # like dict.key, 'key' is a DICT_VAL
token SCOPE_MODIFIER SCOPE_MODIFIER_LITERAL SPECIAL_VAR_PREFIX
token FINISH

prechigh
  right '!'
  left '*' '/' '%'
  left '+' '-' '.'
  left '>' '>#' '>?' '<' '<#' '<?' '>=' '>=#' '>=?'  '<=' '<=#' '<=?'
  left '==' '==?' '==#' '=~' '=~?' '=~#' '!~' '!~?' '!~#' '!=' '!=?' '!=#'
  left IS ISNOT
  left '&&'
  left '||'
  right '?'
  right '=' '+=' '-=' '.='
  left ','
  left IF UNLESS
preclow

# All rules
rule

  Root:
    /* nothing */                         { result = Riml::Nodes.new([]) }
  | Expressions                           { result = val[0] }
  ;

  # any list of expressions
  Expressions:
    AnyExpression                         { result = Riml::Nodes.new([ val[0] ]) }
  | Expressions Terminator AnyExpression  { result = val[0] << val[2] }
  | Expressions Terminator                { result = val[0] }
  | Terminator                            { result = Riml::Nodes.new([]) }
  | Terminator Expressions                { result = Riml::Nodes.new(val[1]) }
  ;

  # All types of expressions in Riml
  AnyExpression:
    ExplicitCall                          { result = val[0] }
  | Def                                   { result = val[0] }
  | Return                                { result = val[0] }
  | UnletVariable                         { result = val[0] }
  | ExLiteral                             { result = val[0] }
  | If                                    { result = val[0] }
  | Unless                                { result = val[0] }
  | For                                   { result = val[0] }
  | While                                 { result = val[0] }
  | Until                                 { result = val[0] }
  | Try                                   { result = val[0] }
  | ClassDefinition                       { result = val[0] }
  | Super                                 { result = val[0] }
  | LoopKeyword                           { result = val[0] }
  | EndScript                             { result = val[0] }
  | ValueExpression                       { result = val[0] }
  | RimlCommand                           { result = val[0] }
  ;

  # Expressions that evaluate to a value
  ValueExpression:
    ValueExpressionWithoutDictLiteral     { result = val[0] }
  | Dictionary                            { result = val[0] }
  | Dictionary DictGetWithDotLiteral      { result = Riml::DictGetDotNode.new(val[0], val[1]) }
  | BinaryOperator                        { result = val[0] }
  | Ternary                               { result = val[0] }
  | '(' ValueExpression ')'               { result = Riml::WrapInParensNode.new(val[1]) }
  ;

  ValueExpressionWithoutDictLiteral:
    UnaryOperator                         { result = val[0] }
  | Assign                                { result = val[0] }
  | DictGet                               { result = val[0] }
  | ListOrDictGet                         { result = val[0] }
  | AllVariableRetrieval                  { result = val[0] }
  | LiteralWithoutDictLiteral             { result = val[0] }
  | Call                                  { result = val[0] }
  | ObjectInstantiation                   { result = val[0] }
  | '(' ValueExpressionWithoutDictLiteral ')'               { result = Riml::WrapInParensNode.new(val[1]) }
  ;

  # for inside curly-brace variable names
  PossibleStringValue:
    String                                { result = val[0] }
  | DictGet                               { result = val[0] }
  | ListOrDictGet                         { result = val[0] }
  | AllVariableRetrieval                  { result = val[0] }
  | BinaryOperator                        { result = val[0] }
  | Ternary                               { result = val[0] }
  | Call                                  { result = val[0] }
  ;

  Terminator:
    NEWLINE                               { result = nil }
  | ';'                                   { result = nil }
  ;

  LiteralWithoutDictLiteral:
    Number                                { result = val[0] }
  | String                                { result = val[0] }
  | Regexp                                { result = val[0] }
  | List                                  { result = val[0] }
  | ScopeModifierLiteral                  { result = val[0] }
  | TRUE                                  { result = Riml::TrueNode.new }
  | FALSE                                 { result = Riml::FalseNode.new }
  | NIL                                   { result = Riml::NilNode.new }
  ;

  Number:
    NUMBER                                { result = Riml::NumberNode.new(val[0]) }
  ;

  String:
    STRING_S                              { result = Riml::StringNode.new(val[0], :s) }
  | STRING_D                              { result = Riml::StringNode.new(val[0], :d) }
  | String STRING_S                       { result = Riml::StringLiteralConcatNode.new(val[0], Riml::StringNode.new(val[1], :s)) }
  | String STRING_D                       { result = Riml::StringLiteralConcatNode.new(val[0], Riml::StringNode.new(val[1], :d)) }
  ;

  Regexp:
    REGEXP                                { result = Riml::RegexpNode.new(val[0]) }
  ;

  ScopeModifierLiteral:
    SCOPE_MODIFIER_LITERAL                { result = Riml::ScopeModifierLiteralNode.new(val[0]) }
  ;

  List:
    ListLiteral                           { result = Riml::ListNode.new(val[0]) }
  ;

  ListUnpack:
    '[' ListItems ';' ValueExpression ']' { result = Riml::ListUnpackNode.new(val[1] << val[3]) }
  ;

  ListLiteral:
    '[' ListItems ']'                     { result = val[1] }
  | '[' ListItems ',' ']'                 { result = val[1] }
  ;

  ListItems:
    /* nothing */                         { result = [] }
  | ValueExpression                       { result = [val[0]] }
  | ListItems ',' ValueExpression         { result = val[0] << val[2] }
  ;

  Dictionary:
    DictionaryLiteral                     { result = Riml::DictionaryNode.new(val[0]) }
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
    ValueExpression ':' ValueExpression                   { result = [val[0], val[2]] }
  ;

  DictGet:
    AllVariableRetrieval DictGetWithDot          { result = Riml::DictGetDotNode.new(val[0], val[1]) }
  | ListOrDictGet DictGetWithDot                 { result = Riml::DictGetDotNode.new(val[0], val[1]) }
  | Call DictGetWithDot                          { result = Riml::DictGetDotNode.new(val[0], val[1]) }
  | '(' ValueExpression ')' DictGetWithDot       { result = Riml::DictGetDotNode.new(Riml::WrapInParensNode.new(val[1]), val[3]) }
  ;

  ListOrDictGet:
    ValueExpressionWithoutDictLiteral ListOrDictGetWithBrackets  { result = Riml::ListOrDictGetNode.new(val[0], val[1]) }
  | '(' ValueExpression ')' ListOrDictGetWithBrackets            { result = Riml::ListOrDictGetNode.new(Riml::WrapInParensNode.new(val[1]), val[3]) }
  ;

  ListOrDictGetWithBrackets:
    '['  ValueExpression ']'                          { result = [val[1]] }
  | '['  SubList    ']'                               { result = [val[1]] }
  | ListOrDictGetWithBrackets '[' ValueExpression ']' { result = val[0] << val[2] }
  | ListOrDictGetWithBrackets '[' SubList    ']'      { result = val[0] << val[2] }
  ;

  SubList:
    ValueExpression ':' ValueExpression          { result = Riml::SublistNode.new([val[0], Riml::LiteralNode.new(' : '), val[2]]) }
  | ValueExpression ':'                          { result = Riml::SublistNode.new([val[0], Riml::LiteralNode.new(' :')]) }
  | ':' ValueExpression                          { result = Riml::SublistNode.new([Riml::LiteralNode.new(': '), val[1]]) }
  | ':'                                          { result = Riml::SublistNode.new([Riml::LiteralNode.new(':')]) }
  ;

  DictGetWithDot:
    DICT_VAL                        { result = [val[0]]}
  | DictGetWithDot DICT_VAL         { result = val[0] << val[1] }
  ;

  DictGetWithDotLiteral:
    '.' IDENTIFIER                  { result = [val[1]] }
  | DictGetWithDotLiteral DICT_VAL  { result = val[0] << val[1] }
  ;

  Call:
    Scope DefCallIdentifier '(' ArgList ')'       { result = Riml::CallNode.new(val[0], val[1], val[3]) }
  | DictGet '(' ArgList ')'                       { result = Riml::CallNode.new(nil, val[0], val[2]) }
  | BUILTIN_COMMAND '(' ArgList ')'               { result = Riml::CallNode.new(nil, val[0], val[2]) }
  | BUILTIN_COMMAND ArgList                       { result = Riml::CallNode.new(nil, val[0], val[1]) }
  | CALL '(' ArgList ')'                          { result = Riml::ExplicitCallNode.new(nil, nil, val[2]) }
  ;

  RimlCommand:
    RIML_COMMAND '(' ArgList ')'                  { result = Riml::RimlCommandNode.new(nil, val[0], val[2]) }
  | RIML_COMMAND ArgList                          { result = Riml::RimlCommandNode.new(nil, val[0], val[1]) }
  ;

  ExplicitCall:
    CALL Scope DefCallIdentifier '(' ArgList ')'  { result = Riml::ExplicitCallNode.new(val[1], val[2], val[4]) }
  | CALL DictGet '(' ArgList ')'                  { result = Riml::ExplicitCallNode.new(nil, val[1], val[3]) }
  ;

  Scope:
    SCOPE_MODIFIER         { result = val[0] }
  | /* nothing */          { result = nil }
  ;

  ArgList:
    /* nothing */                         { result = [] }
  | ValueExpression                       { result = val }
  | ArgList "," ValueExpression           { result = val[0] << val[2] }
  ;

  BinaryOperator:
    ValueExpression '||' ValueExpression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '&&' ValueExpression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | ValueExpression '==' ValueExpression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '==#' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '==?' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  # added by riml
  | ValueExpression '===' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | ValueExpression '!=' ValueExpression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '!=#' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '!=?' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | ValueExpression '=~' ValueExpression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '=~#' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '=~?' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | ValueExpression '!~' ValueExpression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '!~#' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '!~?' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | ValueExpression '>' ValueExpression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '>#' ValueExpression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '>?' ValueExpression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | ValueExpression '>=' ValueExpression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '>=#' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '>=?' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | ValueExpression '<' ValueExpression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '<#' ValueExpression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '<?' ValueExpression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | ValueExpression '<=' ValueExpression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '<=#' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '<=?' ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | ValueExpression '+' ValueExpression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '-' ValueExpression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '*' ValueExpression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '/' ValueExpression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '.' ValueExpression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression '%' ValueExpression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | ValueExpression IS    ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | ValueExpression ISNOT ValueExpression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  ;

  UnaryOperator:
    '!' ValueExpression                        { result = Riml::UnaryOperatorNode.new(val[0], val[1]) }
  | '+' ValueExpression                        { result = Riml::UnaryOperatorNode.new(val[0], val[1]) }
  | '-' ValueExpression                        { result = Riml::UnaryOperatorNode.new(val[0], val[1]) }
  ;

  # ['=', LHS, RHS]
  Assign:
    LET AssignExpression                       { result = Riml::AssignNode.new(val[1][0], val[1][1], val[1][2]) }
  | AssignExpression                           { result = Riml::AssignNode.new(val[0][0], val[0][1], val[0][2]) }
  ;

  # ['=', AssignLHS, Expression]
  AssignExpression:
    AssignLHS '='  ValueExpression             { result = [val[1], val[0], val[2]] }
  | AssignLHS '+=' ValueExpression             { result = [val[1], val[0], val[2]] }
  | AssignLHS '-=' ValueExpression             { result = [val[1], val[0], val[2]] }
  | AssignLHS '.=' ValueExpression             { result = [val[1], val[0], val[2]] }
  ;

  AssignLHS:
    AllVariableRetrieval                       { result = val[0] }
  | List                                       { result = val[0] }
  | ListUnpack                                 { result = val[0] }
  | DictGet                                    { result = val[0] }
  | ListOrDictGet                              { result = val[0] }
  ;

  # retrieving the value of a variable
  VariableRetrieval:
    Scope IDENTIFIER                           { result = Riml::GetVariableNode.new(val[0], val[1]) }
  | SPECIAL_VAR_PREFIX IDENTIFIER              { result = Riml::GetSpecialVariableNode.new(val[0], val[1]) }
  | ScopeModifierLiteral ListOrDictGetWithBrackets { result = Riml::GetVariableByScopeAndDictNameNode.new(val[0], val[1]) }
  ;

  AllVariableRetrieval:
    VariableRetrieval                          { result = val[0] }
  | Scope CurlyBraceName                       { result = Riml::GetCurlyBraceNameNode.new(val[0], val[1]) }
  ;

  UnletVariable:
    UNLET VariableRetrieval                    { result = Riml::UnletVariableNode.new('!', [ val[1] ]) }
  | UNLET_BANG VariableRetrieval               { result = Riml::UnletVariableNode.new('!', [ val[1] ]) }
  | UnletVariable VariableRetrieval            { result = val[0] << val[1] }
  ;

  CurlyBraceName:
    CurlyBraceVarPart                          { result = Riml::CurlyBraceVariable.new([ val[0] ]) }
  | IDENTIFIER CurlyBraceName                  { result = Riml::CurlyBraceVariable.new([ Riml::CurlyBracePart.new(val[0]), val[1] ]) }
  | CurlyBraceName IDENTIFIER                  { result = val[0] << Riml::CurlyBracePart.new(val[1]) }
  | CurlyBraceName CurlyBraceVarPart           { result = val[0] << val[1] }
  ;

  CurlyBraceVarPart:
    '{' PossibleStringValue '}'                     { result = Riml::CurlyBracePart.new(val[1]) }
  | '{' PossibleStringValue CurlyBraceVarPart '}'   { result = Riml::CurlyBracePart.new([val[1], val[2]]) }
  | '{' CurlyBraceVarPart PossibleStringValue '}'   { result = Riml::CurlyBracePart.new([val[1], val[2]]) }
  ;

  # Method definition
  # [scope_modifier, name, parameters, keyword, expressions]
  Def:
    FunctionType Scope DefCallIdentifier DefKeywords Block END                               { result = Riml.const_get(val[0]).new('!', val[1], val[2], [], val[3], val[4]) }
  | FunctionType Scope DefCallIdentifier '(' ParamList ')' DefKeywords Block END             { result = Riml.const_get(val[0]).new('!', val[1], val[2], val[4], val[6], val[7]) }
  | FunctionType Scope DefCallIdentifier '(' SPLAT     ')' DefKeywords Block END             { result = Riml.const_get(val[0]).new('!', val[1], val[2], [val[4]], val[6], val[7]) }
  | FunctionType Scope DefCallIdentifier '(' ParamList ',' SPLAT ')' DefKeywords Block END   { result = Riml.const_get(val[0]).new('!', val[1], val[2], val[4] << val[6], val[8], val[9]) }
  ;

  FunctionType:
    DEF           { result = "DefNode" }
  | DEF_BANG      { result = "DefNode" }
  | DEFM          { result = "DefMethodNode" }
  ;

  DefCallIdentifier:
    # use '' for first argument instead of nil in order to avoid a double scope-modifier
    CurlyBraceName          { result = Riml::GetCurlyBraceNameNode.new('', val[0]) }
  | IDENTIFIER              { result = val[0] }
  ;

  # Example: 'range', 'dict' or 'abort' after function definition
  DefKeywords:
    IDENTIFIER             { result = [val[0]] }
  | DefKeywords IDENTIFIER { result = val[0] << val[1] }
  | /* nothing */          { result = nil }
  ;

  ParamList:
    /* nothing */                         { result = [] }
  | IDENTIFIER                            { result = val }
  | DefaultParam                          { result = val }
  | ParamList ',' IDENTIFIER              { result = val[0] << val[2] }
  | ParamList ',' DefaultParam            { result = val[0] << val[2] }
  ;

  DefaultParam:
    IDENTIFIER '=' ValueExpression        { result = Riml::DefaultParamNode.new(val[0], val[2]) }
  ;

  Return:
    RETURN ValueExpression                { result = Riml::ReturnNode.new(val[1]) }
  | RETURN                                { result = Riml::ReturnNode.new(nil) }
  ;

  EndScript:
    FINISH                                { result = Riml::FinishNode.new }
  ;

  # [expression, expressions]
  If:
    IF ValueExpression IfBlock END                    { result = Riml::IfNode.new(val[1], val[2]) }
  | IF ValueExpression THEN ValueExpression END       { result = Riml::IfNode.new(val[1], Riml::Nodes.new([val[3]])) }
  | AnyExpression IF ValueExpression                  { result = Riml::IfNode.new(val[2], Riml::Nodes.new([val[0]])) }
  ;

  Unless:
    UNLESS ValueExpression IfBlock END                { result = Riml::UnlessNode.new(val[1], val[2]) }
  | UNLESS ValueExpression THEN ValueExpression END   { result = Riml::UnlessNode.new(val[1], Riml::Nodes.new([val[3]])) }
  | ValueExpression UNLESS ValueExpression            { result = Riml::UnlessNode.new(val[2], Riml::Nodes.new([val[0]])) }
  ;

  Ternary:
    ValueExpression '?' ValueExpression ':' ValueExpression   { result = Riml::TernaryOperatorNode.new([val[0], val[2], val[4]]) }
  ;

  While:
    WHILE ValueExpression Block END                 { result = Riml::WhileNode.new(val[1], val[2]) }
  ;

  LoopKeyword:
    BREAK                                      { result = Riml::BreakNode.new }
  | CONTINUE                                   { result = Riml::ContinueNode.new }
  ;

  Until:
    UNTIL ValueExpression Block END                 { result = Riml::UntilNode.new(val[1], val[2]) }
  ;

  For:
    FOR IDENTIFIER IN ValueExpression Block END     { result = Riml::ForNode.new(val[1], val[3], val[4]) }
  | FOR List IN ValueExpression Block END           { result = Riml::ForNode.new(val[1], val[3], val[4]) }
  | FOR ListUnpack IN ValueExpression Block END     { result = Riml::ForNode.new(val[1], val[3], val[4]) }
  ;

  Try:
    TRY Block END                              { result = Riml::TryNode.new(val[1], nil, nil) }
  | TRY Block Catch END                        { result = Riml::TryNode.new(val[1], val[2], nil) }
  | TRY Block Catch FINALLY Block END          { result = Riml::TryNode.new(val[1], val[2], val[4]) }
  ;

  Catch:
    /* nothing */                              { result = nil }
  | CATCH Block                                { result = [ Riml::CatchNode.new(nil, val[1]) ] }
  | CATCH Regexp Block                         { result = [ Riml::CatchNode.new(val[1], val[2]) ] }
  | Catch CATCH Block                          { result = val[0] << Riml::CatchNode.new(nil, val[2]) }
  | Catch CATCH Regexp Block                   { result = val[0] << Riml::CatchNode.new(val[2], val[3]) }
  ;

  # [expressions]
  # expressions list could contain an ElseNode, which contains expressions
  # itself
  Block:
    NEWLINE Expressions                        { result = val[1] }
  | NEWLINE                                    { result = Riml::Nodes.new([]) }
  ;

  IfBlock:
    Block                                      { result = val[0] }
  | NEWLINE Expressions ElseBlock              { result = val[1] << val[2] }
  | NEWLINE Expressions ElseifBlock            { result = val[1] << val[2] }
  | NEWLINE Expressions ElseifBlock ElseBlock  { result = val[1] << val[2] << val[3] }
  ;

  ElseBlock:
    ELSE NEWLINE Expressions                   { result = Riml::ElseNode.new(val[2]) }
  ;

  ElseifBlock:
    ELSEIF ValueExpression NEWLINE Expressions                   { result = Riml::Nodes.new([Riml::ElseifNode.new(val[1], val[3])]) }
  | ElseifBlock ELSEIF ValueExpression NEWLINE Expressions       { result = val[0] << Riml::ElseifNode.new(val[2], val[4]) }
  ;

  ClassDefinition:
    CLASS IDENTIFIER Block END                   { result = Riml::ClassDefinitionNode.new(val[1], nil, val[2]) }
  | CLASS IDENTIFIER '<' IDENTIFIER Block END    { result = Riml::ClassDefinitionNode.new(val[1], val[3], val[4]) }
  ;

  ObjectInstantiation:
    NEW Call                  { result = Riml::ObjectInstantiationNode.new(val[1]) }
  ;

  Super:
    SUPER '(' ArgList ')'     { result = Riml::SuperNode.new(val[2], true) }
  | SUPER                     { result = Riml::SuperNode.new([], false) }
  ;

  ExLiteral:
    EX_LITERAL                { result = Riml::ExLiteralNode.new(val[0])}
  ;
end

---- header
  require File.expand_path("../lexer", __FILE__)
  require File.expand_path("../nodes", __FILE__)
  require File.expand_path("../ast_rewriter", __FILE__)
  require File.expand_path("../errors", __FILE__)
---- inner
  # This code will be put as-is in the parser class

  attr_accessor :ast_rewriter

  # parses tokens or code into output nodes
  def parse(object, ast_rewriter = Riml::AST_Rewriter.new, include_file = nil)
    if tokens?(object)
      @tokens = object
    elsif code?(object)
      @lexer = Riml::Lexer.new(object)
    end

    begin
      ast = do_parse
    rescue Racc::ParseError => e
      raise unless @lexer
      raise Riml::ParseError,  "on line #{@lexer.lineno}: #{e.message}"
    end

    @ast_rewriter ||= ast_rewriter
    return ast unless @ast_rewriter
    @ast_rewriter.ast = ast
    @ast_rewriter.rewrite(include_file)
  end

  # get the next token from either the list of tokens provided, or
  # the lexer getting the next token
  def next_token
    return @tokens.shift unless @lexer
    @lexer.next_token
  end

  private
  def tokens?(object)
    Array === object
  end

  def code?(object)
    String === object
  end
