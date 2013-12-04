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
    cwd = File.expand_path("../", __FILE__)
    with_riml_source_path(cwd) do
      Dir.chdir(cwd) do
        with_file_cleanup("file1.vim") do
          assert_equal expected, compile(riml)
          file1_vim = File.join(Riml.source_path.first, "file1.vim")
          assert File.exist?(file1_vim)
          assert_equal Riml::FILE_HEADER + File.read("./file1_expected.vim"), File.read(file1_vim)
        end
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
function! s:CarConstructor(...)
  let carObj = {}
  let carObj.maxSpeed = 100
  let carObj.options = a:000
  return carObj
endfunction
source faster_car.vim
Viml

    cwd = File.expand_path("../", __FILE__)
    with_riml_source_path(cwd) do
      Dir.chdir(cwd) do
        with_file_cleanup("faster_car.vim") do
          assert_equal expected, compile(riml)
          assert File.exist?("faster_car.vim")
          assert_equal(
            Riml::FILE_HEADER + Riml::GET_SID_FUNCTION_SRC + File.read("faster_car_expected.vim"),
            File.read("faster_car.vim")
          )
        end
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
function! s:CarConstructor(...)
  let carObj = {}
  let carObj.maxSpeed = 100
  let carObj.options = a:000
  return carObj
endfunction
Viml

    with_riml_include_path(File.expand_path("../", __FILE__)) do
      assert_equal expected, compile(riml)
      faster_car_vim = File.join(Riml.include_path.first, "faster_car.vim")
      refute File.exist?(faster_car_vim)
    end
  end

  test "riml_include raises ClassNotFound if class referenced in included file is undefined" do
    riml = "riml_include 'faster_car.riml'"
    with_riml_include_path(File.expand_path("../", __FILE__)) do
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
function! s:Lib2Constructor()
  let lib2Obj = {}
  return lib2Obj
endfunction
function! s:Lib1Constructor()
  let lib1Obj = {}
  let lib2Obj = s:Lib2Constructor()
  call extend(lib1Obj, lib2Obj)
  return lib1Obj
