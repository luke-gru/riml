require File.expand_path('../../../test_helper', __FILE__)

class SurroundCompilerTest < Riml::TestCase
  test "compiles to target" do
    source   = File.read File.expand_path("../surround.riml", __FILE__)
    compiled = File.read File.expand_path("../surround.vim",  __FILE__)
    assert_equal compiled, compile(source)
  end
end
