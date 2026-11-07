-- Apache Ant's build.xml has the filetype ant as well; its own indent script loads after this one.
if vim.b.did_indent or require('ant').is_build_xml(0) then
  return
end
vim.b.did_indent = 1

vim.bo.indentexpr = "v:lua.require'ant.indent'.get(v:lnum)"
-- <<> is a typed <: a bare < would start a key name and swallow the keys after it; <>> is a typed
-- >, which may end a start tag begun above. =</ reindents an end tag once its / is typed, when it
-- can be told from a start tag; =... and =|| a spread and an operator once they can be told from a
-- continuation.
vim.bo.indentkeys = '0{,0},0),0],0<<>,0<>>,0=</,!^F,o,O,e,0.,0=...,0|,0=||'
vim.bo.autoindent = true
vim.bo.smartindent = false
vim.bo.cindent = false

vim.b.undo_indent = 'setl inde< indk< ai< si< cin<'
