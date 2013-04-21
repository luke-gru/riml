require File.expand_path('../../../test_helper', __FILE__)

class NerdTreeCompilerTest < Riml::TestCase
  test "compiles to target" do
    source   = File.read File.expand_path("../nerdtree.riml", __FILE__)
    compiled = File.read File.expand_path("../nerdtree.vim", __FILE__)
    assert (viml = compile(source))
    assert_equal compiled, viml
  end
end
