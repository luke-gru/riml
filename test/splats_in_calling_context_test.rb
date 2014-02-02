require File.expand_path('../test_helper', __FILE__)

module Riml
class SplatsInCallingContextTest < Riml::TestCase
  test "explicit splat in base class inside initialize using super with splat arg" do
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

  test "explicit splat in base class inside initialize using super with variable arg" do
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

  test "explicit splat in base class inside member function using super with splat arg" do
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
  call call('<SNR>' . s:SID() . '_s:Animal_bark', a:000, self)
endfunction
let s:d = s:DogConstructor('otis', 'golden')
call s:d.bark('woof!')
Viml
    assert_equal expected, compile(riml)
  end

  test "implicit splat in base class inside member function using super" do
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
  call call('<SNR>' . s:SID() . '_s:Animal_bark', a:000, self)
endfunction
let s:d = s:DogConstructor('otis', 'golden')
call s:d.bark('woof!')
Viml
    assert_equal expected, compile(riml)
  end

  test "explicit splat in base class inside member function using super with splatted expression (splat_arg at beg of expr list)" do
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
  call call('<SNR>' . s:SID() . '_s:Animal_bark', (a:000 + [a:count]), self)
endfunction
let s:d = s:DogConstructor('otis', 'golden')
call s:d.bark(2, 'arg1')
Viml

    assert_equal expected, compile(riml)
  end

  test "explicit splat in base class inside private function using super with splat arg" do
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

  test "implicit splat in base class inside private function using super" do
    riml = <<Riml
class A
  def private_func(*args)
    echo args
  end
end

class B < A
  def private_func(*args)
    super
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

  test "explicit splat in base class inside private function using expression with splat arg at end of expr list" do
    riml = <<Riml
class A
  def private_func(*args)
    echo args
  end
end

class B < A
  def private_func(*args)
    super(*(['first_arg'] + args))
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
  call call('s:A_private_func', [a:bObj] + (['first_arg'] + a:000))
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "explicit splat in base class inside private function using expression with splat arg at beg of expr list" do
    riml = <<Riml
class A
  def private_func(*args)
    echo args
  end
end

class B < A
  def private_func(*args)
    super(*(args + ['first_arg']))
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
  call call('s:A_private_func', [a:bObj] + (a:000 + ['first_arg']))
endfunction
Viml

    assert_equal expected, compile(riml)
  end

  test "splat with variable" do
    riml = <<Riml
call some_func(*vars)
Riml
    expected = <<Viml
call call('s:some_func', s:vars)
Viml

    assert_equal expected, compile(riml)
  end

  test "splat with variable in assignment expression" do
    riml = <<Riml
a = some_func(*vars)
Riml
    expected = <<Viml
let s:a = call('s:some_func', s:vars)
Viml

    assert_equal expected, compile(riml)
  end

  test "passing on splatted arguments to constructor function with 's:' scope modifier" do
    riml = <<Riml
class Foo
end
def foo(*args)
  let foo = new Foo(*args)
end
Riml

    expected = <<Viml
function! s:FooConstructor()
  let fooObj = {}
  return fooObj
endfunction
function! s:foo(...)
  let foo = call('s:FooConstructor', a:000)
endfunction
Viml
    assert_equal expected, compile(riml)
  end

  test "passing on splatted arguments to constructor function with 'g:' scope modifier" do
    riml = <<Riml
class g:Foo
end
def foo(*args)
  let foo = new g:Foo(*args)
end
Riml

    expected = <<Viml
function! g:FooConstructor()
  let fooObj = {}
  return fooObj
endfunction
function! s:foo(...)
  let foo = call('g:FooConstructor', a:000)
endfunction
Viml
    assert_equal expected, compile(riml)
  end

end
end