endfunction
Riml
    with_riml_include_path(File.expand_path("../", __FILE__)) do
      assert_equal expected, compile(riml)
    end
  end

  test "riml_include doesn't get stuck in infinite loop when two files include each other" do
    riml = %Q(riml_include 'riml_include_loop1.riml' " loop1 includes loop2 which includes loop1...)
    expected = <<Viml
" included: 'riml_include_loop1.riml'
" included: 'riml_include_loop2.riml'
Viml
    with_riml_include_path(File.expand_path("../", __FILE__)) do
      assert_equal expected, compile(riml)
    end
  end

  test "riml_include raises error when including itself" do
    riml = %Q(riml_include 'riml_include_self.riml')
    with_riml_include_path(File.expand_path("../", __FILE__)) do
      assert_raises(Riml::UserArgumentError) do
        compile(riml)
      end
    end
  end

  test "riml_include raises error if not called from top-level" do
    riml = <<Riml
if includeFile1
  riml_include 'file1.riml'
end
Riml
    assert_raises(Riml::IncludeNotTopLevel) do
      compile(riml)
    end
  end

  test "riml_source raises ArgumentError if argument not a string" do
    riml = "riml_source file"
    assert_raises(Riml::UserArgumentError) do
      compile(riml)
    end

    riml2 = "riml_source"
    assert_raises(Riml::UserArgumentError) do
      compile(riml2)
    end
  end

  test "riml_include raises ArgumentError if argument not a string" do
    riml = "riml_include file"
    assert_raises(Riml::UserArgumentError) do
      compile(riml)
    end

    riml2 = "riml_include"
    assert_raises(Riml::UserArgumentError) do
      compile(riml2)
    end
  end

  test "riml_source only compiles a sourced file once per compilation process, across all files that reference each other" do
    riml = <<RIML
riml_source 'sourced1.riml'
RIML
    expected = "source sourced1.vim\n"
    with_riml_source_path(File.expand_path("../", __FILE__)) do
      with_file_cleanup('sourced1.vim', 'sourced2.vim') do
        assert_equal expected, compile(riml)
        assert File.exist?(File.join(Riml.source_path.first, 'sourced1.vim'))
        assert File.exist?(File.join(Riml.source_path.first, 'sourced2.vim'))
      end
    end
  end

  test "Riml.source_path looks up files in source_path order and riml_source outputs them in proper directory" do
    riml = <<RIML
riml_source 'sourced1.riml'
RIML
    expected = "source sourced1.vim\n"
    with_riml_source_path(File.expand_path("../test_source_path", __FILE__), File.expand_path("../", __FILE__)) do
      with_file_cleanup('sourced2.vim', 'sourced1.vim') do
        assert_equal expected, compile(riml)
        assert File.exist?(File.join(Riml.source_path.first, 'sourced2.vim')) # in test_source_path dir
        assert File.exist?(File.join(Riml.source_path[1], 'sourced1.vim'))
      end
    end
  end

  test "riml_source grabs all classes defined in the files it sources before any compilation takes place" do
    riml = <<RIML
riml_source 'class_test_main.riml'
RIML
    expected = "source class_test_main.vim\n"
    with_riml_source_path(File.expand_path("../", __FILE__)) do
      with_file_cleanup('class_test_main.vim', 'class_test.vim') do
        assert_equal expected, compile(riml)
        assert File.exist?(File.join(Riml.source_path.first, 'class_test_main.vim'))
        assert File.exist?(File.join(Riml.source_path.first, 'class_test.vim'))
        assert_equal Riml::FILE_HEADER + Riml::GET_SID_FUNCTION_SRC + File.read(File.join(Riml.source_path.first, 'class_test_main_expected.vim')),
                     File.read(File.join(Riml.source_path.first, 'class_test_main.vim'))
        assert_equal Riml::FILE_HEADER + Riml::GET_SID_FUNCTION_SRC + File.read(File.join(Riml.source_path.first, 'class_test_expected.vim')),
                     File.read(File.join(Riml.source_path.first, 'class_test.vim'))
      end
    end
  end

  test "riml_include allows leaving '.riml' off the included file name" do
    with_riml_include_path(File.expand_path("../", __FILE__)) do
      riml = 'riml_include "file1"'
      assert compile(riml)
    end
  end

  test "riml_source allows leaving '.riml' off the sourced file name" do
    with_riml_source_path(File.expand_path("../", __FILE__)) do
      with_file_cleanup('file1.vim') do
        riml = 'riml_source "file1"'
        expected = "source file1.vim\n"
        assert_equal expected, compile(riml)
        assert File.exist?(File.join(Riml.source_path.first, 'file1.vim'))
      end
    end
  end

  test "included files get cached in Riml.include_cache during compilation run" do
    with_riml_include_path(File.expand_path("../", __FILE__)) do
      riml = <<Riml
riml_include "file1.riml"
riml_include "file1.riml"
riml_include "riml_include_lib.riml"
Riml
      with_mock_include_cache do |cache|
        # During single compilation run, compiler checks if already included a
        # file, so the compiler should only call `Riml.include_cache.fetch` once
        # per file included.
        cache.expects(:fetch).yields(true).with('file1.riml').once
        cache.expects(:fetch).yields(true).with('riml_include_lib.riml').once
        cache.expects(:fetch).yields(true).with('riml_include_lib2.riml').once
        assert compile(riml)
      end
    end
  end

  test "Riml.include_cache is not cleared between compilation runs" do
    with_riml_include_path(File.expand_path("../", __FILE__)) do
      riml = <<Riml
riml_include "file1.riml"
riml_include "file1.riml"
riml_include "riml_include_lib.riml"
Riml
      with_mock_include_cache do |cache|
        cache.expects(:fetch).yields(true).with('file1.riml').twice
        cache.expects(:fetch).yields(true).with('riml_include_lib.riml').twice
        cache.expects(:fetch).yields(true).with('riml_include_lib2.riml').twice
        cache.expects(:clear).never
        2.times { compile(riml) }
      end
    end
  end

  # `riml_import tests`

  test "riml_import allows using imported class" do
    riml = <<Riml
riml_import g:Animal
animal = new g:Animal('cat', 'black', 'boomer')
Riml
    expected = <<Viml
let s:animal = g:AnimalConstructor('cat', 'black', 'boomer')
Viml

    assert_equal expected, compile(riml)
  end

  test "riml_import allows importing multiple classes" do
    riml = <<Riml
riml_import g:ASCIIArtFormatter, g:StringGenerator
str_g = new g:StringGenerator()
formatter = new g:ASCIIArtFormatter()
echo formatter.format(str_g.generate())
Riml
    assert compile(riml)
  end

  test "riml_import can be given classes with or without g: scope modifier" do
    riml = <<Riml
riml_import ASCIIArtFormatter, StringGenerator
str_g = new g:StringGenerator()
formatter = new g:ASCIIArtFormatter()
echo formatter.format(str_g.generate())
Riml
    assert compile(riml)
  end

  test "riml_import can be given strings with globbed characters to match classes" do
    riml = <<Riml
riml_import 'MyNamespace*', ActualClass
objA = new g:MyNamespaceClassA('globs!')
objB = new g:MyNamespaceClassB('omg!')
actualObj = new g:ActualClass()
Riml
    assert compile(riml)
  end

  test "riml_import raises error when string arguments don't contain '*' character" do
    riml = <<Riml
riml_import 'HasToHaveGlobChar'
Riml
    assert_raises Riml::UserArgumentError do
      compile(riml)
    end
  end

  test "extending imported classes smartly does some vim `execute` magic " \
       "to expand parameters to pass to super when no initialize method is " \
       "given to extending class" do

    riml = <<Riml
riml_import Animal
class Dog < g:Animal
end
Riml

    expected = <<Viml
function! s:DogConstructor(...)
  let dogObj = {}
  let __riml_splat_list = a:000
  let __riml_splat_size = len(__riml_splat_list)
  let __riml_splat_str_vars = []
  let __riml_splat_idx = 1
  while __riml_splat_idx <=# __riml_splat_size
    let __riml_splat_var_{__riml_splat_idx} = get(__riml_splat_list, __riml_splat_idx - 1)
    call add(__riml_splat_str_vars, '__riml_splat_var_' . __riml_splat_idx)
    let __riml_splat_idx += 1
  endwhile
  execute 'let l:animalObj = g:AnimalConstructor(' . join(__riml_splat_str_vars, ', ') . ')'
  call extend(dogObj, animalObj)
  return dogObj
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "`riml_include`s get reordered based on dependency resolution for classes" do
    riml = <<Riml
riml_include 'faster_car.riml' " inherits from car, gets included last
riml_include 'car.riml' " gets included first
Riml
    with_riml_include_path(File.expand_path("../", __FILE__)) do
      assert compile(riml)
    end
  end
end
