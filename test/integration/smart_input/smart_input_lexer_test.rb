require File.expand_path('../../../test_helper', __FILE__)

class SmartInputLexerTest < Riml::TestCase
  test "lexes without error" do
    source = File.read File.expand_path("../smart_input.riml", __FILE__)
    assert lex(source)
  end
end
