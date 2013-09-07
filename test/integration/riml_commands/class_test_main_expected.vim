function! s:SID()
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
source class_test.vim
let s:dog = g:DogGlobalConstructor('otis')
call s:dog.bark()
