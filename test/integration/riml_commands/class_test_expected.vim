function! s:SID()
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
function! s:DogLocalConstructor(name)
  let dogLocalObj = {}
  let dogLocalObj.name = a:name
  let dogLocalObj.bark = function('<SNR>' . s:SID() . '_s:DogLocal_bark')
  return dogLocalObj
endfunction
function! <SID>s:DogLocal_bark() dict
  echo "Woof! My name is " . self.name
endfunction
function! g:DogGlobalConstructor(name)
  let dogGlobalObj = {}
  let dogLocalObj = s:DogLocalConstructor(a:name)
  call extend(dogGlobalObj, dogLocalObj)
  let dogGlobalObj.bark = function('<SNR>' . s:SID() . '_s:DogGlobal_bark')
  let dogGlobalObj.DogLocal_bark = function('<SNR>' . s:SID() . '_s:DogLocal_bark')
  return dogGlobalObj
endfunction
function! <SID>s:DogGlobal_bark() dict
  call self.DogLocal_bark()
  echo "global!!!"
endfunction
