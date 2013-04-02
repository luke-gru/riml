[![Build Status](https://secure.travis-ci.org/luke-gru/riml.png?branch=master)](https://travis-ci.org/luke-gru/riml)

Riml, a relaxed version of Vimscript
====================================

Riml aims to be a superset of VimL that includes some nice features that I
enjoy in other scripting languages: classes, string interpolation,
heredocs, default case-insensitive string comparison, default parameters
in functions, and other things programmers tend to take for granted. Also, Riml takes
some liberties and provides some syntactic sugar for lots of VimL constructs.
To see how Riml constructs are compiled to VimL, just take a look at this README.
The left side is Riml, and the right side is the VimL after compilation.

Variables
---------

    count = 1                     let s:count = 1
    while count < 5               while s:count < 5
      source other.vim              source other.vim
      count += 1                    let s:count += 1
    end                           endwhile

If you don't specify a scope modifier, it's script local (s:) by default in the
global namespace. Within a function, variables without scope modifiers are plain
old local variables.

###globally

    a = 3                         let s:a = 3

###locally

    a = 3                         let a = 3

###Freeing memory

    a = nil                       unlet! a

###Checking for existence

    unless s:callcount?                   if !exists("s:callcount")
      callcount = 0                        let s:callcount = 0
    end                                   endif
    callcount += 1                        let s:callcount += 1
    echo "called #{callcount} times"      echo "called " . s:callcount . " times"

In Riml, you can choose to end any block with 'end', or with whatever you used
to do in Vimscript ('endif', 'endfunction', etc...). Also, 'if' and 'unless' can
now be used as statement modifiers:

    callcount = 0 unless s:callcount?
    callcount += 1
    echo "called #{callcount} times"

Here, the compiled output is the same as the previous example's. Both 'if' and
'unless' can be used this way.

Operators And Case Sensitivity
------------------------------

    a = "hi" == greeting                  if ("hi" ==# s:greeting)
                                            let s:a = 1
                                          else
                                            let s:a = 0
                                          endif

Comparisons compile to case-insensitive by default. To get case-sensitive
comparisons, you have to explicitly use the form ending in '?' (ex: '==?').

Heredocs
--------

    msg = <<EOS                           let s:msg = "a vim heredoc! " . s:cryForJoy() . "!\n"
    A vim heredoc! #{cryForJoy()}!
    EOS

Riml heredocs must have the ending pattern starting at the beginning
of the line. Interpolating expressions is allowed in heredocs. Compiled
heredocs always end with a newline.

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
convenient way to refer to 'a:000' in a function. Splat variables are optional
parameters and get compiled to '...'.

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
has an initialize function and 'FrenchToEnglishTranslation' (referred to now as FET)
doesn't, FET instances use the initialize function from 'Translation', and new
instances must be provided with an 'input' argument on creation. This mirrors
simple OO concepts.

If you look at the last line of Riml in the previous example, you'll see that
it doesn't use Vimscript's builtin 'call' function for calling the 'translate'
method on the translation object. Riml can figure out when 'call' is necessary,
and will add it to the compiled Vimscript.

Coming Soon
-----------

Full list of features with examples. Compilation workflow fully explained.
