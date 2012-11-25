function! g:FasterCarConstructor(...)
  let fasterCarObj = {}
  let carObj = g:CarConstructor(*args)
  call extend(fasterCarObj, carObj)
  let fasterCarObj.maxSpeed = 200
  return fasterCarObj
endfunction
