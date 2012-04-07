#
# DO NOT MODIFY!!!!
# This file is automatically generated by Racc 1.4.8
# from Racc grammer file "".
#

require 'racc/parser.rb'

  require File.expand_path("../lexer", __FILE__)
  require File.expand_path("../nodes", __FILE__)
  require 'pp'

module Riml
  class Parser < Racc::Parser

module_eval(<<'...end grammar.y/module_eval...', 'grammar.y', 147)
  # This code will be put as-is in the parser class

  def parse(code, show_tokens=false)
    @tokens = Riml::Lexer.new.tokenize(code)
    pp(@tokens) if show_tokens
    do_parse
  end

  def next_token
    @tokens.shift
  end
...end grammar.y/module_eval...
##### State transition tables begin ###

racc_action_table = [
    24,    13,    69,    13,    23,    76,    69,    13,    15,    16,
    17,    18,    19,    20,    21,    22,    93,    73,    41,    72,
    40,    86,    13,    85,    81,    14,    24,    14,    68,    12,
    23,    14,    70,    13,    15,    16,    17,    18,    19,    20,
    21,    22,    44,    86,    45,    94,    14,    29,    30,    29,
    30,    66,    24,    37,    38,    12,    23,    14,    84,    13,
    15,    16,    17,    18,    19,    20,    21,    22,    29,    30,
    79,    43,    76,    78,    78,    90,    24,    37,    38,    69,
    23,    12,    92,    14,    15,    16,    17,    18,    19,    20,
    21,    22,    29,    30,    47,    76,    76,    96,    24,    69,
    25,    76,    23,    42,   nil,    12,    15,    16,    17,    18,
    19,    20,    21,    22,   nil,   nil,   nil,   nil,   nil,   nil,
    24,   nil,   nil,   nil,    23,   nil,   nil,    12,    15,    16,
    17,    18,    19,    20,    21,    22,   nil,   nil,   nil,   nil,
   nil,   nil,    24,   nil,   nil,   nil,    23,   nil,   nil,    12,
    15,    16,    17,    18,    19,    20,    21,    22,   nil,   nil,
   nil,   nil,   nil,   nil,    24,   nil,   nil,   nil,    23,   nil,
   nil,    12,    15,    16,    17,    18,    19,    20,    21,    22,
   nil,   nil,   nil,   nil,   nil,   nil,    24,   nil,   nil,   nil,
    23,   nil,   nil,    12,    15,    16,    17,    18,    19,    20,
    21,    22,   nil,   nil,   nil,   nil,   nil,   nil,    24,   nil,
   nil,   nil,    23,   nil,   nil,    12,    15,    16,    17,    18,
    19,    20,    21,    22,   nil,   nil,   nil,   nil,   nil,   nil,
    24,   nil,   nil,   nil,    23,   nil,   nil,    12,    15,    16,
    17,    18,    19,    20,    21,    22,   nil,   nil,   nil,   nil,
   nil,   nil,    24,   nil,   nil,   nil,    23,   nil,   nil,    12,
    15,    16,    17,    18,    19,    20,    21,    22,   nil,   nil,
   nil,   nil,   nil,   nil,    24,   nil,   nil,   nil,    23,   nil,
   nil,    12,    15,    16,    17,    18,    19,    20,    21,    22,
   nil,   nil,   nil,   nil,   nil,   nil,    24,   nil,   nil,   nil,
    23,   nil,   nil,    12,    15,    16,    17,    18,    19,    20,
    21,    22,   nil,   nil,   nil,   nil,   nil,   nil,    24,   nil,
   nil,   nil,    23,   nil,   nil,    12,    15,    16,    17,    18,
    19,    20,    21,    22,   nil,   nil,   nil,   nil,   nil,   nil,
    24,   nil,   nil,   nil,    23,   nil,   nil,    12,    15,    16,
    17,    18,    19,    20,    21,    22,   nil,   nil,   nil,   nil,
   nil,   nil,    24,   nil,   nil,   nil,    23,   nil,   nil,    12,
    15,    16,    17,    18,    19,    20,    21,    22,   nil,   nil,
   nil,   nil,   nil,   nil,    24,   nil,   nil,   nil,    23,   nil,
   nil,    12,    15,    16,    17,    18,    19,    20,    21,    22,
   nil,   nil,   nil,   nil,   nil,   nil,    24,   nil,   nil,   nil,
    23,   nil,   nil,    12,    15,    16,    17,    18,    19,    20,
    21,    22,   nil,   nil,   nil,   nil,   nil,   nil,    24,   nil,
   nil,   nil,    23,   nil,   nil,    12,    15,    16,    17,    18,
    19,    20,    21,    22,   nil,   nil,   nil,   nil,   nil,   nil,
    24,   nil,   nil,   nil,    23,   nil,   nil,    12,    15,    16,
    17,    18,    19,    20,    21,    22,   nil,   nil,   nil,   nil,
   nil,   nil,    24,   nil,   nil,   nil,    23,   nil,   nil,    12,
    15,    16,    17,    18,    19,    20,    21,    22,   nil,   nil,
   nil,   nil,   nil,   nil,    24,   nil,   nil,   nil,    23,   nil,
    69,    12,    15,    16,    17,    18,    19,    20,    21,    22,
    37,    38,    35,    36,    31,    32,    33,    34,    28,    27,
   nil,   nil,   nil,    12,   nil,    29,    30,    37,    38,    35,
    36,    31,    32,    33,    34,    28,    27,   nil,   nil,   nil,
   nil,   nil,    29,    30,    37,    38,    35,    36,    31,    32,
    33,    34,    28,    27,   nil,   nil,   nil,   nil,   nil,    29,
    30,    37,    38,    35,    36,    31,    32,    33,    34,    28,
    27,   nil,   nil,   nil,   nil,   nil,    29,    30,    37,    38,
    35,    36,    31,    32,    33,    34,    28,    27,   nil,    37,
    38,    35,    36,    29,    30,    37,    38,    35,    36,    31,
    32,    33,    34,    28,    29,    30,    37,    38,    35,    36,
    29,    30,    37,    38,    35,    36,    31,    32,    33,    34,
   nil,    29,    30,   nil,   nil,   nil,   nil,    29,    30,    37,
    38,    35,    36,    31,    32,    33,    34,    28,    27,   nil,
   nil,   nil,   nil,   nil,    29,    30,    37,    38,    35,    36,
    31,    32,    33,    34,    28,    27,    37,    38,    35,    36,
   nil,    29,    30,    37,    38,    35,    36,   nil,   nil,   nil,
   nil,    29,    30,   nil,   nil,   nil,   nil,   nil,    29,    30,
    37,    38,    35,    36,    31,    32,    33,    34,    28,    27,
   nil,   nil,   nil,   nil,   nil,    29,    30,    37,    38,    35,
    36,    31,    32,    33,    34,    28,    27,   nil,   nil,   nil,
   nil,   nil,    29,    30,    37,    38,    35,    36,    31,    32,
    33,    34,    28,    27,   nil,   nil,   nil,   nil,   nil,    29,
    30,    37,    38,    35,    36,    31,    32,    33,    34,    28,
    27,   nil,   nil,   nil,    61,   nil,    29,    30 ]

