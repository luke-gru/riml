require File.expand_path('../../../test_helper', __FILE__)

class SmartInputLexerTest < Riml::TestCase
  test "lexes without error" do
    source = File.read File.expand_path("../smartinput.riml", __FILE__)
    assert lex(source)
  end
end
