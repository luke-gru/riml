require File.expand_path('../../../test_helper', __FILE__)

class SmartInputCompilerTest < Riml::TestCase
  test "parses without error" do
    source = File.read File.expand_path("../smart_input.riml", __FILE__)
    assert compile(source)
    #puts("\n")
    #compile(source).each_line do |line| puts line end
  end

  test "wrong newline insertion" do
    riml = <<Riml
if (stridx(nrule.mode, a:cl_type) ==# -1)
endif
Riml

    expected = <<Viml
if (stridx(s:nrule.mode, a:cl_type) ==# -1)
endif
Viml
    assert_equal expected, compile(riml)
  end

  test "again, wrong newline insertion" do
    riml = <<Riml
let nrule.hash = string([
\\   printf('%06d', nrule.priority),
\\   nrule.at,
\\   nrule.char,
\\   nrule.filetype,
\\   nrule.syntax
\\ ])
Riml

    expected = <<Viml
let s:nrule.hash = string([printf('%06d', s:nrule.priority), s:nrule.at, s:nrule.char, s:nrule.filetype, s:nrule.syntax])
Viml
    assert_equal expected, compile(riml)
  end

  test "problem with dictionaries" do
    riml = <<Riml
if a:nrule.hash ==# a:sorted_nrules[i_med].hash
  break
elseif !(a:nrule.hash <# a:sorted_nrules[i_med].hash)
  let i_max = i_med - 1
else
  let i_min = i_med + 1
endif
Riml

    expected = <<Viml
if (a:nrule.hash ==# a:sorted_nrules[s:i_med].hash)
  break
elseif (!a:nrule.hash <# a:sorted_nrules[s:i_med].hash)
  let s:i_max = s:i_med - 1
else
  let s:i_min = s:i_med + 1
endif
Viml
    assert_equal expected, compile(riml)
  end

end