racc_action_check = [
     0,    98,    70,     2,     0,    80,    44,     0,     0,     0,
     0,     0,     0,     0,     0,     0,    87,    62,    20,    62,
    20,    77,    87,    77,    70,    98,    96,     2,    44,     0,
    96,     0,    45,    96,    96,    96,    96,    96,    96,    96,
    96,    96,    23,    89,    23,    89,    87,    59,    59,    60,
    60,    43,    79,    57,    57,    96,    79,    96,    76,    79,
    79,    79,    79,    79,    79,    79,    79,    79,    57,    57,
    69,    22,    71,    81,    68,    84,    26,    58,    58,    85,
    26,    79,    86,    79,    26,    26,    26,    26,    26,    26,
    26,    26,    58,    58,    25,    67,    91,    93,    73,    94,
     1,    97,    73,    21,   nil,    26,    73,    73,    73,    73,
    73,    73,    73,    73,   nil,   nil,   nil,   nil,   nil,   nil,
    66,   nil,   nil,   nil,    66,   nil,   nil,    73,    66,    66,
    66,    66,    66,    66,    66,    66,   nil,   nil,   nil,   nil,
   nil,   nil,    42,   nil,   nil,   nil,    42,   nil,   nil,    66,
    42,    42,    42,    42,    42,    42,    42,    42,   nil,   nil,
   nil,   nil,   nil,   nil,    41,   nil,   nil,   nil,    41,   nil,
   nil,    42,    41,    41,    41,    41,    41,    41,    41,    41,
   nil,   nil,   nil,   nil,   nil,   nil,    24,   nil,   nil,   nil,
    24,   nil,   nil,    41,    24,    24,    24,    24,    24,    24,
    24,    24,   nil,   nil,   nil,   nil,   nil,   nil,    40,   nil,
   nil,   nil,    40,   nil,   nil,    24,    40,    40,    40,    40,
    40,    40,    40,    40,   nil,   nil,   nil,   nil,   nil,   nil,
    12,   nil,   nil,   nil,    12,   nil,   nil,    40,    12,    12,
    12,    12,    12,    12,    12,    12,   nil,   nil,   nil,   nil,
   nil,   nil,    27,   nil,   nil,   nil,    27,   nil,   nil,    12,
    27,    27,    27,    27,    27,    27,    27,    27,   nil,   nil,
   nil,   nil,   nil,   nil,    28,   nil,   nil,   nil,    28,   nil,
   nil,    27,    28,    28,    28,    28,    28,    28,    28,    28,
   nil,   nil,   nil,   nil,   nil,   nil,    29,   nil,   nil,   nil,
    29,   nil,   nil,    28,    29,    29,    29,    29,    29,    29,
    29,    29,   nil,   nil,   nil,   nil,   nil,   nil,    30,   nil,
   nil,   nil,    30,   nil,   nil,    29,    30,    30,    30,    30,
    30,    30,    30,    30,   nil,   nil,   nil,   nil,   nil,   nil,
    31,   nil,   nil,   nil,    31,   nil,   nil,    30,    31,    31,
    31,    31,    31,    31,    31,    31,   nil,   nil,   nil,   nil,
   nil,   nil,    32,   nil,   nil,   nil,    32,   nil,   nil,    31,
    32,    32,    32,    32,    32,    32,    32,    32,   nil,   nil,
   nil,   nil,   nil,   nil,    38,   nil,   nil,   nil,    38,   nil,
   nil,    32,    38,    38,    38,    38,    38,    38,    38,    38,
   nil,   nil,   nil,   nil,   nil,   nil,    34,   nil,   nil,   nil,
    34,   nil,   nil,    38,    34,    34,    34,    34,    34,    34,
    34,    34,   nil,   nil,   nil,   nil,   nil,   nil,    35,   nil,
   nil,   nil,    35,   nil,   nil,    34,    35,    35,    35,    35,
    35,    35,    35,    35,   nil,   nil,   nil,   nil,   nil,   nil,
    36,   nil,   nil,   nil,    36,   nil,   nil,    35,    36,    36,
    36,    36,    36,    36,    36,    36,   nil,   nil,   nil,   nil,
   nil,   nil,    37,   nil,   nil,   nil,    37,   nil,   nil,    36,
    37,    37,    37,    37,    37,    37,    37,    37,   nil,   nil,
   nil,   nil,   nil,   nil,    33,   nil,   nil,   nil,    33,   nil,
    46,    37,    33,    33,    33,    33,    33,    33,    33,    33,
    46,    46,    46,    46,    46,    46,    46,    46,    46,    46,
   nil,   nil,   nil,    33,   nil,    46,    46,    51,    51,    51,
    51,    51,    51,    51,    51,    51,    51,   nil,   nil,   nil,
   nil,   nil,    51,    51,     3,     3,     3,     3,     3,     3,
     3,     3,     3,     3,   nil,   nil,   nil,   nil,   nil,     3,
     3,    83,    83,    83,    83,    83,    83,    83,    83,    83,
    83,   nil,   nil,   nil,   nil,   nil,    83,    83,    48,    48,
    48,    48,    48,    48,    48,    48,    48,    48,   nil,    53,
    53,    53,    53,    48,    48,    49,    49,    49,    49,    49,
    49,    49,    49,    49,    53,    53,    54,    54,    54,    54,
    49,    49,    50,    50,    50,    50,    50,    50,    50,    50,
   nil,    54,    54,   nil,   nil,   nil,   nil,    50,    50,    74,
    74,    74,    74,    74,    74,    74,    74,    74,    74,   nil,
   nil,   nil,   nil,   nil,    74,    74,    52,    52,    52,    52,
    52,    52,    52,    52,    52,    52,    55,    55,    55,    55,
   nil,    52,    52,    56,    56,    56,    56,   nil,   nil,   nil,
   nil,    55,    55,   nil,   nil,   nil,   nil,   nil,    56,    56,
    63,    63,    63,    63,    63,    63,    63,    63,    63,    63,
   nil,   nil,   nil,   nil,   nil,    63,    63,    65,    65,    65,
    65,    65,    65,    65,    65,    65,    65,   nil,   nil,   nil,
   nil,   nil,    65,    65,    64,    64,    64,    64,    64,    64,
    64,    64,    64,    64,   nil,   nil,   nil,   nil,   nil,    64,
    64,    39,    39,    39,    39,    39,    39,    39,    39,    39,
    39,   nil,   nil,   nil,    39,   nil,    39,    39 ]

