require File.expand_path('../test_helper', __FILE__)

module Riml
class ErrorMessagesTest < Riml::TestCase

  test "gives proper lineno and filename for unexpected construct during compilation" do
    riml = <<Riml
echo "line1"
echo "line2"
super
echo "line4"
Riml

    assert_raises(
      Riml::CompileError,
      /#{Constants::COMPILED_STRING_LOCATION}:3/
    ) { compile(riml) }
  end

  test "invalid function name (bad chars) that get through the lexer/parser" do
    bad_chars = %w(! ? #)
    bad_chars.each do |chr|
      riml = <<Riml
def omglol#{chr}()
end
Riml
      assert_raises(
        Riml::InvalidMethodDefinition,
        /invalid function name/i
      ) { compile(riml) }
    end
  end

end
end
