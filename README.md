### Riml, a relaxed version of Vimscript

* The following won't raise a compilation error unless there are multiple *count*
variables in scope with different access modifiers.

s:count = 1                   let s:count = 1
while count < 5               while s:count < 5
  source other.vim              source other.vim
  count += 1                    let s:count += 1
end                           endwhile

* If you don't specify a scope modifier, it's script local by default in the
  global namespace. Within a function, variables without scope modifiers are plain
  old local variables.

a = 3                         s:a = 3

* Freeing memory

a = nil                       unlet! a

* Checking for existence

if s:callcount.nil?                    if !exists("s:callcount")
  callcount = 0                          let s:callcount = 0
end                                     endif
callcount += 1                         let s:callcount = s:callcount + 1
puts "called #{callcount} times"       echo "called" s:callcount "times"


if b:didftplugin.present?             if exists("b:didftplugin")
  finish                                finish
end                                   endif
didftplugin = 1                       let b:didftplugin = 1

command? -nargs=1 Correct :call s:Add(<q-args>, 0)      if !exists(":Correct")
                                                          command -nargs=1 Correct :call s:Add(<q-args>, 0)
                                                        end
* String and truthiness

if "true"                               if 1
if "6elves"                             if 6
if "0people"                            if 0
if ""                                   if 1
if " dinosaurs\t"                       if 1

* Options and Registers
saveic = &ic
set noic
/The Start/, $delete
&ic = saveic

* Functions
see usr_41, 1021G
