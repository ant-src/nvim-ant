local h = dofile('tests/helpers.lua')
local test = require('ant.test')

-- Patterns, as ant lsp makes them.
h.eq('^parse$', test.quote('parse'), 'quote')
h.eq([[^a\/b$]], test.quote('a/b'), 'quote a slash, which would split the pattern')
h.eq('^c( #[0-9]+)?$', test.quote('c', true), 'quote a subtest, with its repeats')
h.eq([[^a\.b \(\[x\]\)\$\^\*\+\?\{\}\|\\$]], test.quote([[a.b ([x])$^*+?{}|\]]), 'quote metacharacters')
h.eq({ 'ant', 'test', '-run', '^a$', 'x_test.ant' }, test.command('ant', 'x_test.ant', '^a$'), 'command')
h.eq({ 'ant', 'test', '.' }, test.command('ant', '.', nil), 'command without a pattern')
h.eq('^a$/^0$', test.config('/d/x_test.ant', '^a$/^0$').test, 'dap test')
h.eq('/d/x_test.ant', test.config('/d/x_test.ant', '^a$/^0$').program, 'dap program')
h.eq(nil, test.config('/d/x_test.ant', '').test, 'dap without a pattern')

-- The nearest test, from the lines above the cursor.
local nb = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(nb, 0, -1, false, {
  'func helper() {}', -- 1
  'test "parse" {', -- 2
  '  for c in cases {', -- 3
  '    test "${c}" {', -- 4
  '      check(c)', -- 5
  '    }', -- 6
  '  }', -- 7
  '  test "0x10" {', -- 8
  '    check(1)', -- 9
  '  }', -- 10
  '}', -- 11
  '', -- 12
  'test "a.b" {', -- 13
  '}', -- 14
})
h.eq(nil, test.nearest(nb, 1), 'outside a test')
h.eq('^parse$', test.nearest(nb, 2), 'on a test')
h.eq('^parse$', test.nearest(nb, 3), 'in a test')
h.eq('^parse$', test.nearest(nb, 5), 'in a subtest named by interpolation')
h.eq('^parse$/^0x10( #[0-9]+)?$', test.nearest(nb, 8), 'on a subtest')
h.eq('^parse$/^0x10( #[0-9]+)?$', test.nearest(nb, 9), 'in a subtest')
h.eq('^parse$/^0x10( #[0-9]+)?$', test.nearest(nb, 10), 'on the brace closing a subtest')
h.eq('^parse$', test.nearest(nb, 11), 'on the brace closing a test')
h.eq(nil, test.nearest(nb, 12), 'between tests')
h.eq('^a\\.b$', test.nearest(nb, 14), 'quoted')

-- Lines of strings and comments at column 0 do not end the test they are in, with syntax
-- highlighting and without.
local text = {
  'test "render" {', -- 1
  '  var want = `<ul>', -- 2
  '<li>a</li>', -- 3
  '</ul>`', -- 4
  '  assert(render() == want)', -- 5
  '  var s = "one', -- 6
  'two \\" } ${f("x")}', -- 7
  'three"', -- 8
  '/* a', -- 9
  'test "no" {', -- 10
  '*/', -- 11
  '// test "nor" {', -- 12
  '  check()', -- 13
  '}', -- 14
}
for _, synon in ipairs({ false, true }) do
  local tb = h.buffer(text, 'render_test.ant')
  if not synon then
    vim.cmd('syntax off')
  end
  local how = synon and ' with syntax' or ' without syntax'
  h.eq(synon and 'ant' or nil, vim.b[tb].current_syntax, 'syntax' .. how)
  h.eq('^render$', test.nearest(tb, 3), 'in a raw string' .. how)
  h.eq('^render$', test.nearest(tb, 5), 'after a raw string' .. how)
  h.eq('^render$', test.nearest(tb, 8), 'in a string' .. how)
  h.eq('^render$', test.nearest(tb, 13), 'after comments' .. how)
  h.eq('^render$', test.nearest(tb, 14), 'on the closing brace' .. how)
  vim.cmd('syntax on')
  vim.cmd('silent! bwipeout!')
end

local ant = h.ant()
if not ant then
  io.stdout:write('skipped: no ant; set ANT_PATH\n')
  return
end
vim.g.ant = { path = ant }

local function wait(what, cond, ms)
  if not vim.wait(ms or 10000, cond, 20) then
    error('timed out waiting for ' .. what, 2)
  end
end

-- terminal_output waits for the job of the terminal buffer buf to end and returns its text.
local function terminal_output(buf)
  local job = vim.b[buf].terminal_job_id
  h.eq({ 0 }, vim.tbl_map(function(c)
    return c >= 0 and 0 or c
  end, vim.fn.jobwait({ job }, 10000)), 'the job ended')
  local text
  wait('the output', function()
    text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
    return text:find('%(%d+%.%d+s%)') ~= nil
  end)
  return text
end