racc_action_pointer = [
    -2,   100,    -6,   525,   nil,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,   228,   nil,   nil,   nil,   nil,   nil,   nil,   nil,
   -11,    74,    56,    27,   184,    94,    74,   250,   272,   294,
   316,   338,   360,   492,   404,   426,   448,   470,   382,   712,
   206,   162,   140,    22,    -3,    17,   491,   nil,   559,   576,
   593,   508,   627,   570,   587,   637,   644,    34,    58,    13,
    15,   nil,   -13,   661,   695,   678,   118,    90,    59,    63,
    -7,    67,   nil,    96,   610,   nil,    49,    -9,   nil,    50,
     0,    58,   nil,   542,    67,    70,    67,    13,   nil,    13,
   nil,    91,   nil,    88,    90,   nil,    24,    96,    -8,   nil ]

racc_action_default = [
    -1,   -55,    -2,    -3,    -6,    -7,    -8,    -9,   -10,   -11,
   -12,   -13,   -55,   -15,   -16,   -17,   -18,   -19,   -20,   -21,
   -22,   -39,   -55,   -55,   -55,   -55,    -5,   -55,   -55,   -55,
   -55,   -55,   -55,   -55,   -55,   -55,   -55,   -55,   -55,   -55,
   -24,   -55,   -55,   -55,   -55,   -55,   -55,   100,    -4,   -27,
   -28,   -29,   -30,   -31,   -32,   -33,   -34,   -35,   -36,   -37,
   -38,   -14,   -55,   -25,   -40,   -42,   -55,   -55,   -49,   -55,
   -55,   -55,   -23,   -55,   -41,   -43,   -48,   -55,   -50,   -55,
   -55,   -49,   -52,   -26,   -55,   -55,   -55,   -54,   -45,   -55,
   -47,   -55,   -51,   -55,   -55,   -44,   -55,   -55,   -53,   -46 ]

