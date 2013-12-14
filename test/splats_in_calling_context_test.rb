require File.expand_path('../test_helper', __FILE__)

module Riml
class SplatsInCallingContextTest < Riml::TestCase
  test "splat in calling context in initialize function using splat param with call to `super`" do
    riml = <<Riml
class Animal
  def initialize(name, color)
    self.name = name
    self.color = color
  end
end

class Dog < Animal
  def initialize(*args)
    super({{SPLAT_ARGUMENT}})
  end

  defm bark
    echo "woof, I am a \#{self.color} dog named \#{self.name}."
  end
end

d = new Dog('otis', 'golden')
d.bark()
Riml

    expected = <<Viml
function! s:AnimalConstructor(name, color)
  let animalObj = {}
  let animalObj.name = a:name
  let animalObj.color = a:color
  return animalObj
endfunction
function! s:DogConstructor(...)
  let dogObj = {}
  let __riml_splat_list = a:000
  let __riml_splat_size = len(__riml_splat_list)
  let __riml_splat_str_vars = []
  let __riml_splat_idx = 1
  while __riml_splat_idx <=# __riml_splat_size
    let __riml_splat_var_{__riml_splat_idx} = get(__riml_splat_list, __riml_splat_idx - 1)
    call add(__riml_splat_str_vars, '__riml_splat_var_' . __riml_splat_idx)
    let __riml_splat_idx += 1
  endwhile
  execute 'let l:animalObj = s:AnimalConstructor(' . join(__riml_splat_str_vars, ', ') . ')'
  call extend(dogObj, animalObj)
  let dogObj.bark = function('<SNR>' . s:SID() . '_s:Dog_bark')
  return dogObj
endfunction
function! <SID>s:Dog_bark() dict
  echo "woof, I am a " . self.color . " dog named " . self.name . "."
endfunction
let s:d = s:DogConstructor('otis', 'golden')
call s:d.bark()
Viml

    splat_arguments = ['*args', '*a:000']
    splat_arguments.each do |splat_argument|
      assert_equal expected, compile(riml.sub('{{SPLAT_ARGUMENT}}', splat_argument))
    end
  end

  test "splat in calling context in initialize function without using splat param with call to `super`" do
    riml = <<Riml
class Animal
  def initialize(name, color)
    self.name = name
    self.color = color
  end
end

class Dog < Animal
  def initialize(*args)
    splat_args = args
    super(*splat_args)
  end

  defm bark
    echo "woof, I am a \#{self.color} dog named \#{self.name}."
  end
end

d = new Dog('otis', 'golden')
d.bark()
Riml
    expected = <<Viml
function! s:AnimalConstructor(name, color)
  let animalObj = {}
  let animalObj.name = a:name
  let animalObj.color = a:color
  return animalObj
endfunction
function! s:DogConstructor(...)
  let dogObj = {}
  let splat_args = a:000
  let __riml_splat_list = splat_args
  let __riml_splat_size = len(__riml_splat_list)
  let __riml_splat_str_vars = []
  let __riml_splat_idx = 1
  while __riml_splat_idx <=# __riml_splat_size
    let __riml_splat_var_{__riml_splat_idx} = get(__riml_splat_list, __riml_splat_idx - 1)
    call add(__riml_splat_str_vars, '__riml_splat_var_' . __riml_splat_idx)
    let __riml_splat_idx += 1
  endwhile
  execute 'let l:animalObj = s:AnimalConstructor(' . join(__riml_splat_str_vars, ', ') . ')'
  call extend(dogObj, animalObj)
  let dogObj.bark = function('<SNR>' . s:SID() . '_s:Dog_bark')
  return dogObj
endfunction
function! <SID>s:Dog_bark() dict
  echo "woof, I am a " . self.color . " dog named " . self.name . "."
endfunction
let s:d = s:DogConstructor('otis', 'golden')
call s:d.bark()
Viml

    assert_equal expected, compile(riml)
  end

  test "splat in calling context in non-initialize function using splat param with call to `super`" do
    riml = <<Riml
class Animal
  def initialize(name, color)
    self.name = name
    self.color = color
  end

  defm bark(*args)
    echo args
  end
end

class Dog < Animal
  defm bark(*args)
    super(*args)
  end
end

d = new Dog('otis', 'golden')
d.bark('woof!')
Riml
    expected = <<Viml
function! s:AnimalConstructor(name, color)
  let animalObj = {}
  let animalObj.name = a:name
  let animalObj.color = a:color
  let animalObj.bark = function('<SNR>' . s:SID() . '_s:Animal_bark')
  return animalObj
endfunction
function! <SID>s:Animal_bark(...) dict
  echo a:000
endfunction
function! s:DogConstructor(name, color)
  let dogObj = {}
  let animalObj = s:AnimalConstructor(a:name, a:color)
  call extend(dogObj, animalObj)
  let dogObj.bark = function('<SNR>' . s:SID() . '_s:Dog_bark')
  let dogObj.Animal_bark = function('<SNR>' . s:SID() . '_s:Animal_bark')
  return dogObj
endfunction
function! <SID>s:Dog_bark(...) dict
  let __riml_splat_list = a:000
  let __riml_splat_size = len(__riml_splat_list)
  let __riml_splat_str_vars = []
  let __riml_splat_idx = 1
  while __riml_splat_idx <=# __riml_splat_size
    let __riml_splat_var_{__riml_splat_idx} = get(__riml_splat_list, __riml_splat_idx - 1)
    call add(__riml_splat_str_vars, '__riml_splat_var_' . __riml_splat_idx)
    let __riml_splat_idx += 1
  endwhile
  execute 'call self.Animal_bark(' . join(__riml_splat_str_vars, ', ') . ')'
