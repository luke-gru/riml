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
  execute 'let l:animalObj = s:AnimalConstructor(' . join(map(copy(a:000), '"''" . v:val . "''"'), ', ') . ')'
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
  execute 'let l:animalObj = s:AnimalConstructor(' . join(map(copy(splat_args), '"''" . v:val . "''"'), ', ') . ')'
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
  execute 'call self.Animal_bark(' . join(map(copy(a:000), '"''" . v:val . "''"'), ', ') . ')'
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
  execute 'call self.Animal_bark(' . join(map(copy(a:000), '"''" . v:val . "''"'), ', ') . ')'
endfunction
let s:d = s:DogConstructor('otis', 'golden')
call s:d.bark('woof!')
Viml
    assert_equal expected, compile(riml)
  end

end
end