racc_goto_table = [
    26,     2,    39,    67,    62,    71,     1,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,    46,   nil,    48,    49,    50,    51,
    52,    53,    54,    55,    56,    57,    58,    59,    60,    80,
    63,    64,    65,    77,    75,   nil,   nil,   nil,    82,   nil,
   nil,   nil,   nil,   nil,    91,   nil,    89,    88,   nil,   nil,
   nil,   nil,   nil,    97,   nil,   nil,    74,   nil,    95,   nil,
   nil,   nil,   nil,    83,    99,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,
    87,   nil,   nil,   nil,   nil,    26,   nil,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,   nil,   nil,    26,    98 ]

racc_goto_check = [
     4,     2,     3,    13,    12,    13,     1,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,     3,   nil,     3,     3,     3,     3,
     3,     3,     3,     3,     3,     3,     3,     3,     3,    13,
     3,     3,     3,    15,    14,   nil,   nil,   nil,    14,   nil,
   nil,   nil,   nil,   nil,    13,   nil,    15,    14,   nil,   nil,
   nil,   nil,   nil,    13,   nil,   nil,     3,   nil,    14,   nil,
   nil,   nil,   nil,     3,    14,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,
     2,   nil,   nil,   nil,   nil,     4,   nil,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,   nil,   nil,     4,     2 ]

