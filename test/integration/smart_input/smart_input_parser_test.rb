require File.expand_path('../../../test_helper', __FILE__)

class SmartInputParserTest < Riml::TestCase
  test "parses without error" do
    skip "not working yet"
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

end
