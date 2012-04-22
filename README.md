Riml, a relaxed version of Vimscript
====================================

Riml aims to be a superset of VimL that includes some nice features that I
enjoy in other scripting languages, including string interpolation, default
case-sensitive string comparison and other things most programmers take for
granted. Also, Riml takes some liberties and provides some syntactic sugar for
lots of VimL constructs. Check out the test/compiler\_test.rb file to see how
Riml constructs are compiled into VimL, or just take a look in this README.
The left side is Riml, and the right side is the equivalent VimL after
compilation.

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

Checking for existence
----------------------

###Variables

    unless s:callcount?                    if !exists("s:callcount")
      callcount = 0                         let s:callcount = 0
    end                                    endif
    callcount += 1                         let s:callcount += 1
    puts "called #{callcount} times"       echo "called" s:callcount "times"


    if b:didftplugin?                      if exists("b:didftplugin")
      finish                                 finish
    end                                    endif
    didftplugin = true                     let b:didftplugin = 1

###Commands

    command? -nargs=1 Correct :call s:Add(<q-args>, 0)          if !exists(":Correct")
                                                                  command -nargs=1 Correct :call s:Add(<q-args>, 0)
                                                                end

Hacking
-------

Make sure to generate the parser before running tests or developing on Riml.
Also, make sure to regenerate the parser after modifiying the grammar file.

1. `bundle install`
2. Go to the lib directory and enter `racc -o parser.rb grammar.y`