racc_goto_pointer = [
   nil,     6,     1,   -10,    -2,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,   -36,   -41,   -33,   -35 ]

racc_goto_default = [
   nil,   nil,   nil,     3,     4,     5,     6,     7,     8,     9,
    10,    11,   nil,   nil,   nil,   nil ]

racc_reduce_table = [
  0, 0, :racc_error,
  0, 37, :_reduce_1,
  1, 37, :_reduce_2,
  1, 38, :_reduce_3,
  3, 38, :_reduce_4,
  2, 38, :_reduce_5,
  1, 38, :_reduce_6,
  1, 39, :_reduce_none,
  1, 39, :_reduce_none,
  1, 39, :_reduce_none,
  1, 39, :_reduce_none,
  1, 39, :_reduce_none,
  1, 39, :_reduce_none,
  1, 39, :_reduce_none,
  3, 39, :_reduce_14,
  1, 40, :_reduce_none,
  1, 40, :_reduce_none,
  1, 41, :_reduce_17,
  1, 41, :_reduce_18,
  1, 41, :_reduce_19,
  1, 41, :_reduce_20,
  1, 41, :_reduce_21,
  1, 42, :_reduce_22,
  4, 42, :_reduce_23,
  0, 48, :_reduce_24,
  1, 48, :_reduce_25,
  3, 48, :_reduce_26,
  3, 43, :_reduce_27,
  3, 43, :_reduce_28,
  3, 43, :_reduce_29,
  3, 43, :_reduce_30,
  3, 43, :_reduce_31,
  3, 43, :_reduce_32,
  3, 43, :_reduce_33,
  3, 43, :_reduce_34,
  3, 43, :_reduce_35,
  3, 43, :_reduce_36,
  3, 43, :_reduce_37,
  3, 43, :_reduce_38,
  1, 44, :_reduce_39,
  3, 45, :_reduce_40,
  4, 45, :_reduce_41,
  3, 45, :_reduce_42,
  4, 46, :_reduce_43,
  7, 46, :_reduce_44,
  5, 46, :_reduce_45,
  8, 46, :_reduce_46,
  3, 50, :_reduce_none,
  1, 50, :_reduce_none,
  0, 51, :_reduce_49,
  1, 51, :_reduce_50,
  3, 51, :_reduce_51,
  4, 47, :_reduce_52,
  6, 49, :_reduce_53,
  3, 49, :_reduce_54 ]

