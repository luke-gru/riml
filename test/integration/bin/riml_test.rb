require File.expand_path('../../../test_helper', __FILE__)
require 'shellwords'

class BinRimlTest < Riml::TestCase
  EXEC = Shellwords.escape(File.join(Riml::Environment::BINDIR, 'riml'))

  test "compiles riml from stdin to viml on stdout with -s option" do
    pathogen_riml_path = File.expand_path('../../pathogen/pathogen.riml', __FILE__)
    expected = File.read File.expand_path('../../pathogen/pathogen.vim', __FILE__)
    assert_equal expected, `cat #{Shellwords.escape(pathogen_riml_path)} | #{EXEC} -s`
    assert_equal 0, $?.exitstatus
  end

  test "fails when given a file that doesn't exist with -c option" do
    bad_path = './nonexistent_file.riml'
    out, err = capture_subprocess_io do
      system "#{EXEC} -c #{Shellwords.escape(bad_path)}"
    end
    assert_equal 1, $?.exitstatus
    assert out.empty?
    refute err.empty?
  end

  test "compiles riml paths to viml files with -c option, outputting them into cwd" do
    pathogen_riml_path = File.expand_path('../../pathogen/pathogen.riml', __FILE__)
    smartinput_riml_path = File.expand_path('../../smartinput/smartinput.riml', __FILE__)
    Dir.chdir(File.expand_path('../', __FILE__)) do
      with_file_cleanup('./pathogen.vim', './smartinput.vim') do
        system "#{EXEC} -c #{Shellwords.escape(pathogen_riml_path)},#{Shellwords.escape(smartinput_riml_path)}"
        assert_equal 0, $?.exitstatus
        assert File.exists?('./pathogen.vim')
        assert File.exists?('./smartinput.vim')
      end
    end
  end

  test "checks syntax with -k option (success)" do
    source_file = File.expand_path("../../riml_commands/file1.riml", __FILE__)
    out, err = capture_subprocess_io do
      system "#{EXEC} -k #{Shellwords.escape(source_file)}"
    end
    assert_equal 0, $?.exitstatus
    assert err.empty?
    assert_match(/ok/, out)
    assert_match(/\(1 file\)/,  out)
  end

  test "checks syntax with -k option (failure)" do
    source_file = File.expand_path("../../riml_commands/compiler_test.rb", __FILE__)
    out, err = capture_subprocess_io do
      system "#{EXEC} -k #{Shellwords.escape(source_file)}"
    end
    assert_equal 1, $?.exitstatus
    refute err.empty?
    assert out.empty?
  end
end