local buf, file = h.buffer({
  'test "a" {',
  '  println("in a")',
  '  assert(1 == 1)',
  '}',
  '',
  'test "b" {',
  '  test "x.y" {',
  '    assert(1 == 2)',
  '  }',
  '}',
}, 'm_test.ant')
vim.fn.writefile({ 'var m = 1' }, vim.fs.joinpath(vim.fs.dirname(file), 'm.ant'))

-- The server's code lenses, two per test, are shown.
local function client()
  return vim.lsp.get_clients({ bufnr = buf, name = 'ant' })[1]
end
wait('the client', function()
  return client() ~= nil and client().initialized
end)
local lenses
wait('code lenses', function()
  if vim.lsp.codelens.enable then
    -- Neovim 0.12 returns each lens with its client.
    lenses = vim.tbl_map(function(r)
      return r.lens
    end, vim.lsp.codelens.get({ bufnr = buf }))
  else
    lenses = vim.lsp.codelens.get(buf)
  end
  return #lenses == 6 and lenses[6].command ~= nil
end)
table.sort(lenses, function(x, y)
  return x.range.start.line * 10 + #x.command.command < y.range.start.line * 10 + #y.command.command
end)
h.eq({ 'ant.test.run', vim.uri_from_bufnr(buf), '^a$' }, { lenses[1].command.command, unpack(lenses[1].command.arguments) }, 'run lens')
h.eq('ant.test.debug', lenses[2].command.command, 'debug lens')
h.eq('^b$/^x\\.y( #[0-9]+)?$', lenses[6].command.arguments[2], 'subtest lens')

-- Running a lens runs ant test with its pattern in a terminal.
client():exec_cmd(lenses[1].command, { bufnr = buf })
local term = vim.api.nvim_get_current_buf()
h.eq('terminal', vim.bo[term].buftype, 'a terminal')
local out = terminal_output(term)
assert(out:find('ok    1 passed', 1, true), out)
vim.cmd.bwipeout({ term, bang = true })

-- :Ant test runs the file's tests, with a pattern if given; from the companion as well.
vim.cmd.buffer(buf)
vim.cmd('Ant test ^b$')
out = terminal_output(vim.api.nvim_get_current_buf())
assert(out:find('FAIL  1 failed, 0 passed', 1, true), out)
vim.cmd('bwipeout!')
vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(vim.fs.dirname(file), 'm.ant')))
vim.cmd('Ant test')
out = terminal_output(vim.api.nvim_get_current_buf())
assert(out:find('FAIL  1 failed, 1 passed', 1, true), out)
vim.cmd('bwipeout!')

-- :Ant test-nearest runs the test the cursor is in.
vim.cmd.buffer(buf)
vim.api.nvim_win_set_cursor(0, { 3, 0 })
vim.cmd('Ant test-nearest')
out = terminal_output(vim.api.nvim_get_current_buf())
assert(out:find('ok    1 passed', 1, true), out)
vim.cmd('bwipeout!')
vim.cmd.buffer(buf)

-- Debugging a lens launches ant dap with the lens's pattern as test.
local real = pcall(require, 'dap')
if not real then
  local launched
  package.loaded.dap = {
    adapters = {},
    configurations = {},
    run = function(config)
      launched = config
    end,
  }
  client():exec_cmd(lenses[6].command, { bufnr = buf })
  h.eq('ant', launched.type, 'dap type')
  h.eq('launch', launched.request, 'dap request')
  h.eq(vim.uri_to_fname(vim.uri_from_bufnr(buf)), launched.program, 'dap program')
  h.eq('^b$/^x\\.y( #[0-9]+)?$', launched.test, 'dap test')
  package.loaded.dap = nil
  io.stdout:write('nvim-dap not found: checked the launch configuration only\n')
  return
end

-- With nvim-dap: a breakpoint in the chosen test stops it, and the run ends with ant test's status.
local dap = require('dap')
require('ant.dap').setup()
vim.api.nvim_win_set_cursor(0, { 2, 0 })
dap.toggle_breakpoint()
local stopped, exited, console = nil, nil, {}
dap.listeners.after.event_stopped['test'] = function(_, body)
  stopped = body
end
dap.listeners.after.event_exited['test'] = function(_, body)
  exited = body
end
dap.listeners.after.event_output['test'] = function(_, body)
  table.insert(console, body.output)
end
client():exec_cmd(lenses[2].command, { bufnr = buf })
wait('the breakpoint', function()
  return stopped ~= nil
end)
h.eq('breakpoint', stopped.reason, 'stop reason')
local session = assert(dap.session())
wait('the frame', function()
  return session.current_frame ~= nil
end)
h.eq(2, session.current_frame.line, 'stopped in test a')
dap.continue()
wait('the exit', function()
  return exited ~= nil
end)
h.eq(0, exited.exitCode, 'only test a ran, and passed')
local text = table.concat(console)
assert(text:find('in a', 1, true), text)
assert(not text:find('x.y', 1, true), text)