racc_reduce_n = 55

racc_shift_n = 100

racc_token_table = {
  false => 0,
  :error => 1,
  :IF => 2,
  :ELSE => 3,
  :ELSIF => 4,
  :END => 5,
  :DEF => 6,
  :INDENT => 7,
  :DEDENT => 8,
  :NEWLINE => 9,
  :NUMBER => 10,
  :STRING => 11,
  :TRUE => 12,
  :FALSE => 13,
  :NIL => 14,
  :IDENTIFIER => 15,
  :CONSTANT => 16,
  :SCOPE_MODIFIER => 17,
  "!" => 18,
  "*" => 19,
  "/" => 20,
  "+" => 21,
  "-" => 22,
  ">" => 23,
  ">=" => 24,
  "<" => 25,
  "<=" => 26,
  "&&" => 27,
  "||" => 28,
  "=" => 29,
  "," => 30,
  "(" => 31,
  ")" => 32,
  ";" => 33,
  "==" => 34,
  "!=" => 35 }

racc_nt_base = 36

racc_use_result_var = true

Racc_arg = [
  racc_action_table,
  racc_action_check,
  racc_action_default,
  racc_action_pointer,
  racc_goto_table,
  racc_goto_check,
  racc_goto_default,
  racc_goto_pointer,
  racc_nt_base,
  racc_reduce_table,
  racc_token_table,
  racc_shift_n,
  racc_reduce_n,
  racc_use_result_var ]

Racc_token_to_s_table = [
  "$end",
  "error",
  "IF",
  "ELSE",
  "ELSIF",
  "END",
  "DEF",
  "INDENT",
  "DEDENT",
  "NEWLINE",
  "NUMBER",
  "STRING",
  "TRUE",
  "FALSE",
  "NIL",
  "IDENTIFIER",
  "CONSTANT",
  "SCOPE_MODIFIER",
  "\"!\"",
  "\"*\"",
  "\"/\"",
  "\"+\"",
  "\"-\"",
  "\">\"",
  "\">=\"",
  "\"<\"",
  "\"<=\"",
  "\"&&\"",
  "\"||\"",
  "\"=\"",
  "\",\"",
  "\"(\"",
  "\")\"",
  "\";\"",
  "\"==\"",
  "\"!=\"",
  "$start",
  "Root",
  "Expressions",
  "Expression",
  "Terminator",
  "Literal",
  "Call",
  "Operator",
  "Constant",
  "Assign",
  "Def",
  "If",
  "ArgList",
  "Block",
  "End",
  "ParamList" ]

Racc_debug_parser = false

##### State transition tables end #####

# reduce 0 omitted

module_eval(<<'.,.,', 'grammar.y', 28)
  def _reduce_1(val, _values, result)
     result = Nodes.new([]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 29)
  def _reduce_2(val, _values, result)
     result = val[0] 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 34)
  def _reduce_3(val, _values, result)
     result = Nodes.new([ val[0] ]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 35)
  def _reduce_4(val, _values, result)
     result = val[0] << val[2] 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 36)
  def _reduce_5(val, _values, result)
     result = val[0] 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 37)
  def _reduce_6(val, _values, result)
     result = Nodes.new([]) 
    result
  end
.,.,

# reduce 7 omitted

# reduce 8 omitted

# reduce 9 omitted

# reduce 10 omitted

# reduce 11 omitted

# reduce 12 omitted

# reduce 13 omitted

module_eval(<<'.,.,', 'grammar.y', 49)
  def _reduce_14(val, _values, result)
     result = val[1] 
    result
  end
.,.,

# reduce 15 omitted

# reduce 16 omitted

