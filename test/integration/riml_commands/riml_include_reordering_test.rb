require File.expand_path('../../../test_helper', __FILE__)

class RimlIncludeReorderingTest < Riml::TestCase

  test "riml_includes get reordered based on class dependencies" do
    riml = <<Riml
riml_include 'riml_include_lib2'
riml_include 'riml_include_lib'

lib1 = new Lib1()
Riml
    expected = <<Viml
" included: 'riml_include_lib2.riml'
function! s:Lib2Constructor()
  let lib2Obj = {}
  return lib2Obj
endfunction
" included: 'riml_include_lib.riml'
function! s:Lib1Constructor()
  let lib1Obj = {}
  let lib2Obj = s:Lib2Constructor()
  call extend(lib1Obj, lib2Obj)
  return lib1Obj
endfunction
let s:lib1 = s:Lib1Constructor()
Viml

    with_riml_include_path(File.expand_path('../', __FILE__)) do
      assert_equal expected, compile(riml)
    end
  end

end
