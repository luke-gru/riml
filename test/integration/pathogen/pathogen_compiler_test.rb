require File.expand_path('../../../test_helper', __FILE__)

class PathogenCompilerTest < Riml::TestCase
  test "compiles without error" do
    #source = File.read File.expand_path("../pathogen.riml", __FILE__)
    #assert compile(source)
    #puts("\n")
    #compile(source).each_line do |line| puts line end
  end

  test "function that tripped up compiler" do
    riml = <<Riml
" Convert a list to a path.
function! pathogen#join(...) abort " {{{1
  if type(a:1) == type(1) && a:1
    let i = 1
    let space = ' '
  else
    let i = 0
    let space = ''
  endif
  let path = ""
  while i < a:0
    if type(a:000[i]) == type([])
      let list = a:000[i]
      let j = 0
      while j < len(list)
        let escaped = substitute(list[j],'[,'.space.']\|\\[\,'.space.']\@=','\\&','g')
        let path .= ',' . escaped
        let j += 1
      endwhile
    else
      let path .= "," . a:000[i]
    endif
    let i += 1
  endwhile
  return substitute(path,'^,','','')
endfunction " }}}1
Riml

    expected = <<Viml
function! s:pathogen#join(...) abort
  if type(a:1) ==# type(1) && a:1
    let i = 1
    let space = ' '
  else
    let i = 0
    let space = ''
  endif
  let path = ""
  while i <# a:0
    if type(a:000[i]) ==# type([])
      let list = a:000[i]
      let j = 0
      while j <# len(list)
        let escaped = substitute(list[j], '[,' . space . ']\|\\[\,' . space . ']\@=', '\\&', 'g')
        let path .= ',' . escaped
        let j += 1
      endwhile
    else
      let path .= "," . a:000[i]
    endif
    let i += 1
  endwhile
  return substitute(path, '^,', '', '')
endfunction
Viml
    assert_equal expected, compile(riml)
  end
end