module_eval(<<'.,.,', 'grammar.y', 59)
  def _reduce_17(val, _values, result)
     result = NumberNode.new(val[0]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 60)
  def _reduce_18(val, _values, result)
     result = StringNode.new(val[0]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 61)
  def _reduce_19(val, _values, result)
     result = TrueNode.new 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 62)
  def _reduce_20(val, _values, result)
     result = FalseNode.new 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 63)
  def _reduce_21(val, _values, result)
     result = NilNode.new 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 69)
  def _reduce_22(val, _values, result)
     result = CallNode.new(val[0], []) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 71)
  def _reduce_23(val, _values, result)
     result = CallNode.new(val[0], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 75)
  def _reduce_24(val, _values, result)
     result = [] 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 76)
  def _reduce_25(val, _values, result)
     result = val 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 77)
  def _reduce_26(val, _values, result)
     result = val[0] << val[2] 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 82)
  def _reduce_27(val, _values, result)
     result = CallNode.new(val[0], val[1], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 83)
  def _reduce_28(val, _values, result)
     result = CallNode.new(val[0], val[1], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 84)
  def _reduce_29(val, _values, result)
     result = CallNode.new(val[0], val[1], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 85)
  def _reduce_30(val, _values, result)
     result = CallNode.new(val[0], val[1], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 86)
  def _reduce_31(val, _values, result)
     result = CallNode.new(val[0], val[1], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 87)
  def _reduce_32(val, _values, result)
     result = CallNode.new(val[0], val[1], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 88)
  def _reduce_33(val, _values, result)
     result = CallNode.new(val[0], val[1], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 89)
  def _reduce_34(val, _values, result)
     result = CallNode.new(val[0], val[1], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 90)
  def _reduce_35(val, _values, result)
     result = CallNode.new(val[0], val[1], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 91)
  def _reduce_36(val, _values, result)
     result = CallNode.new(val[0], val[1], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 92)
  def _reduce_37(val, _values, result)
     result = CallNode.new(val[0], val[1], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 93)
  def _reduce_38(val, _values, result)
     result = CallNode.new(val[0], val[1], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 97)
  def _reduce_39(val, _values, result)
     result = GetConstantNode.new(val[0]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 102)
  def _reduce_40(val, _values, result)
     result = SetVariableNode.new(nil, val[0], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 103)
  def _reduce_41(val, _values, result)
     result = SetVariableNode.new(val[0], val[1], val[3]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 104)
  def _reduce_42(val, _values, result)
     result = SetConstantNode.new(val[0], val[2]) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 110)
  def _reduce_43(val, _values, result)
     indent = val[2].pop; result = DefNode.new(nil,    val[1], [],     val[2], indent) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 111)
  def _reduce_44(val, _values, result)
     indent = val[5].pop; result = DefNode.new(nil,    val[1], val[3], val[5], indent) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 112)
  def _reduce_45(val, _values, result)
     indent = val[3].pop; result = DefNode.new(val[1], val[2], [],     val[3], indent) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 113)
  def _reduce_46(val, _values, result)
     indent = val[6].pop; result = DefNode.new(val[1], val[2], val[4], val[6], indent) 
    result
  end
.,.,

# reduce 47 omitted

# reduce 48 omitted

module_eval(<<'.,.,', 'grammar.y', 122)
  def _reduce_49(val, _values, result)
     result = [] 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 123)
  def _reduce_50(val, _values, result)
     result = val 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 124)
  def _reduce_51(val, _values, result)
     result = val[0] << val[2] 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 129)
  def _reduce_52(val, _values, result)
     indent = val[2].pop; result = IfNode.new(val[1], val[2], indent) 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 135)
  def _reduce_53(val, _values, result)
     result = val[2] << ElseNode.new(val[5]) << val[1] 
    result
  end
.,.,

module_eval(<<'.,.,', 'grammar.y', 136)
  def _reduce_54(val, _values, result)
     result = val[2] << val[1] 
    result
  end
.,.,

def _reduce_none(val, _values, result)
  val[0]
end

  end   # class Parser
  end   # module Riml