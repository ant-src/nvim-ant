local h = dofile('tests/helpers.lua')

h.buffer({
  '#!/usr/bin/env ant',
  '//! Module doc.',
  '// TODO: something',
  'export type Point = { x: float64, type: string }',
  'func Point.norm(p: Point): float64 { Math.sqrt(p.x * p.x) }',
  'var r = /^\\d{4}[/]x$/i',
  'var q = total / count',
  'var s = "a\\nb\\q"',
  'var t = `n: ${ { x: 1 }.x } \\` end`',
  'var e = event.type',
  'var h = <div class="a" id={id}>if x &amp; <br /> {name}</div>',
  'var f = <>for <b>y</b></>',
  'var c = a < b',
  'if 0x1F == 1_000 && 2.5e-3 > 1e9 { println(null) } else { await }',
  '/* block',
  '   comment */ var after = true',
  'var st = <style>a { color: red } if</style>',
})
vim.bo.filetype = 'ant'

h.eq('ant', vim.b.current_syntax, 'b:current_syntax')
h.eq('antShebang', h.group(1, '#!'), 'shebang')
h.eq('antModuleDoc', h.group(2, '//!'), 'module doc')
h.eq('antTodo', h.group(3, 'TODO'), 'todo')
h.eq('antInclude', h.group(4, 'export'), 'export')
h.eq('antStorage', h.group(4, 'type'), 'type keyword')
h.eq('antTypeName', h.group(4, 'Point'), 'type name')
h.eq('antPrimitive', h.group(4, 'float64'), 'primitive')
h.eq('', h.group(4, 'type:'), 'keyword as a field name')
h.eq('antFuncName', h.group(5, 'norm'), 'method name')
h.eq('antType', h.group(5, 'Point.'), 'receiver type')
h.eq('antFunction', h.group(5, 'sqrt'), 'member call')
h.eq('antRegex', h.group(6, '/^'), 'regex start')
h.eq('antRegexClass', h.group(6, '[/]'), 'slash in class')
h.eq('antRegex', h.group(6, '$/i', 2), 'regex flags')
h.eq('antOperator', h.group(7, '/ count'), 'division')
h.eq('antEscape', h.group(8, '\\n'), 'escape')
h.eq('antEscapeError', h.group(8, '\\q'), 'bad escape')
h.eq('antDelimiter', h.group(9, '${'), 'interpolation start')
h.eq('antTemplate', h.group(9, '} \\`', 1), 'template after nested braces')
h.eq('antEscape', h.group(9, '\\`'), 'escaped backtick')
h.eq('', h.group(10, 'type'), 'keyword after .')
h.eq('antTag', h.group(11, '<div'), 'tag')
h.eq('antAttribute', h.group(11, 'class'), 'attribute')
h.eq('antAttributeString', h.group(11, '"a"'), 'attribute string')
h.eq('antElement', h.group(11, 'if x'), 'markup text is not code')
h.eq('antEntity', h.group(11, '&amp;'), 'entity')
h.eq('antTag', h.group(11, '/>'), 'self-closing tag')
h.eq('antDelimiter', h.group(11, '{name}'), 'markup interpolation')
h.eq('antTag', h.group(11, '</div>'), 'end tag')
h.eq('antFragment', h.group(12, 'for'), 'fragment text')
h.eq('antTag', h.group(12, '</>'), 'fragment end')
h.eq('antOperator', h.group(13, '<'), 'comparison')
h.eq('antNumber', h.group(14, '0x1F'), 'hex')
h.eq('antNumber', h.group(14, '1_000'), 'separated digits')
h.eq('antFloat', h.group(14, '2.5e-3'), 'float')
h.eq('antFloat', h.group(14, '1e9'), 'exponent')
h.eq('antBuiltin', h.group(14, 'println'), 'prelude function')
h.eq('antConstant', h.group(14, 'null'), 'null')
h.eq('antConditional', h.group(14, 'else'), 'else')
h.eq('antReserved', h.group(14, 'await'), 'reserved word')
h.eq('antComment', h.group(16, 'comment'), 'block comment')
h.eq('antStorage', h.group(16, 'var'), 'code after a block comment')
h.eq('antRaw', h.group(17, 'color'), 'style content')
h.eq('antRaw', h.group(17, 'if'), 'style content keyword')

-- Every file of the corpus ends outside any string, comment, regex, or markup, so no region runs away.
local open = {
  antString = true, antTemplate = true, antRegex = true, antComment = true, antElement = true,
  antFragment = true, antElementNested = true, antRaw = true, antStartTag = true,
  antInterpolation = true, antMarkupInterpolation = true,
}
local bad = {}
for _, f in ipairs(h.corpus()) do
  local file = f.file
  vim.cmd('silent! edit! ' .. vim.fn.fnameescape(file))
  local last = vim.fn.line('$')
  vim.fn.append(last, 'var __end = 0')
  for _, id in ipairs(vim.fn.synstack(last + 1, 1)) do
    local name = vim.fn.synIDattr(id, 'name')
    if open[name] then
      table.insert(bad, file .. ': ends inside ' .. name)
      break
    end
  end
  vim.cmd('silent! bwipeout!')
end
if #bad > 0 then
  error(#bad .. ' corpus files end inside a region:\n' .. table.concat(bad, '\n'))
end
