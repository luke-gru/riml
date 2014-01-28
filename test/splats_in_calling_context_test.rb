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
  let animalObj = call('s:AnimalConstructor', a:000)
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
  let animalObj = call('s:AnimalConstructor', splat_args)
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
  call call('Animal_bark', a:000, self)
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
  call call('Animal_bark', a:000, self)
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
  call call('Animal_bark', (args + [count]), self)
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
  call call('s:A_private_func', [a:bObj] + a:000)
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "non-super function call" do
    riml = <<Riml
call some_func(*vars)
Riml
    expected = <<Viml
call call('s:some_func', vars)
Viml

    assert_equal expected, compile(riml)
  end

  test "non-super function call with assignment" do
    riml = <<Riml
a = some_func(*vars)
Riml
    expected = <<Viml
let s:a = call('s:some_func', vars)
Viml

    assert_equal expected, compile(riml)
  end

  test "non-super function call with assignment doesn't override assignment scope modifier if present" do
    riml = <<Riml
g:a = some_func(*vars)
Riml
    expected = <<Viml
let g:a = call('s:some_func', vars)
Viml

    assert_equal expected, compile(riml)
  end

  test "calling 2 functions with splats in same scope reuses same variable names" do
    riml = <<Riml
some_func(*vars)
some_func(*vars)
Riml
    expected = <<Viml
call call('s:some_func', vars)
call call('s:some_func', vars)
Viml

    assert_equal expected, compile(riml)
  end

end
end
