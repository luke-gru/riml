require File.expand_path('../../../test_helper', __FILE__)

class SmartInputParserTest < Riml::TestCase
  test "parses without error" do
    source = File.read File.expand_path("../smart_input.riml", __FILE__)
    assert parse(source)
  end

  test "complicated expression" do
    riml = <<Riml
" ft_urule_sets_table... "{{{
let ft_urule_sets_table = {
\\   '*': [
\\     urules.table['()'],
\\     urules.table['[]'],
\\     urules.table['{}'],
\\     urules.table[''''''],
\\     urules.table[''''''''],
\\     urules.table['""'],
\\     urules.table['"""'],
\\     urules.table['``'],
\\     urules.table['```'],
\\     urules.table['English'],
\\   ],
\\   'clojure': [
\\     urules.table['Lisp quote'],
\\   ],
\\   'csh': [
\\     urules.table[''''' as strong quote'],
\\   ],
\\   'lisp': [
\\     urules.table['Lisp quote'],
\\   ],
\\   'perl': [
\\     urules.table[''''' as strong quote'],
\\   ],
\\   'python': [
\\     urules.table['Python string'],
\\   ],
\\   'ruby': [
\\     urules.table[''''' as strong quote'],
\\   ],
\\   'scheme': [
\\     urules.table['Lisp quote'],
\\   ],
\\   'sh': [
\\     urules.table[''''' as strong quote'],
\\   ],
\\   'tcsh': [
\\     urules.table[''''' as strong quote'],
\\   ],
\\   'vim': [
\\     urules.table[''''' as strong quote'],
\\     urules.table['Vim script comment'],
\\   ],
\\   'zsh': [
\\     urules.table[''''' as strong quote'],
\\   ],
\\ }
"}}}
Riml

    assert parse(riml)
    assert compile(riml)
  end

  test "parse `is` expression" do
    riml = <<Riml
function! overlaied_urules.add(urule, ft)
  for [urule, fts] in self.pairs
    if urule is a:urule
      call add(fts, a:ft)
      return
    endif
  endfor
  call add(self.pairs, [a:urule, [a:ft]])
endfunction
Riml

    assert parse(riml)
  end

  test "complex variable assignment" do
    riml = <<Riml
function! s:_trigger_or_fallback(char, fallback)
  let nrule =
  \\ mode() =~# '\v^(i|R|Rv)$'
  \\ ? s:find_the_most_proper_rule_in_insert_mode(
  \\     s:available_nrules,
  \\     a:char
  \\   )
  \\ : s:find_the_most_proper_rule_in_command_line_mode(
  \\     s:available_nrules,
  \\     a:char,
  \\     getcmdline(),
  \\     getcmdpos(),
  \\     getcmdtype()
  \\   )
  if nrule is 0
    return a:fallback
  else
    return nrule._input
  endif
endfunction
Riml
    assert parse(riml)
  end

  test "expression that found edge-case in parser" do
    riml = <<Riml
let d['i'][char] = char
Riml
    assert parse(riml)
  end

  test "tripped up the parser with extra newline" do
    riml = <<Riml
function! s:insert_or_replace_a_rule(sorted_nrules, nrule)  "{{{2
  " a:sorted_nrules MUST be sorted by "hash" in descending order.
  " So that binary search can be applied
  "
  " * To replace an existing rule which is equivalent to a:nrule, and
  " * To insert a:nrule at the proper position to make the resulting
  "   a:sorted_nrules sorted.

  let i_min = 0
endfunction
Riml
    assert parse(riml)
  end
end
