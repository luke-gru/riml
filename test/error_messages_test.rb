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
end
end
