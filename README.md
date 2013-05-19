[![Build Status](https://secure.travis-ci.org/luke-gru/riml.png?branch=master)](https://travis-ci.org/luke-gru/riml)

Riml, a relaxed Vimscript
====================================

Riml is a subset of Vimscript with some added features, and it compiles to
plain Vimscript. Some of the added features include classes, string interpolation,
heredocs, default case-sensitive string comparison, default parameters
in functions, and other things programmers tend to take for granted.
To see how Riml is compiled to VimL, just take a look at this README. The left
side is Riml, and the right side is the VimL after compilation.

Variables
---------

    count = 1                     let s:count = 1
    while count < 5               while s:count < 5
      source other.vim              source other.vim
      count += 1                    let s:count += 1
    end                           endwhile

If you don't specify a scope modifier (or namespace in Vimspeak), it's script local (s:)
by default in the global scope. Within a function, variables without scope modifiers are plain
old local variables.

###globally

    a = 3                         let s:a = 3

###locally (within function or for loop)

    def exampleFunc(msg)          function! s:exampleFunc(msg)
      a = 3                         let a = 3
      echo msg                      echo a:msg
    end                           endfunction

    for i in expr()               for i in s:expr()
      echo i                        echo i
    end                           endfor

Notice that within a function, it's unnecessary to prefix argument variables
with 'a:'. This is, of course, unless we shadow the argument variable by creating
our own local variable called 'msg'. In that case, we'd have to refer to the argument variable
as 'a:msg' explicitly. Shadowing variables in Riml is considered bad practice, as it's
much easier to just come up with unique variable names across a scope.

###Assignment as Expression

    let a = b = c = 0                   let s:c = 0
                                        let s:b = s:c
                                        let s:a = s:b

The 'let' is optional in Riml for all assignments. Without it, the results are
the same.

###Multiple Assignment Statement

    a = 0, b = 1                        let s:a = 0
                                        let s:b = 1

###Checking for existence

    unless callcount?                     if !exists("s:callcount")
      callcount = 0                        let s:callcount = 0
    end                                   endif
    callcount += 1                        let s:callcount += 1
    echo "called #{callcount} times"      echo "called " . s:callcount . " times"

Notice in the last line of Riml there's string interpolation. This works
in double-quoted strings and heredocs, which we'll encounter later.

In Riml, you can choose to end any block with 'end', or with whatever you used
to do in Vimscript ('endif', 'endfunction', etc...). Also, 'if' and 'unless' can
now be used as statement modifiers:

    callcount = 0 unless callcount?
    callcount += 1
    echo "called #{callcount} times"

Here, the compiled output is the same as the previous example's. Both 'if' and
'unless' can be used this way.

###True and False

    a = true                                      let a = 1
    b = false                                     let b = 0

Operators And Case Sensitivity
------------------------------

    if "hi" == greeting                      if "hi" ==# s:greeting
      echo greeting                            echo s:greeting
    end                                      end

Comparisons compile to case-sensitive by default. To get case-insensitive
comparisons, you have to explicitly use the form ending in '?' (ex: '==?').
The only operators that don't add a '#' even though the forms exist are the
'is' and 'isnot' operators. This is because 'is' is much different from its
cousin 'is#', and the same is true of 'isnot'.


###=== Operator

Oh no, not another of THOSE operators! Well, this one is pretty sweet
actually. In VimL, automatic type conversion can be a pain. For example:

    echo 4 ==# "4"
    => 1

To mitigate this, we can wrap each side in a list, since lists are more strict
regarding equality:

    echo [4] ==# ["4"]
    => 0

The '===' operator wraps both operands in lists:

    echo 4 === "4"                        echo [4] ==# ["4"]


Heredocs
--------

    msg = <<EOS                           let s:msg = "a vim heredoc! " . s:cryForJoy() . "!\nHooray!\n"
    A vim heredoc! #{cryForJoy()}!
    Hooray!
    EOS

Riml heredocs must have the ending pattern ('EOS' in this case) start at the
beginning of the line. Interpolating expressions is allowed in heredocs.
Compiled heredocs always end with a newline.

Functions
---------

    def fillSearchPat             function! s:fillSearchPat()
      @/ = getSearchPat()           let @/ = s:getSearchPat()
      return @/                     return @/
    end                           endfunction

When defining a function with no parameters, the parens after the function name are optional.

Functions are by default prepended by 's:' unless explicitly prepended with a
different scope modifier. Of course, you can use the old form ('function! Name()')
for defining functions if you want, as Riml aims to be as compatible as possible
with VimL. There are a few exceptions where Riml and VimL aren't compatible, and
these differences are explained in the section 'Incompatibilities with VimL'.

###Default Arguments

    def fillSearchPat(pat = getDefaultSearchPat())        function! s:fillSearchPat(...)
      @/ = pat                                              if get(a:000, 0, 'rimldefault') !=# 'rimldefault'
      return @/                                               let pat = remove(a:000, 0)
    end                                                     else
                                                              let pat = s:getDefaultSearchPat()
                                                            endif
                                                            @/ = pat
                                                            return @/
                                                          endfunction


Default arguments must be the last arguments given to a function, but there can be more
than one default argument. Also, a splat argument (... or \*argName) can come after default argument(s).
Splats will be explained in the next section.

We can now call the function 'fillSearchPat' without any arguments and it will use the default
argument. Also, if we pass the string 'rimldefault', it will use the default argument as well. This
is useful if a function has many default arguments.

Classes
-------

###Basic Class

    class MyClass                                      function! g:MyClassConstructor(data, otherData, ...)
      def initialize(data, otherData, *options)          let myClassObj = {}
        self.data = data                                 let myClassObj.data = a:data
        self.otherData = otherData                       let myClassObj.otherData = a:otherData
        self.options = options                           let myClassObj.options = a:000
      end                                                let myClassObj.getData = function('g:MyClass_getData')
                                                         let myClassObj.getOtherData = function('g:MyClass_getOtherData')
      defm getData                                       return myClassObj
        return self.data                               endfunction
      end
                                                       function! g:MyClass_getdata() dict
      defm getOtherData                                  return self.data
        return self.otherData                          endfunction
      end
    end                                                function! g:MyClass_getOtherData() dict
                                                         return self.otherData
                                                       endfunction

Classes can only be defined once, and cannot be reopened. Public member
functions are defined with 'defm'. If you want to create a non-public function
inside a class, use 'def'. To create an instance of this class, simply:

    obj = new MyClass('someData', 'someOtherData')

In this basic example of a class, we see a \*splat variable. This is just a
convenient way to refer to 'a:000' in the body of a function. Splat variables
are optional parameters and get compiled to '...'.

###Class Inheritance

    class Translation                                  function! g:TranslationConstructor(input)
      def initialize(input)                              let translationObj = {}
        self.input = input                               let translationObj.input = a:input
      end                                                return translationObj
    end                                                endfunction

    class FrenchToEnglishTranslation < Translation     function! g:FrenchToEnglishTranslationConstructor(input)
      defm translate                                     let frenchToEnglishTranslationObj = {}
        if (self.input == "Bonjour!")                    let translationObj = g:TranslationConstructor(a:input)
          echo "Hello!"                                  call extend(frenchToEnglishTranslationObj, translationObj)
        else                                             let frenchToEnglishTranslationObj.translate = function('g:FrenchToEnglishTranslation_translate')
          echo "Sorry, I don't know that word."          return frenchToEnglishTranslationObj
        end                                            endfunction
      end
    end                                                function! g:FrenchToEnglishTranslation_translate() dict
                                                         if (self.input ==# "Bonjour!")
    translation = new                                      echo "Hello!"
    \ FrenchToEnglishTranslation("Bonjour!")             else
    translation.translate()                                echo "Sorry, I don't know that word."
                                                         endif
                                                       endfunction

                                                       let s:translation = g:TranslationConstructor("Bonjour!")
                                                       call s:translation.translate()
    => "Hello!"

Classes that inherit must have their superclass defined before inheritance takes place. In
this example, 'Translation' is defined first, which is legal. Since 'Translation'
has an initialize function and 'FrenchToEnglishTranslation' doesn't, 'FrenchToEnglishTranslation'
instances use the initialize function from 'Translation', and new instances must
be provided with an 'input' argument on creation. Basically, if a class doesn't
provide an initialize function, it uses its superclass's.

If you look at the last line of Riml in the previous example, you'll see that
it doesn't use Vimscript's builtin 'call' function for calling the 'translate'
method on the translation object. Riml can figure out when 'call' is necessary,
and will add it to the compiled Vimscript.

###Using 'super'

    class Car                                             function! g:CarConstructor(make, model, color)
      def initialize(make, model, color)                    let carObj = {}
        self.make = make                                    let carObj.make = a:make
        self.model = model                                  let carObj.model = a:model
        self.color = color                                  let carObj.color = a:color
      end                                                 endfunction
    end

    class HotRod < Car                                    function! g:HotRodConstructor(make, model, color, topSpeed)
      def initialize(make, model, color, topSpeed)          let hotRodObj = {}
        self.topSpeed = topSpeed                            let hotRodObj.topSpeed = a:topSpeed
        super(make, model, color)                           let carObj = g:CarConstructor(a:make, a:model, a:color)
      end                                                   call extend(hotRodObj, carObj)
                                                            let hotRodObj.drive = function('g:HotRod_drive')
      defm drive                                            return hotRodObj
        if self.topSpeed > 140                            endfunction
          echo "Ahhhhhhh!"
        else                                              function! g:HotRod_drive() dict
          echo "Nice"                                       if self.topSpeed ># 140
        end                                                   echo "Ahhhhhhh!"
      end                                                   else
    end                                                       echo "Nice"
                                                            endif
    newCar = new HotRod("chevy", "mustang", "red", 160)   endfunction
    newCar.drive()
                                                          let s:newCar = g:HotRodConstructor("chevy", "mustang", "red", 160)
                                                          call s:newCar.drive()

Use of 'super' is legal only within subclasses. If arguments are given, these arguments are sent
to the superclass's function of the same name. If no arguments are given and parentheses are omitted,
('super' as opposed to 'super()'), every single argument is passed to the superclass's function.
This mirrors Ruby's approach.

Super can be called from an initialize (constructor) function, a public member function
('defm'), or a non-public function ('def'). An error is given during compilation if no
superclass function with that name is defined.

Compiling Riml
--------------

To compile a riml file named 'example.riml' that resides in the current
directory:

    $ riml -c example.riml

This will create a new VimL file named 'example.vim' in the current directory.

###riml\_source

It's useful to split a project into many files. For example, imagine we're creating a plugin
called 'awesome' that does something totally awesome, and it relies on another library
we wrote called 'my\_framework' that's also written in Riml.

Somewhere in 'awesome.riml', we have the line:

    riml_source 'my_framework.riml'

This will compile the file 'my\_framework.riml' and create a VimL file named
'my\_framework.vim'.

In 'awesome.riml', that line will be compiled to:

    source 'my_framework.vim'

This process is recursive, meaning that if 'my\_framework.riml' riml\_source's other
files, then those files will be compiled as well.

The previous example would only work if 'my\_framework.riml' were in the
current working directory where the compilation command 'riml -c' was issued.
In order to tell the compiler where to look for files that are being
riml\_source'd, you can provide an environment variable or a command-line
option of colon-separated paths. For example:

    riml -c awesome.riml -S 'first_dir:second_dir'

With this command, the compiler will look for files that are riml\_source'd
first in ./first\_dir, then in ./second\_dir if not found in first\_dir.
The same can be achieved by:

    riml -c awesome.riml RIML_SOURCE_PATH='first_dir:second_dir'

Paths can either be relative or absolute. The sourced files that are compiled
will end up in the same directory in which they were found.

###riml\_include

Sometimes it's useful to have many files in development, but to include a file's contents
into another file during the build process. This is much like the C preprocessor's #include
directive.

To include a file named 'my\_lib.riml':

    riml_include 'my_lib.riml'

This compiles the file and includes its content in place of the riml\_include directive itself.
Much like riml\_sourcing, the process is recursive. If 'my\_lib.riml' includes files, these files
are also compiled and will be part of the inclusion. Note that riml\_include does not create a
new file like riml\_source does.

Like riml\_source, riml\_include looks in a set of ordered paths to find the
files to include, with the default being the working directory in which the
compilation command was issued. Here are some examples of commands that set
the include path:

    riml -c 'main.riml' -I 'lib:helpers:debug'

    riml -c 'plugin_name.riml' RIML_INCLUDE_PATH='lib:modules'

Since riml\_include acts as a sort of preprocessor, it *cannot* be issued
inside of a conditional, function, or anything dynamic. It must be at the
top-level (non-nested).

Incompatibilities with VimL
---------------------------

Riml aims to be as compatible with VimL as possible, therefore any legal VimL
should be legal Riml as well. Unfortunately, this is not 100% possible as Vim
is an old and cryptic beast, and trying to create grammar for every possible VimL
construct would be a nightmare. In practice, however, when I've transformed plain
old VimL plugins to be Riml-compatible, only a couple of ':' needed to be placed
in strategic locations for it to be valid Riml. This is explained below.

###Ex-literals

Fortunately, there are some pretty simple rules to follow to get valid Riml.

When doing anything with autocommands, normal, commands, set, ranges, etc... simply do:

    :autocmd BufEnter * blahblah...

That is, prepend ':' to the line. When a line starts with ':', it passes directly
through the compiler and no transformations occur. This includes string interpolation,
which is ignored as well.

In Riml, when a line starts with ':' it's called an ex-literal.

Ex-literals are necessary for the following:

* autocommands
* command definitions
* set
* ranges (:h cmdline-ranges)
* normal (:h normal)
* mappings
* augroups

Basically anything that isn't a class, number, string, list, dict, function call,
function definition, loop or if construct, variable definition or unlet, etc...
needs to be an ex-literal in Riml.

Note that, like 'echo' which isn't a builtin function (:h functions) but is still legal
Riml, 'execute' is also allowed as it takes a string. This is extremely useful, as we can
now use execute with a string that allows interpolation!

Imagine having to write a grammar rule for the following:

    set statusline+=[%{strlen(&fenc)?&fenc:'none'}, " File encoding

Since there's no string after the '+=', it makes it very hard.
So when the compiler can't parse a file correctly, prepend those lines with
':' and all should be well.

###Abbreviations

In VimL, there are abbreviations for everything; even "keywords" like 'function' can be
abbreviated. In Riml, abbreviations are not allowed. This makes Riml much easier to read
and understand.

Everything Else That Works
--------------------------

Everything not mentioned above as illegal is legal Riml. Here's a short (non-comprehensive) list
of constructs which are legal Riml but not mentioned in any of the examples:

* try/catch/finally blocks and throw
* curly-brace variable and function names
* while (and until) loops
* ternary operators
* exponents
* line continuations
* autoloadable variables and functions (:h autoload)
* let unpack (:h let-unpack)
* Much more!
