require File.expand_path('../../../test_helper', __FILE__)
require 'shellwords'
require 'fileutils'

class BinRimlTest < Riml::TestCase
  EXEC = Shellwords.escape(File.join(Riml::Environment::BINDIR, 'riml'))

  test "compiles riml from stdin to viml on stdout with -s option" do
    pathogen_riml_path = File.expand_path('../../pathogen/pathogen.riml', __FILE__)
    expected = File.read File.expand_path('../../pathogen/pathogen.vim', __FILE__)
    assert_equal expected, `cat #{Shellwords.escape(pathogen_riml_path)} | #{EXEC} -s -d`
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
    Dir.chdir(File.expand_path('../', __FILE__)) do
      with_file_cleanup('./pathogen.vim', './smartinput.vim') do
        system "#{EXEC} -c ../pathogen/pathogen.riml,../smartinput/smartinput.riml"
        assert_equal 0, $?.exitstatus
        assert File.exists?('./pathogen.vim')
        assert File.exists?('./smartinput.vim')
      end
    end
  end

  test "checks syntax with -k option (success)" do
    Dir.chdir(File.expand_path("../../riml_commands", __FILE__)) do
      out, err = capture_subprocess_io do
        system "#{EXEC} -k file1.riml"
      end
      assert_equal 0, $?.exitstatus
      assert err.empty?
      assert_match(/ok/, out)
      assert_match(/\(1 file\)/,  out)
    end
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

  test "sets source path with -S option" do
    riml_commands_dir = File.expand_path("../../riml_commands", __FILE__)
    sourced1_vim_path = './sourced1.vim'
    sourced2_vim_path = File.join(riml_commands_dir, 'sourced2.vim')
    Dir.chdir(File.expand_path("../", __FILE__)) do
      begin
        system "#{EXEC} -S #{riml_commands_dir} -c ../riml_commands/sourced1.riml"
        assert_equal 0, $?.exitstatus
        assert File.exists?(sourced1_vim_path)
        assert File.exists?(sourced2_vim_path)
      ensure
        File.delete(sourced1_vim_path) if File.exists?(sourced1_vim_path)
        File.delete(sourced2_vim_path) if File.exists?(sourced2_vim_path)
      end
    end
  end

  test "sets source_path with RIML_SOURCE_PATH env. variable" do
    riml_commands_dir = File.expand_path("../../riml_commands", __FILE__)
    sourced1_vim_path = './sourced1.vim'
    sourced2_vim_path = File.join(riml_commands_dir, 'sourced2.vim')
    Dir.chdir(File.expand_path("../", __FILE__)) do
      begin
        ENV['RIML_SOURCE_PATH'] = riml_commands_dir
        system "#{EXEC} -c ../riml_commands/sourced1.riml"
        assert_equal 0, $?.exitstatus
        assert File.exists?(sourced1_vim_path)
        assert File.exists?(sourced2_vim_path)
      ensure
        File.delete(sourced1_vim_path) if File.exists?(sourced1_vim_path)
        File.delete(sourced2_vim_path) if File.exists?(sourced2_vim_path)
        ENV['RIML_SOURCE_PATH'] = nil
      end
    end
  end

  test "sets include_path with -I option" do
    riml_commands_dir = File.expand_path("../../riml_commands", __FILE__)
    include1_vim_path = './riml_include_lib.vim'
    include2_vim_path = '../riml_commands/riml_include_lib2.vim'
    Dir.chdir(File.expand_path("../", __FILE__)) do
      begin
        system "#{EXEC} -I #{riml_commands_dir} -c ../riml_commands/riml_include_lib.riml"
        assert_equal 0, $?.exitstatus
        assert File.exists?(include1_vim_path)
        refute File.exists?(include2_vim_path)
      ensure
        File.delete(include1_vim_path) if File.exists?(include1_vim_path)
        File.delete(include2_vim_path) if File.exists?(include2_vim_path)
      end
    end
  end

  test "sets include_path with RIML_INCLUDE_PATH env. variable" do
    riml_commands_dir = File.expand_path("../../riml_commands", __FILE__)
    include1_vim_path = './riml_include_lib.vim'
    include2_vim_path = '../riml_commands/riml_include_lib2.vim'
    Dir.chdir(File.expand_path("../", __FILE__)) do
      begin
        ENV['RIML_INCLUDE_PATH'] = riml_commands_dir
        system "#{EXEC} -c ../riml_commands/riml_include_lib.riml"
        assert_equal 0, $?.exitstatus
        assert File.exists?(include1_vim_path)
        refute File.exists?(include2_vim_path)
      ensure
        File.delete(include1_vim_path) if File.exists?(include1_vim_path)
        File.delete(include2_vim_path) if File.exists?(include2_vim_path)
        ENV['RIML_INCLUDE_PATH'] = nil
      end
    end
  end

  test "aborts if Riml.source_path is set with -S option and one of the dirs doesn't exist" do
    riml_commands_dir = File.expand_path("../../riml_commands", __FILE__)
    sourced1_vim_path = './sourced1.vim'
    sourced2_vim_path = File.join(riml_commands_dir, 'sourced2.vim')
    Dir.chdir(File.expand_path("../", __FILE__)) do
      begin
        _, err = capture_subprocess_io do
          system "#{EXEC} -S #{riml_commands_dir}/nonexistent_dir -c ../riml_commands/sourced1.riml"
        end
        assert_equal 1, $?.exitstatus
        assert err =~ /error trying to set source_path/i
        refute File.exists?(sourced1_vim_path)
        refute File.exists?(sourced2_vim_path)
      ensure
        File.delete(sourced1_vim_path) if File.exists?(sourced1_vim_path)
        File.delete(sourced2_vim_path) if File.exists?(sourced2_vim_path)
      end
    end
  end

  test "aborts if Riml.include_path is set with -I option and one of the dirs doesn't exist" do
    riml_commands_dir = File.expand_path("../../riml_commands", __FILE__)
    include1_vim_path = './riml_include_lib.vim'
    include2_vim_path = '../riml_commands/riml_include_lib2.vim'
    Dir.chdir(File.expand_path("../", __FILE__)) do
      begin
        _, err = capture_subprocess_io do
          system "#{EXEC} -I #{riml_commands_dir}:nonexistent_dir -c ../riml_commands/riml_include_lib.riml"
        end
        assert_equal 1, $?.exitstatus
        assert err =~ /error trying to set include_path/i
        refute File.exists?(include1_vim_path)
        refute File.exists?(include2_vim_path)
      ensure
        File.delete(include1_vim_path) if File.exists?(include1_vim_path)
        File.delete(include2_vim_path) if File.exists?(include2_vim_path)
      end
    end
  end

  test "--output-dir option outputs all .vim files into specified dir and mirrors the input file structure" do
    Dir.chdir(File.expand_path("../", __FILE__)) do
      begin
        system "#{EXEC} -c test_output_dir.riml -o newdir -S test_output_dir"
        assert_equal 0, $?.exitstatus
        assert File.exists?('./newdir/test_output_dir.vim')
        assert File.exists?('./newdir/test_output_dir/sourced.vim')
        refute File.exists?('./test_output_dir.vim')
        refute File.exists?('./test_output_dir/sourced.vim')
      ensure
        FileUtils.rm_r 'newdir' if File.directory?('newdir')
      end
    end
  end

  test "--allow-undef-global-classes option keeps on compiling when hitting undefined global class" do
    Dir.chdir(File.expand_path("../", __FILE__)) do
      begin
        system "#{EXEC} --allow-undef-global-classes -c undefined_global_class.riml"
        assert_equal 0, $?.exitstatus
        assert File.exists?('./undefined_global_class.vim')
      ensure
        File.delete('./undefined_global_class.vim') if File.exists?('./undefined_global_class.vim')
      end
    end
  end

end
