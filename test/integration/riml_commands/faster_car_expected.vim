function! s:FasterCarConstructor(...)
  let fasterCarObj = {}
  let carObj = s:CarConstructor(a:000)
  call extend(fasterCarObj, carObj)
  let fasterCarObj.maxSpeed = 200
  return fasterCarObj
endfunction
