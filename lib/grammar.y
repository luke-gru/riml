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
token TRUE FALSE
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
    /* nothing */                        { result = Riml::Nodes.new([]) }
  | Statements                           { result = val[0] }
  ;

  # any list of expressions
  Statements:
    Statement                            { result = Riml::Nodes.new([ val[0] ]) }
  | Statements Terminator Statement      { result = val[0] << val[2] }
  | Statements Terminator                { result = val[0] }
  | Terminator                           { result = Riml::Nodes.new([]) }
  | Terminator Statements                { result = Riml::Nodes.new(val[1]) }
  ;

  # All types of expressions in Riml
  Statement:
    ExplicitCall                          { result = val[0] }
  | Def                                   { result = val[0] }
  | Return                                { result = val[0] }
  | UnletVariable                         { result = val[0] }
  | ExLiteral                             { result = val[0] }
  | For                                   { result = val[0] }
  | While                                 { result = val[0] }
  | Until                                 { result = val[0] }
  | Try                                   { result = val[0] }
  | ClassDefinition                       { result = val[0] }
  | LoopKeyword                           { result = val[0] }
  | EndScript                             { result = val[0] }
  | RimlCommand                           { result = val[0] }
  | MultiAssign                           { result = val[0] }
  | If                                    { result = val[0] }
  | Unless                                { result = val[0] }
  | Expression                            { result = val[0] }
  ;

  Expression:
    ExpressionWithoutDictLiteral          { result = val[0] }
  | Dictionary                            { result = val[0] }
  | Dictionary DictGetWithDotLiteral      { result = Riml::DictGetDotNode.new(val[0], val[1]) }
  | BinaryOperator                        { result = val[0] }
  | Ternary                               { result = val[0] }
  | Assign                                { result = val[0] }
  | Super                                 { result = val[0] }
  | '(' Expression ')'                    { result = Riml::WrapInParensNode.new(val[1]) }
  ;

  ExpressionWithoutDictLiteral:
    UnaryOperator                         { result = val[0] }
  | DictGet                               { result = val[0] }
  | ListOrDictGet                         { result = val[0] }
  | AllVariableRetrieval                  { result = val[0] }
  | LiteralWithoutDictLiteral             { result = val[0] }
  | Call                                  { result = val[0] }
  | ObjectInstantiation                   { result = val[0] }
  | '(' ExpressionWithoutDictLiteral ')'               { result = Riml::WrapInParensNode.new(val[1]) }
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
    '[' ListItems ';' Expression ']' { result = Riml::ListUnpackNode.new(val[1] << val[3]) }
  ;

  ListLiteral:
    '[' ListItems ']'                     { result = val[1] }
  | '[' ListItems ',' ']'                 { result = val[1] }
  ;

  ListItems:
    /* nothing */                         { result = [] }
  | Expression                       { result = [val[0]] }
  | ListItems ',' Expression         { result = val[0] << val[2] }
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
    Expression ':' Expression                   { result = [val[0], val[2]] }
  ;

  DictGet:
    AllVariableRetrieval DictGetWithDot          { result = Riml::DictGetDotNode.new(val[0], val[1]) }
  | ListOrDictGet DictGetWithDot                 { result = Riml::DictGetDotNode.new(val[0], val[1]) }
  | Call DictGetWithDot                          { result = Riml::DictGetDotNode.new(val[0], val[1]) }
  | '(' Expression ')' DictGetWithDot       { result = Riml::DictGetDotNode.new(Riml::WrapInParensNode.new(val[1]), val[3]) }
  ;

  ListOrDictGet:
    ExpressionWithoutDictLiteral ListOrDictGetWithBrackets  { result = Riml::ListOrDictGetNode.new(val[0], val[1]) }
  | '(' Expression ')' ListOrDictGetWithBrackets            { result = Riml::ListOrDictGetNode.new(Riml::WrapInParensNode.new(val[1]), val[3]) }
  ;

  ListOrDictGetAssign:
    ExpressionWithoutDictLiteral ListOrDictGetWithBrackets  { result = Riml::ListOrDictGetNode.new(val[0], val[1]) }
  ;

  ListOrDictGetWithBrackets:
    '['  Expression ']'                           { result = [val[1]] }
  | '['  SubList    ']'                           { result = [val[1]] }
  | ListOrDictGetWithBrackets '[' Expression ']'  { result = val[0] << val[2] }
  | ListOrDictGetWithBrackets '[' SubList    ']'  { result = val[0] << val[2] }
  ;

  SubList:
    Expression ':' Expression          { result = Riml::SublistNode.new([val[0], Riml::LiteralNode.new(' : '), val[2]]) }
  | Expression ':'                     { result = Riml::SublistNode.new([val[0], Riml::LiteralNode.new(' :')]) }
  | ':' Expression                     { result = Riml::SublistNode.new([Riml::LiteralNode.new(': '), val[1]]) }
  | ':'                                { result = Riml::SublistNode.new([Riml::LiteralNode.new(':')]) }
  ;

  DictGetWithDot:
    DICT_VAL                        { result = [val[0]] }
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
  | BUILTIN_COMMAND ArgListWithoutNothing         { result = Riml::CallNode.new(nil, val[0], val[1]) }
  | BUILTIN_COMMAND NEWLINE                       { result = Riml::CallNode.new(nil, val[0], []) }
  | CALL '(' ArgList ')'                          { result = Riml::ExplicitCallNode.new(nil, nil, val[2]) }
  ;

  ObjectInstantiationCall:
    Scope DefCallIdentifier '(' ArgList ')'       { result = Riml::CallNode.new(val[0], val[1], val[3]) }
  | Scope DefCallIdentifier                       { result = Riml::CallNode.new(val[0], val[1], []) }
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

  # [SID, scope_modifier]
  SIDAndScope:
    Scope                       { result = [ nil, val[0] ] }
  | '<' IDENTIFIER '>' Scope    { result = [ Riml::SIDNode.new(val[1]), val[3] ] }
  ;

  ArgList:
    /* nothing */                         { result = [] }
  | ArgListWithoutNothing                 { result = val[0] }
  ;

  ArgListWithoutNothing:
    Expression                               { result = val }
  | ArgListWithoutNothing "," Expression     { result = val[0] << val[2] }
  ;

  BinaryOperator:
    Expression '||' Expression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '&&' Expression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | Expression '==' Expression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '==#' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '==?' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  # added by riml
  | Expression '===' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | Expression '!=' Expression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '!=#' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '!=?' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | Expression '=~' Expression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '=~#' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '=~?' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | Expression '!~' Expression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '!~#' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '!~?' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | Expression '>' Expression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '>#' Expression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '>?' Expression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | Expression '>=' Expression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '>=#' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '>=?' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | Expression '<' Expression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '<#' Expression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '<?' Expression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | Expression '<=' Expression            { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '<=#' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '<=?' Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | Expression '+' Expression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '-' Expression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '*' Expression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '/' Expression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '.' Expression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression '%' Expression             { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }

  | Expression IS    Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  | Expression ISNOT Expression           { result = Riml::BinaryOperatorNode.new(val[1], [val[0], val[2]]) }
  ;

  UnaryOperator:
    '!' Expression                        { result = Riml::UnaryOperatorNode.new(val[0], [val[1]]) }
  | '+' Expression                        { result = Riml::UnaryOperatorNode.new(val[0], [val[1]]) }
  | '-' Expression                        { result = Riml::UnaryOperatorNode.new(val[0], [val[1]]) }
  ;

  # ['=', LHS, RHS]
  Assign:
    LET AssignExpression                       { result = Riml::AssignNode.new(val[1][0], val[1][1], val[1][2]) }
  | AssignExpression                           { result = Riml::AssignNode.new(val[0][0], val[0][1], val[0][2]) }
  ;

  MultiAssign:
    Assign ',' Assign                          { result = Riml::MultiAssignNode.new([val[0], val[2]]) }
  | MultiAssign ',' Assign                     { val[0].assigns << val[2]; result = val[0] }
  ;

  # ['=', AssignLHS, Expression]
  AssignExpression:
    AssignLHS '='  Expression             { result = [val[1], val[0], val[2]] }
  | AssignLHS '+=' Expression             { result = [val[1], val[0], val[2]] }
  | AssignLHS '-=' Expression             { result = [val[1], val[0], val[2]] }
  | AssignLHS '.=' Expression             { result = [val[1], val[0], val[2]] }
  ;

  AssignLHS:
    AllVariableRetrieval                       { result = val[0] }
  | List                                       { result = val[0] }
  | ListUnpack                                 { result = val[0] }
  | DictGet                                    { result = val[0] }
  | ListOrDictGetAssign                        { result = val[0] }
  ;

  # retrieving the value of a variable
  VariableRetrieval:
    Scope IDENTIFIER                               { result = Riml::GetVariableNode.new(val[0], val[1]) }
  | SPECIAL_VAR_PREFIX IDENTIFIER                  { result = Riml::GetSpecialVariableNode.new(val[0], val[1]) }
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
  # [SID, scope_modifier, name, parameters, keyword, expressions]
  Def:
    FunctionType SIDAndScope DefCallIdentifier DefKeywords Block END                               { result = Riml.const_get(val[0]).new('!', val[1][0], val[1][1], val[2], [], val[3], val[4]) }
  | FunctionType SIDAndScope DefCallIdentifier '(' ParamList ')' DefKeywords Block END             { result = Riml.const_get(val[0]).new('!', val[1][0], val[1][1], val[2], val[4], val[6], val[7]) }
  | FunctionType SIDAndScope DefCallIdentifier '(' SPLAT     ')' DefKeywords Block END             { result = Riml.const_get(val[0]).new('!', val[1][0], val[1][1], val[2], [val[4]], val[6], val[7]) }
  | FunctionType SIDAndScope DefCallIdentifier '(' ParamList ',' SPLAT ')' DefKeywords Block END   { result = Riml.const_get(val[0]).new('!', val[1][0], val[1][1], val[2], val[4] << val[6], val[8], val[9]) }
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
    IDENTIFIER '=' Expression        { result = Riml::DefaultParamNode.new(val[0], val[2]) }
  ;

  Return:
    RETURN Returnable                        { result = Riml::ReturnNode.new(val[1]) }
  | RETURN Returnable IF Expression          { result = Riml::IfNode.new(val[3], Nodes.new([ReturnNode.new(val[1])])) }
  | RETURN Returnable UNLESS Expression      { result = Riml::UnlessNode.new(val[3], Nodes.new([ReturnNode.new(val[1])])) }
  ;

  Returnable:
    /* nothing */     { result = nil }
  | Expression        { result = val[0] }
  ;

  EndScript:
    FINISH                                { result = Riml::FinishNode.new }
  ;

  # [expression, expressions]
  If:
    IF Expression IfBlock END               { result = Riml::IfNode.new(val[1], val[2]) }
  | IF Expression THEN Expression END       { result = Riml::IfNode.new(val[1], Riml::Nodes.new([val[3]])) }
  | Expression IF Expression                { result = Riml::IfNode.new(val[2], Riml::Nodes.new([val[0]])) }
  ;

  Unless:
    UNLESS Expression IfBlock END           { result = Riml::UnlessNode.new(val[1], val[2]) }
  | UNLESS Expression THEN Expression END   { result = Riml::UnlessNode.new(val[1], Riml::Nodes.new([val[3]])) }
  | Expression UNLESS Expression            { result = Riml::UnlessNode.new(val[2], Riml::Nodes.new([val[0]])) }
  ;

  Ternary:
    Expression '?' Expression ':' Expression   { result = Riml::TernaryOperatorNode.new([val[0], val[2], val[4]]) }
  ;

  While:
    WHILE Expression Block END                 { result = Riml::WhileNode.new(val[1], val[2]) }
  ;

  LoopKeyword:
    BREAK                                      { result = Riml::BreakNode.new }
  | CONTINUE                                   { result = Riml::ContinueNode.new }
  ;

  Until:
    UNTIL Expression Block END                 { result = Riml::UntilNode.new(val[1], val[2]) }
  ;

  For:
    FOR IDENTIFIER IN Expression Block END     { result = Riml::ForNode.new(val[1], val[3], val[4]) }
  | FOR List IN Expression Block END           { result = Riml::ForNode.new(val[1], val[3], val[4]) }
  | FOR ListUnpack IN Expression Block END     { result = Riml::ForNode.new(val[1], val[3], val[4]) }
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
    NEWLINE Statements                        { result = val[1] }
  | NEWLINE                                   { result = Riml::Nodes.new([]) }
  ;

  IfBlock:
    Block                                     { result = val[0] }
  | NEWLINE Statements ElseBlock              { result = val[1] << val[2] }
  | NEWLINE Statements ElseifBlock            { result = val[1] << val[2] }
  | NEWLINE Statements ElseifBlock ElseBlock  { result = val[1] << val[2] << val[3] }
  ;

  ElseBlock:
    ELSE NEWLINE Statements                   { result = Riml::ElseNode.new(val[2]) }
  ;

  ElseifBlock:
    ELSEIF Expression NEWLINE Statements                   { result = Riml::Nodes.new([Riml::ElseifNode.new(val[1], val[3])]) }
  | ElseifBlock ELSEIF Expression NEWLINE Statements       { result = val[0] << Riml::ElseifNode.new(val[2], val[4]) }
  ;

  ClassDefinition:
    CLASS Scope IDENTIFIER Block END                         { result = Riml::ClassDefinitionNode.new(val[1], val[2], nil, val[3]) }
  | CLASS Scope IDENTIFIER '<' Scope IDENTIFIER Block END    { result = Riml::ClassDefinitionNode.new(val[1], val[2], (val[4] || ClassDefinitionNode::DEFAULT_SCOPE_MODIFIER) + val[5], val[6]) }
  ;

  ObjectInstantiation:
    NEW ObjectInstantiationCall                  { result = Riml::ObjectInstantiationNode.new(val[1]) }
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
  def parse(object, ast_rewriter = Riml::AST_Rewriter.new, filename = nil, included = false)
    if tokens?(object)
      @tokens = object
    elsif code?(object)
      @lexer = Riml::Lexer.new(object)
    end

    begin
      ast = do_parse
    rescue Racc::ParseError => e
      raise unless @lexer
      if @lexer.prev_token_is_keyword?
        warning = "#{@lexer.invalid_keyword.inspect} is a keyword, and cannot " \
          "be used as a variable name"
      end
      error_msg = "on line #{@lexer.lineno}: #{e.message}"
      error_msg << "\n\n#{warning}" if warning
      raise Riml::ParseError, error_msg
    end

    @ast_rewriter ||= ast_rewriter
    return ast unless @ast_rewriter
    @ast_rewriter.ast = ast
    @ast_rewriter.rewrite(filename, included)
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
