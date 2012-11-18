require File.expand_path('../../../test_helper', __FILE__)

class PathogenCompilerTest < Riml::TestCase
  test "compiles without error" do
    source = File.read File.expand_path("../pathogen.riml", __FILE__)
    assert compile(source)
    #puts("\n")
    #compile(source).each_line do |line| puts line end
  end

  test "&& operator tripped up lexer, was shadowed by '&' SPECIAL_VAR_PREFIX" do
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

  test "call statement without a name tripped up parser" do
    riml = <<Riml
" Convert a list to a path with escaped spaces for 'path', 'tag', etc.
function! pathogen#legacyjoin(...) abort " {{{1
  return call('pathogen#join',[1] + a:000)
endfunction " }}}1
Riml

    expected = <<Viml
function! s:pathogen#legacyjoin(...) abort
  return call('pathogen#join', [1] + a:000)
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "elseif without an else tripped up parser" do
    riml = <<Riml
" Checks if a bundle is 'disabled'. A bundle is considered 'disabled' if
" its 'basename()' is included in g:pathogen_disabled[]' or ends in a tilde.
function! pathogen#is_disabled(path) " {{{1
  if a:path =~# '\~$'
    return 1
  elseif !exists("g:pathogen_disabled")
    return 0
  endif
  let sep = pathogen#separator()
  return index(g:pathogen_disabled, strpart(a:path, strridx(a:path, sep)+1)) != -1
endfunction
Riml

    expected = <<Viml
function! s:pathogen#is_disabled(path)
  if a:path =~# '\~$'
    return 1
  elseif !exists("g:pathogen_disabled")
    return 0
  endif
  let sep = pathogen#separator()
  return index(g:pathogen_disabled, strpart(a:path, strridx(a:path, sep) + 1)) !=# -1
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "tripped up parser" do
    riml = <<Riml
" Prepend all subdirectories of path to the rtp, and append all 'after'
" directories in those subdirectories.
function! pathogen#runtime_prepend_subdirectories(path) " {{{1
  let sep    = pathogen#separator()
  let before = filter(pathogen#glob_directories(a:path . sep . "*"), '!pathogen#is_disabled(v:val)')
  let after  = filter(pathogen#glob_directories(a:path . sep . "*" . sep . "after"), '!pathogen#is_disabled(v:val[0:-7])')
  let rtp = pathogen#split(&rtp)
  let path = expand(a:path)
  call filter(rtp,'v:val[0:strlen(path)-1] !=# path')
  let &rtp = pathogen#join(pathogen#uniq(before + rtp + after))
  return &rtp
endfunction " }}}1
Riml

    expected = <<Viml
function! s:pathogen#runtime_prepend_subdirectories(path)
  let sep = pathogen#separator()
  let before = filter(pathogen#glob_directories(a:path . sep . "*"), '!pathogen#is_disabled(v:val)')
  let after = filter(pathogen#glob_directories(a:path . sep . "*" . sep . "after"), '!pathogen#is_disabled(v:val[0:-7])')
  let rtp = pathogen#split(&rtp)
  let a:path = expand(a:path)
  call filter(rtp, 'v:val[0:strlen(path)-1] !=# path')
  let &rtp = pathogen#join(pathogen#uniq(before + rtp + after))
  return &rtp
endfunction
Viml
    assert_equal expected, compile(riml)
  end
end
