require File.expand_path('../../../test_helper', __FILE__)

class RimlCommandsCompilerTest < Riml::TestCase
  test "riml_source raises error if the file is not in Riml.source_path" do
    riml = <<Riml
riml_source "nonexistent_file.riml"
Riml
    assert_raises Riml::FileNotFound do
      compile(riml)
    end
  end

  test "riml_include raises error if the file is not in Riml.source_path" do
    riml = <<Riml
riml_include "nonexistent_file.riml"
Riml
    assert_raises Riml::FileNotFound do
      compile(riml)
    end
  end

  test "riml_source compiles and sources file if file exists in Riml.source_path" do
    riml = <<Riml
riml_source "file1.riml"
Riml

    expected = <<Viml
source file1.vim
Viml
    with_riml_source_path(File.expand_path("../", __FILE__)) do
      with_file_cleanup("file1.vim") do
        assert_equal expected, compile(riml)
        file1_vim = File.join(Riml.source_path, "file1.vim")
        assert File.exists?(file1_vim)
        assert_equal Riml::FILE_HEADER + File.read("./file1_expected.vim"), File.read(file1_vim)
      end
    end
  end

  test "files sourced from the main file have access to the classes created in the main file" do
    riml = <<Riml
class Car
  def initialize(*args)
    self.maxSpeed = 100
    self.options = args
  end
end

riml_source 'faster_car.riml'
Riml

    expected = <<Viml
function! g:CarConstructor(...)
  let carObj = {}
  let carObj.maxSpeed = 100
  let carObj.options = a:000
  return carObj
endfunction
source faster_car.vim
Viml

    with_riml_source_path(File.expand_path("../", __FILE__)) do
      with_file_cleanup("faster_car.vim") do
        assert_equal expected, compile(riml)
        faster_car_vim = File.join(Riml.source_path, "faster_car.vim")
        assert File.exists?(faster_car_vim)
        assert_equal Riml::FILE_HEADER + File.read("./faster_car_expected.vim"), File.read(faster_car_vim)
      end
    end

  end

  test "riml_source raises ClassNotFound if the sourced file references undefined class" do
    riml = <<Riml
riml_source 'faster_car.riml'
Riml

    with_riml_source_path(File.expand_path("../", __FILE__)) do
      with_file_cleanup("faster_car.vim") do
        assert_raises Riml::ClassNotFound do
          compile(riml)
        end
      end
    end
  end

  test "riml_include #includes the compiled output of the included file inline in the code" do
    riml = <<Riml
riml_include 'file1.riml'
class Car
  def initialize(*args)
    self.maxSpeed = 100
    self.options = args
  end
end

Riml

    expected = <<Viml
" included: 'file1.riml'
echo "hi"
function! g:CarConstructor(...)
  let carObj = {}
  let carObj.maxSpeed = 100
  let carObj.options = a:000
  return carObj
endfunction
Viml

    with_riml_source_path(File.expand_path("../", __FILE__)) do
      assert_equal expected, compile(riml)
      faster_car_vim = File.join(Riml.source_path, "faster_car.vim")
      refute File.exists?(faster_car_vim)
    end
  end

  test "riml_include raises ClassNotFound if class referenced in included file is undefined" do
    riml = "riml_include 'faster_car.riml'"
    with_riml_source_path(File.expand_path("../", __FILE__)) do
      assert_raises(Riml::ClassNotFound) do
        compile(riml)
      end
    end
  end

  test "riml_include is recursive" do
    riml = "riml_include 'riml_include_lib.riml'"
    expected = <<Riml
" included: 'riml_include_lib.riml'
" included: 'riml_include_lib2.riml'
function! g:Lib2Constructor()
  let lib2Obj = {}
  return lib2Obj
endfunction
function! g:Lib1Constructor()
  let lib1Obj = {}
  let lib2Obj = g:Lib2Constructor()
  call extend(lib1Obj, lib2Obj)
  return lib1Obj
endfunction
Riml
    with_riml_source_path(File.expand_path("../", __FILE__)) do
      assert_equal expected, compile(riml)
    end
  end
end