" Vim syntax file
" Language:    Ant (https://github.com/ant-src/spec)
" Filenames:   *.ant
"
" The lexical rules are those of spec/ant-lang.md section 2, and the markup those of section 5
" (HTML expressions). The language server's semantic tokens refine identifiers on top of this.

if exists('b:current_syntax')
  finish
endif
" Apache Ant's build.xml has the filetype ant as well; its own syntax file loads after this one.
if expand('<afile>:e') ==? 'xml' || expand('%:e') ==? 'xml'
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn sync fromstart

" A keyword after . or ?. is a field, and one before : is a record key (section 2), so keywords
" are matches with look-around rather than syn keyword, which would win over everything.
let s:pre = '\%(\%(?\?\.\)\s*\)\@<!\<'
let s:post = '\>\%(\s*:\)\@!'
function! s:words(group, words) abort
  execute 'syn match ' . a:group . ' "' . s:pre . '\%(' . join(a:words, '\|') . '\)' . s:post . '"'
endfunction

call s:words('antConditional', ['if', 'else', 'select'])
call s:words('antRepeat', ['for', 'while', 'in'])
call s:words('antStatement', ['return', 'break', 'continue', 'go', 'defer', 'try'])
call s:words('antOperatorWord', ['is'])
call s:words('antStorage', ['var', 'func', 'type'])
call s:words('antInclude', ['import', 'export'])
call s:words('antBoolean', ['true', 'false'])
call s:words('antConstant', ['null', 'void'])
call s:words('antReserved', ['as', 'async', 'await', 'catch', 'class', 'const', 'enum', 'finally',
      \ 'function', 'interface', 'let', 'match', 'switch', 'this', 'throw', 'undefined'])
call s:words('antPrimitive', ['int', 'int8', 'int16', 'int32', 'int64', 'uint8', 'uint16',
      \ 'uint32', 'uint64', 'byte', 'float32', 'float64', 'string', 'bool', 'never'])

" In a test file, test before a string declares a test (section 10, Tests); elsewhere, and after
" ., it is a name.
if expand('<afile>:t') =~# '_test\.ant$' || expand('%:t') =~# '_test\.ant$'
  syn match antTest '\%(?\?\.\s*\)\@<!\<test\ze\s*["`]'
endif

" Capitalized names are types and namespaces; calls of lowercase names are functions.
syn match antType '\%(?\?\.\s*\)\@<!\<\u\w*\>'
syn match antFunction '\<\l\w*\ze\s*('
syn match antFunction '\<_\w\+\ze\s*('
syn match antBuiltin '\%(?\?\.\s*\)\@<!\<\%(print\|println\|eprint\|eprintln\|panic\|len\)\ze\s*('

" Declarations: func Type.name, type Name.
syn match antStorage '\<func\>\ze\s\+\h' nextgroup=antFuncName skipwhite
syn match antFuncName '\%(\h\w*\s*\.\s*\)\?\h\w*' contained contains=antType,antFuncDot
syn match antFuncDot '\.' contained
syn match antStorage '\<type\>\ze\s\+\h' nextgroup=antTypeName skipwhite
syn match antTypeName '\h\w*' contained

" Numbers. A float has digits on both sides of the point, an exponent, or both.
syn match antNumber '\<0x\x\%(_\?\x\)*\>'
syn match antNumber '\<0b[01]\%(_\?[01]\)*\>'
syn match antNumber '\<\d\%(_\?\d\)*\>'
syn match antFloat '\<\d\%(_\?\d\)*\.\d\%(_\?\d\)*\%(e[-+]\?\d\%(_\?\d\)*\)\?\>'
syn match antFloat '\<\d\%(_\?\d\)*e[-+]\?\d\%(_\?\d\)*\>'

syn match antOperator '[-+*/%=!<>&|?]'
syn match antOperator '\.\.\.'

" Strings (section 2): "..." has escapes and ${...} interpolation, a `...` raw string has neither,
" and both may span lines.
syn match antEscape '\\\%([ntr\\"$]\|u{\x\+}\)' contained
syn match antEscapeError '\\[^ntr\\"$u]' contained
syn region antString start='"' skip='\\\\\|\\"' end='"' contains=antEscape,antEscapeError,antInterpolation
syn region antRawString start='`' end='`'
syn region antInterpolation matchgroup=antDelimiter start='\${' end='}' contained contains=TOP

" Braces nest, so that the } of a lambda or record inside ${...} or {...} does not end it.
syn region antBraces start='{' end='}' transparent contains=TOP

