require File.expand_path('../test_helper', __FILE__)

module Riml
class BasicParserTest < Riml::TestCase

  test "parsing basic method" do
    code = <<-Viml
    def a_method(a, b)
      true
    end
    Viml
    expected = Nodes.new([
      DefNode.new('!', nil, "a_method", ['a', 'b'], nil,
        Nodes.new([TrueNode.new])
      )
    ])
    assert_equal expected, parse(code)
  end

  test "parsing method with if block" do
    code = <<Viml
def b:another_method(a, b)
  if hello()
    true
  else
    false
  end
end
Viml
    expected = Nodes.new([
      DefNode.new('!', 'b:', "another_method", ['a', 'b'], nil, Nodes.new(
        [IfNode.new(CallNode.new(nil, "hello", []),
                      Nodes.new([TrueNode.new,
                                 ElseNode.new(
                                 Nodes.new([FalseNode.new])
                                )])
                   )]
      ))
    ])
    assert_equal expected, parse(code)
  end

  test "parsing a ruby-like 'if this then that end' expression" do
    code = <<-Riml
    if b() then a = 2 end
    Riml
    expected = Nodes.new([
      IfNode.new(
        CallNode.new(nil, 'b', []),
        Nodes.new(
          [AssignNode.new("=", GetVariableNode.new(nil, "a"), NumberNode.new("2"))]
        )
      )
    ])
    assert_equal expected, parse(code)
  end

  test "parsing an unless expression" do
    riml = <<Riml
unless shy()
  echo("hi");
end
Riml
    expected = Nodes.new([
      UnlessNode.new(
        CallNode.new(nil, 'shy', []),
        Nodes.new(
          [ CallNode.new(nil, 'echo', [StringNode.new('hi', :d)]) ]
        )
      )
    ])

    assert_equal expected, parse(riml)
  end

  test "scope modifier literal" do
    riml = <<Riml
if s:var
  return s:
else
  return g:
end
Riml

    expected =
      Nodes.new([
        IfNode.new(GetVariableNode.new("s:","var"), Nodes.new([
          ReturnNode.new(ScopeModifierLiteralNode.new("s:")),
        ElseNode.new(Nodes.new([
          ReturnNode.new(ScopeModifierLiteralNode.new("g:"))
        ]))
        ])
      )])
    assert_equal expected, parse(riml)
  end

  test "dictionary key with bracket assign" do
    riml = <<Riml
  function! urules.add(name, urules)
    call add(self.names, a:name)
    let self.table[a:name] = a:urules
  endfunction
Riml

    expected = Nodes.new([
        DefNode.new("!", nil, "urules.add", ["name", "urules"], nil, Nodes.new([
          ExplicitCallNode.new(nil, "add", [DictGetDotNode.new(
            GetVariableNode.new(nil, "self"), ["names"]), GetVariableNode.new("a:", "name")]),
          AssignNode.new("=", ListOrDictGetNode.new(
            DictGetDotNode.new(GetVariableNode.new(nil, "self"), ["table"]), [GetVariableNode.new("a:", "name")]), GetVariableNode.new("a:", "urules"))]))])
    assert_equal expected, parse(riml)
  end

  test "curly-brace names parse even if prefix and suffix parts of the variables are absent" do
    riml = <<Riml
let {color} = 138
Riml

    riml2 = <<Riml
let {bright{color}} = 138
Riml

    assert parse(riml)
    assert parse(riml2)
  end

  test "curly-brace names parse non-variables inside braces" do
    riml = <<Riml
let insertion = repl_{char2nr(char)}
Riml

    expected = <<Viml
let s:insertion = s:repl_{char2nr(s:char)}
Viml
    assert_equal expected,  compile(riml)
  end

  test "for loop iterating over all variables in a certain scope" do
    # :help internal-variables
    riml = <<Riml
for k in keys(s:)
    unlet s:[k]
endfor
Riml

    assert parse(riml)
  end

  test "use of keyword as variable on LHS raises parse error" do
    Riml::Constants::KEYWORDS.each do |keyword|
      riml = <<Riml
let #{keyword} = s:wrap(orig,a:char,type,special)
Riml
      begin
        error = nil
        parse(riml)
      rescue Riml::ParseError => e
        error = e
      end
      assert error, "#{keyword} didn't raise error on use as LHS of assignment"
      assert error.message =~ /cannot be used as a variable name/, "#{keyword} didn't give proper error message"
    end
  end

  test "use of keyword as variable on LHS still raises parse error even when scope modified" do
    Riml::Constants::KEYWORDS.each do |keyword|
      riml = <<Riml
let n:#{keyword} = s:wrap(orig,a:char,type,special)
Riml
      begin
        error = nil
        parse(riml)
      rescue Riml::ParseError => e
        error = e
      end
      assert error, "error was not raised for keyword: #{keyword}"
    end
  end

  test "use of keyword as variable in dict get with brackets raises parse error" do
    Riml::Constants::KEYWORDS.each do |keyword|
      riml = <<Riml
dict[#{keyword}] = true
Riml
      begin
        error = nil
        parse(riml)
      rescue Riml::ParseError => e
        error = e
      end
      # FIXME: super and nil should not be in this list of acceptable keywords
      allowed_keywords = %w(true false super nil)
      unless allowed_keywords.include?(keyword)
        assert error, "error was not raised for keyword: #{keyword}"
      end
    end
  end

  # concatenation edge cases

  test "concatenate result of two function calls" do
    riml = <<Riml
call1().call2()
Riml

    assert parse(riml)
  end

  test "concatenate the result of two function calls with scope modifiers" do
    riml = <<Riml
s:call1().s:call2()
Riml

    assert parse(riml)
  end
end
end
