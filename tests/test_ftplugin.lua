local h = dofile('tests/helpers.lua')

local buf = h.buffer({ 'import "./lib.ant" { f }', 'println(f())' })
h.eq('ant', vim.bo[buf].filetype, 'filetype')
h.eq('// %s', vim.bo[buf].commentstring, 'commentstring')
h.eq(2, vim.bo[buf].shiftwidth, 'shiftwidth')
h.eq(true, vim.bo[buf].expandtab, 'expandtab')
h.eq("v:lua.require'ant.indent'.get(v:lnum)", vim.bo[buf].indentexpr, 'indentexpr')

-- :make reads ant check's errors, and passes over the source lines under each and the count.
vim.fn.setqflist({}, 'r', {
  lines = {
    'bad.ant:2:16: cannot use string where int is expected',
    '   │',
    ' 2 │   var x: int = "a"',
    '   │                ^^^',
    '',
    '1 error',
  },
  efm = vim.bo[buf].errorformat,
})
local qf = vim.tbl_filter(function(e)
  return e.valid == 1
end, vim.fn.getqflist())
h.eq(1, #qf, 'one quickfix entry')
h.eq({ 2, 16, 'cannot use string where int is expected' }, { qf[1].lnum, qf[1].col, qf[1].text }, 'quickfix entry')
h.eq(1, #vim.fn.getqflist(), 'no lines of the source frame in the quickfix list')

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
  h.eq({ 0 }, vim.fn.jobwait({ vim.b[term].terminal_job_id }, 10000), 'ant run exit status')
  vim.wait(500, function()
    return vim.api.nvim_buf_get_lines(term, 0, 1, false)[1] == '1'
  end, 20)
  h.eq('1', vim.api.nvim_buf_get_lines(term, 0, 1, false)[1], 'program output')
end
