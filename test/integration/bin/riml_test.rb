require File.expand_path('../../../test_helper', __FILE__)

class BinRimlTest < Riml::TestCase
  EXEC = File.join(Riml::Environment::BINDIR, 'riml')

  test "compiles riml from stdin to viml on stdout with -s option" do
    pathogen_riml_path = File.expand_path('../../pathogen/pathogen.riml', __FILE__)
    expected = File.read File.expand_path('../../pathogen/pathogen.vim', __FILE__)
    assert_equal expected, `cat #{pathogen_riml_path} | #{EXEC} -s`
    assert_equal 0, $?.exitstatus
  end

  test "fails when given a file that doesn't exist with -c option" do
    bad_path = './nonexistent_file.riml'
    out, err = capture_subprocess_io do
      `#{EXEC} -c #{bad_path}`
    end
    assert_equal 1, $?.exitstatus
    assert out.empty?
    refute err.empty?
  end

  test "compiles riml paths to viml files with -c option, outputting them into cwd" do
    pathogen_riml_path = File.expand_path('../../pathogen/pathogen.riml', __FILE__)
    smartinput_riml_path = File.expand_path('../../smartinput/smartinput.riml', __FILE__)
    Dir.chdir(File.expand_path('../', __FILE__)) do
      with_file_cleanup('./pathogen.vim', 'smartinput.vim') do
        `#{EXEC} -c #{pathogen_riml_path},#{smartinput_riml_path}`
        assert_equal 0, $?.exitstatus
        assert File.exists?('./pathogen.vim')
        assert File.exists?('./smartinput.vim')
      end
    end
  end
end
