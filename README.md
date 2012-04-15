Riml, a relaxed version of Vimscript
====================================

Variables
---------

The following won't raise a compilation error unless there are multiple count
variables in scope with different scope modifiers.

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
    callcount += 1                         let s:callcount = s:callcount + 1
    puts "called #{callcount} times"       echo "called" s:callcount "times"


    if b:didftplugin?                      if exists("b:didftplugin")
      finish                                 finish
    end                                    endif
    didftplugin = true                     let b:didftplugin = 1

###Commands

    command? -nargs=1 Correct :call s:Add(<q-args>, 0)          if !exists(":Correct")
                                                                  command -nargs=1 Correct :call s:Add(<q-args>, 0)
                                                                end
