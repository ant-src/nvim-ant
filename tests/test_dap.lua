local h = dofile('tests/helpers.lua')

local ant = h.ant()
if not ant then
  io.stdout:write('skipped: no ant; set ANT_PATH\n')
  return
end
vim.g.ant = { path = ant }

local real = pcall(require, 'dap')

if not real then
  -- Without nvim-dap, a stand-in checks what the plugin registers.
  package.loaded.dap = { adapters = {}, configurations = {} }
  local dap = require('dap')
  h.eq(true, require('ant.dap').setup(), 'setup with dap')
  h.eq('${file}', dap.configurations.ant[1].program, 'default configuration')

  local cwd = vim.fn.getcwd()
  local adapter
  dap.adapters.ant(function(a)
    adapter = a
  end, { program = '/x/main.ant' })
  h.eq('executable', adapter.type, 'adapter type')
  h.eq(ant, adapter.command, 'adapter command')
  h.eq({ 'dap' }, adapter.args, 'adapter args')
  h.eq('/x', adapter.options.cwd, 'adapter cwd is the program directory')

  local enriched
  adapter.enrich_config({ program = 'a/main.ant', stdin = '/in.txt', cwd = 'b' }, function(c)
    enriched = c
  end)
  h.eq(vim.fs.joinpath(cwd, 'a/main.ant'), enriched.program, 'relative program')
  h.eq(vim.fs.joinpath(cwd, 'b'), enriched.cwd, 'relative cwd')
  h.eq('/in.txt', enriched.stdin, 'absolute stdin')

  -- A configuration of the user's own is kept.
  dap.configurations.ant = { { name = 'mine' } }
  require('ant.dap').setup()
  h.eq('mine', dap.configurations.ant[1].name, 'own configuration kept')
  io.stdout:write('nvim-dap not found: checked the registration only\n')
  return
end

-- With nvim-dap: a breakpoint stops the program, and continuing runs it to the end.
local dap = require('dap')
local buf, file = h.buffer({
  'var x = 1',
  'println(x)',
  'println(x + 1)',
}, 'main.ant')
require('ant.dap').setup()
vim.api.nvim_win_set_cursor(0, { 2, 0 })
dap.toggle_breakpoint()

local stopped, exited, output = nil, nil, {}
dap.listeners.after.event_stopped['test'] = function(_, body)
  stopped = body
end
dap.listeners.after.event_exited['test'] = function(_, body)
  exited = body
end
dap.listeners.after.event_output['test'] = function(_, body)
  if body.category == 'stdout' then
    table.insert(output, body.output)
  end
end

vim.cmd('Ant debug')
assert(vim.wait(10000, function()
  return stopped ~= nil
end, 20), 'the breakpoint was not hit')
h.eq('breakpoint', stopped.reason, 'stop reason')
local session = assert(dap.session())
local frame = session.current_frame
h.eq(2, frame and frame.line, 'stopped at line 2')
h.eq(vim.uv.fs_realpath(file), vim.uv.fs_realpath(frame.source.path), 'stopped in the file')

dap.continue()
assert(vim.wait(10000, function()
  return exited ~= nil
end, 20), 'the program did not exit')
h.eq(0, exited.exitCode, 'exit code')
h.eq('1\n2\n', table.concat(output), 'program output')
_ = buf
