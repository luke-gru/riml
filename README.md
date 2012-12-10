[![Build Status](https://secure.travis-ci.org/luke-gru/riml.png?branch=master)](https://travis-ci.org/luke-gru/riml)

Riml, a relaxed version of Vimscript
====================================

Riml aims to be a superset of VimL that includes some nice features that I
enjoy in other scripting languages, including classes, string interpolation,
heredocs, default case-sensitive string comparison and other things most
programmers take for granted. Also, Riml takes some liberties and provides
some syntactic sugar for lots of VimL constructs. To see how Riml constructs
are compiled into VimL, just take a look in this README. The left side is Riml,
and the right side is the equivalent VimL after compilation.
Variables
---------

    count = 1                     let s:count = 1
    while count < 5               while s:count < 5
      source other.vim              source other.vim
      count += 1                    let s:count += 1
    end                           endwhile

If you don't specify a scope modifier, it's script local by default in the
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

Comparisons
-----------

    a = "hi" == "hi"                      if ("hi" ==# "hi")
                                            let s:a = 1
                                          else
                                            let s:a = 0
                                          endif

Heredocs
--------

    msg = <<EOS                           let s:msg = "a vim heredoc! " . s:cryForJoy() . "!\n"
    A vim heredoc! #{cryForJoy()}!
    EOS

Classes
-------

###Basic Class

    class MyClass                                      function! g:MyClassConstructor(data, otherData, ...)
      def initialize(data, otherData, *options)          let myClassObj = {}
        self.data = data                                 let myClassObj.data = a:data
        self.otherData = otherData                       let myClassObj.otherData = a:otherData
        self.options = options                           let myClassObj.options = a:000
      end                                                function! myClassObj.getData() dict
                                                           return self.data
      defm getData                                       endfunction
        return self.data                                 function! myClassObj.getOtherData() dict
      end                                                  return self.otherData
                                                         endfunction
      defm getOtherData                                  return myClassObj
        return self.otherData                          endfunction
      end
    end

###Class with Inheritance

    class Translation                                  function! g:TranslationConstructor(input)
      def initialize(input)                              let translationObj = {}
        self.input = input                               let translationObj.input = a:input
      end                                                return translationObj
    end                                                endfunction

    class FrenchToEnglishTranslation < Translation     function! g:FrenchToEnglishTranslationConstructor(input)
      defm translate                                     let frenchToEnglishTranslationObj = {}
        if (self.input == "Bonjour!")                    let translationObj = g:TranslationConstructor(a:input)
          echo "Hello!"                                  call extend(frenchToEnglishTranslationObj, translationObj)
        else                                             function! frenchToEnglishTranslationObj.translate() dict
          echo "Sorry, I don't know that word."            if (self.input ==# "Bonjour!")
        end                                                  echo "Hello!"
      end                                                  else
    end                                                      echo "Sorry, I don't know that word."
                                                           endif
    translation = new                                    endfunction
    \ FrenchToEnglishTranslation("Bonjour!")             return frenchToEnglishTranslationObj
    translation.translate()                            endfunction
                                                       let s:translation = g:FrenchToEnglishTranslationConstructor("Bonjour!")
                                                       call s:translation.translate()


Coming soon: for a full list of the language's rules complete with examples, check out the Wiki
