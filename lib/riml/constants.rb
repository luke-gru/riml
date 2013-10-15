module Riml
  module Constants
    VIML_KEYWORDS =
      %w(function function! if else elseif while for in
         return is isnot finish break continue call let unlet unlet! try
         catch finally)

    VIML_END_KEYWORDS =
      %w(endfunction endif endwhile endfor endtry)
    RIML_END_KEYWORDS = %w(end)
    END_KEYWORDS = VIML_END_KEYWORDS + RIML_END_KEYWORDS

    RIML_KEYWORDS =
      %w(def defm super end then unless until true false class new)
    DEFINE_KEYWORDS = %w(def def! defm defm! function function!)

    KEYWORDS = VIML_KEYWORDS + VIML_END_KEYWORDS + RIML_KEYWORDS

    SPECIAL_VARIABLE_PREFIXES =
      %w(& @ $)
    BUILTIN_COMMANDS  =
      %w(echo echon echomsg echoerr echohl execute exec sleep throw)
    RIML_FILE_COMMANDS =
      %w(riml_source riml_include)
    RIML_CLASS_COMMANDS = %w(riml_import)
    RIML_COMMANDS = RIML_FILE_COMMANDS + RIML_CLASS_COMMANDS
    VIML_COMMANDS =
      %w(source source! command! command silent silent!)

    IGNORECASE_CAPABLE_OPERATORS =
      %w(== != >= > <= < =~ !~)
    COMPARISON_OPERATORS = IGNORECASE_CAPABLE_OPERATORS.map do |o|
      [o + '#', o + '?', o]
    end.flatten

    SPLAT_LITERAL = '...'

    # :help registers
    REGISTERS = [
      '"',
      ('0'..'9').to_a,
      '-',
      ('a'..'z').to_a,
      ('A'..'Z').to_a,
      ':', '.', '%', '#',
      '=',
      '*', '+', '~',
      '_',
      '/',
      '@'
    ].flatten

    # For when showing source location (file:lineno) during error
    # and no file was given
    COMPILED_STRING_LOCATION = '<String>'

    # :help function-list
    BUILTIN_FUNCTIONS =
    %w(
abs
acos
add
append
append
argc
argidx
argv
argv
asin
atan
atan2
browse
browsedir
bufexists
buflisted
bufloaded
bufname
bufnr
bufwinnr
byte2line
byteidx
call
ceil
changenr
char2nr
cindent
clearmatches
col
complete
complete_add
complete_check
confirm
copy
cos
cosh
count
cscope_connection
cursor
cursor
deepcopy
delete
did_filetype
diff_filler
diff_hlID
empty
escape
eval
eventhandler
executable
exists
extend
exp
expand
feedkeys
filereadable
filewritable
filter
finddir
findfile
float2nr
floor
fmod
fnameescape
fnamemodify
foldclosed
foldclosedend
foldlevel
foldtext
foldtextresult
foreground
function
garbagecollect
get
get
getbufline
getbufvar
getchar
getcharmod
getcmdline
getcmdpos
getcmdtype
getcwd
getfperm
getfsize
getfontname
getftime
getftype
getline
getline
getloclist
getmatches
getpid
getpos
getqflist
getreg
getregtype
gettabvar
gettabwinvar
getwinposx
getwinposy
getwinvar
glob
globpath
has
has_key
haslocaldir
hasmapto
histadd
histdel
histget
histnr
hlexists
hlID
hostname
iconv
indent
index
input
inputdialog
inputlist
inputrestore
inputsave
inputsecret
insert
isdirectory
islocked
items
join
keys
len
libcall
libcallnr
line
line2byte
lispindent
localtime
log
log10
map
maparg
mapcheck
match
matchadd
matcharg
matchdelete
matchend
matchlist
matchstr
max
min
mkdir
mode
mzeval
nextnonblank
nr2char
pathshorten
pow
prevnonblank
printf
pumvisible
range
readfile
reltime
reltimestr
remote_expr
remote_foreground
remote_peek
remote_read
remote_send
remove
remove
rename
repeat
resolve
reverse
round
search
searchdecl
searchpair
searchpairpos
searchpos
server2client
serverlist
setbufvar
setcmdpos
setline
setloclist
setmatches
setpos
setqflist
setreg
settabvar
settabwinvar
setwinvar
shellescape
simplify
sin
sinh
sort
soundfold
spellbadword
spellsuggest
split
sqrt
str2float
str2nr
strchars
strdisplaywidth
strftime
stridx
string
strlen
strpart
strridx
strtrans
strwidth
submatch
substitute
synID
synIDattr
synIDtrans
synstack
system
tabpagebuflist
tabpagenr
tabpagewinnr
taglist
tagfiles
tempname
tan
tanh
tolower
toupper
tr
trunc
type
undofile
undotree
values
virtcol
visualmode
winbufnr
wincol
winheight
winline
winnr
winrestcmd
winrestview
winsaveview
winwidth
writefile
)
  end
end
