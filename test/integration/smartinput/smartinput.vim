let s:available_nrules = []
function! smartinput#clear_rules()
  let s:available_nrules = []
endfunction
function! smartinput#define_default_rules()
  let urules = {}
  let urules.names = []
  let urules.table = {}
  function! urules.add(name, urules) dict
    call add(self.names, a:name)
    let self.table[a:name] = a:urules
  endfunction
  call urules.add('()', [{'at': '\%#', 'char': '(', 'input': '()<Left>'}, {'at': '\%#\_s*)', 'char': ')', 'input': '<C-r>=smartinput#_leave_block('')'')<Enter><Right>'}, {'at': '(\%#)', 'char': '<BS>', 'input': '<BS><Del>'}, {'at': '()\%#', 'char': '<BS>', 'input': '<BS><BS>'}, {'at': '\\\%#', 'char': '(', 'input': '('}, {'at': '(\%#)', 'char': '<Enter>', 'input': '<Enter><Enter><Up><Esc>"_S'}])
  call urules.add('[]', [{'at': '\%#', 'char': '[', 'input': '[]<Left>'}, {'at': '\%#\_s*\]', 'char': ']', 'input': '<C-r>=smartinput#_leave_block('']'')<Enter><Right>'}, {'at': '\[\%#\]', 'char': '<BS>', 'input': '<BS><Del>'}, {'at': '\[\]\%#', 'char': '<BS>', 'input': '<BS><BS>'}, {'at': '\\\%#', 'char': '[', 'input': '['}])
  call urules.add('{}', [{'at': '\%#', 'char': '{', 'input': '{}<Left>'}, {'at': '\%#\_s*}', 'char': '}', 'input': '<C-r>=smartinput#_leave_block(''}'')<Enter><Right>'}, {'at': '{\%#}', 'char': '<BS>', 'input': '<BS><Del>'}, {'at': '{}\%#', 'char': '<BS>', 'input': '<BS><BS>'}, {'at': '\\\%#', 'char': '{', 'input': '{'}, {'at': '{\%#}', 'char': '<Enter>', 'input': '<Enter><Enter><Up><Esc>"_S'}])
  call urules.add('''''', [{'at': '\%#', 'char': '''', 'input': '''''<Left>'}, {'at': '\%#''\ze', 'char': '''', 'input': '<Right>'}, {'at': '''\%#''', 'char': '<BS>', 'input': '<BS><Del>'}, {'at': '''''\%#', 'char': '<BS>', 'input': '<BS><BS>'}, {'at': '\\\%#\ze', 'char': '''', 'input': ''''}])
  call urules.add(''''' as strong quote', [{'at': '\%#''', 'char': '''', 'input': '<Right>'}])
  call urules.add('''''''', [{'at': '''''\%#', 'char': '''', 'input': '''''''''<Left><Left><Left>'}, {'at': '\%#''''''\ze', 'char': '''', 'input': '<Right><Right><Right>'}, {'at': '''''''\%#''''''', 'char': '<BS>', 'input': '<BS><BS><BS><Del><Del><Del>'}, {'at': '''''''''''''\%#', 'char': '<BS>', 'input': '<BS><BS><BS><BS><BS><BS>'}])
  call urules.add('""', [{'at': '\%#', 'char': '"', 'input': '""<Left>'}, {'at': '\%#"', 'char': '"', 'input': '<Right>'}, {'at': '"\%#"', 'char': '<BS>', 'input': '<BS><Del>'}, {'at': '""\%#', 'char': '<BS>', 'input': '<BS><BS>'}, {'at': '\\\%#', 'char': '"', 'input': '"'}])
  call urules.add('"""', [{'at': '""\%#', 'char': '"', 'input': '""""<Left><Left><Left>'}, {'at': '\%#"""', 'char': '"', 'input': '<Right><Right><Right>'}, {'at': '"""\%#"""', 'char': '<BS>', 'input': '<BS><BS><BS><Del><Del><Del>'}, {'at': '""""""\%#', 'char': '<BS>', 'input': '<BS><BS><BS><BS><BS><BS>'}])
  call urules.add('``', [{'at': '\%#', 'char': '`', 'input': '``<Left>'}, {'at': '\%#`', 'char': '`', 'input': '<Right>'}, {'at': '`\%#`', 'char': '<BS>', 'input': '<BS><Del>'}, {'at': '``\%#', 'char': '<BS>', 'input': '<BS><BS>'}, {'at': '\\\%#', 'char': '`', 'input': '`'}])
  call urules.add('```', [{'at': '``\%#', 'char': '`', 'input': '````<Left><Left><Left>'}, {'at': '\%#```', 'char': '`', 'input': '<Right><Right><Right>'}, {'at': '```\%#```', 'char': '<BS>', 'input': '<BS><BS><BS><Del><Del><Del>'}, {'at': '``````\%#', 'char': '<BS>', 'input': '<BS><BS><BS><BS><BS><BS>'}])
  call urules.add('English', [{'at': '\w\%#', 'char': '''', 'input': ''''}])
  call urules.add('Lisp quote', [{'at': '\%#', 'char': '''', 'input': ''''}, {'at': '\%#', 'char': '''', 'input': '''''<Left>', 'syntax': ['Constant']}])
  call urules.add('Python string', [{'at': '\v\c<([bu]|[bu]?r)>%#', 'char': '''', 'input': '''''<Left>'}, {'at': '\v\c<([bu]|[bu]?r)>%#', 'char': '''', 'input': '''', 'syntax': ['Comment', 'Constant']}, {'at': '\v\c\#.*<([bu]|[bu]?r)>%#$', 'char': '''', 'input': ''''}])
  call urules.add('Vim script comment', [{'at': '^\s*\%#', 'char': '"', 'input': '"'}])
  let ft_urule_sets_table = {'*': [s:urules.table['()'], s:urules.table['[]'], s:urules.table['{}'], s:urules.table[''''''], s:urules.table[''''''''], s:urules.table['""'], s:urules.table['"""'], s:urules.table['``'], s:urules.table['```'], s:urules.table['English']], 'clojure': [s:urules.table['Lisp quote']], 'csh': [s:urules.table[''''' as strong quote']], 'lisp': [s:urules.table['Lisp quote']], 'perl': [s:urules.table[''''' as strong quote']], 'python': [s:urules.table['Python string']], 'ruby': [s:urules.table[''''' as strong quote']], 'scheme': [s:urules.table['Lisp quote']], 'sh': [s:urules.table[''''' as strong quote']], 'tcsh': [s:urules.table[''''' as strong quote']], 'vim': [s:urules.table[''''' as strong quote'], s:urules.table['Vim script comment']], 'zsh': [s:urules.table[''''' as strong quote']]}
  for urule_set in ft_urule_sets_table['*']
    for urule in urule_set
      call smartinput#define_rule(urule)
    endfor
  endfor
  let overlaied_urules = {}
  let overlaied_urules.pairs = []
  function! overlaied_urules.add(urule, ft) dict
    for [urule, fts] in self.pairs
      if urule is a:urule
        call add(fts, a:ft)
        return
      endif
    endfor
    call add(self.pairs, [a:urule, [a:ft]])
  endfunction
  for ft in filter(keys(ft_urule_sets_table), 'v:val != "*"')
    for urule_set in ft_urule_sets_table[ft]
      for urule in urule_set
        call overlaied_urules.add(urule, ft)
      endfor
    endfor
  endfor
  for [urule, fts] in overlaied_urules.pairs
    let completed_urule = copy(urule)
    let completed_urule.filetype = fts
    call smartinput#define_rule(completed_urule)
  endfor
endfunction
function! s:_operator_key_from(operator_name)
  let k = a:operator_name
  let k = substitute(k, '\V<', '<LT>', 'g')
  let k = substitute(k, '\V|', '<Bar>', 'g')
  return k
endfunction
function! s:_operator_pattern_from(operator_name)
  let k = a:operator_name
  return k
endfunction
function! smartinput#_leave_block(end_char)
  call search(a:end_char, 'cW')
  return ''
endfunction
function! smartinput#define_rule(urule)
  let nrule = s:normalize_rule(a:urule)
  call s:insert_or_replace_a_rule(s:available_nrules, nrule)
endfunction
function! smartinput#map_to_trigger(mode, lhs, rhs_char, rhs_fallback)
  let char_expr = s:_encode_for_map_char_expr(a:rhs_char)
  let fallback_expr = s:_encode_for_map_char_expr(a:rhs_fallback)
  execute printf('%snoremap %s %s  <SID>_trigger_or_fallback(%s, %s)', a:mode, '<script> <expr>', a:lhs, char_expr, fallback_expr)
endfunction
function! s:_encode_for_map_char_expr(rhs_char)
  let s = a:rhs_char
  let s = substitute(s, '<', '<Bslash><LT>', 'g')
  let s = escape(s, '"')
  let s = '"' . s . '"'
  return s
endfunction
function! s:_trigger_or_fallback(char, fallback)
  let nrule = mode() =~# '\v^(i|R|Rv)$' ? s:find_the_most_proper_rule_in_insert_mode(s:available_nrules, a:char) : s:find_the_most_proper_rule_in_command_line_mode(s:available_nrules, a:char, getcmdline(), getcmdpos(), getcmdtype())
  if nrule is 0
    return a:fallback
  else
    return nrule._input
  endif
endfunction
function! smartinput#map_trigger_keys(...)
  let overridep = 1 <=# a:0 ? a:1 : 0
  let d = {'i': {}, 'c': {}}
  for nrule in s:available_nrules
    let char = nrule.char
    if nrule.mode =~# 'i'
      let d['i'][char] = char
    endif
    if nrule.mode =~# '[^i]'
      let d['c'][char] = char
    endif
  endfor
  let M = function('smartinput#map_to_trigger')
  let map_modifier = overridep ? '' : '<unique>'
  for mode in keys(d)
    let unique_chars = keys(d[mode])
    for char in unique_chars
      silent! call M(mode, map_modifier.' '.char, char, char)
    endfor
  endfor
  for mode in ['i', 'c']
    silent! call M(mode, map_modifier.' '.'<C-h>', '<BS>', '<C-h>')
    silent! call M(mode, map_modifier.' '.'<Return>', '<Enter>', '<Return>')
    silent! call M(mode, map_modifier.' '.'<C-m>', '<Enter>', '<C-m>')
    silent! call M(mode, map_modifier.' '.'<CR>', '<Enter>', '<CR>')
    silent! call M(mode, map_modifier.' '.'<C-j>', '<Enter>', '<C-j>')
    silent! call M(mode, map_modifier.' '.'<NL>', '<Enter>', '<NL>')
  endfor
endfunction
function! smartinput#invoke_the_initial_setup_if_necessary()
endfunction
function! smartinput#scope()
  return s:
endfunction
function! smartinput#sid()
  return maparg('<SID>', 'n')
endfunction
nnoremap <SID>  <SID>
function! s:calculate_rule_priority(snrule)
  return len(a:snrule.at) + (a:snrule.filetype is 0 ? 0 : 100 / len(a:snrule.filetype)) + (a:snrule.syntax is 0 ? 0 : 100 / len(a:snrule.syntax)) + 100 / len(a:snrule.mode)
endfunction
function! s:decode_key_notation(s)
  return eval('"' . escape(a:s, '<"\') . '"')
endfunction
function! s:find_the_most_proper_rule_in_command_line_mode(nrules, char, cl_text, cl_column, cl_type)
  let column = a:cl_column - 1
  let a:cl_text = (column ==# 0 ? '' : a:cl_text[: (column - 1)]) . s:UNTYPABLE_CHAR . a:cl_text[(column) :]
  for nrule in a:nrules
    if stridx(nrule.mode, a:cl_type) ==# -1
      continue
    endif
    if !(a:char ==# nrule._char)
      continue
    endif
    if a:cl_text !~# substitute(nrule.at, '\\%#', s:UNTYPABLE_CHAR, 'g')
      continue
    endif
    return nrule
  endfor
  return 0
endfunction
let s:UNTYPABLE_CHAR = "\x01"
function! s:find_the_most_proper_rule_in_insert_mode(nrules, char)
  let syntax_names = map(synstack(line('.'), col('.')), 'synIDattr(synIDtrans(v:val), "name")')
  for nrule in a:nrules
    if stridx(nrule.mode, 'i') ==# -1
      continue
    endif
    if !(a:char ==# nrule._char)
      continue
    endif
    if !(search(nrule.at, 'bcnW'))
      continue
    endif
    if !(nrule.filetype is 0 ? !0 : 0 <=# index(nrule.filetype, &l:filetype))
      continue
    endif
    if !(nrule.syntax is 0 ? !0 : 0 <=# max(map(copy(nrule.syntax), 'index(syntax_names, v:val)')))
      continue
    endif
    return nrule
  endfor
  return 0
endfunction
function! s:insert_or_replace_a_rule(sorted_nrules, nrule)
  let i_min = 0
  let i_max = len(a:sorted_nrules) - 1
  let i_med = 0
  while i_min <=# i_max
    let i_med = (i_min + i_max) / 2
    if a:nrule.hash ==# a:sorted_nrules[i_med].hash
      break
    elseif !(a:nrule.hash <# a:sorted_nrules[s:i_med].hash)
      let i_max = i_med - 1
    else
      let i_min = i_med + 1
    endif
  endwhile
  if i_min <=# i_max
    let a:sorted_nrules[i_med] = a:nrule
  elseif s:i_max <# s:i_med
    call insert(a:sorted_nrules, a:nrule, i_med + 0)
  else
    call insert(a:sorted_nrules, a:nrule, i_med + 1)
  endif
endfunction
function! s:normalize_rule(urule)
  let nrule = deepcopy(a:urule)
  let nrule._char = s:decode_key_notation(nrule.char)
  let nrule._input = s:decode_key_notation(nrule.input)
  if !has_key(nrule, 'mode')
    let nrule.mode = 'i'
  endif
  if has_key(nrule, 'filetype')
    call sort(nrule.filetype)
  else
    let nrule.filetype = 0
  endif
  if has_key(nrule, 'syntax')
    call sort(nrule.syntax)
  else
    let nrule.syntax = 0
  endif
  let nrule.priority = s:calculate_rule_priority(nrule)
  let nrule.hash = string([printf('%06d', nrule.priority), nrule.at, nrule.char, nrule.filetype, nrule.syntax])
  return nrule
endfunction
function! s:sid_value()
  return substitute(smartinput#sid(), '<SNR>', "\<SNR>", 'g')
endfunction
function! s:do_initial_setup()
  call smartinput#define_default_rules()
  if !exists('g:smartinput_no_default_key_mappings')
    call smartinput#map_trigger_keys()
  endif
endfunction
if !exists('s:loaded_count')
  let s:loaded_count = 0
endif
let s:loaded_count += 1
if s:loaded_count ==# 1
  call s:do_initial_setup()
endif
