require File.expand_path('../../../test_helper', __FILE__)

class FugitiveCompilerTest < Riml::TestCase
  test "compiles to target" do
    source   = File.read File.expand_path("../fugitive.riml", __FILE__)
    compiled = File.read File.expand_path("../fugitive.vim",  __FILE__)
    viml = nil
    assert_block { viml = compile(source) }
    assert_equal compiled, viml
  end

  test "thought this tripped up the compiler, turns out it didn't." do
    riml = <<Riml
function! s:buffer_type(...) dict abort
  if self.getvar('fugitive_type') != ''
      let type = self.getvar('fugitive_type')
    elseif fnamemodify(self.spec(),':p') =~# '.\git/refs/\|\.git/\w*HEAD$'
      let type = 'head'
    elseif self.getline(1) =~ '^tree \\x\{40\}$' && self.getline(2) == ''
      let type = 'tree'
    elseif self.getline(1) =~ '^\d\{6\} \w\{4\} \\x\{40\}\>\\t'
      let type = 'tree'
    elseif self.getline(1) =~ '^\d\{6\} \\x\{40\}\> \d\\t'
      let type = 'index'
    elseif isdirectory(self.spec())
      let type = 'directory'
    elseif self.spec() == ''
      let type = 'null'
    else
      let type = 'file'
    endif
  if a:0
    return !empty(filter(copy(a:000),'v:val ==# type'))
  else
    return type
  endif
endfunction
Riml

    assert compile(riml)
  end

  test "tripped up lexer, for some reason lexer thought first line was statement modifier" do
    riml = <<Riml
if has('win32')

  function! s:buffer_spec() dict abort
    let bufname = bufname(self['#'])
    let retval = ''
    for i in split(bufname,'[^:]\zs\\\')
      let retval = fnamemodify((retval==''?'':retval.'\').i,':.')
    endfor
    return s:shellslash(fnamemodify(retval,':p'))
  endfunction

else

  function! s:buffer_spec() dict abort
    let bufname = bufname(self['#'])
    return s:shellslash(bufname == '' ? '' : fnamemodify(bufname,':p'))
  endfunction

endif
Riml

    expected = <<Viml
if has('win32')
  function! s:buffer_spec() dict abort
    let bufname = bufname(self['#'])
    let retval = ''
    for i in split(bufname, '[^:]zs\\')
      let retval = fnamemodify((retval ==# '' ? '' : retval . '').i, ':.')
    endfor
    return s:shellslash(fnamemodify(retval, ':p'))
  endfunction
else
  function! s:buffer_spec() dict abort
    let bufname = bufname(self['#'])
    return s:shellslash(bufname ==# '' ? '' : fnamemodify(bufname, ':p'))
  endfunction
endif
Viml

    assert_equal expected, compile(riml)
  end
end
