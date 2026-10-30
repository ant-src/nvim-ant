local h = dofile('tests/helpers.lua')

local buf = h.buffer({ 'import "./lib.ant" { f }', 'println(f())' })
h.eq('ant', vim.bo[buf].filetype, 'filetype')
h.eq('// %s', vim.bo[buf].commentstring, 'commentstring')
h.eq(2, vim.bo[buf].shiftwidth, 'shiftwidth')
h.eq(true, vim.bo[buf].expandtab, 'expandtab')
h.eq("v:lua.require'ant.indent'.get(v:lnum)", vim.bo[buf].indentexpr, 'indentexpr')

-- gf follows an import.
local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
vim.fn.writefile({ 'export func f(): int { 1 }' }, vim.fs.joinpath(dir, 'lib.ant'))
vim.api.nvim_win_set_cursor(0, { 1, 10 })
vim.cmd('normal! gf')
h.eq('lib.ant', vim.fs.basename(vim.api.nvim_buf_get_name(0)), 'gf on an import')
vim.cmd.buffer(buf)

-- gc comments a line.
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.cmd('normal gcc')
h.eq('// println(f())', vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1], 'gcc')
vim.cmd('normal gcc')

-- :Ant run runs the file in a terminal.
local ant = h.ant()
if ant then
  vim.g.ant = { path = ant }
  vim.cmd('Ant run')
  local term = vim.api.nvim_get_current_buf()
  h.eq('terminal', vim.bo[term].buftype, 'a terminal')
  assert(vim.wait(10000, function()
    return table.concat(vim.api.nvim_buf_get_lines(term, 0, -1, false), '\n'):find('Process exited 0', 1, true) ~= nil
  end, 20), 'ant run ended: ' .. table.concat(vim.api.nvim_buf_get_lines(term, 0, -1, false), '\n'))
  h.eq('1', vim.api.nvim_buf_get_lines(term, 0, 1, false)[1], 'program output')
end
