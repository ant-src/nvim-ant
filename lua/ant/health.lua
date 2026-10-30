-- :checkhealth ant
local M = {}

function M.check()
  local health = vim.health
  health.start('ant')

  if vim.fn.has('nvim-0.11') == 1 then
    health.ok('Neovim ' .. tostring(vim.version()))
  else
    health.error('Neovim 0.11 or later is needed', { 'Upgrade Neovim' })
  end

  local ant = require('ant').find()
  if not ant then
    health.error('ant not found', {
      'Install it with: go install github.com/ant-src/ant/cmd/ant@latest',
      'Or set vim.g.ant = { path = "/path/to/ant" }',
    })
  else
    local res = vim.system({ ant, 'help' }, { text = true }):wait(5000)
    local usage = (res.stdout or '') .. (res.stderr or '')
    health.ok('ant: ' .. ant)
    for _, cmd in ipairs({ 'lsp', 'dap' }) do
      if usage:find('ant ' .. cmd, 1, true) then
        health.ok('ant ' .. cmd .. ' is available')
      else
        health.warn('this ant has no `ant ' .. cmd .. '`', { 'Install a newer ant' })
      end
    end
  end

  local opts = require('ant').options()
  if not opts.lsp then
    health.info('the language server is off (vim.g.ant.lsp = false)')
  elseif vim.lsp.is_enabled('ant') then
    local clients = vim.lsp.get_clients({ name = 'ant' })
    health.ok(('the language server is enabled, %d running'):format(#clients))
  else
    health.warn('the language server is not enabled', { "Call vim.lsp.enable('ant')" })
  end

  if not opts.dap then
    health.info('debugging is off (vim.g.ant.dap = false)')
  elseif pcall(require, 'dap') then
    health.ok('nvim-dap is installed: :Ant debug debugs the current file')
  else
    health.info('nvim-dap is not installed; install it to debug with ant dap')
  end
end

return M