endfunction
let s:d = s:DogConstructor('otis', 'golden')
call s:d.bark('woof!')
Viml
    assert_equal expected, compile(riml)
  end

  test "implicit splat in calling context in non-initialize function with call to `super`" do
    riml = <<Riml
class Animal
  def initialize(name, color)
    self.name = name
    self.color = color
  end

  defm bark(*args)
    echo args
  end
end

class Dog < Animal
  defm bark(*args)
    super
  end
end

d = new Dog('otis', 'golden')
d.bark('woof!')
Riml
    expected = <<Viml
function! s:AnimalConstructor(name, color)
  let animalObj = {}
  let animalObj.name = a:name
  let animalObj.color = a:color
  let animalObj.bark = function('<SNR>' . s:SID() . '_s:Animal_bark')
  return animalObj
endfunction
function! <SID>s:Animal_bark(...) dict
  echo a:000
endfunction
function! s:DogConstructor(name, color)
  let dogObj = {}
  let animalObj = s:AnimalConstructor(a:name, a:color)
  call extend(dogObj, animalObj)
  let dogObj.bark = function('<SNR>' . s:SID() . '_s:Dog_bark')
  let dogObj.Animal_bark = function('<SNR>' . s:SID() . '_s:Animal_bark')
  return dogObj
endfunction
function! <SID>s:Dog_bark(...) dict
  let __riml_splat_list = a:000
  let __riml_splat_size = len(__riml_splat_list)
  let __riml_splat_str_vars = []
  let __riml_splat_idx = 1
  while __riml_splat_idx <=# __riml_splat_size
    let __riml_splat_var_{__riml_splat_idx} = get(__riml_splat_list, __riml_splat_idx - 1)
    call add(__riml_splat_str_vars, '__riml_splat_var_' . __riml_splat_idx)
    let __riml_splat_idx += 1
  endwhile
  execute 'call self.Animal_bark(' . join(__riml_splat_str_vars, ', ') . ')'
endfunction
let s:d = s:DogConstructor('otis', 'golden')
call s:d.bark('woof!')
Viml
    assert_equal expected, compile(riml)
  end

  test "explicit splat with non-variable splat expression" do
    riml = <<Riml
class Animal
  def initialize(name, color)
    self.name = name
    self.color = color
  end

  defm bark(*args)
    echo args
  end
end

class Dog < Animal
  defm bark(count, *args)
    super(*(args + [count]))
  end
end

d = new Dog('otis', 'golden')
d.bark(2, 'arg1')
Riml
    expected = <<Viml
function! s:AnimalConstructor(name, color)
  let animalObj = {}
  let animalObj.name = a:name
  let animalObj.color = a:color
  let animalObj.bark = function('<SNR>' . s:SID() . '_s:Animal_bark')
  return animalObj
endfunction
function! <SID>s:Animal_bark(...) dict
  echo a:000
endfunction
function! s:DogConstructor(name, color)
  let dogObj = {}
  let animalObj = s:AnimalConstructor(a:name, a:color)
  call extend(dogObj, animalObj)
  let dogObj.bark = function('<SNR>' . s:SID() . '_s:Dog_bark')
  let dogObj.Animal_bark = function('<SNR>' . s:SID() . '_s:Animal_bark')
  return dogObj
endfunction
function! <SID>s:Dog_bark(count, ...) dict
  let __riml_splat_list = (a:000 + [a:count])
  let __riml_splat_size = len(__riml_splat_list)
  let __riml_splat_str_vars = []
  let __riml_splat_idx = 1
  while __riml_splat_idx <=# __riml_splat_size
    let __riml_splat_var_{__riml_splat_idx} = get(__riml_splat_list, __riml_splat_idx - 1)
    call add(__riml_splat_str_vars, '__riml_splat_var_' . __riml_splat_idx)
    let __riml_splat_idx += 1
  endwhile
  execute 'call self.Animal_bark(' . join(__riml_splat_str_vars, ', ') . ')'
endfunction
let s:d = s:DogConstructor('otis', 'golden')
call s:d.bark(2, 'arg1')
Viml

    assert_equal expected, compile(riml)
  end

  test "splat in calling context in private function with call to `super`" do
    riml = <<Riml
class A
  def private_func(*args)
    echo args
  end
end

class B < A
  def private_func(*args)
    super(*args)
  end
end
Riml
    expected = <<Viml
function! s:AConstructor()
  let aObj = {}
  return aObj
endfunction
function! s:A_private_func(aObj, ...)
  echo a:000
endfunction
function! s:BConstructor()
  let bObj = {}
  let aObj = s:AConstructor()
  call extend(bObj, aObj)
  return bObj
endfunction
function! s:B_private_func(bObj, ...)
  let __riml_splat_list = ([a:bObj] + a:000)
  let __riml_splat_size = len(__riml_splat_list)
  let __riml_splat_str_vars = []
  let __riml_splat_idx = 1
  while __riml_splat_idx <=# __riml_splat_size
    let __riml_splat_var_{__riml_splat_idx} = get(__riml_splat_list, __riml_splat_idx - 1)
    call add(__riml_splat_str_vars, '__riml_splat_var_' . __riml_splat_idx)
    let __riml_splat_idx += 1
  endwhile
  execute 'call s:A_private_func(' . join(__riml_splat_str_vars, ', ') . ')'
endfunction
Viml
    assert_equal expected, compile(riml)
  end

end
end