" A / begins a regular expression after a token that is not an operand (section 2); this looks
" one character back, as far as a pattern on one line can.
syn region antRegex start='\%(\%([-(,=:[{|!&?+*%<>]\|\<return\|\<break\|\<continue\)\s*\)\@<=/[/*]\@!' skip='\\.\|\[\%(\\.\|[^]\\]\)*\]' end='/[ims]*' oneline contains=antRegexClass,antRegexEscape
syn match antRegexEscape '\\.' contained
syn match antRegexClass '\[\%(\\.\|[^]\\]\)*\]' contained contains=antRegexEscape

" Markup (section 5): < begins an element where an operand cannot end, followed by a letter.
let s:markup = '\%(\%([=(,[{|:?!&>]\|\<return\)\s*\|^\s*\)\@<='
execute 'syn region antElement matchgroup=antTag start=+' . s:markup . '<\z(\a[-[:alnum:]]*\)\%(\_s\|/\|>\)\@=+ end=+</\z1\_s*>+ end=+/>+ contains=antStartTag,antElementNested,antRaw,antMarkupInterpolation,antEntity,antEntityError'
execute 'syn region antFragment matchgroup=antTag start=+' . s:markup . '<>+ end=+</>+ contains=antElementNested,antRaw,antMarkupInterpolation,antEntity,antEntityError'
syn region antElementNested matchgroup=antTag start=+<\z(\a[-[:alnum:]]*\)\%(\_s\|/\|>\)\@=+ end=+</\z1\_s*>+ end=+/>+ contained contains=antStartTag,antElementNested,antRaw,antMarkupInterpolation,antEntity,antEntityError
syn region antElementNested matchgroup=antTag start=+<>+ end=+</>+ contained contains=antElementNested,antRaw,antMarkupInterpolation,antEntity,antEntityError
" <script> and <style> hold literal text.
syn region antRaw matchgroup=antTag start=+\c<\z(script\|style\)\%(\_s\|/\|>\)\@=+ end=+</\z1\_s*>+ end=+/>+ contained contains=antStartTag
execute 'syn region antRaw matchgroup=antTag start=+' . s:markup . '\c<\z(script\|style\)\%(\_s\|/\|>\)\@=+ end=+</\z1\_s*>+ end=+/>+ contains=antStartTag'
" The start tag runs from the name to > or up to />.
syn region antStartTag start=+\%(<\a[-[:alnum:]]*\)\@<=+ matchgroup=antTag end=+>+ end=+\ze/>+ contained contains=antAttribute,antAttributeString,antMarkupInterpolation
syn match antAttribute '\<\h[-[:alnum:]_:.]*' contained
syn region antAttributeString start=+"+ end=+"+ contained contains=antEntity
syn region antMarkupInterpolation matchgroup=antDelimiter start='{' end='}' contained contains=TOP
syn match antEntityError '&\a\+;' contained
syn match antEntity '&\%(amp\|lt\|gt\|quot\|apos\|nbsp\|#\d\+\|#x\x\+\);' contained

" Comments last, so that they win over everything that starts at the same place.
syn keyword antTodo TODO FIXME XXX NOTE contained
syn match antComment '//.*' contains=antTodo,@Spell
syn match antModuleDoc '//!.*' contains=antTodo,@Spell
syn region antComment start='/\*' end='\*/' contains=antTodo,@Spell
syn match antShebang '\%^#!.*'

hi def link antConditional Conditional
hi def link antRepeat Repeat
hi def link antStatement Statement
hi def link antOperatorWord Keyword
hi def link antStorage Keyword
hi def link antInclude Include
hi def link antBoolean Boolean
hi def link antConstant Constant
hi def link antReserved Error
hi def link antTest Keyword
hi def link antPrimitive Type
hi def link antType Type
hi def link antTypeName Typedef
hi def link antFunction Function
hi def link antFuncName Function
hi def link antBuiltin Special
hi def link antNumber Number
hi def link antFloat Float
hi def link antOperator Operator
hi def link antString String
hi def link antRawString String
hi def link antEscape SpecialChar
hi def link antEscapeError Error
hi def link antDelimiter Delimiter
hi def link antRegex String
hi def link antRegexEscape SpecialChar
hi def link antRegexClass SpecialChar
hi def link antTag Tag
hi def link antAttribute Identifier
hi def link antAttributeString String
hi def link antEntity SpecialChar
hi def link antEntityError Error
hi def link antComment Comment
hi def link antModuleDoc SpecialComment
hi def link antTodo Todo
hi def link antShebang PreProc

let b:current_syntax = 'ant'

let &cpo = s:cpo_save
unlet s:cpo_save
